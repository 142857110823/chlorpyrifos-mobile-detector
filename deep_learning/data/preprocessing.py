"""
光谱数据预处理流水线模块

功能：实现SG平滑、导数变换、SNV/MSC散射校正、Z-score标准化全流程。
核心实现fit(训练集拟合参数)与transform(推理调用)方法，
保证训练/推理端参数1:1复用，杜绝数据泄露。
"""

import json
import os
from typing import Optional

import numpy as np
from scipy.signal import savgol_filter


class SpectralPreprocessingPipeline:
    """
    光谱专属预处理流水线。

    处理流程: SG平滑降噪 → 导数变换 → 散射校正(SNV/MSC) → Z-Score标准化

    核心设计:
        - fit(): 在训练集上拟合统计参数(均值/标准差/MSC参考光谱)
        - transform(): 使用已拟合参数对任意数据做变换
        - fit_transform(): fit + transform 快捷组合
        - save()/load(): 序列化管线状态用于推理部署

    Args:
        sg_window: Savitzky-Golay滤波窗口大小，必须为正奇数
        sg_polyorder: SG多项式阶数
        derivative_order: 导数阶数，0=不做导数，1=一阶，2=二阶
        scatter_correction: 散射校正方法，'snv'/'msc'/'none'
        standardize: 是否执行Z-score标准化
    """

    def __init__(
        self,
        sg_window: int = 11,
        sg_polyorder: int = 2,
        derivative_order: int = 1,
        scatter_correction: str = "snv",
        standardize: bool = True,
    ):
        self.sg_window = sg_window
        self.sg_polyorder = sg_polyorder
        self.derivative_order = derivative_order
        self.scatter_correction = scatter_correction
        self.standardize = standardize

        # 训练集拟合参数(fit后填充)
        self._fitted = False
        self._channel_mean: Optional[np.ndarray] = None
        self._channel_std: Optional[np.ndarray] = None
        self._msc_reference: Optional[np.ndarray] = None

    @property
    def is_fitted(self) -> bool:
        return self._fitted

    def fit(self, spectra: np.ndarray) -> "SpectralPreprocessingPipeline":
        """
        在训练集上拟合预处理参数。仅使用训练集数据，杜绝数据泄露。

        Args:
            spectra: 训练集原始光谱数据, shape (N, num_wavelengths)

        Returns:
            self: 返回自身，支持链式调用
        """
        # 先对训练集执行SG平滑和导数变换
        processed = self._apply_sg(spectra)

        # 拟合散射校正参数
        if self.scatter_correction == "msc":
            self._msc_reference = np.mean(processed, axis=0)
            processed = self._apply_msc(processed)
        elif self.scatter_correction == "snv":
            processed = self._apply_snv(processed)

        # 拟合标准化参数(逐通道均值和标准差)
        if self.standardize:
            self._channel_mean = np.mean(processed, axis=0)
            self._channel_std = np.std(processed, axis=0)
            # 防止除零
            self._channel_std[self._channel_std < 1e-8] = 1e-8

        self._fitted = True
        return self

    def transform(self, spectra: np.ndarray) -> np.ndarray:
        """
        使用已拟合的参数对光谱数据做变换。

        Args:
            spectra: 光谱数据, shape (N, num_wavelengths) 或 (num_wavelengths,)

        Returns:
            np.ndarray: 预处理后的光谱数据
        """
        if not self._fitted:
            raise RuntimeError("预处理管线未拟合，请先调用fit()方法")

        single = spectra.ndim == 1
        if single:
            spectra = spectra[np.newaxis, :]

        # SG平滑 + 导数
        processed = self._apply_sg(spectra)

        # 散射校正
        if self.scatter_correction == "msc":
            processed = self._apply_msc(processed)
        elif self.scatter_correction == "snv":
            processed = self._apply_snv(processed)

        # Z-score标准化
        if self.standardize:
            processed = (processed - self._channel_mean) / self._channel_std

        if single:
            processed = processed[0]

        return processed.astype(np.float32)

    def fit_transform(self, spectra: np.ndarray) -> np.ndarray:
        """fit + transform 快捷组合，仅用于训练集。"""
        return self.fit(spectra).transform(spectra)

    def _apply_sg(self, spectra: np.ndarray) -> np.ndarray:
        """应用Savitzky-Golay平滑和导数变换。"""
        result = np.zeros_like(spectra)
        for i in range(spectra.shape[0]):
            result[i] = savgol_filter(
                spectra[i],
                window_length=self.sg_window,
                polyorder=self.sg_polyorder,
                deriv=self.derivative_order,
            )
        return result

    def _apply_snv(self, spectra: np.ndarray) -> np.ndarray:
        """
        标准正态变量变换(SNV)。
        每条光谱独立：减去自身均值，除以自身标准差。
        用于消除样本间的散射差异。
        """
        means = np.mean(spectra, axis=1, keepdims=True)
        stds = np.std(spectra, axis=1, keepdims=True)
        stds[stds < 1e-8] = 1e-8
        return (spectra - means) / stds

    def _apply_msc(self, spectra: np.ndarray) -> np.ndarray:
        """
        多元散射校正(MSC)。
        以训练集平均光谱为参考，对每条光谱做线性回归校正。
        """
        if self._msc_reference is None:
            raise RuntimeError("MSC参考光谱未设置")

        corrected = np.zeros_like(spectra)
        for i in range(spectra.shape[0]):
            # 线性回归: spectrum_i = a * reference + b
            coeffs = np.polyfit(self._msc_reference, spectra[i], deg=1)
            corrected[i] = (spectra[i] - coeffs[1]) / max(coeffs[0], 1e-8)

        return corrected

    def save(self, save_path: str):
        """
        保存预处理管线参数，供推理端复用。

        Args:
            save_path: JSON文件保存路径
        """
        if not self._fitted:
            raise RuntimeError("管线未拟合，无法保存")

        os.makedirs(os.path.dirname(save_path) if os.path.dirname(save_path) else ".", exist_ok=True)

        params = {
            "sg_window": self.sg_window,
            "sg_polyorder": self.sg_polyorder,
            "derivative_order": self.derivative_order,
            "scatter_correction": self.scatter_correction,
            "standardize": self.standardize,
        }

        if self._channel_mean is not None:
            params["channel_mean"] = self._channel_mean.tolist()
        if self._channel_std is not None:
            params["channel_std"] = self._channel_std.tolist()
        if self._msc_reference is not None:
            params["msc_reference"] = self._msc_reference.tolist()

        with open(save_path, 'w', encoding='utf-8') as f:
            json.dump(params, f, indent=2)

    @classmethod
    def load(cls, load_path: str) -> "SpectralPreprocessingPipeline":
        """
        从JSON文件加载已拟合的预处理管线。

        Args:
            load_path: JSON文件路径

        Returns:
            SpectralPreprocessingPipeline: 已恢复状态的管线实例
        """
        with open(load_path, 'r', encoding='utf-8') as f:
            params = json.load(f)

        pipeline = cls(
            sg_window=params["sg_window"],
            sg_polyorder=params["sg_polyorder"],
            derivative_order=params["derivative_order"],
            scatter_correction=params["scatter_correction"],
            standardize=params["standardize"],
        )

        if "channel_mean" in params:
            pipeline._channel_mean = np.array(params["channel_mean"])
        if "channel_std" in params:
            pipeline._channel_std = np.array(params["channel_std"])
        if "msc_reference" in params:
            pipeline._msc_reference = np.array(params["msc_reference"])

        pipeline._fitted = True
        return pipeline
