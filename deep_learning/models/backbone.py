"""
SpectralBackbone主干网络模块

功能：搭建「1D多尺度卷积局部特征提取 → BiLSTM长程时序建模 →
注意力加权特征聚合」三级链路，实现光谱端到端特征编码。
"""

from typing import List

import torch
import torch.nn as nn

from models.attention import ChannelAttention, TemporalAttention


class MultiScaleConvBlock(nn.Module):
    """
    多尺度1D卷积模块。

    使用多个不同核大小的并行卷积分支捕获不同尺度的局部特征，
    通过1x1卷积融合后接BN、ReLU、MaxPool。

    Args:
        in_channels: 输入通道数
        out_channels: 输出通道数
        kernel_sizes: 多尺度卷积核大小列表
        use_batchnorm: 是否使用BatchNorm
        dropout: Dropout率
        pool_size: 池化核大小
    """

    def __init__(
        self,
        in_channels: int,
        out_channels: int,
        kernel_sizes: List[int] = None,
        use_batchnorm: bool = True,
        dropout: float = 0.3,
        pool_size: int = 2,
    ):
        super().__init__()
        if kernel_sizes is None:
            kernel_sizes = [3, 5, 7]

        # 并行卷积分支
        self.branches = nn.ModuleList()
        for ks in kernel_sizes:
            padding = ks // 2  # same padding
            branch = nn.Conv1d(in_channels, out_channels, kernel_size=ks, padding=padding)
            self.branches.append(branch)

        # 1x1卷积融合多尺度特征
        total_channels = out_channels * len(kernel_sizes)
        self.fusion = nn.Conv1d(total_channels, out_channels, kernel_size=1)

        # 正则化
        self.bn = nn.BatchNorm1d(out_channels) if use_batchnorm else nn.Identity()
        self.relu = nn.ReLU(inplace=True)
        self.dropout = nn.Dropout(dropout) if dropout > 0 else nn.Identity()
        self.pool = nn.MaxPool1d(kernel_size=pool_size, stride=pool_size)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Args:
            x: (B, C_in, L)

        Returns:
            (B, C_out, L//pool_size)
        """
        # 多尺度并行卷积
        branch_outputs = [branch(x) for branch in self.branches]

        # 拼接 (B, C_out*num_branches, L)
        merged = torch.cat(branch_outputs, dim=1)

        # 1x1融合 (B, C_out, L)
        out = self.fusion(merged)
        out = self.bn(out)
        out = self.relu(out)
        out = self.dropout(out)
        out = self.pool(out)

        return out


class SpectralBackbone(nn.Module):
    """
    光谱主干编码器网络。

    架构: MultiScaleConv(×3阶段) → BiLSTM → ChannelAttention + TemporalAttention
          → GlobalAvgPool ⊕ GlobalMaxPool

    Args:
        num_wavelengths: 输入光谱波长点数(默认256)
        conv_channels: 各阶段卷积通道数列表
        kernel_sizes: 多尺度卷积核大小列表
        use_batchnorm: 是否使用BatchNorm
        conv_dropout: 卷积层Dropout率
        pool_size: 卷积池化大小
        lstm_hidden_dim: BiLSTM隐藏维度
        lstm_num_layers: BiLSTM层数
        lstm_bidirectional: 是否双向
        lstm_dropout: LSTM Dropout率
        use_channel_attention: 是否使用通道注意力
        use_temporal_attention: 是否使用时序注意力
        channel_reduction: 通道注意力压缩比
        temporal_heads: 时序注意力头数
    """

    def __init__(
        self,
        num_wavelengths: int = 256,
        conv_channels: List[int] = None,
        kernel_sizes: List[int] = None,
        use_batchnorm: bool = True,
        conv_dropout: float = 0.3,
        pool_size: int = 2,
        lstm_hidden_dim: int = 64,
        lstm_num_layers: int = 1,
        lstm_bidirectional: bool = True,
        lstm_dropout: float = 0.2,
        use_channel_attention: bool = True,
        use_temporal_attention: bool = True,
        channel_reduction: int = 4,
        temporal_heads: int = 4,
    ):
        super().__init__()

        if conv_channels is None:
            conv_channels = [32, 64, 128]
        if kernel_sizes is None:
            kernel_sizes = [3, 5, 7]

        # ---- 第一级：多尺度卷积局部特征提取 ----
        self.conv_blocks = nn.ModuleList()
        in_ch = 1  # 初始输入通道数(单通道光谱)
        for out_ch in conv_channels:
            block = MultiScaleConvBlock(
                in_channels=in_ch,
                out_channels=out_ch,
                kernel_sizes=kernel_sizes,
                use_batchnorm=use_batchnorm,
                dropout=conv_dropout,
                pool_size=pool_size,
            )
            self.conv_blocks.append(block)
            in_ch = out_ch

        # 计算卷积输出序列长度
        conv_out_length = num_wavelengths
        for _ in conv_channels:
            conv_out_length = conv_out_length // pool_size

        # ---- 第二级：BiLSTM长程时序建模 ----
        lstm_input_dim = conv_channels[-1]
        self.lstm = nn.LSTM(
            input_size=lstm_input_dim,
            hidden_size=lstm_hidden_dim,
            num_layers=lstm_num_layers,
            batch_first=True,
            bidirectional=lstm_bidirectional,
            dropout=lstm_dropout if lstm_num_layers > 1 else 0,
        )

        lstm_out_dim = lstm_hidden_dim * 2 if lstm_bidirectional else lstm_hidden_dim

        # ---- 第三级：注意力加权特征聚合 ----
        self.use_channel_attention = use_channel_attention
        self.use_temporal_attention = use_temporal_attention

        if use_channel_attention:
            self.channel_attn = ChannelAttention(lstm_out_dim, reduction=channel_reduction)

        if use_temporal_attention:
            self.temporal_attn = TemporalAttention(
                embed_dim=lstm_out_dim,
                num_heads=temporal_heads,
            )

        self.layer_norm = nn.LayerNorm(lstm_out_dim)

        # 特征维度：GlobalAvgPool + GlobalMaxPool 拼接
        self.output_dim = lstm_out_dim * 2

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        前向传播。

        Args:
            x: 输入光谱张量, shape (B, num_wavelengths)

        Returns:
            torch.Tensor: 编码后的特征向量, shape (B, output_dim)
        """
        # Reshape: (B, L) → (B, 1, L)
        x = x.unsqueeze(1)

        # 多尺度卷积
        for conv_block in self.conv_blocks:
            x = conv_block(x)
        # x shape: (B, C_last, L')

        # Permute: (B, C, L') → (B, L', C) 用于LSTM
        x = x.permute(0, 2, 1)

        # BiLSTM
        x, _ = self.lstm(x)
        # x shape: (B, L', lstm_out_dim)

        # 注意力(在channel维度上操作需要permute)
        if self.use_channel_attention:
            # (B, L', C) → (B, C, L') → attention → (B, C, L') → (B, L', C)
            x_ch = x.permute(0, 2, 1)
            x_ch = self.channel_attn(x_ch)
            x = x_ch.permute(0, 2, 1)

        if self.use_temporal_attention:
            x = x + self.temporal_attn(x)  # 残差连接

        x = self.layer_norm(x)

        # 特征聚合：GlobalAvgPool + GlobalMaxPool
        avg_pool = torch.mean(x, dim=1)  # (B, C)
        max_pool, _ = torch.max(x, dim=1)  # (B, C)
        features = torch.cat([avg_pool, max_pool], dim=1)  # (B, 2*C)

        return features

    @classmethod
    def from_config(cls, config) -> "SpectralBackbone":
        """从配置对象创建实例。"""
        model_cfg = config.model
        bb = model_cfg.backbone
        lstm = model_cfg.bilstm
        attn = model_cfg.attention

        return cls(
            num_wavelengths=config.data.num_wavelengths,
            conv_channels=bb.conv_channels,
            kernel_sizes=bb.kernel_sizes,
            use_batchnorm=bb.use_batchnorm,
            conv_dropout=bb.dropout,
            pool_size=bb.pool_size,
            lstm_hidden_dim=lstm.hidden_dim,
            lstm_num_layers=lstm.num_layers,
            lstm_bidirectional=lstm.bidirectional,
            lstm_dropout=lstm.dropout,
            use_channel_attention=attn.use_channel,
            use_temporal_attention=attn.use_temporal,
            channel_reduction=attn.channel_reduction,
            temporal_heads=attn.temporal_heads,
        )
