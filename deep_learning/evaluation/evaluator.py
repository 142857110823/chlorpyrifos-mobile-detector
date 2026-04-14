"""
综合评估器模块

功能：整合分类和回归指标，对模型进行全维度性能评估，
生成结构化评估报告。
"""

import json
import os
import sys
from typing import Dict, List, Optional

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from evaluation.classification_metrics import compute_all_classification_metrics
from evaluation.regression_metrics import compute_all_regression_metrics


@torch.no_grad()
def evaluate_model(
    model: nn.Module,
    dataloader: DataLoader,
    device: torch.device,
    class_names: Optional[List[str]] = None,
    mrl_limits: Optional[Dict[int, float]] = None,
    top_k_values: List[int] = None,
) -> Dict[str, object]:
    """
    对模型进行全维度评估。

    Args:
        model: 训练好的模型
        dataloader: 测试集DataLoader
        device: 计算设备
        class_names: 类别名列表
        mrl_limits: MRL限量字典 {class_idx: mrl_value}
        top_k_values: Top-K的K值列表

    Returns:
        dict: 包含分类指标、回归指标的完整评估报告
    """
    model.eval()

    all_preds = []
    all_probs = []
    all_labels = []
    all_conc_preds = []
    all_conc_targets = []

    for spectra, labels, concentrations in dataloader:
        spectra = spectra.to(device)

        class_logits, conc_pred = model(spectra)

        probs = torch.softmax(class_logits, dim=1)
        preds = torch.argmax(class_logits, dim=1)

        all_preds.append(preds.cpu().numpy())
        all_probs.append(probs.cpu().numpy())
        all_labels.append(labels.numpy())
        all_conc_preds.append(conc_pred.squeeze(-1).cpu().numpy())
        all_conc_targets.append(concentrations.numpy())

    all_preds = np.concatenate(all_preds)
    all_probs = np.concatenate(all_probs)
    all_labels = np.concatenate(all_labels)
    all_conc_preds = np.concatenate(all_conc_preds)
    all_conc_targets = np.concatenate(all_conc_targets)

    # 分类指标
    cls_metrics = compute_all_classification_metrics(
        preds=all_preds,
        targets=all_labels,
        probs=all_probs,
        class_names=class_names,
        top_k_values=top_k_values or [3, 5],
    )

    # 回归指标
    reg_metrics = compute_all_regression_metrics(
        preds=all_conc_preds,
        targets=all_conc_targets,
        labels=all_labels,
        mrl_limits=mrl_limits,
    )

    report = {
        "classification": {k: v.tolist() if isinstance(v, np.ndarray) else v
                           for k, v in cls_metrics.items()},
        "regression": {k: v.tolist() if isinstance(v, np.ndarray) else v
                       for k, v in reg_metrics.items()},
        "total_samples": len(all_labels),
    }

    return report


def print_evaluation_report(report: Dict[str, object], class_names: Optional[List[str]] = None):
    """打印格式化的评估报告。"""
    print("\n" + "=" * 60)
    print("模型评估报告")
    print("=" * 60)

    cls = report["classification"]
    print(f"\n--- 分类任务指标 ---")
    print(f"  准确率:       {cls['accuracy']:.4f}")
    print(f"  宏平均F1:     {cls['f1_macro']:.4f}")
    print(f"  加权F1:       {cls['f1_weighted']:.4f}")

    for key, val in cls.items():
        if key.startswith("top_"):
            k = key.split("_")[1]
            print(f"  Top-{k}准确率:  {val:.4f}")

    reg = report["regression"]
    print(f"\n--- 回归任务指标 ---")
    print(f"  RMSE:         {reg['rmse']:.4f} mg/kg")
    print(f"  MAPE:         {reg['mape']:.2f}%")
    print(f"  R2:           {reg['r2']:.4f}")
    print(f"  最大绝对误差: {reg['max_absolute_error']:.4f} mg/kg")

    if "mrl_compliance" in reg:
        mrl = reg["mrl_compliance"]
        print(f"\n--- 国标限量符合性 ---")
        print(f"  判定准确率:   {mrl['decision_accuracy']:.4f}")
        print(f"  漏检率:       {mrl['false_negative_rate']:.4f}")
        print(f"  误报率:       {mrl['false_positive_rate']:.4f}")

    print(f"\n总评估样本数: {report['total_samples']}")
    print("=" * 60)


def save_evaluation_report(report: Dict[str, object], save_path: str):
    """保存评估报告为JSON文件。"""
    os.makedirs(os.path.dirname(save_path) if os.path.dirname(save_path) else ".", exist_ok=True)
    with open(save_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False, default=str)
    print(f"[Save] 评估报告: {save_path}")
