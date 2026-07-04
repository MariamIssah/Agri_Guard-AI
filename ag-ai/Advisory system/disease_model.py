"""
Plant Disease Image Classifier
Uses MobileNetV3-Small (pretrained ImageNet) as backbone.
Training time: ~15-30 min on CPU, ~5 min on GPU  (vs hours for custom CNN).
"""
from __future__ import annotations  # makes all annotations lazy strings — safe without torch

import argparse
import json
import os
import pickle
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image

# PyTorch imports are optional — only needed for local training, not for
# ONNX-based inference on the server. Wrap so the module loads without them.
try:
    import matplotlib.pyplot as plt
    import torch
    import torch.nn as nn
    import torch.optim as optim
    import torch.nn.functional as F
    from sklearn.model_selection import train_test_split
    from sklearn.preprocessing import LabelEncoder
    from torch.utils.data import Dataset, DataLoader
    from torchvision import transforms, models
    from tqdm import tqdm
    _TORCH_AVAILABLE = True
except ImportError:
    _TORCH_AVAILABLE = False
    # Stub base class so class definitions below don't crash at import time
    class Dataset:  # type: ignore
        pass
    class nn:  # type: ignore
        class Module:
            pass


# ── Dataset ────────────────────────────────────────────────────────────────────

class PlantDiseaseDataset(Dataset):
    def __init__(self, image_paths, labels, transform=None):
        self.image_paths = image_paths
        self.labels = labels
        self.transform = transform

    def __len__(self):
        return len(self.labels)

    def __getitem__(self, idx):
        image = Image.open(self.image_paths[idx]).convert('RGB')
        if self.transform:
            image = self.transform(image)
        return image, torch.tensor(self.labels[idx], dtype=torch.long)


# ── Model: MobileNetV3-Small backbone + custom head ───────────────────────────

class PlantDiseaseModel(nn.Module):
    """
    MobileNetV3-Small pretrained on ImageNet, with a custom classifier head.
    ~2.5M parameters vs ~14M for the old custom CNN — trains much faster and
    achieves higher accuracy via transfer learning.
    """

    def __init__(self, num_classes: int, dropout_rate: float = 0.4, freeze_backbone: bool = False):
        super().__init__()
        backbone = models.mobilenet_v3_small(weights=models.MobileNet_V3_Small_Weights.IMAGENET1K_V1)

        if freeze_backbone:
            for param in backbone.features.parameters():
                param.requires_grad = False

        in_features = backbone.classifier[3].in_features
        backbone.classifier[3] = nn.Sequential(
            nn.Dropout(p=dropout_rate),
            nn.Linear(in_features, num_classes),
        )
        self.model = backbone

    def forward(self, x):
        return self.model(x)


# ── Early stopping ─────────────────────────────────────────────────────────────

class EarlyStopping:
    def __init__(self, patience=7, min_delta=0.001, save_path='best_disease_model.pth'):
        self.patience = patience
        self.min_delta = min_delta
        self.save_path = save_path
        self.best_loss = float('inf')
        self.counter = 0

    def __call__(self, val_loss, model):
        if val_loss < self.best_loss - self.min_delta:
            self.best_loss = val_loss
            self.counter = 0
            Path(self.save_path).parent.mkdir(parents=True, exist_ok=True)
            torch.save(model.state_dict(), self.save_path)
            print(f'[INFO] Best model saved → {self.save_path}')
            return False
        self.counter += 1
        if self.counter >= self.patience:
            print('[INFO] Early stopping triggered.')
            return True
        return False


# ── Data utilities ─────────────────────────────────────────────────────────────

def extract_dataset(data_path: str, extract_root: Path) -> Path:
    source = Path(data_path)
    if source.is_dir():
        return source
    if source.is_file() and source.suffix.lower() == '.zip':
        extract_root.mkdir(parents=True, exist_ok=True)
        out_dir = extract_root / source.stem.replace(' ', '_')
        if not out_dir.exists():
            print(f'[INFO] Extracting {source.name} → {out_dir}')
            with zipfile.ZipFile(source, 'r') as zf:
                zf.extractall(out_dir)
        return out_dir
    raise FileNotFoundError(f'Dataset not found: {data_path}')


def load_images(directory_root: Path):
    image_paths, labels = [], []
    print(f'[INFO] Scanning {directory_root}')
    for root, _, files in os.walk(directory_root):
        for filename in files:
            if filename.startswith('.'):
                continue
            path = Path(root) / filename
            if path.suffix.lower() in {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}:
                label = path.parent.name
                if label.lower() in {'train', 'validation', 'valid', 'val', 'test'}:
                    label = path.parent.parent.name
                image_paths.append(str(path))
                labels.append(label)

    if not image_paths:
        raise ValueError(f'No images found under: {directory_root}')
    print(f'[INFO] Found {len(image_paths)} images across {len(set(labels))} classes')
    return image_paths, labels


def prepare_data(
    directory_root: Path,
    image_size=(224, 224),
    batch_size=32,
    test_size=0.25,
    valid_ratio=0.5,
    random_state=42,
    num_workers=0,
):
    image_paths, raw_labels = load_images(directory_root)

    label_encoder = LabelEncoder()
    labels_enc = label_encoder.fit_transform(raw_labels)
    class_names = list(label_encoder.classes_)

    X_train, X_tmp, y_train, y_tmp = train_test_split(
        image_paths, labels_enc,
        test_size=test_size, random_state=random_state, stratify=labels_enc,
    )
    X_val, X_test, y_val, y_test = train_test_split(
        X_tmp, y_tmp,
        test_size=valid_ratio, random_state=random_state, stratify=y_tmp,
    )

    print(f'[INFO] Train: {len(X_train)}, Val: {len(X_val)}, Test: {len(X_test)}')

    # MobileNetV3 expects 224×224 and ImageNet normalisation
    train_tf = transforms.Compose([
        transforms.Resize(image_size),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(),
        transforms.RandomRotation(20),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.15, hue=0.05),
        transforms.RandomAffine(degrees=0, translate=(0.05, 0.05)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    eval_tf = transforms.Compose([
        transforms.Resize(image_size),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])

    train_dl = DataLoader(
        PlantDiseaseDataset(X_train, y_train, train_tf),
        batch_size=batch_size, shuffle=True, num_workers=num_workers, pin_memory=True,
    )
    val_dl = DataLoader(
        PlantDiseaseDataset(X_val, y_val, eval_tf),
        batch_size=batch_size, shuffle=False, num_workers=num_workers,
    )
    test_dl = DataLoader(
        PlantDiseaseDataset(X_test, y_test, eval_tf),
        batch_size=batch_size, shuffle=False, num_workers=num_workers,
    )

    return train_dl, val_dl, test_dl, len(class_names), label_encoder, class_names, eval_tf


# ── Training loop ──────────────────────────────────────────────────────────────

def evaluate_model(model, loader, criterion, device):
    model.eval()
    total_loss, correct, total = 0.0, 0, 0
    all_preds, all_labels = [], []

    with torch.no_grad():
        for inputs, labels in tqdm(loader, desc='Eval', leave=False):
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            total_loss += loss.item()
            _, predicted = torch.max(outputs, 1)
            correct += (predicted == labels).sum().item()
            total += labels.size(0)
            all_preds.extend(predicted.cpu().tolist())
            all_labels.extend(labels.cpu().tolist())

    return (
        total_loss / len(loader),
        correct / total * 100 if total else 0.0,
        np.array(all_preds),
        np.array(all_labels),
    )


def train_model(
    model, train_loader, valid_loader, criterion, optimizer,
    scheduler=None, epochs=20, early_stopping=None, device='cpu',
    use_amp=False,
):
    model.to(device)
    scaler = torch.amp.GradScaler('cuda') if use_amp and device.type == 'cuda' else None
    train_losses, val_losses, val_accs = [], [], []

    for epoch in range(epochs):
        model.train()
        running_loss = 0.0

        for inputs, labels in tqdm(train_loader, desc=f'Epoch {epoch+1}/{epochs}', leave=False):
            inputs, labels = inputs.to(device), labels.to(device)
            optimizer.zero_grad()

            if scaler:
                with torch.amp.autocast('cuda'):
                    outputs = model(inputs)
                    loss = criterion(outputs, labels)
                scaler.scale(loss).backward()
                scaler.step(optimizer)
                scaler.update()
            else:
                outputs = model(inputs)
                loss = criterion(outputs, labels)
                loss.backward()
                optimizer.step()

            running_loss += loss.item()

        train_loss = running_loss / len(train_loader)
        val_loss, val_acc, _, _ = evaluate_model(model, valid_loader, criterion, device)

        train_losses.append(train_loss)
        val_losses.append(val_loss)
        val_accs.append(val_acc)

        print(f'Epoch {epoch+1:3d}: train_loss={train_loss:.4f}  val_loss={val_loss:.4f}  val_acc={val_acc:.2f}%')

        if scheduler:
            scheduler.step(val_loss)
        if early_stopping and early_stopping(val_loss, model):
            break

    _save_curves(train_losses, val_losses, val_accs)
    return train_losses, val_losses, val_accs


def _save_curves(train_losses, val_losses, val_accs):
    plt.figure(figsize=(12, 5))
    plt.subplot(1, 2, 1)
    plt.plot(train_losses, label='Train Loss')
    plt.plot(val_losses, label='Val Loss')
    plt.xlabel('Epoch'); plt.ylabel('Loss'); plt.legend(); plt.title('Loss')

    plt.subplot(1, 2, 2)
    plt.plot(val_accs, label='Val Accuracy', color='green')
    plt.xlabel('Epoch'); plt.ylabel('Accuracy (%)'); plt.legend(); plt.title('Accuracy')

    plt.tight_layout()
    plt.savefig('learning_curves.png')
    plt.close()
    print('[INFO] Saved learning_curves.png')


# ── Inference asset save / load ────────────────────────────────────────────────

def save_inference_components(model, model_dir, label_encoder, transform, class_names, model_save_path, image_size=(224, 224)):
    model_dir = Path(model_dir)
    model_dir.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), model_save_path)

    with open(model_dir / 'label_encoder.pkl', 'wb') as f:
        pickle.dump(label_encoder, f)
    with open(model_dir / 'inference_transform.pkl', 'wb') as f:
        pickle.dump(transform, f)

    config = {
        'model_path': Path(model_save_path).name,
        'label_encoder_path': 'label_encoder.pkl',
        'transform_path': 'inference_transform.pkl',
        'class_names_path': 'class_names.json',
        'image_size': list(image_size),
        'num_classes': len(class_names),
        'classes': class_names,
        'backbone': 'mobilenet_v3_small',
    }
    with open(model_dir / 'class_names.json', 'w') as f:
        json.dump(class_names, f, indent=2)
    with open(model_dir / 'model_config.json', 'w') as f:
        json.dump(config, f, indent=2)

    print(f'[INFO] Inference assets saved → {model_dir}')


def get_device():
    if not _TORCH_AVAILABLE:
        raise RuntimeError('PyTorch is not installed')
    return torch.device('cuda' if torch.cuda.is_available() else 'cpu')


def _detect_arch(state_keys: list) -> str:
    """Infer saved model architecture from state-dict key names."""
    keys = set(state_keys)
    if 'model.features.0.0.weight' in keys:
        return 'mobilenet_v3_small'
    if 'conv1.weight' in keys and any(k.startswith('layer1.') for k in keys):
        return 'resnet18'
    if any(k.startswith('conv_block1.') for k in keys):
        return 'custom_cnn'
    return 'mobilenet_v3_small'  # best default for new models


def _build_model(arch: str, num_classes: int) -> nn.Module:
    """Construct the correct model class for the detected architecture."""
    from torchvision import models as tvm
    if arch == 'resnet18':
        m = tvm.resnet18(weights=None)
        m.fc = nn.Sequential(nn.Dropout(p=0.3), nn.Linear(m.fc.in_features, num_classes))
        return m
    if arch == 'resnet50':
        m = tvm.resnet50(weights=None)
        m.fc = nn.Sequential(nn.Dropout(p=0.3), nn.Linear(m.fc.in_features, num_classes))
        return m
    # MobileNetV3-Small (new default) or fallback
    return PlantDiseaseModel(num_classes=num_classes, dropout_rate=0.4)


def load_inference_assets(model_dir: str, device: torch.device = None):
    """
    Load inference assets. Prefers ONNX Runtime (no PyTorch needed on server).
    Falls back to PyTorch if .onnx is missing but .pth is present.
    """
    model_dir = Path(model_dir)
    if not model_dir.exists():
        raise FileNotFoundError(f'Disease model directory not found: {model_dir}')

    with open(model_dir / 'model_config.json') as f:
        config = json.load(f)

    with open(model_dir / 'label_encoder.pkl', 'rb') as f:
        label_encoder = pickle.load(f)

    class_names = config.get('classes', [])

    onnx_path = model_dir / 'disease_model.onnx'

    # ── Try ONNX Runtime first (lightweight, no PyTorch needed) ──────────────
    try:
        import onnxruntime as ort
        if onnx_path.exists():
            sess = ort.InferenceSession(str(onnx_path), providers=['CPUExecutionProvider'])
            print(f'[INFO] Disease model loaded via ONNX Runtime: {onnx_path}')
            return {
                'onnx_session': sess,
                'label_encoder': label_encoder,
                'class_names': class_names,
                'backend': 'onnx',
            }
    except ImportError:
        pass

    # ── Fallback: PyTorch (for local training/development) ───────────────────
    if not _TORCH_AVAILABLE:
        raise RuntimeError(
            'onnxruntime is not installed and PyTorch is not available. '
            'Install onnxruntime to run inference without PyTorch.'
        )

    with open(model_dir / 'inference_transform.pkl', 'rb') as f:
        transform = pickle.load(f)

    if device is None:
        device = get_device()

    num_classes = config['num_classes']
    state = torch.load(model_dir / config['model_path'], map_location=device, weights_only=True)

    arch = config.get('backbone') or _detect_arch(list(state.keys()))
    print(f'[INFO] Disease model loaded via PyTorch ({arch})')
    model = _build_model(arch, num_classes)
    model.load_state_dict(state)
    model.to(device)
    model.eval()

    return {
        'model': model,
        'transform': transform,
        'label_encoder': label_encoder,
        'class_names': class_names,
        'device': device,
        'backend': 'torch',
    }


# ImageNet normalisation constants
_IMAGENET_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
_IMAGENET_STD  = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def _enhance_image(img: Image.Image) -> Image.Image:
    """
    Adaptive contrast enhancement for real-world farm photos.

    Farmers often photograph immediately after watering, in harsh sunlight,
    or in low-light shade. Water droplets create specular highlights that
    wash out leaf texture. This normalises the per-channel intensity so the
    model sees leaf features rather than glare or darkness.

    Technique: percentile contrast stretching (p2–p98) per RGB channel.
    Clips the brightest 2% (glare/water) and darkest 2% (shadow) then
    rescales to the full 0-255 range.
    """
    arr = np.array(img, dtype=np.float32)
    for c in range(3):
        ch = arr[:, :, c]
        lo, hi = np.percentile(ch, (2, 98))
        if hi > lo:
            arr[:, :, c] = np.clip((ch - lo) / (hi - lo) * 255.0, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def _preprocess_image_numpy(image_path: str, image_size: int = 224) -> np.ndarray:
    """Preprocess an image for ONNX inference — no torchvision needed."""
    img = Image.open(image_path).convert('RGB').resize((image_size, image_size))
    img = _enhance_image(img)                               # remove glare/shadow
    arr = np.array(img, dtype=np.float32) / 255.0          # HWC, [0,1]
    arr = (arr - _IMAGENET_MEAN) / _IMAGENET_STD           # ImageNet normalise
    arr = arr.transpose(2, 0, 1)[np.newaxis, :]            # NCHW
    return arr


def predict_image(model, image_path, transform, device, label_encoder=None):
    model.eval()
    image = Image.open(image_path).convert('RGB')
    tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        out = model(tensor)
        probs = F.softmax(out, dim=1)[0]
        conf, idx = torch.max(probs, 0)

    idx_val = idx.item()
    conf_pct = float(conf.item() * 100)
    prob_list = probs.cpu().numpy().tolist()

    if label_encoder is not None:
        label = label_encoder.inverse_transform([idx_val])[0]
        return label, conf_pct, prob_list

    return idx_val, conf_pct, prob_list


def infer_image(image_path: str, model_assets: dict):
    backend = model_assets.get('backend', 'torch')

    if backend == 'onnx':
        import onnxruntime as ort  # already available if backend == onnx
        sess: ort.InferenceSession = model_assets['onnx_session']
        label_encoder = model_assets['label_encoder']

        arr = _preprocess_image_numpy(image_path)
        logits = sess.run(['logits'], {'image': arr})[0]

        # Softmax
        e = np.exp(logits - logits.max(axis=1, keepdims=True))
        probs = (e / e.sum(axis=1, keepdims=True))[0]

        top_idx  = int(np.argmax(probs))
        conf_pct = float(probs[top_idx] * 100)
        label    = label_encoder.inverse_transform([top_idx])[0]
        return label, conf_pct, probs.tolist()

    return predict_image(
        model=model_assets['model'],
        image_path=image_path,
        transform=model_assets['transform'],
        device=model_assets['device'],
        label_encoder=model_assets['label_encoder'],
    )


# ── Main training entry point ──────────────────────────────────────────────────

def train(
    data_path: str,
    model_dir: str = 'models/disease',
    model_filename: str = 'disease_model.pth',
    batch_size: int = 32,
    epochs: int = 25,
    learning_rate: float = 3e-4,
    image_size: int = 224,
    test_size: float = 0.25,
    valid_ratio: float = 0.5,
    patience: int = 7,
    freeze_epochs: int = 3,
):
    """
    Two-phase training:
      Phase 1 (freeze_epochs): only the classifier head trains — fast warm-up.
      Phase 2: full fine-tune with a lower LR — extracts domain-specific features.
    """
    dataset_root = extract_dataset(data_path, Path('data'))
    train_dl, val_dl, test_dl, num_classes, label_encoder, class_names, eval_tf = prepare_data(
        dataset_root, image_size=(image_size, image_size),
        batch_size=batch_size, test_size=test_size, valid_ratio=valid_ratio,
    )

    model_dir_path = Path(model_dir)
    model_dir_path.mkdir(parents=True, exist_ok=True)
    model_save = model_dir_path / model_filename

    device = get_device()
    use_amp = device.type == 'cuda'
    print(f'[INFO] Device: {device}  |  Classes: {num_classes}  |  AMP: {use_amp}')

    # ── Phase 1: frozen backbone, train head only ──────────────────────────────
    if freeze_epochs > 0:
        print(f'\n── Phase 1: Warm-up ({freeze_epochs} epochs, backbone frozen) ──')
        model = PlantDiseaseModel(num_classes, dropout_rate=0.4, freeze_backbone=True)
        model.to(device)
        criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
        optimizer = optim.AdamW(
            filter(lambda p: p.requires_grad, model.parameters()),
            lr=learning_rate * 3, weight_decay=1e-4,
        )
        early_stop = EarlyStopping(patience=3, save_path=str(model_save))
        train_model(model, train_dl, val_dl, criterion, optimizer,
                    epochs=freeze_epochs, early_stopping=early_stop, device=device, use_amp=use_amp)
        model.load_state_dict(torch.load(model_save, map_location=device))
        # Unfreeze backbone
        for param in model.model.features.parameters():
            param.requires_grad = True
    else:
        model = PlantDiseaseModel(num_classes, dropout_rate=0.4, freeze_backbone=False)
        model.to(device)
        criterion = nn.CrossEntropyLoss(label_smoothing=0.1)

    # ── Phase 2: full fine-tune ────────────────────────────────────────────────
    print(f'\n── Phase 2: Full fine-tune ({epochs} epochs) ──')
    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    optimizer = optim.AdamW(model.parameters(), lr=learning_rate, weight_decay=1e-4)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.3, patience=3)
    early_stop = EarlyStopping(patience=patience, save_path=str(model_save))

    train_model(model, train_dl, val_dl, criterion, optimizer,
                scheduler=scheduler, epochs=epochs, early_stopping=early_stop,
                device=device, use_amp=use_amp)

    model.load_state_dict(torch.load(model_save, map_location=device))
    test_loss, test_acc, _, _ = evaluate_model(model, test_dl, criterion, device)
    print(f'\n[RESULT] Test Loss: {test_loss:.4f}  |  Test Accuracy: {test_acc:.2f}%')

    save_inference_components(
        model=model, model_dir=model_dir_path, label_encoder=label_encoder,
        transform=eval_tf, class_names=class_names,
        model_save_path=model_save, image_size=(image_size, image_size),
    )
    print('[INFO] Training complete.')
    return model


def parse_args():
    p = argparse.ArgumentParser(description='Train plant disease classifier (MobileNetV3)')
    p.add_argument('--data-path', required=True, help='Dataset directory or zip archive')
    p.add_argument('--model-dir', default='models/disease', help='Output model directory')
    p.add_argument('--model-filename', default='disease_model.pth')
    p.add_argument('--batch-size', type=int, default=32)
    p.add_argument('--epochs', type=int, default=25, help='Fine-tune epochs (Phase 2)')
    p.add_argument('--freeze-epochs', type=int, default=3, help='Warm-up epochs (Phase 1, frozen backbone)')
    p.add_argument('--learning-rate', type=float, default=3e-4)
    p.add_argument('--image-size', type=int, default=224)
    p.add_argument('--test-size', type=float, default=0.25)
    p.add_argument('--valid-ratio', type=float, default=0.5)
    p.add_argument('--patience', type=int, default=7)
    return p.parse_args()


if __name__ == '__main__':
    args = parse_args()
    train(
        data_path=args.data_path,
        model_dir=args.model_dir,
        model_filename=args.model_filename,
        batch_size=args.batch_size,
        epochs=args.epochs,
        freeze_epochs=args.freeze_epochs,
        learning_rate=args.learning_rate,
        image_size=args.image_size,
        test_size=args.test_size,
        valid_ratio=args.valid_ratio,
        patience=args.patience,
    )
