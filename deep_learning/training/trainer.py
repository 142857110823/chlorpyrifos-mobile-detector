"""
训练与验证全流程模块

功能：实现train_one_epoch/val_one_epoch单轮函数和main_train端到端训练入口，
支持梯度累积、混合精度训练、梯度裁剪，整合早停与模型保存。
"""

import os
import sys
import time
from typing import Dict, Optional, Tuple

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from tqdm import tqdm

# 添加项目根目录到路径
_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from data.data_utils import create_dataloaders
from losses.multitask_loss import MultiTaskLoss
from models.multitask_model import MultiTaskSpectralModel
from models.lightweight_model import LightweightSpectralModel
from training.early_stopping import EarlyStopping
from training.optimizer import create_optimizer, create_scheduler
from utils.config import load_config, save_config
from utils.device import get_device
from utils.io_utils import save_checkpoint
from utils.seed import set_global_seed


def train_one_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    loss_fn: MultiTaskLoss,
    optimizer: torch.optim.Optimizer,
    scheduler,
    device: torch.device,
    config,
    scaler: Optional[torch.amp.GradScaler] = None,
) -> Dict[str, float]:
    """
    单轮训练函数。

    封装批次遍历、前向传播、损失计算、梯度清零、反向传播、参数更新全流程。
    兼容梯度累积和混合精度训练。

    Args:
        model: 模型
        dataloader: 训练集DataLoader
        loss_fn: 多任务损失函数
        optimizer: 优化器
        scheduler: 学习率调度器
        device: 计算设备
        config: 全局配置
        scaler: 可选的混合精度GradScaler

    Returns:
        dict: {"total_loss", "cls_loss", "reg_loss", "lr"}
    """
    model.train()
    train_cfg = config.training

    accum_steps = train_cfg.gradient_accumulation_steps
    grad_clip = train_cfg.grad_clip_norm
    use_amp = train_cfg.mixed_precision and device.type == "cuda"

    total_loss_sum = 0.0
    cls_loss_sum = 0.0
    reg_loss_sum = 0.0
    num_batches = 0

    optimizer.zero_grad()

    progress = tqdm(dataloader, desc="  Training", leave=False)
    for batch_idx, (spectra, labels, concentrations) in enumerate(progress):
        spectra = spectra.to(device)
        labels = labels.to(device)
        concentrations = concentrations.to(device)

        # 前向传播(混合精度)
        if use_amp:
            with torch.amp.autocast("cuda"):
                class_logits, conc_pred = model(spectra)
                total_loss, cls_loss, reg_loss = loss_fn(
                    class_logits, labels, conc_pred, concentrations
                )
                total_loss = total_loss / accum_steps
        else:
            class_logits, conc_pred = model(spectra)
            total_loss, cls_loss, reg_loss = loss_fn(
                class_logits, labels, conc_pred, concentrations
            )
            total_loss = total_loss / accum_steps

        # 反向传播
        if use_amp and scaler is not None:
            scaler.scale(total_loss).backward()
        else:
            total_loss.backward()

        # 梯度累积步
        if (batch_idx + 1) % accum_steps == 0 or (batch_idx + 1) == len(dataloader):
            # 梯度裁剪
            if grad_clip > 0:
                if use_amp and scaler is not None:
                    scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), grad_clip)

            # 参数更新
            if use_amp and scaler is not None:
                scaler.step(optimizer)
                scaler.update()
            else:
                optimizer.step()

            optimizer.zero_grad()

            # 学习率调度(per-step)
            if scheduler is not None:
                scheduler.step()

        total_loss_sum += total_loss.item() * accum_steps
        cls_loss_sum += cls_loss.item()
        reg_loss_sum += reg_loss.item()
        num_batches += 1

        progress.set_postfix({
            "loss": f"{total_loss.item() * accum_steps:.4f}",
            "cls": f"{cls_loss.item():.4f}",
            "reg": f"{reg_loss.item():.4f}",
        })

    current_lr = optimizer.param_groups[0]["lr"]

    return {
        "total_loss": total_loss_sum / max(num_batches, 1),
        "cls_loss": cls_loss_sum / max(num_batches, 1),
        "reg_loss": reg_loss_sum / max(num_batches, 1),
        "lr": current_lr,
    }


@torch.no_grad()
def val_one_epoch(
    model: nn.Module,
    dataloader: DataLoader,
    loss_fn: MultiTaskLoss,
    device: torch.device,
) -> Dict[str, object]:
    """
    单轮验证/测试函数。

    禁用梯度计算与Dropout，封装前向传播、损失计算、核心指标统计全流程。

    Args:
        model: 模型
        dataloader: 验证/测试集DataLoader
        loss_fn: 多任务损失函数
        device: 计算设备

    Returns:
        dict: {
            "total_loss", "cls_loss", "reg_loss",
            "all_preds": ndarray, "all_labels": ndarray,
            "all_conc_preds": ndarray, "all_conc_targets": ndarray,
            "accuracy": float
        }
    """
    model.eval()

    total_loss_sum = 0.0
    cls_loss_sum = 0.0
    reg_loss_sum = 0.0
    num_batches = 0

    all_preds = []
    all_labels = []
    all_conc_preds = []
    all_conc_targets = []

    progress = tqdm(dataloader, desc="  Validating", leave=False)
    for spectra, labels, concentrations in progress:
        spectra = spectra.to(device)
        labels = labels.to(device)
        concentrations = concentrations.to(device)

        class_logits, conc_pred = model(spectra)
        total_loss, cls_loss, reg_loss = loss_fn(
            class_logits, labels, conc_pred, concentrations
        )

        total_loss_sum += total_loss.item()
        cls_loss_sum += cls_loss.item()
        reg_loss_sum += reg_loss.item()
        num_batches += 1

        # 收集预测结果
        preds = torch.argmax(class_logits, dim=1)
        all_preds.append(preds.cpu().numpy())
        all_labels.append(labels.cpu().numpy())
        all_conc_preds.append(conc_pred.squeeze(-1).cpu().numpy())
        all_conc_targets.append(concentrations.cpu().numpy())

    all_preds = np.concatenate(all_preds)
    all_labels = np.concatenate(all_labels)
    all_conc_preds = np.concatenate(all_conc_preds)
    all_conc_targets = np.concatenate(all_conc_targets)

    accuracy = (all_preds == all_labels).mean()

    return {
        "total_loss": total_loss_sum / max(num_batches, 1),
        "cls_loss": cls_loss_sum / max(num_batches, 1),
        "reg_loss": reg_loss_sum / max(num_batches, 1),
        "all_preds": all_preds,
        "all_labels": all_labels,
        "all_conc_preds": all_conc_preds,
        "all_conc_targets": all_conc_targets,
        "accuracy": accuracy,
    }


def main_train(config_path: str, smoke_test: bool = False):
    """
    端到端训练主函数。

    整合配置加载、种子固定、数据集初始化、模型/损失/优化器初始化、
    训练循环、早停、测试集评估全流程，实现模型权重、预处理参数、
    配置文件一体化保存。

    Args:
        config_path: YAML配置文件路径
        smoke_test: 是否为冒烟测试模式(少量数据、少量epoch)
    """
    # 1. 加载配置
    config = load_config(config_path)

    # 冒烟测试覆盖
    if smoke_test:
        config.data.simulation.samples_per_class = 50
        config.training.epochs = 3
        config.training.early_stopping.patience = 5
        print("[Smoke Test] 模式启用: 50样本/类, 3 epochs")

    print("=" * 60)
    print("光谱农药残留检测 - 多任务深度学习训练")
    print("=" * 60)

    # 2. 固定随机种子
    generator = set_global_seed(config.seed)
    print(f"[Config] 随机种子: {config.seed}")

    # 3. 设备配置
    device = get_device(config.device)

    # 4. 创建数据加载器
    print("\n[Phase 1] 数据工程...")
    train_loader, val_loader, test_loader, pipeline = create_dataloaders(config, generator)

    # 5. 构建模型
    print("\n[Phase 2] 构建模型...")
    model_type = getattr(config.model, 'type', 'standard')
    if model_type == "lightweight":
        model = LightweightSpectralModel(
            num_wavelengths=config.data.num_wavelengths,
            num_classes=config.model.classification_head.num_classes,
        )
    else:
        model = MultiTaskSpectralModel.from_config(config)

    model = model.to(device)
    param_count = model.get_param_count()
    print(f"[Model] 类型: {model_type}")
    for name, count in param_count.items():
        print(f"  {name}: {count:,} 参数")
    model_size_mb = param_count["total"] * 4 / (1024 * 1024)
    print(f"  预估模型大小(float32): {model_size_mb:.2f} MB")

    # 6. 构建损失函数
    loss_fn = MultiTaskLoss.from_config(config).to(device)
    print(f"[Loss] 加权策略: {config.loss.weighting}")

    # 7. 构建优化器和调度器
    optimizer = create_optimizer(model, config)
    scheduler = create_scheduler(optimizer, config, steps_per_epoch=len(train_loader))
    print(f"[Optimizer] AdamW, lr={config.training.learning_rate}, "
          f"weight_decay={config.training.weight_decay}")

    # 8. 早停
    es_cfg = config.training.early_stopping
    early_stopper = EarlyStopping(
        patience=es_cfg.patience,
        min_delta=es_cfg.min_delta,
        mode=es_cfg.mode,
    )

    # 混合精度
    use_amp = config.training.mixed_precision and device.type == "cuda"
    scaler = torch.amp.GradScaler("cuda") if use_amp else None
    if use_amp:
        print("[Training] 混合精度训练: 已启用")

    # 9. 准备输出目录
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ckpt_dir = os.path.join(base_dir, getattr(config.paths, 'checkpoint_dir', 'checkpoints'))
    os.makedirs(ckpt_dir, exist_ok=True)

    # 10. 训练循环
    print(f"\n[Phase 3] 开始训练 (共{config.training.epochs}轮)...")
    best_val_loss = float("inf")

    for epoch in range(1, config.training.epochs + 1):
        print(f"\nEpoch {epoch}/{config.training.epochs}")
        epoch_start = time.time()

        # 训练
        train_metrics = train_one_epoch(
            model, train_loader, loss_fn, optimizer, scheduler, device, config, scaler
        )

        # 验证
        val_result = val_one_epoch(model, val_loader, loss_fn, device)

        epoch_time = time.time() - epoch_start

        # 打印metrics
        print(f"  Train - Loss: {train_metrics['total_loss']:.4f} "
              f"(cls: {train_metrics['cls_loss']:.4f}, reg: {train_metrics['reg_loss']:.4f}) "
              f"lr: {train_metrics['lr']:.6f}")
        print(f"  Val   - Loss: {val_result['total_loss']:.4f} "
              f"(cls: {val_result['cls_loss']:.4f}, reg: {val_result['reg_loss']:.4f}) "
              f"Acc: {val_result['accuracy']:.4f} "
              f"Time: {epoch_time:.1f}s")

        # 任务权重日志
        if config.loss.weighting == "uncertainty":
            weights = loss_fn.get_task_weights()
            print(f"  Weights - cls: {weights['cls_weight']:.4f}, reg: {weights['reg_weight']:.4f}")

        # 保存最佳模型
        val_loss = val_result["total_loss"]
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_path = os.path.join(ckpt_dir, "best_model.pt")
            save_checkpoint(
                model=model,
                optimizer=optimizer,
                epoch=epoch,
                metrics={
                    "val_loss": val_loss,
                    "val_accuracy": val_result["accuracy"],
                    "train_loss": train_metrics["total_loss"],
                },
                save_path=best_path,
                scheduler=scheduler,
            )
            print(f"  >>> 最佳模型已保存 (val_loss={val_loss:.4f})")

        # 早停判断
        if early_stopper.step(val_loss, epoch):
            print(f"\n[EarlyStopping] 训练提前终止于 epoch {epoch}")
            break

    # 11. 测试集最终评估
    print(f"\n[Phase 4] 测试集评估...")
    # 加载最佳模型
    best_ckpt = torch.load(os.path.join(ckpt_dir, "best_model.pt"),
                           map_location=device, weights_only=False)
    model.load_state_dict(best_ckpt["model_state_dict"])

    test_result = val_one_epoch(model, test_loader, loss_fn, device)
    print(f"  Test - Loss: {test_result['total_loss']:.4f} "
          f"(cls: {test_result['cls_loss']:.4f}, reg: {test_result['reg_loss']:.4f})")
    print(f"  Test - Accuracy: {test_result['accuracy']:.4f}")

    # 回归指标(仅非none类)
    reg_mask = test_result["all_labels"] != 0
    if reg_mask.sum() > 0:
        reg_preds = test_result["all_conc_preds"][reg_mask]
        reg_targets = test_result["all_conc_targets"][reg_mask]
        rmse = np.sqrt(np.mean((reg_preds - reg_targets) ** 2))
        r2 = 1 - np.sum((reg_targets - reg_preds) ** 2) / np.sum((reg_targets - reg_targets.mean()) ** 2)
        print(f"  Test - RMSE: {rmse:.4f} mg/kg, R2: {r2:.4f}")

    # 12. 保存预处理参数
    pipeline_path = os.path.join(ckpt_dir, "preprocessing_params.json")
    pipeline.save(pipeline_path)
    print(f"\n[Save] 预处理参数: {pipeline_path}")

    # 保存配置副本
    config_save_path = os.path.join(ckpt_dir, "training_config.yaml")
    save_config(config, config_save_path)
    print(f"[Save] 配置副本: {config_save_path}")

    print("\n" + "=" * 60)
    print("训练完成!")
    print(f"  最佳验证损失: {best_val_loss:.4f} (epoch {early_stopper.best_epoch})")
    print(f"  测试集准确率: {test_result['accuracy']:.4f}")
    print(f"  模型文件: {os.path.join(ckpt_dir, 'best_model.pt')}")
    print("=" * 60)

    return model, test_result
