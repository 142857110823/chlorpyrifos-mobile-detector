"""
检查点保存/加载工具模块

功能：实现模型权重、优化器状态、训练进度、预处理参数的一体化保存与加载。
"""

import json
import os
from typing import Any, Optional

import torch


def save_checkpoint(
    model: torch.nn.Module,
    optimizer: torch.optim.Optimizer,
    epoch: int,
    metrics: dict,
    save_path: str,
    scheduler: Optional[Any] = None,
    extra: Optional[dict] = None,
):
    """
    保存训练检查点，包含模型权重、优化器状态、训练进度、指标。

    Args:
        model: PyTorch模型
        optimizer: 优化器
        epoch: 当前epoch
        metrics: 当前指标字典
        save_path: 保存文件路径(.pt)
        scheduler: 可选的学习率调度器
        extra: 额外需要保存的信息
    """
    os.makedirs(os.path.dirname(save_path), exist_ok=True)

    state = {
        "epoch": epoch,
        "model_state_dict": model.state_dict(),
        "optimizer_state_dict": optimizer.state_dict(),
        "metrics": metrics,
    }

    if scheduler is not None:
        state["scheduler_state_dict"] = scheduler.state_dict()

    if extra is not None:
        state["extra"] = extra

    torch.save(state, save_path)


def load_checkpoint(
    checkpoint_path: str,
    model: torch.nn.Module,
    optimizer: Optional[torch.optim.Optimizer] = None,
    scheduler: Optional[Any] = None,
    device: Optional[torch.device] = None,
) -> dict:
    """
    加载训练检查点并恢复模型/优化器状态。

    Args:
        checkpoint_path: 检查点文件路径
        model: 要恢复权重的模型
        optimizer: 可选的要恢复状态的优化器
        scheduler: 可选的要恢复状态的调度器
        device: 目标设备

    Returns:
        dict: 检查点中的完整信息(epoch, metrics, extra等)
    """
    map_location = device if device is not None else "cpu"
    checkpoint = torch.load(checkpoint_path, map_location=map_location, weights_only=False)

    model.load_state_dict(checkpoint["model_state_dict"])

    if optimizer is not None and "optimizer_state_dict" in checkpoint:
        optimizer.load_state_dict(checkpoint["optimizer_state_dict"])

    if scheduler is not None and "scheduler_state_dict" in checkpoint:
        scheduler.load_state_dict(checkpoint["scheduler_state_dict"])

    return {
        "epoch": checkpoint.get("epoch", 0),
        "metrics": checkpoint.get("metrics", {}),
        "extra": checkpoint.get("extra", {}),
    }


def save_preprocessing_params(params: dict, save_path: str):
    """
    保存预处理参数为JSON文件，供推理端复用。

    Args:
        params: 预处理参数字典(均值、标准差、SG参数等)
        save_path: 保存路径(.json)
    """
    os.makedirs(os.path.dirname(save_path), exist_ok=True)

    # 将numpy数组转为列表
    serializable = _make_serializable(params)

    with open(save_path, 'w', encoding='utf-8') as f:
        json.dump(serializable, f, indent=2, ensure_ascii=False)


def load_preprocessing_params(load_path: str) -> dict:
    """
    加载预处理参数。

    Args:
        load_path: JSON文件路径

    Returns:
        dict: 预处理参数字典
    """
    with open(load_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def _make_serializable(obj):
    """递归将numpy数组等转为JSON可序列化格式。"""
    import numpy as np

    if isinstance(obj, dict):
        return {k: _make_serializable(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_make_serializable(item) for item in obj]
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    elif isinstance(obj, (np.integer,)):
        return int(obj)
    elif isinstance(obj, (np.floating,)):
        return float(obj)
    else:
        return obj
