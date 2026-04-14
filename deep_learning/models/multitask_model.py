"""
多任务光谱模型 - 端到端主模型类

功能：整合SpectralBackbone主干编码器与双任务头(分类+回归)，
实现光谱数据的端到端多任务联合推理。
"""

from typing import Tuple

import torch
import torch.nn as nn

from models.backbone import SpectralBackbone
from models.heads import ClassificationHead, RegressionHead


class MultiTaskSpectralModel(nn.Module):
    """
    多任务光谱模型。

    架构: SpectralBackbone(共享编码器) → ClassificationHead + RegressionHead

    输入: 光谱张量 (B, num_wavelengths)
    输出: (分类logits, 浓度预测值)

    Args:
        backbone: SpectralBackbone实例
        cls_head: ClassificationHead实例
        reg_head: RegressionHead实例
    """

    def __init__(
        self,
        backbone: SpectralBackbone,
        cls_head: ClassificationHead,
        reg_head: RegressionHead,
    ):
        super().__init__()
        self.backbone = backbone
        self.cls_head = cls_head
        self.reg_head = reg_head

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        端到端前向传播。

        Args:
            x: 光谱输入, shape (B, num_wavelengths)

        Returns:
            tuple: (class_logits, concentration)
                - class_logits: shape (B, num_classes)
                - concentration: shape (B, 1)
        """
        features = self.backbone(x)
        class_logits = self.cls_head(features)
        concentration = self.reg_head(features)
        return class_logits, concentration

    def get_shared_features(self, x: torch.Tensor) -> torch.Tensor:
        """
        获取主干网络编码的共享特征(用于可视化/解释性分析)。

        Args:
            x: 光谱输入, shape (B, num_wavelengths)

        Returns:
            torch.Tensor: 共享特征向量, shape (B, backbone.output_dim)
        """
        return self.backbone(x)

    def get_param_count(self) -> dict:
        """返回各模块的参数量统计。"""
        def count_params(module):
            return sum(p.numel() for p in module.parameters())

        return {
            "backbone": count_params(self.backbone),
            "cls_head": count_params(self.cls_head),
            "reg_head": count_params(self.reg_head),
            "total": count_params(self),
        }

    @classmethod
    def from_config(cls, config) -> "MultiTaskSpectralModel":
        """
        从配置对象构建完整多任务模型。

        Args:
            config: 全局配置对象(ConfigNamespace)

        Returns:
            MultiTaskSpectralModel: 构建好的模型实例
        """
        model_cfg = config.model

        # 构建主干网络
        backbone = SpectralBackbone.from_config(config)

        # 构建分类头
        cls_cfg = model_cfg.classification_head
        cls_head = ClassificationHead(
            input_dim=backbone.output_dim,
            hidden_dims=cls_cfg.hidden_dims,
            num_classes=cls_cfg.num_classes,
            dropout=cls_cfg.dropout,
        )

        # 构建回归头
        reg_cfg = model_cfg.regression_head
        reg_head = RegressionHead(
            input_dim=backbone.output_dim,
            hidden_dims=reg_cfg.hidden_dims,
            output_dim=reg_cfg.output_dim,
            dropout=reg_cfg.dropout,
        )

        return cls(backbone=backbone, cls_head=cls_head, reg_head=reg_head)
