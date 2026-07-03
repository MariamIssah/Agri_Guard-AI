"""
Fine-tune the existing disease model.

Loads the Phase-1 (head-only) checkpoint, unfreezes the full backbone,
and trains with a low LR for better feature adaptation.

Usage:
    python finetune_disease_model.py
    python finetune_disease_model.py --epochs 20 --lr 5e-5
"""

import argparse, json, os, pickle
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
from PIL import Image
from torch.utils.data import Dataset, DataLoader
from torchvision import transforms, models
from tqdm import tqdm

MODEL_DIR   = Path('models/disease')
DATA_DIR    = Path('data/plantvillage')
ARCH        = 'resnet18'
NUM_CLASSES = 38
IMG_SIZE    = 224
BATCH_SIZE  = 32
CAP_PER_CLASS = 250


# ── Dataset ────────────────────────────────────────────────────────────────────

class PlantVillageDataset(Dataset):
    def __init__(self, samples, transform=None):
        self.samples   = samples   # list of (path, label_idx)
        self.transform = transform

    def __len__(self):  return len(self.samples)

    def __getitem__(self, idx):
        path, label = self.samples[idx]
        img = Image.open(path).convert('RGB')
        if self.transform:
            img = self.transform(img)
        return img, label


def _build_model(num_classes):
    m = models.resnet18(weights=None)
    m.fc = nn.Sequential(nn.Dropout(p=0.3), nn.Linear(m.fc.in_features, num_classes))
    return m


def load_data(data_dir: Path, model_dir: Path, img_size=224, batch_size=32):
    # Use EXACTLY the same class names the model was trained on
    class_names = json.loads((model_dir / 'class_names.json').read_text())
    class_to_idx = {c: i for i, c in enumerate(class_names)}
    print(f'Using {len(class_names)} classes from saved model config')

    all_samples = []
    for cls in class_names:
        cls_dir = data_dir / cls
        if not cls_dir.exists():
            continue
        files = list(cls_dir.glob('*.jpg')) + list(cls_dir.glob('*.JPG')) + \
                list(cls_dir.glob('*.png'))
        files = files[:CAP_PER_CLASS]
        for f in files:
            all_samples.append((f, class_to_idx[cls]))

    # 80/20 train/val split
    import random; random.seed(42)
    random.shuffle(all_samples)
    split = int(0.8 * len(all_samples))
    train_samples, val_samples = all_samples[:split], all_samples[split:]

    train_tf = transforms.Compose([
        transforms.RandomResizedCrop(img_size, scale=(0.5, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(),
        transforms.RandomPerspective(distortion_scale=0.3, p=0.4),
        transforms.ColorJitter(brightness=0.5, contrast=0.4, saturation=0.4, hue=0.15),
        transforms.RandomGrayscale(p=0.1),
        transforms.RandomRotation(45),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        transforms.RandomErasing(p=0.2, scale=(0.02, 0.15)),
    ])
    val_tf = transforms.Compose([
        transforms.Resize(int(img_size * 1.14)),
        transforms.CenterCrop(img_size),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    train_dl = DataLoader(PlantVillageDataset(train_samples, train_tf),
                          batch_size=batch_size, shuffle=True,
                          num_workers=0, pin_memory=False)
    val_dl   = DataLoader(PlantVillageDataset(val_samples, val_tf),
                          batch_size=batch_size, shuffle=False,
                          num_workers=0, pin_memory=False)
    return train_dl, val_dl, class_names


def finetune(epochs=15, lr=3e-5, patience=5):
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f'Device: {device}')

    # Load existing weights
    model = _build_model(NUM_CLASSES)
    ckpt  = MODEL_DIR / 'disease_model.pth'
    model.load_state_dict(torch.load(ckpt, map_location=device))
    model.to(device)
    print(f'Loaded checkpoint: {ckpt}')

    # Unfreeze ALL layers (full fine-tune with low LR)
    for p in model.parameters():
        p.requires_grad = True
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f'Trainable parameters: {trainable:,} (full backbone unfrozen)')

    train_dl, val_dl, class_names = load_data(DATA_DIR, MODEL_DIR, IMG_SIZE, BATCH_SIZE)
    print(f'Train: {len(train_dl.dataset):,}  Val: {len(val_dl.dataset):,}')

    criterion = nn.CrossEntropyLoss(label_smoothing=0.1)
    # Discriminative LRs: backbone much lower than head
    optimizer = optim.AdamW([
        {'params': model.layer1.parameters(), 'lr': lr * 0.1},
        {'params': model.layer2.parameters(), 'lr': lr * 0.2},
        {'params': model.layer3.parameters(), 'lr': lr * 0.5},
        {'params': model.layer4.parameters(), 'lr': lr * 0.8},
        {'params': model.fc.parameters(),     'lr': lr},
    ], weight_decay=1e-4)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)

    best_acc, no_improve = 0.0, 0
    for epoch in range(1, epochs + 1):
        # Train
        model.train()
        correct, total, running_loss = 0, 0, 0.0
        for imgs, labels in tqdm(train_dl, desc=f'Epoch {epoch:02d}/{epochs}', leave=False):
            imgs, labels = imgs.to(device), labels.to(device)
            optimizer.zero_grad()
            out  = model(imgs)
            loss = criterion(out, labels)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            running_loss += loss.item() * imgs.size(0)
            correct      += (out.argmax(1) == labels).sum().item()
            total        += imgs.size(0)
        train_acc  = correct / total
        train_loss = running_loss / total

        # Validate
        model.eval()
        correct, total, val_loss = 0, 0, 0.0
        with torch.no_grad():
            for imgs, labels in val_dl:
                imgs, labels = imgs.to(device), labels.to(device)
                out   = model(imgs)
                loss  = criterion(out, labels)
                val_loss += loss.item() * imgs.size(0)
                correct  += (out.argmax(1) == labels).sum().item()
                total    += imgs.size(0)
        val_acc  = correct / total
        val_loss = val_loss / total

        scheduler.step()
        print(f'Epoch {epoch:02d}/{epochs}  train {train_loss:.4f}/{train_acc:.4f}'
              f'  val {val_loss:.4f}/{val_acc:.4f}', end='')

        if val_acc > best_acc:
            best_acc = val_acc
            torch.save(model.state_dict(), ckpt)
            print(f'  >> saved best (val_acc={best_acc:.4f})')
            no_improve = 0
        else:
            print()
            no_improve += 1
            if no_improve >= patience:
                print(f'Early stopping after {epoch} epochs (no improvement for {patience} epochs)')
                break

    print(f'\nBest val accuracy: {best_acc:.4f}')

    # Update model_config.json
    cfg = json.loads((MODEL_DIR / 'model_config.json').read_text())
    cfg['finetuned_val_acc'] = round(best_acc, 4)
    (MODEL_DIR / 'model_config.json').write_text(json.dumps(cfg, indent=2))
    print('Updated model_config.json')
    print('Restart the FastAPI server to use the fine-tuned model.')


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--epochs',   type=int,   default=15)
    p.add_argument('--lr',       type=float, default=3e-5)
    p.add_argument('--patience', type=int,   default=5)
    a = p.parse_args()
    finetune(a.epochs, a.lr, a.patience)
