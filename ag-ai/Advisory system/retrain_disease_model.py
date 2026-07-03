"""
Retrain the plant disease classifier with balanced classes and field-realistic augmentation.

Fixes vs original:
  - Per-class image cap (1500) so soybean's 13k images don't swamp training
  - WeightedRandomSampler + class-weighted loss for perfect class balance
  - Stronger augmentation: perspective, erasing, aggressive colour jitter
  - Duplicate class folders filtered out using class_names.json
  - num_workers=0 (Windows-compatible)

Usage:
    python retrain_disease_model.py

Saves to models/disease/ — restart FastAPI server to pick up the new model.
"""

import json
import pickle
import random
from pathlib import Path

import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import CosineAnnealingLR
from torch.utils.data import DataLoader, WeightedRandomSampler, Subset
from torchvision import datasets, models, transforms
from sklearn.preprocessing import LabelEncoder

# ── Config ─────────────────────────────────────────────────────────────────────

DATA_DIR      = Path('data/plantvillage')
MODEL_DIR     = Path('models/disease')
EPOCHS        = 10
BATCH_SIZE    = 32
LR            = 5e-4
IMAGE_SIZE    = 224
MAX_PER_CLASS = 1500   # caps soybean (13 790) and tomato variants equally
VAL_SPLIT     = 0.15
SEED          = 42
BACKBONE      = 'resnet18'  # change to 'resnet50' if GPU available
FREEZE_BODY   = True        # True = only train the head (fast on CPU)

# ── Entry point guard (required on Windows) ────────────────────────────────────

if __name__ == '__main__':

    torch.manual_seed(SEED)
    random.seed(SEED)

    # Load the canonical 38-class list — used to filter duplicate folders
    with open(MODEL_DIR / 'class_names.json') as f:
        VALID_CLASSES = set(json.load(f))

    # ── Transforms ─────────────────────────────────────────────────────────────

    MEAN = [0.485, 0.456, 0.406]
    STD  = [0.229, 0.224, 0.225]

    train_transform = transforms.Compose([
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.5, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(p=0.2),
        transforms.RandomPerspective(distortion_scale=0.3, p=0.5),
        transforms.ColorJitter(brightness=0.4, contrast=0.4,
                               saturation=0.3, hue=0.08),
        transforms.RandomGrayscale(p=0.05),
        transforms.ToTensor(),
        transforms.Normalize(MEAN, STD),
        transforms.RandomErasing(p=0.2, scale=(0.02, 0.1)),
    ])

    val_transform = transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(MEAN, STD),
    ])

    # ── Dataset ─────────────────────────────────────────────────────────────────

    print(f'Loading dataset from {DATA_DIR} …')
    full_dataset = datasets.ImageFolder(str(DATA_DIR), transform=train_transform)
    print(f'Total images (all folders): {len(full_dataset)}')
    print(f'Total class folders found:  {len(full_dataset.classes)}')

    # Filter to valid classes + apply per-class cap
    valid_indices = []
    class_counts  = {}

    for idx, (_, label) in enumerate(full_dataset.samples):
        cls = full_dataset.classes[label]
        if cls not in VALID_CLASSES:
            continue
        class_counts[cls] = class_counts.get(cls, 0)
        if class_counts[cls] >= MAX_PER_CLASS:
            continue
        class_counts[cls] += 1
        valid_indices.append(idx)

    random.shuffle(valid_indices)
    n_val         = max(int(len(valid_indices) * VAL_SPLIT), 1)
    val_indices   = valid_indices[:n_val]
    train_indices = valid_indices[n_val:]

    print(f'\nAfter filter + cap ({MAX_PER_CLASS}/class):')
    print(f'  Training samples  : {len(train_indices)}')
    print(f'  Validation samples: {len(val_indices)}')
    for cls in sorted(class_counts):
        print(f'  {cls}: {class_counts[cls]}')

    train_set = Subset(full_dataset, train_indices)

    val_full  = datasets.ImageFolder(str(DATA_DIR), transform=val_transform)
    val_set   = Subset(val_full, val_indices)

    # WeightedRandomSampler: every class equally likely in each batch
    label_list        = [full_dataset.samples[i][1] for i in train_indices]
    class_sample_count = {}
    for lbl in label_list:
        cls = full_dataset.classes[lbl]
        if cls in VALID_CLASSES:
            class_sample_count[lbl] = class_sample_count.get(lbl, 0) + 1

    weights = [1.0 / class_sample_count.get(full_dataset.samples[i][1], 1)
               for i in train_indices]
    sampler = WeightedRandomSampler(weights, num_samples=len(weights),
                                    replacement=True)

    # num_workers=0 to avoid Windows multiprocessing issues
    train_loader = DataLoader(train_set, batch_size=BATCH_SIZE,
                              sampler=sampler, num_workers=0, pin_memory=False)
    val_loader   = DataLoader(val_set, batch_size=BATCH_SIZE, shuffle=False,
                              num_workers=0, pin_memory=False)

    # ── Model ───────────────────────────────────────────────────────────────────

    num_classes = len(VALID_CLASSES)
    print(f'\nBuilding {BACKBONE} for {num_classes} classes …')

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f'Device: {device}')

    if BACKBONE == 'resnet50':
        w = getattr(models, 'ResNet50_Weights', None)
        model = models.resnet50(weights=w.DEFAULT if w else None)
    else:
        w = getattr(models, 'ResNet18_Weights', None)
        model = models.resnet18(weights=w.DEFAULT if w else None)

    if FREEZE_BODY:
        for param in model.parameters():
            param.requires_grad = False

    in_features = model.fc.in_features
    model.fc = nn.Sequential(
        nn.Dropout(p=0.3),
        nn.Linear(in_features, num_classes),
    )
    model = model.to(device)

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f'Trainable parameters: {trainable:,} (backbone frozen={FREEZE_BODY})')

    # ── Loss: inverse-frequency class weights ──────────────────────────────────

    new_class_names = sorted(VALID_CLASSES)
    valid_cls_to_new_idx = {cls: i for i, cls in enumerate(new_class_names)}
    cls_to_idx = full_dataset.class_to_idx

    freq = torch.zeros(num_classes)
    for cls, cnt in class_counts.items():
        new_idx = valid_cls_to_new_idx.get(cls)
        if new_idx is not None:
            freq[new_idx] = cnt
    freq = freq.clamp(min=1)
    class_weights = (freq.sum() / (num_classes * freq)).to(device)
    criterion = nn.CrossEntropyLoss(weight=class_weights)

    # ── Optimizer ──────────────────────────────────────────────────────────────

    optimizer = AdamW(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=LR, weight_decay=1e-4,
    )
    scheduler = CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-6)

    # Label remapping: original ImageFolder indices → new contiguous indices
    orig_idx_to_new = {}
    for cls in new_class_names:
        orig = cls_to_idx.get(cls)
        new  = valid_cls_to_new_idx.get(cls)
        if orig is not None and new is not None:
            orig_idx_to_new[orig] = new

    def remap(batch_labels):
        return torch.tensor(
            [orig_idx_to_new[l.item()] for l in batch_labels],
            dtype=torch.long, device=device,
        )

    # ── Training loop ───────────────────────────────────────────────────────────

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    best_acc = 0.0
    best_path = MODEL_DIR / 'disease_model.pth'

    print()
    for epoch in range(1, EPOCHS + 1):
        # train
        model.train()
        run_loss = correct = total = 0
        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = remap(yb)
            optimizer.zero_grad()
            out  = model(xb)
            loss = criterion(out, yb)
            loss.backward()
            optimizer.step()
            run_loss += loss.item() * xb.size(0)
            correct  += (out.argmax(1) == yb).sum().item()
            total    += xb.size(0)

        # validate
        model.eval()
        v_loss = v_correct = v_total = 0
        with torch.no_grad():
            for xb, yb in val_loader:
                xb = xb.to(device)
                yb = remap(yb)
                out  = model(xb)
                loss = criterion(out, yb)
                v_loss    += loss.item() * xb.size(0)
                v_correct += (out.argmax(1) == yb).sum().item()
                v_total   += xb.size(0)

        scheduler.step()
        val_acc = v_correct / v_total if v_total else 0

        print(f'Epoch {epoch:02d}/{EPOCHS}  '
              f'train {run_loss/total:.4f}/{correct/total:.4f}  '
              f'val {v_loss/v_total:.4f}/{val_acc:.4f}')

        if val_acc > best_acc:
            best_acc = val_acc
            torch.save(model.state_dict(), best_path)
            print(f'  >> saved best model  (val_acc={val_acc:.4f})')

    print(f'\nBest val accuracy: {best_acc:.4f}')

    # ── Save inference assets ───────────────────────────────────────────────────

    print('Saving inference assets …')

    label_encoder = LabelEncoder()
    label_encoder.fit(new_class_names)

    with open(MODEL_DIR / 'label_encoder.pkl', 'wb') as f:
        pickle.dump(label_encoder, f)
    with open(MODEL_DIR / 'inference_transform.pkl', 'wb') as f:
        pickle.dump(val_transform, f)
    with open(MODEL_DIR / 'class_names.json', 'w') as f:
        json.dump(new_class_names, f, indent=2)

    config = {
        'model_path':         'disease_model.pth',
        'label_encoder_path': 'label_encoder.pkl',
        'transform_path':     'inference_transform.pkl',
        'class_names_path':   'class_names.json',
        'image_size':         [IMAGE_SIZE, IMAGE_SIZE],
        'num_classes':        num_classes,
        'backbone':           BACKBONE,
        'classes':            new_class_names,
    }
    with open(MODEL_DIR / 'model_config.json', 'w') as f:
        json.dump(config, f, indent=2)

    print(f'\nDone -- model and assets saved to {MODEL_DIR}/')
    print(f'Backbone : {BACKBONE}  |  Classes: {num_classes}')
    print(f'Best val accuracy: {best_acc:.4f}')
    print('Restart the FastAPI server to use the new model.')
