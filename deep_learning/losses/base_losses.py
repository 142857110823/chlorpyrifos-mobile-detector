"""
基础损失函数封装模块

功能：封装分类交叉熵损失和回归MSE损失的批次化计算，
支持类别权重和回归mask处理。
"""

from typing import Optional

import torch
import torch.nn as nn


class ClassificationLoss(nn.Module):
    """
    分类任务损失(交叉熵)。

    封装nn.CrossEntropyLoss，支持类别权重配置。

    Args:
        num_classes: 类别数
        class_weights: 可选的类别权重张量
        label_smoothing: 标签平滑系数
    """

    def __init__(
        self,
        num_classes: int = 11,
        class_weights: Optional[torch.Tensor] = None,
        label_smoothing: float = 0.0,
    ):
        super().__init__()
        self.criterion = nn.CrossEntropyLoss(
            weight=class_weights,
            label_smoothing=label_smoothing,
        )

    def forward(self, logits: torch.Tensor, targets: torch.Tensor) -> torch.Tensor:
        """
        Args:
            logits: 模型输出logits, shape (B, num_classes)
            targets: 真实标签, shape (B,), dtype int64

        Returns:
            torch.Tensor: 标量损失值
        """
        return self.criterion(logits, targets)


class RegressionLoss(nn.Module):
    """
    回归任务损失(MSE)。

    封装nn.MSELoss，支持mask处理。
    对于"none"类(class 0)样本，浓度为0且不应贡献回归损失。

    Args:
        reduction: 损失缩减方式
    """

    def __init__(self, reduction: str = "mean"):
        super().__init__()
        self.criterion = nn.MSELoss(reduction="none")
        self.reduction = reduction

    def forward(
        self,
        predictions: torch.Tensor,
        targets: torch.Tensor,
        mask: Optional[torch.Tensor] = None,
    ) -> torch.Tensor:
        """
        Args:
            predictions: 浓度预测值, shape (B, 1) 或 (B,)
            targets: 真实浓度值, shape (B,)
            mask: 可选的有效样本mask, shape (B,), True表示参与计算

        Returns:
            torch.Tensor: 标量损失值
        """
        predictions = predictions.squeeze(-1)  # (B,)
        loss = self.criterion(predictions, targets)  # (B,)

        if mask is not None:
            loss = loss * mask.float()
            num_valid = mask.sum().clamp(min=1)
            return loss.sum() / num_valid
        else:
            if self.reduction == "mean":
                return loss.mean()
            elif self.reduction == "sum":
                return loss.sum()
            return loss
