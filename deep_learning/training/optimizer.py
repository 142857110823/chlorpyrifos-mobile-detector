"""
优化器与学习率调度器配置模块

功能：实现AdamW优化器配置(BN/bias不施加weight_decay)，
线性warm-up + 余弦退火学习率调度策略。
"""

import math
from typing import List

import torch
import torch.nn as nn
from torch.optim.lr_scheduler import LambdaLR


def create_optimizer(model: nn.Module, config) -> torch.optim.Optimizer:
    """
    创建AdamW优化器，对BN参数和bias不施加权重衰减。

    Args:
        model: PyTorch模型
        config: 全局配置对象

    Returns:
        torch.optim.Optimizer: 配置好的优化器
    """
    train_cfg = config.training

    # 分组参数：BN和bias不使用weight_decay
    decay_params = []
    no_decay_params = []

    for name, param in model.named_parameters():
        if not param.requires_grad:
            continue
        if "bn" in name or "bias" in name or "norm" in name:
            no_decay_params.append(param)
        else:
            decay_params.append(param)

    param_groups = [
        {"params": decay_params, "weight_decay": train_cfg.weight_decay},
        {"params": no_decay_params, "weight_decay": 0.0},
    ]

    optimizer = torch.optim.AdamW(
        param_groups,
        lr=train_cfg.learning_rate,
    )

    return optimizer


def create_scheduler(
    optimizer: torch.optim.Optimizer,
    config,
    steps_per_epoch: int,
) -> LambdaLR:
    """
    创建线性warm-up + 余弦退火学习率调度器。

    前warmup_epochs个epoch线性从warmup_start_lr增加到learning_rate，
    之后余弦退火降至min_lr。per-step更新。

    Args:
        optimizer: 优化器
        config: 全局配置对象
        steps_per_epoch: 每个epoch的step数(即train_loader的batch数)

    Returns:
        LambdaLR: 学习率调度器
    """
    train_cfg = config.training
    sched_cfg = train_cfg.scheduler

    total_epochs = train_cfg.epochs
    warmup_epochs = sched_cfg.warmup_epochs
    base_lr = train_cfg.learning_rate
    warmup_start_lr = sched_cfg.warmup_start_lr
    min_lr = sched_cfg.min_lr

    total_steps = total_epochs * steps_per_epoch
    warmup_steps = warmup_epochs * steps_per_epoch

    def lr_lambda(current_step: int) -> float:
        if current_step < warmup_steps:
            # 线性warm-up
            alpha = current_step / max(warmup_steps, 1)
            lr = warmup_start_lr + alpha * (base_lr - warmup_start_lr)
        else:
            # 余弦退火
            progress = (current_step - warmup_steps) / max(total_steps - warmup_steps, 1)
            lr = min_lr + 0.5 * (base_lr - min_lr) * (1 + math.cos(math.pi * progress))

        return lr / base_lr  # LambdaLR期望返回乘法因子

    scheduler = LambdaLR(optimizer, lr_lambda=lr_lambda)
    return scheduler
