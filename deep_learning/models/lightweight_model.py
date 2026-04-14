"""
轻量化光谱模型

功能：基于深度可分离卷积搭建轻量化主干网络，大幅降低参数量，
适配移动端 ≤10MB 包体约束，保持与主模型一致的输入输出接口。
"""

from typing import List, Tuple

import torch
import torch.nn as nn

from models.heads import ClassificationHead, RegressionHead


class DepthwiseSeparableConv1d(nn.Module):
    """
    1D深度可分离卷积。

    Depthwise Conv(逐通道卷积) + Pointwise Conv(1×1卷积)，
    参数量约为标准卷积的 1/k (k为kernel_size)。

    Args:
        in_channels: 输入通道数
        out_channels: 输出通道数
        kernel_size: 卷积核大小
        padding: 填充大小
    """

    def __init__(self, in_channels: int, out_channels: int, kernel_size: int, padding: int = 0):
        super().__init__()
        self.depthwise = nn.Conv1d(
            in_channels, in_channels, kernel_size=kernel_size,
            padding=padding, groups=in_channels, bias=False,
        )
        self.pointwise = nn.Conv1d(in_channels, out_channels, kernel_size=1, bias=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.pointwise(self.depthwise(x))


class LightweightBackbone(nn.Module):
    """
    轻量化光谱主干编码器。

    使用深度可分离卷积替代标准卷积，结合全局平均池化，
    以极低参数量实现光谱特征编码。

    Args:
        num_wavelengths: 输入波长点数
        channels: 各阶段通道数列表
        kernel_size: 卷积核大小
        dropout: Dropout率
    """

    def __init__(
        self,
        num_wavelengths: int = 256,
        channels: List[int] = None,
        kernel_size: int = 5,
        dropout: float = 0.2,
    ):
        super().__init__()

        if channels is None:
            channels = [16, 32, 64]

        blocks = []
        in_ch = 1
        for out_ch in channels:
            blocks.extend([
                DepthwiseSeparableConv1d(in_ch, out_ch, kernel_size=kernel_size, padding=kernel_size // 2),
                nn.BatchNorm1d(out_ch),
                nn.ReLU(inplace=True),
                nn.MaxPool1d(2),
                nn.Dropout(dropout),
            ])
            in_ch = out_ch

        self.encoder = nn.Sequential(*blocks)
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        self.output_dim = channels[-1]

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: (B, num_wavelengths)

        Returns:
            (B, output_dim)
        """
        x = x.unsqueeze(1)  # (B, 1, L)
        x = self.encoder(x)
        x = self.global_pool(x).squeeze(-1)  # (B, C)
        return x


class LightweightSpectralModel(nn.Module):
    """
    轻量化多任务光谱模型。

    使用深度可分离卷积替代多尺度卷积+BiLSTM，大幅减少参数量。
    保持与MultiTaskSpectralModel一致的forward接口。

    Args:
        num_wavelengths: 波长点数
        channels: 通道数列表
        num_classes: 分类类别数
        dropout: Dropout率
    """

    def __init__(
        self,
        num_wavelengths: int = 256,
        channels: List[int] = None,
        num_classes: int = 11,
        dropout: float = 0.2,
    ):
        super().__init__()

        if channels is None:
            channels = [16, 32, 64]

        self.backbone = LightweightBackbone(
            num_wavelengths=num_wavelengths,
            channels=channels,
            dropout=dropout,
        )

        feature_dim = self.backbone.output_dim

        self.cls_head = ClassificationHead(
            input_dim=feature_dim,
            hidden_dims=[32],
            num_classes=num_classes,
            dropout=dropout,
        )

        self.reg_head = RegressionHead(
            input_dim=feature_dim,
            hidden_dims=[32],
            output_dim=1,
            dropout=dropout,
        )

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        Args:
            x: (B, num_wavelengths)

        Returns:
            tuple: (class_logits, concentration)
        """
        features = self.backbone(x)
        class_logits = self.cls_head(features)
        concentration = self.reg_head(features)
        return class_logits, concentration

    def get_param_count(self) -> dict:
        def count_params(m):
            return sum(p.numel() for p in m.parameters())
        return {
            "backbone": count_params(self.backbone),
            "cls_head": count_params(self.cls_head),
            "reg_head": count_params(self.reg_head),
            "total": count_params(self),
        }
