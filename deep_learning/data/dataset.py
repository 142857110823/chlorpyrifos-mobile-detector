"""
光谱数据集模块

功能：自定义SpectralDataset类(继承torch.utils.data.Dataset)，
实现光谱数据、分类标签、回归标签的加载与张量转换，
内置数据增强调用接口。
"""

from typing import Optional, Tuple

import numpy as np
import torch
from torch.utils.data import Dataset

from data.augmentation import SpectralAugmentation


class SpectralDataset(Dataset):
    """
    光谱数据集，适配PyTorch DataLoader。

    存储已预处理的光谱数据及对应的分类标签和回归标签(浓度)。
    训练集可配置数据增强，验证/测试集不使用增强。

    Args:
        spectra: 预处理后的光谱数据, shape (N, num_wavelengths)
        labels: 分类标签, shape (N,), 值域[0, num_classes-1]
        concentrations: 浓度值, shape (N,), 单位 mg/kg
        augmentation: 可选的数据增强实例(仅训练集传入)
    """

    def __init__(
        self,
        spectra: np.ndarray,
        labels: np.ndarray,
        concentrations: np.ndarray,
        augmentation: Optional[SpectralAugmentation] = None,
    ):
        assert len(spectra) == len(labels) == len(concentrations), \
            f"数据长度不一致: spectra={len(spectra)}, labels={len(labels)}, conc={len(concentrations)}"

        self.spectra = spectra.astype(np.float32)
        self.labels = labels.astype(np.int64)
        self.concentrations = concentrations.astype(np.float32)
        self.augmentation = augmentation

    def __len__(self) -> int:
        """返回数据集样本总数。"""
        return len(self.spectra)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """
        获取单个样本。

        Args:
            idx: 样本索引

        Returns:
            tuple: (光谱张量, 分类标签张量, 浓度张量)
                - spectrum: shape (num_wavelengths,), float32
                - label: shape (), int64
                - concentration: shape (), float32
        """
        spectrum = self.spectra[idx].copy()
        label = self.labels[idx]
        concentration = self.concentrations[idx]

        # 仅训练集应用数据增强
        if self.augmentation is not None:
            spectrum = self.augmentation(spectrum)

        spectrum_tensor = torch.from_numpy(spectrum)
        label_tensor = torch.tensor(label, dtype=torch.long)
        concentration_tensor = torch.tensor(concentration, dtype=torch.float32)

        return spectrum_tensor, label_tensor, concentration_tensor

    @property
    def num_samples(self) -> int:
        return len(self.spectra)

    @property
    def num_wavelengths(self) -> int:
        return self.spectra.shape[1]

    def get_class_distribution(self) -> dict:
        """返回各类别的样本数量分布。"""
        unique, counts = np.unique(self.labels, return_counts=True)
        return {int(k): int(v) for k, v in zip(unique, counts)}
