"""
多任务组合损失函数模块

功能：实现MultiTaskLoss自定义损失类，支持固定权重加权和
不确定性自适应加权两种模式，实现双任务损失平衡优化。
"""

from typing import Tuple

import torch
import torch.nn as nn

from losses.base_losses import ClassificationLoss, RegressionLoss


class MultiTaskLoss(nn.Module):
    """
    多任务组合损失函数。

    支持两种加权策略：
    1. fixed: 固定权重加权 L = w_cls * L_cls + w_reg * L_reg
    2. uncertainty: 不确定性自适应加权(Kendall et al., 2018)
       L = (1/2σ²_cls)*L_cls + log(σ_cls) + (1/2σ²_reg)*L_reg + log(σ_reg)
       两个log_sigma为可学习参数，模型自动学习最优任务权重比例。

    输出总损失、分类损失、回归损失三个值，便于训练过程监控。

    Args:
        weighting: 加权策略，'fixed'或'uncertainty'
        fixed_cls_weight: 固定模式下分类损失权重
        fixed_reg_weight: 固定模式下回归损失权重
        num_classes: 分类类别数
    """

    def __init__(
        self,
        weighting: str = "uncertainty",
        fixed_cls_weight: float = 1.0,
        fixed_reg_weight: float = 1.0,
        num_classes: int = 11,
    ):
        super().__init__()

        self.weighting = weighting
        self.cls_loss_fn = ClassificationLoss(num_classes=num_classes)
        self.reg_loss_fn = RegressionLoss()

        if weighting == "fixed":
            self.register_buffer("cls_weight", torch.tensor(fixed_cls_weight))
            self.register_buffer("reg_weight", torch.tensor(fixed_reg_weight))
        elif weighting == "uncertainty":
            # 可学习的log(σ²)参数，初始化为0 → σ² = 1 → 初始权重=0.5
            self.log_var_cls = nn.Parameter(torch.zeros(1))
            self.log_var_reg = nn.Parameter(torch.zeros(1))
        else:
            raise ValueError(f"不支持的加权策略: {weighting}，可选: fixed, uncertainty")

    def forward(
        self,
        class_logits: torch.Tensor,
        class_targets: torch.Tensor,
        concentration_pred: torch.Tensor,
        concentration_targets: torch.Tensor,
    ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """
        计算多任务组合损失。

        Args:
            class_logits: 分类logits, shape (B, num_classes)
            class_targets: 分类标签, shape (B,)
            concentration_pred: 浓度预测, shape (B, 1)
            concentration_targets: 浓度真值, shape (B,)

        Returns:
            tuple: (total_loss, cls_loss, reg_loss)
                - total_loss: 加权后的总损失(用于反向传播)
                - cls_loss: 分类损失(用于监控)
                - reg_loss: 回归损失(用于监控)
        """
        # 计算各任务基础损失
        cls_loss = self.cls_loss_fn(class_logits, class_targets)

        # 回归损失：排除"none"类(class 0)的样本
        reg_mask = (class_targets != 0)
        reg_loss = self.reg_loss_fn(concentration_pred, concentration_targets, mask=reg_mask)

        # 加权组合
        if self.weighting == "fixed":
            total_loss = self.cls_weight * cls_loss + self.reg_weight * reg_loss
        elif self.weighting == "uncertainty":
            # L = (1/2σ²)*L + log(σ) = (1/2)*exp(-log_var)*L + 0.5*log_var
            precision_cls = torch.exp(-self.log_var_cls)
            precision_reg = torch.exp(-self.log_var_reg)
            total_loss = (
                0.5 * precision_cls * cls_loss + 0.5 * self.log_var_cls
                + 0.5 * precision_reg * reg_loss + 0.5 * self.log_var_reg
            )

        return total_loss, cls_loss.detach(), reg_loss.detach()

    def get_task_weights(self) -> dict:
        """获取当前任务权重(用于日志记录)。"""
        if self.weighting == "fixed":
            return {
                "cls_weight": self.cls_weight.item(),
                "reg_weight": self.reg_weight.item(),
            }
        elif self.weighting == "uncertainty":
            return {
                "cls_weight": (0.5 * torch.exp(-self.log_var_cls)).item(),
                "reg_weight": (0.5 * torch.exp(-self.log_var_reg)).item(),
                "log_var_cls": self.log_var_cls.item(),
                "log_var_reg": self.log_var_reg.item(),
            }

    @classmethod
    def from_config(cls, config) -> "MultiTaskLoss":
        """从配置对象创建实例。"""
        loss_cfg = config.loss
        fixed_weights = getattr(loss_cfg, 'fixed_weights', None)
        cls_w = getattr(fixed_weights, 'classification', 1.0) if fixed_weights else 1.0
        reg_w = getattr(fixed_weights, 'regression', 1.0) if fixed_weights else 1.0

        return cls(
            weighting=loss_cfg.weighting,
            fixed_cls_weight=cls_w,
            fixed_reg_weight=reg_w,
            num_classes=config.model.classification_head.num_classes,
        )
