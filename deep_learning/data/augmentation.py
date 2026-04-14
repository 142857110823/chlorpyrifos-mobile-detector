"""
光谱数据增强模块

功能：实现光谱专属数据增强策略，包含高斯噪声注入、基线随机偏移、
波段随机dropout。严格限制仅作用于训练集，验证/测试集禁用。
"""

import numpy as np
import torch


class SpectralAugmentation:
    """
    光谱专属数据增强类。

    仅在训练集的__getitem__中调用，通过随机变换提升模型泛化性。
    每种增强方法独立随机决定是否应用。

    Args:
        gaussian_noise_std: 高斯噪声标准差
        baseline_shift_range: 基线偏移范围 [low, high]
        band_dropout_prob: 波段dropout触发概率
        band_dropout_width: 单次dropout的连续波段宽度
        p_noise: 噪声增强应用概率
        p_shift: 基线偏移应用概率
        p_dropout: 波段dropout应用概率
    """

    def __init__(
        self,
        gaussian_noise_std: float = 0.02,
        baseline_shift_range: list = None,
        band_dropout_prob: float = 0.1,
        band_dropout_width: int = 5,
        p_noise: float = 0.5,
        p_shift: float = 0.5,
        p_dropout: float = 0.3,
    ):
        self.gaussian_noise_std = gaussian_noise_std
        self.baseline_shift_range = baseline_shift_range or [-0.05, 0.05]
        self.band_dropout_prob = band_dropout_prob
        self.band_dropout_width = band_dropout_width
        self.p_noise = p_noise
        self.p_shift = p_shift
        self.p_dropout = p_dropout

    def __call__(self, spectrum: np.ndarray) -> np.ndarray:
        """
        对单条光谱应用随机数据增强。

        Args:
            spectrum: 一维光谱数组, shape (num_wavelengths,)

        Returns:
            np.ndarray: 增强后的光谱数据
        """
        spectrum = spectrum.copy()

        # 高斯噪声注入
        if np.random.random() < self.p_noise:
            noise = np.random.normal(0, self.gaussian_noise_std, spectrum.shape).astype(spectrum.dtype)
            spectrum = spectrum + noise

        # 基线随机偏移
        if np.random.random() < self.p_shift:
            shift = np.float32(np.random.uniform(
                self.baseline_shift_range[0],
                self.baseline_shift_range[1],
            ))
            spectrum = spectrum + shift

        # 波段随机dropout
        if np.random.random() < self.p_dropout:
            num_wavelengths = len(spectrum)
            start = np.random.randint(0, max(1, num_wavelengths - self.band_dropout_width))
            end = min(start + self.band_dropout_width, num_wavelengths)
            spectrum[start:end] = 0.0

        return spectrum.astype(np.float32)

    @classmethod
    def from_config(cls, config) -> "SpectralAugmentation":
        """
        从配置对象创建增强实例。

        Args:
            config: 包含augmentation配置的对象

        Returns:
            SpectralAugmentation: 增强实例
        """
        return cls(
            gaussian_noise_std=getattr(config, 'gaussian_noise_std', 0.02),
            baseline_shift_range=getattr(config, 'baseline_shift_range', [-0.05, 0.05]),
            band_dropout_prob=getattr(config, 'band_dropout_prob', 0.1),
            band_dropout_width=getattr(config, 'band_dropout_width', 5),
        )
