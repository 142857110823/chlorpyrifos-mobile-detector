"""
双任务头模块

功能：实现分类任务头和回归任务头，采用硬参数共享架构，
共用主干编码器输出的特征向量。
"""

from typing import List

import torch
import torch.nn as nn


class ClassificationHead(nn.Module):
    """
    分类任务头。

    多层全连接网络，输出农药类别logits(不含Softmax，由CrossEntropyLoss内部处理)。

    Args:
        input_dim: 输入特征维度(主干网络输出维度)
        hidden_dims: 隐藏层维度列表
        num_classes: 分类类别数
        dropout: Dropout率
    """

    def __init__(
        self,
        input_dim: int,
        hidden_dims: List[int] = None,
        num_classes: int = 11,
        dropout: float = 0.4,
    ):
        super().__init__()

        if hidden_dims is None:
            hidden_dims = [128, 64]

        layers = []
        in_dim = input_dim
        for h_dim in hidden_dims:
            layers.extend([
                nn.Linear(in_dim, h_dim),
                nn.BatchNorm1d(h_dim),
                nn.ReLU(inplace=True),
                nn.Dropout(dropout),
            ])
            in_dim = h_dim

        layers.append(nn.Linear(in_dim, num_classes))

        self.head = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: 主干网络特征, shape (B, input_dim)

        Returns:
            torch.Tensor: 分类logits, shape (B, num_classes)
        """
        return self.head(x)


class RegressionHead(nn.Module):
    """
    回归任务头。

    多层全连接网络，输出残留浓度预测值。
    最后一层使用ReLU保证输出非负(浓度值物理意义要求)。

    Args:
        input_dim: 输入特征维度(主干网络输出维度)
        hidden_dims: 隐藏层维度列表
        output_dim: 输出维度(默认1，单一浓度值)
        dropout: Dropout率
    """

    def __init__(
        self,
        input_dim: int,
        hidden_dims: List[int] = None,
        output_dim: int = 1,
        dropout: float = 0.3,
    ):
        super().__init__()

        if hidden_dims is None:
            hidden_dims = [128, 64]

        layers = []
        in_dim = input_dim
        for h_dim in hidden_dims:
            layers.extend([
                nn.Linear(in_dim, h_dim),
                nn.BatchNorm1d(h_dim),
                nn.ReLU(inplace=True),
                nn.Dropout(dropout),
            ])
            in_dim = h_dim

        layers.append(nn.Linear(in_dim, output_dim))
        layers.append(nn.ReLU())  # 浓度非负约束

        self.head = nn.Sequential(*layers)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: 主干网络特征, shape (B, input_dim)

        Returns:
            torch.Tensor: 浓度预测值, shape (B, output_dim)
        """
        return self.head(x)
