"""
回归任务指标计算模块

功能：实现RMSE、MAPE、R²、最大绝对误差的计算，配套国标限量符合性校验。
"""

from typing import Dict, Optional

import numpy as np


def compute_rmse(preds: np.ndarray, targets: np.ndarray) -> float:
    """计算均方根误差(RMSE)。"""
    return np.sqrt(np.mean((preds - targets) ** 2))


def compute_mape(preds: np.ndarray, targets: np.ndarray, epsilon: float = 1e-8) -> float:
    """
    计算平均绝对百分比误差(MAPE)。

    对目标值接近0的样本使用epsilon保护防止除零。

    Args:
        preds: 预测值
        targets: 真实值
        epsilon: 防除零最小值
    """
    mask = np.abs(targets) > epsilon
    if mask.sum() == 0:
        return 0.0
    return np.mean(np.abs((targets[mask] - preds[mask]) / targets[mask])) * 100


def compute_r2(preds: np.ndarray, targets: np.ndarray) -> float:
    """计算决定系数R²。"""
    ss_res = np.sum((targets - preds) ** 2)
    ss_tot = np.sum((targets - np.mean(targets)) ** 2)
    if ss_tot < 1e-10:
        return 0.0
    return 1.0 - ss_res / ss_tot


def compute_max_absolute_error(preds: np.ndarray, targets: np.ndarray) -> float:
    """计算最大绝对误差。"""
    return np.max(np.abs(preds - targets))


def check_mrl_compliance(
    preds: np.ndarray,
    targets: np.ndarray,
    labels: np.ndarray,
    mrl_limits: Dict[int, float],
) -> Dict[str, object]:
    """
    国标最大残留限量(MRL)符合性校验。

    检查预测的浓度判定(超标/合格)与真实值判定是否一致。

    Args:
        preds: 预测浓度值 (N,)
        targets: 真实浓度值 (N,)
        labels: 分类标签 (N,)
        mrl_limits: {class_idx: mrl_value} 各类别MRL限量

    Returns:
        dict: {
            "total_samples": int,
            "correct_decisions": int,
            "decision_accuracy": float,
            "false_negative_rate": float,  # 漏检率(实际超标但预测合格)
            "false_positive_rate": float,  # 误报率(实际合格但预测超标)
        }
    """
    total = 0
    correct = 0
    false_neg = 0  # 漏检
    false_pos = 0  # 误报
    actual_exceed = 0
    actual_comply = 0

    for i in range(len(preds)):
        cls = int(labels[i])
        if cls == 0:  # none类跳过
            continue

        mrl = mrl_limits.get(cls, float('inf'))
        pred_exceed = preds[i] > mrl
        true_exceed = targets[i] > mrl

        total += 1
        if pred_exceed == true_exceed:
            correct += 1

        if true_exceed:
            actual_exceed += 1
            if not pred_exceed:
                false_neg += 1
        else:
            actual_comply += 1
            if pred_exceed:
                false_pos += 1

    return {
        "total_samples": total,
        "correct_decisions": correct,
        "decision_accuracy": correct / max(total, 1),
        "false_negative_rate": false_neg / max(actual_exceed, 1),
        "false_positive_rate": false_pos / max(actual_comply, 1),
    }


def compute_all_regression_metrics(
    preds: np.ndarray,
    targets: np.ndarray,
    labels: Optional[np.ndarray] = None,
    mrl_limits: Optional[Dict[int, float]] = None,
) -> Dict[str, object]:
    """
    计算全部回归指标。

    Args:
        preds: 预测浓度 (N,)
        targets: 真实浓度 (N,)
        labels: 可选，分类标签用于MRL校验
        mrl_limits: 可选，MRL限量字典

    Returns:
        dict: 全部回归指标
    """
    # 过滤none类(浓度为0)
    if labels is not None:
        mask = labels != 0
        preds = preds[mask]
        targets = targets[mask]

    metrics = {
        "rmse": compute_rmse(preds, targets),
        "mape": compute_mape(preds, targets),
        "r2": compute_r2(preds, targets),
        "max_absolute_error": compute_max_absolute_error(preds, targets),
        "num_samples": len(preds),
    }

    if labels is not None and mrl_limits is not None:
        mask = labels != 0
        metrics["mrl_compliance"] = check_mrl_compliance(
            preds, targets, labels[mask], mrl_limits
        )

    return metrics
