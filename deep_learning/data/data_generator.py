"""
模拟光谱数据生成模块

功能：生成11种农药的模拟光谱数据集，用于开发调试阶段。
支持配置化参数控制，预留真实数据加载接口。
"""

from typing import Dict, Optional, Tuple

import numpy as np


# 农药类别定义
PESTICIDE_CLASSES = [
    'none',           # 无农药 (class 0)
    'chlorpyrifos',   # 毒死蜱
    'dimethoate',     # 乐果
    'omethoate',      # 氧化乐果
    'phoxim',         # 辛硫磷
    'malathion',      # 马拉硫磷
    'carbofuran',     # 克百威
    'carbendazim',    # 多菌灵
    'imidacloprid',   # 吡虫啉
    'acetamiprid',    # 啶虫脒
    'cypermethrin',   # 氯氰菊酯
]

# 农药中文名映射
PESTICIDE_NAMES_ZH = {
    'none': '无农药', 'chlorpyrifos': '毒死蜱', 'dimethoate': '乐果',
    'omethoate': '氧化乐果', 'phoxim': '辛硫磷', 'malathion': '马拉硫磷',
    'carbofuran': '克百威', 'carbendazim': '多菌灵', 'imidacloprid': '吡虫啉',
    'acetamiprid': '啶虫脒', 'cypermethrin': '氯氰菊酯',
}

# 每种农药的特征波长峰(波长nm, 峰强度系数)
PESTICIDE_PEAKS = {
    'none': [],
    'chlorpyrifos':  [(450, 0.8), (520, 0.6), (680, 0.4)],
    'dimethoate':    [(380, 0.7), (480, 0.9), (620, 0.5)],
    'omethoate':     [(400, 0.85), (510, 0.7), (650, 0.45)],
    'phoxim':        [(420, 0.75), (540, 0.8), (700, 0.5)],
    'malathion':     [(390, 0.6), (490, 0.85), (630, 0.55)],
    'carbofuran':    [(360, 0.9), (460, 0.7), (580, 0.4)],
    'carbendazim':   [(340, 0.8), (440, 0.75), (560, 0.6)],
    'imidacloprid':  [(370, 0.7), (470, 0.8), (600, 0.45)],
    'acetamiprid':   [(350, 0.75), (450, 0.85), (590, 0.5)],
    'cypermethrin':  [(410, 0.65), (530, 0.9), (690, 0.55)],
}

# 最大残留限量 (mg/kg)
MRL_LIMITS = {
    'none': 0.0,
    'chlorpyrifos': 0.1, 'dimethoate': 1.0, 'omethoate': 0.02,
    'phoxim': 0.05, 'malathion': 0.5, 'carbofuran': 0.02,
    'carbendazim': 0.5, 'imidacloprid': 0.5, 'acetamiprid': 0.3,
    'cypermethrin': 0.5,
}


def generate_spectral_data(
    num_wavelengths: int = 256,
    wavelength_range: Tuple[float, float] = (200, 1000),
    samples_per_class: int = 500,
    concentration_range: Tuple[float, float] = (0.01, 2.0),
    noise_std: float = 30.0,
    baseline_amplitude: float = 200.0,
    peak_intensity_scale: float = 1000.0,
    concentration_distribution: str = "log_uniform",
    seed: Optional[int] = None,
) -> Dict[str, np.ndarray]:
    """
    生成模拟光谱数据集。

    Args:
        num_wavelengths: 波长采样点数
        wavelength_range: 波长范围(nm)
        samples_per_class: 每类样本数
        concentration_range: 浓度范围(mg/kg)
        noise_std: 高斯噪声标准差
        baseline_amplitude: 基线漂移振幅
        peak_intensity_scale: 峰强度缩放因子
        concentration_distribution: 浓度分布方式，'uniform'或'log_uniform'
        seed: 随机种子(可选，用于独立控制数据生成随机性)

    Returns:
        dict: {
            "spectra": ndarray (N, num_wavelengths),
            "labels": ndarray (N,),
            "concentrations": ndarray (N,),
            "wavelengths": ndarray (num_wavelengths,),
        }
    """
    if seed is not None:
        rng = np.random.RandomState(seed)
    else:
        rng = np.random

    wavelengths = np.linspace(wavelength_range[0], wavelength_range[1], num_wavelengths)

    all_spectra = []
    all_labels = []
    all_concentrations = []

    for class_idx, pesticide in enumerate(PESTICIDE_CLASSES):
        for _ in range(samples_per_class):
            # 生成基础光谱(背景信号)
            baseline = 500 + baseline_amplitude * np.sin(wavelengths / 200)
            noise = rng.normal(0, noise_std, num_wavelengths)
            spectrum = baseline + noise

            # 确定浓度
            if pesticide == 'none':
                concentration = 0.0
            else:
                if concentration_distribution == "log_uniform":
                    log_low = np.log10(concentration_range[0])
                    log_high = np.log10(concentration_range[1])
                    concentration = 10 ** rng.uniform(log_low, log_high)
                else:
                    concentration = rng.uniform(concentration_range[0], concentration_range[1])

            # 添加农药特征峰
            peaks = PESTICIDE_PEAKS.get(pesticide, [])
            for peak_wl, peak_intensity in peaks:
                sigma = 20 + rng.uniform(-5, 5)
                peak_signal = concentration * peak_intensity * peak_intensity_scale * np.exp(
                    -((wavelengths - peak_wl) ** 2) / (2 * sigma ** 2)
                )
                spectrum = spectrum + peak_signal

            all_spectra.append(spectrum)
            all_labels.append(class_idx)
            all_concentrations.append(concentration)

    return {
        "spectra": np.array(all_spectra, dtype=np.float64),
        "labels": np.array(all_labels, dtype=np.int64),
        "concentrations": np.array(all_concentrations, dtype=np.float64),
        "wavelengths": wavelengths,
    }


def load_real_data(data_path: str) -> Dict[str, np.ndarray]:
    """
    加载真实光谱数据(预留接口)。

    支持格式:
        - .npz: NumPy压缩文件，需包含'spectra','labels','concentrations'键
        - .csv: CSV文件，最后两列分别为label和concentration

    Args:
        data_path: 数据文件路径

    Returns:
        dict: 与generate_spectral_data相同格式的字典
    """
    if data_path.endswith('.npz'):
        data = np.load(data_path)
        return {
            "spectra": data["spectra"],
            "labels": data["labels"],
            "concentrations": data["concentrations"],
            "wavelengths": data.get("wavelengths", np.arange(data["spectra"].shape[1])),
        }
    elif data_path.endswith('.csv'):
        import pandas as pd
        df = pd.read_csv(data_path)
        spectra = df.iloc[:, :-2].values
        labels = df.iloc[:, -2].values.astype(np.int64)
        concentrations = df.iloc[:, -1].values.astype(np.float64)
        return {
            "spectra": spectra,
            "labels": labels,
            "concentrations": concentrations,
            "wavelengths": np.arange(spectra.shape[1]),
        }
    else:
        raise ValueError(f"不支持的数据格式: {data_path}")
