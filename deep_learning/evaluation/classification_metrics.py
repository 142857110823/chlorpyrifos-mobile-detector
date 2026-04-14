"""
分类任务指标计算模块

功能：实现准确率、宏平均/加权F1、混淆矩阵、Top-K准确率的计算与可视化。
"""

from typing import Dict, List, Optional

import numpy as np
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)


def compute_accuracy(preds: np.ndarray, targets: np.ndarray) -> float:
    """计算分类准确率。"""
    return accuracy_score(targets, preds)


def compute_f1(preds: np.ndarray, targets: np.ndarray, average: str = "macro") -> float:
    """
    计算F1分数。

    Args:
        preds: 预测标签
        targets: 真实标签
        average: 'macro'(宏平均)或'weighted'(加权平均)
    """
    return f1_score(targets, preds, average=average, zero_division=0)


def compute_confusion_matrix(
    preds: np.ndarray,
    targets: np.ndarray,
    class_names: Optional[List[str]] = None,
) -> np.ndarray:
    """
    计算混淆矩阵。

    Args:
        preds: 预测标签
        targets: 真实标签
        class_names: 类别名称列表

    Returns:
        np.ndarray: 混淆矩阵, shape (num_classes, num_classes)
    """
    return confusion_matrix(targets, preds)


def compute_top_k_accuracy(
    probs: np.ndarray,
    targets: np.ndarray,
    k: int = 3,
) -> float:
    """
    计算Top-K准确率。

    Args:
        probs: 概率分布矩阵, shape (N, num_classes)
        targets: 真实标签, shape (N,)
        k: Top-K的K值

    Returns:
        float: Top-K准确率
    """
    top_k_preds = np.argsort(probs, axis=1)[:, -k:]
    correct = 0
    for i, target in enumerate(targets):
        if target in top_k_preds[i]:
            correct += 1
    return correct / len(targets)


def compute_classification_report(
    preds: np.ndarray,
    targets: np.ndarray,
    class_names: Optional[List[str]] = None,
) -> str:
    """生成分类报告(包含各类别的precision/recall/f1)。"""
    return classification_report(
        targets, preds,
        target_names=class_names,
        zero_division=0,
    )


def compute_all_classification_metrics(
    preds: np.ndarray,
    targets: np.ndarray,
    probs: Optional[np.ndarray] = None,
    class_names: Optional[List[str]] = None,
    top_k_values: List[int] = None,
) -> Dict[str, object]:
    """
    计算全部分类指标。

    Args:
        preds: 预测标签 (N,)
        targets: 真实标签 (N,)
        probs: 概率分布 (N, C)，用于Top-K
        class_names: 类别名列表
        top_k_values: Top-K的K值列表

    Returns:
        dict: 全部指标
    """
    if top_k_values is None:
        top_k_values = [3, 5]

    metrics = {
        "accuracy": compute_accuracy(preds, targets),
        "f1_macro": compute_f1(preds, targets, average="macro"),
        "f1_weighted": compute_f1(preds, targets, average="weighted"),
        "confusion_matrix": compute_confusion_matrix(preds, targets, class_names),
    }

    if probs is not None:
        for k in top_k_values:
            if k <= probs.shape[1]:
                metrics[f"top_{k}_accuracy"] = compute_top_k_accuracy(probs, targets, k)

    return metrics
