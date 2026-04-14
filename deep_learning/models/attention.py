"""
注意力机制模块

功能：实现光谱通道注意力(SE-style)和时序注意力(Multi-Head Self-Attention)，
用于对光谱特征进行自适应加权聚合。
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class ChannelAttention(nn.Module):
    """
    光谱通道注意力模块(SE-Net风格)。

    通过全局平均池化→全连接瓶颈层→Sigmoid，
    自适应学习各通道(卷积特征图)的重要性权重。

    Args:
        num_channels: 输入通道数
        reduction: 通道压缩比，默认4
    """

    def __init__(self, num_channels: int, reduction: int = 4):
        super().__init__()
        mid_channels = max(num_channels // reduction, 1)

        self.squeeze = nn.AdaptiveAvgPool1d(1)
        self.excitation = nn.Sequential(
            nn.Linear(num_channels, mid_channels, bias=False),
            nn.ReLU(inplace=True),
            nn.Linear(mid_channels, num_channels, bias=False),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: 输入张量, shape (B, C, L)

        Returns:
            torch.Tensor: 通道加权后的张量, shape (B, C, L)
        """
        b, c, _ = x.shape
        # 全局平均池化 (B, C, L) -> (B, C, 1) -> (B, C)
        weights = self.squeeze(x).view(b, c)
        # 瓶颈层 (B, C) -> (B, C)
        weights = self.excitation(weights).view(b, c, 1)
        # 逐通道缩放
        return x * weights


class TemporalAttention(nn.Module):
    """
    时序注意力模块(Multi-Head Scaled Dot-Product Attention)。

    对序列中的每个时间步，通过多头自注意力机制
    学习其与其他时间步的关联权重。

    Args:
        embed_dim: 输入特征维度
        num_heads: 注意力头数，必须能被embed_dim整除
        dropout: 注意力权重dropout率
    """

    def __init__(self, embed_dim: int, num_heads: int = 4, dropout: float = 0.1):
        super().__init__()
        assert embed_dim % num_heads == 0, \
            f"embed_dim({embed_dim})必须能被num_heads({num_heads})整除"

        self.embed_dim = embed_dim
        self.num_heads = num_heads
        self.head_dim = embed_dim // num_heads
        self.scale = self.head_dim ** -0.5

        self.q_proj = nn.Linear(embed_dim, embed_dim)
        self.k_proj = nn.Linear(embed_dim, embed_dim)
        self.v_proj = nn.Linear(embed_dim, embed_dim)
        self.out_proj = nn.Linear(embed_dim, embed_dim)
        self.attn_dropout = nn.Dropout(dropout)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: 输入张量, shape (B, L, C) — 序列长度L, 特征维度C

        Returns:
            torch.Tensor: 注意力加权后的张量, shape (B, L, C)
        """
        b, l, c = x.shape

        # 线性投影 → 多头拆分 (B, L, C) -> (B, num_heads, L, head_dim)
        q = self.q_proj(x).view(b, l, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_proj(x).view(b, l, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_proj(x).view(b, l, self.num_heads, self.head_dim).transpose(1, 2)

        # 缩放点积注意力 (B, H, L, L)
        attn_weights = torch.matmul(q, k.transpose(-2, -1)) * self.scale
        attn_weights = F.softmax(attn_weights, dim=-1)
        attn_weights = self.attn_dropout(attn_weights)

        # 加权求和 (B, H, L, head_dim)
        attn_output = torch.matmul(attn_weights, v)

        # 合并多头 (B, L, C)
        attn_output = attn_output.transpose(1, 2).contiguous().view(b, l, c)
        return self.out_proj(attn_output)
