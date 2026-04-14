#!/usr/bin/env python3
"""
农药残留智能检测系统v1.0 - Streamlit Web 完整版
移植自 Flutter APP 的全部核心功能模块
"""
import streamlit as st
import numpy as np
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import List, Dict, Optional, Tuple
import datetime, uuid, json, math, io, struct, base64, time, os, pathlib
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
import cv2
from scipy.interpolate import interp1d
from scipy.signal import savgol_filter as sg_filter_scipy
from scipy.spatial.distance import cosine as cosine_distance

# ======================================================================
# S1 - 常量与配置
# ======================================================================

PESTICIDE_CLASSES = [
    'none', 'pest_a', 'dimethoate', 'omethoate', 'phoxim',
    'malathion', 'carbofuran', 'carbendazim', 'imidacloprid',
    'acetamiprid', 'cypermethrin',
]

PESTICIDE_CN = {
    'none': '无农药', 'pest_a': '有机磷A', 'dimethoate': '乐果',
    'omethoate': '氧化乐果', 'phoxim': '辛硫磷', 'malathion': '马拉硫磷',
    'carbofuran': '克百威', 'carbendazim': '多菌灵', 'imidacloprid': '吡虫啉',
    'acetamiprid': '啶虫脒', 'cypermethrin': '氯氰菊酯',
}

PESTICIDE_PEAKS = {
    'none': [],
    'pest_a': [(450, 0.8), (520, 0.6), (680, 0.4)],
    'dimethoate': [(380, 0.7), (480, 0.9), (620, 0.5)],
    'omethoate': [(400, 0.85), (510, 0.7), (650, 0.45)],
    'phoxim': [(420, 0.75), (540, 0.8), (700, 0.5)],
    'malathion': [(390, 0.6), (490, 0.85), (630, 0.55)],
    'carbofuran': [(360, 0.9), (460, 0.7), (580, 0.4)],
    'carbendazim': [(340, 0.8), (440, 0.75), (560, 0.6)],
    'imidacloprid': [(370, 0.7), (470, 0.8), (600, 0.45)],
    'acetamiprid': [(350, 0.75), (450, 0.85), (590, 0.5)],
    'cypermethrin': [(410, 0.65), (530, 0.9), (690, 0.55)],
}

MRL_LIMITS = {
    'pest_a': 0.1, 'dimethoate': 1.0, 'omethoate': 0.02,
    'phoxim': 0.05, 'malathion': 0.5, 'carbofuran': 0.02,
    'carbendazim': 0.5, 'imidacloprid': 0.5, 'acetamiprid': 0.3,
    'cypermethrin': 0.5,
}

PESTICIDE_TYPES = {
    'pest_a': '有机磷', 'dimethoate': '有机磷', 'omethoate': '有机磷',
    'phoxim': '有机磷', 'malathion': '有机磷', 'carbofuran': '氨基甲酸酯',
    'carbendazim': '苯并咪唑', 'imidacloprid': '新烟碱', 'acetamiprid': '新烟碱',
    'cypermethrin': '拟除虫菊酯',
}

SAMPLE_CATEGORIES = [
    '叶菜类', '根茎类', '茄果类', '瓜类', '豆类',
    '菌菇类', '水果类', '浆果类', '柑橘类', '其他',
]

class RiskLevel(Enum):
    SAFE = 0
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4

RISK_CN = {
    RiskLevel.SAFE: '安全', RiskLevel.LOW: '低风险',
    RiskLevel.MEDIUM: '中等风险', RiskLevel.HIGH: '高风险',
    RiskLevel.CRITICAL: '严重超标',
}

RISK_EN = {
    RiskLevel.SAFE: 'SAFE', RiskLevel.LOW: 'LOW RISK',
    RiskLevel.MEDIUM: 'MEDIUM RISK', RiskLevel.HIGH: 'HIGH RISK',
    RiskLevel.CRITICAL: 'CRITICAL',
}

RISK_COLORS = {
    RiskLevel.SAFE: '#4CAF50', RiskLevel.LOW: '#8BC34A',
    RiskLevel.MEDIUM: '#FF9800', RiskLevel.HIGH: '#FF5722',
    RiskLevel.CRITICAL: '#F44336',
}

CATEGORY_EN = {
    '叶菜类': 'Leafy Vegetables', '根茎类': 'Root Vegetables',
    '茄果类': 'Solanaceous Fruits', '瓜类': 'Melons',
    '豆类': 'Legumes', '菌菇类': 'Mushrooms',
    '水果类': 'Fruits', '浆果类': 'Berries',
    '柑橘类': 'Citrus', '其他': 'Other',
}

PESTICIDE_TYPE_EN = {
    '有机磷': 'Organophosphate', '氨基甲酸酯': 'Carbamate',
    '苯并咪唑': 'Benzimidazole', '新烟碱': 'Neonicotinoid',
    '拟除虫菊酯': 'Pyrethroid',
}

# Reverse map: Chinese pesticide name -> English key
PESTICIDE_EN = {v: k for k, v in PESTICIDE_CN.items()}

WAVELENGTH_MEANINGS = [
    (0, 300, '芳香族化合物吸收区'), (300, 400, '共轭体系跃迁区'),
    (400, 500, '紫外-可见过渡区'), (500, 600, '可见光吸收区'),
    (600, 700, '叶绿素吸收带'), (700, 800, '近红外过渡区'),
    (800, 950, 'O-H/N-H伸缩泛频'), (950, 1100, 'C-H伸缩泛频区'),
]

WAVELENGTH_MEANINGS_EN = {
    '芳香族化合物吸收区': 'Aromatic Absorption',
    '共轭体系跃迁区': 'Conjugation Transition',
    '紫外-可见过渡区': 'UV-Vis Transition',
    '可见光吸收区': 'Visible Absorption',
    '叶绿素吸收带': 'Chlorophyll Absorption',
    '近红外过渡区': 'NIR Transition',
    'O-H/N-H伸缩泛频': 'O-H/N-H Overtone',
    'C-H伸缩泛频区': 'C-H Overtone',
}

STANDARD_WAVELENGTHS = np.linspace(200, 1000, 256)

# ======================================================================
# S2 - 数据模型
# ======================================================================

@dataclass
class DetectedPesticide:
    name: str
    pesticide_type: str
    concentration: float
    max_residue_limit: float
    unit: str = 'mg/kg'

    @property
    def is_over_limit(self) -> bool:
        return self.concentration > self.max_residue_limit

    @property
    def over_limit_ratio(self) -> float:
        if self.max_residue_limit <= 0:
            return 0.0
        return self.concentration / self.max_residue_limit

    def to_dict(self) -> dict:
        return {'name': self.name, 'type': self.pesticide_type,
                'concentration': self.concentration,
                'mrl': self.max_residue_limit, 'unit': self.unit}

    @staticmethod
    def from_dict(d: dict) -> 'DetectedPesticide':
        return DetectedPesticide(
            name=d['name'], pesticide_type=d.get('type', ''),
            concentration=d['concentration'],
            max_residue_limit=d.get('mrl', 0.1), unit=d.get('unit', 'mg/kg'))


@dataclass
class DetectionResult:
    id: str
    timestamp: str
    sample_name: str
    sample_category: str
    risk_level: int
    confidence: float
    detected_pesticides: List[dict]
    notes: str = ''
    spectral_data_id: str = ''
    explainability: Optional[dict] = None

    def to_dict(self) -> dict:
        return asdict(self)

    @staticmethod
    def from_dict(d: dict) -> 'DetectionResult':
        return DetectionResult(**d)

    @property
    def risk_enum(self) -> RiskLevel:
        return RiskLevel(self.risk_level)


@dataclass
class ExplainabilityResult:
    shap_values: List[float]
    feature_importance: Dict[str, float]
    critical_wavelengths: List[dict]
    confidence_interval: Tuple[float, float]
    spectral_bands: Dict[str, float]

    def to_dict(self) -> dict:
        return {
            'shap_values': self.shap_values,
            'feature_importance': self.feature_importance,
            'critical_wavelengths': self.critical_wavelengths,
            'confidence_interval': list(self.confidence_interval),
            'spectral_bands': self.spectral_bands,
        }


# ======================================================================
# S3 - 光谱预处理引擎
# ======================================================================

def remove_invalid_values(data: np.ndarray) -> np.ndarray:
    d = np.copy(data).astype(float)
    mask = ~np.isfinite(d)
    if np.any(mask):
        d[mask] = 0.0
    return d


def weighted_moving_average(data: np.ndarray, weights: np.ndarray, window_size: int = 10) -> np.ndarray:
    n = len(data)
    result = np.zeros(n)
    hw = window_size // 2
    for i in range(n):
        lo, hi = max(0, i - hw), min(n, i + hw + 1)
        w_slice = weights[lo:hi]
        ws = np.sum(w_slice)
        result[i] = np.sum(data[lo:hi] * w_slice) / ws if ws > 0 else data[i]
    return result


def als_baseline_correction(data: np.ndarray, lam: float = 1e5, p: float = 0.001, max_iter: int = 10) -> np.ndarray:
    n = len(data)
    w = np.ones(n)
    ws = max(5, min(50, int(n * 0.1)))
    z = np.copy(data)
    for _ in range(max_iter):
        baseline = weighted_moving_average(data, w, ws)
        diff = data - baseline
        w = np.where(diff < 0, p, 1 - p)
        z = baseline
    return data - z


def polynomial_baseline_correction(data: np.ndarray, degree: int = 3) -> np.ndarray:
    n = len(data)
    min_pts = []
    for i in range(1, n - 1):
        if data[i] < data[i - 1] and data[i] < data[i + 1]:
            min_pts.append(i)
    if len(min_pts) < degree + 1:
        return data - np.min(data)
    xs = np.array(min_pts, dtype=float)
    ys = data[min_pts]
    coeffs = np.polyfit(xs, ys, min(degree, len(min_pts) - 1))
    baseline = np.polyval(coeffs, np.arange(n, dtype=float))
    return data - baseline


def rubberband_baseline(data: np.ndarray) -> np.ndarray:
    bl = np.copy(data)
    for _ in range(3):
        for i in range(1, len(bl) - 1):
            avg = (bl[i - 1] + bl[i + 1]) / 2
            if bl[i] > avg:
                bl[i] = avg
    return data - bl


def simple_baseline(data: np.ndarray) -> np.ndarray:
    return data - np.min(data)


def baseline_correction(data: np.ndarray, method: str = 'ALS') -> np.ndarray:
    m = method.upper()
    if m == 'ALS':
        return als_baseline_correction(data)
    elif m == 'POLYNOMIAL':
        return polynomial_baseline_correction(data)
    elif m == 'RUBBERBAND':
        return rubberband_baseline(data)
    else:
        return simple_baseline(data)


def moving_average_filter(data: np.ndarray, window: int = 5) -> np.ndarray:
    kernel = np.ones(window) / window
    return np.convolve(data, kernel, mode='same')


def gaussian_filter(data: np.ndarray, window: int = 5) -> np.ndarray:
    hw = window // 2
    sigma = window / 6.0
    kernel = np.array([math.exp(-((x - hw) ** 2) / (2 * sigma ** 2)) for x in range(window)])
    kernel /= np.sum(kernel)
    return np.convolve(data, kernel, mode='same')


def median_filter(data: np.ndarray, window: int = 5) -> np.ndarray:
    n = len(data)
    result = np.copy(data)
    hw = window // 2
    for i in range(n):
        lo, hi = max(0, i - hw), min(n, i + hw + 1)
        result[i] = np.median(data[lo:hi])
    return result


def savitzky_golay_filter(data: np.ndarray, window: int = 5) -> np.ndarray:
    coeffs = np.array([-3.0, 12.0, 17.0, 12.0, -3.0]) / 35.0
    n = len(data)
    result = np.copy(data)
    for i in range(2, n - 2):
        result[i] = np.sum(coeffs * data[i - 2:i + 3])
    return result


def denoise_filter(data: np.ndarray, method: str = 'SG', window: int = 5) -> np.ndarray:
    m = method.upper()
    if m == 'SG':
        return savitzky_golay_filter(data, window)
    elif m == 'GAUSSIAN':
        return gaussian_filter(data, window)
    elif m == 'MEDIAN':
        return median_filter(data, window)
    else:
        return moving_average_filter(data, window)


def minmax_normalize(data: np.ndarray) -> np.ndarray:
    mn, mx = np.min(data), np.max(data)
    r = mx - mn
    if r == 0:
        return np.zeros_like(data)
    return (data - mn) / r


def zscore_normalize(data: np.ndarray) -> np.ndarray:
    m, s = np.mean(data), np.std(data)
    if s < 1e-10:
        return np.zeros_like(data)
    return (data - m) / s


def l1_normalize(data: np.ndarray) -> np.ndarray:
    s = np.sum(np.abs(data))
    if s == 0:
        return np.zeros_like(data)
    return data / s


def l2_normalize(data: np.ndarray) -> np.ndarray:
    s = np.sqrt(np.sum(data ** 2))
    if s == 0:
        return np.zeros_like(data)
    return data / s


def normalize_data(data: np.ndarray, method: str = 'MinMax') -> np.ndarray:
    m = method.upper()
    if m == 'ZSCORE' or m == 'SNV':
        return zscore_normalize(data)
    elif m == 'L1':
        return l1_normalize(data)
    elif m == 'L2':
        return l2_normalize(data)
    else:
        return minmax_normalize(data)


def interpolate_to_standard(wavelengths: np.ndarray, intensities: np.ndarray,
                            target_wl: np.ndarray = STANDARD_WAVELENGTHS) -> np.ndarray:
    return np.interp(target_wl, wavelengths, intensities)


def preprocess_spectrum(wavelengths: np.ndarray, intensities: np.ndarray,
                        baseline_method: str = 'ALS', denoise_method: str = 'SG',
                        norm_method: str = 'MinMax', filter_window: int = 5) -> Tuple[np.ndarray, np.ndarray]:
    data = remove_invalid_values(intensities)
    data = baseline_correction(data, baseline_method)
    data = denoise_filter(data, denoise_method, filter_window)
    data = normalize_data(data, norm_method)
    if len(wavelengths) != 256 or not np.allclose(wavelengths, STANDARD_WAVELENGTHS):
        data = interpolate_to_standard(wavelengths, data)
        wavelengths = STANDARD_WAVELENGTHS.copy()
    return wavelengths, data


# ======================================================================
# S4 - 特征工程引擎
# ======================================================================

def extract_statistical_features(data: np.ndarray) -> Dict[str, float]:
    n = len(data)
    if n == 0:
        return {}
    s = np.sort(data)
    mean = np.mean(data)
    std = np.std(data)
    variance = np.var(data)
    mn, mx = float(np.min(data)), float(np.max(data))
    rng = mx - mn
    median = float(np.median(data))
    q1 = float(s[int(n * 0.25)])
    q3 = float(s[int(n * 0.75)])
    iqr = q3 - q1
    if std > 0:
        skewness = float(np.mean(((data - mean) / std) ** 3))
        kurtosis = float(np.mean(((data - mean) / std) ** 4) - 3)
    else:
        skewness = kurtosis = 0.0
    energy = float(np.sum(data ** 2))
    # entropy
    hist, _ = np.histogram(data, bins=20, range=(mn, mx) if rng > 0 else (mn - 1, mx + 1))
    probs = hist / n
    nz = probs[probs > 0]
    entropy = -float(np.sum(nz * np.log(nz)))
    rms = math.sqrt(energy / n) if n > 0 else 0.0
    cv = std / abs(mean) if mean != 0 else 0.0
    return {
        'mean': mean, 'std': std, 'variance': variance, 'min': mn, 'max': mx,
        'range': rng, 'median': median, 'q1': q1, 'q3': q3, 'iqr': iqr,
        'skewness': skewness, 'kurtosis': kurtosis, 'energy': energy,
        'entropy': entropy, 'rms': rms, 'cv': cv,
    }


def extract_derivative_features(data: np.ndarray) -> Dict[str, float]:
    if len(data) < 3:
        return {}
    d1 = np.diff(data)
    d2 = np.diff(d1)
    d1_mean = float(np.mean(d1))
    d1_std = float(np.std(d1))
    d1_max = float(np.max(d1))
    d1_min = float(np.min(d1))
    d1_zc = int(np.sum(np.diff(np.sign(d1)) != 0))
    d2_mean = float(np.mean(d2)) if len(d2) > 0 else 0.0
    d2_std = float(np.std(d2)) if len(d2) > 0 else 0.0
    return {
        'd1_mean': d1_mean, 'd1_std': d1_std, 'd1_max': d1_max,
        'd1_min': d1_min, 'd1_zero_crossings': float(d1_zc),
        'd2_mean': d2_mean, 'd2_std': d2_std,
    }


def extract_peak_features(data: np.ndarray, threshold: float = 0.1) -> Dict[str, float]:
    if len(data) < 3:
        return {}
    peaks, valleys = [], []
    for i in range(1, len(data) - 1):
        if data[i] > data[i - 1] and data[i] > data[i + 1] and data[i] > threshold:
            peaks.append(i)
        if data[i] < data[i - 1] and data[i] < data[i + 1]:
            valleys.append(i)
    pc = len(peaks)
    vc = len(valleys)
    ph_mean = float(np.mean(data[peaks])) if peaks else 0.0
    ph_max = float(np.max(data[peaks])) if peaks else 0.0
    pd_mean = float(np.mean(np.diff(peaks))) if len(peaks) > 1 else 0.0
    if peaks:
        mp_idx = peaks[int(np.argmax(data[peaks]))]
        mp_pos = mp_idx / len(data)
        mp_h = float(data[mp_idx])
    else:
        mp_pos = mp_h = 0.0
    return {
        'peak_count': float(pc), 'valley_count': float(vc),
        'peak_height_mean': ph_mean, 'peak_height_max': ph_max,
        'peak_distance_mean': pd_mean,
        'main_peak_position': mp_pos, 'main_peak_height': mp_h,
    }


def extract_wavelet_features(data: np.ndarray, levels: int = 3) -> Dict[str, float]:
    features = {}
    current = np.copy(data)
    for level in range(levels):
        if len(current) < 2:
            break
        n = len(current) - len(current) % 2
        c = current[:n].reshape(-1, 2)
        approx = (c[:, 0] + c[:, 1]) / math.sqrt(2)
        detail = (c[:, 0] - c[:, 1]) / math.sqrt(2)
        if len(detail) > 0:
            dm = float(np.mean(detail))
            ds = float(np.std(detail))
            de = float(np.sum(detail ** 2))
            features[f'wavelet_d{level}_energy'] = de
            features[f'wavelet_d{level}_mean'] = dm
            features[f'wavelet_d{level}_std'] = ds
        current = approx
    if len(current) > 0:
        features['wavelet_approx_energy'] = float(np.sum(current ** 2))
    return features


def extract_frequency_features(data: np.ndarray) -> Dict[str, float]:
    if len(data) < 4:
        return {}
    fft_vals = np.fft.rfft(data)
    magnitudes = np.abs(fft_vals)[1:]  # skip DC
    if len(magnitudes) == 0:
        return {}
    total_power = float(np.sum(magnitudes ** 2))
    max_idx = int(np.argmax(magnitudes))
    dominant_freq = max_idx / len(magnitudes)
    centroid_den = float(np.sum(magnitudes))
    if centroid_den > 0:
        indices = np.arange(len(magnitudes))
        centroid = float(np.sum(indices * magnitudes) / centroid_den / len(magnitudes))
        bw = float(np.sqrt(np.sum((indices / len(magnitudes) - centroid) ** 2 * magnitudes) / centroid_den))
    else:
        centroid = bw = 0.0
    mid = len(magnitudes) // 2
    lfe = float(np.sum(magnitudes[:mid] ** 2))
    hfe = float(np.sum(magnitudes[mid:] ** 2))
    ratio = lfe / hfe if hfe > 0 else 0.0
    return {
        'total_power': total_power, 'dominant_freq': dominant_freq,
        'spectral_centroid': centroid, 'spectral_bandwidth': bw,
        'low_high_freq_ratio': ratio,
    }


def extract_texture_features(data: np.ndarray) -> Dict[str, float]:
    if len(data) < 2:
        return {}
    mean = float(np.mean(data))
    var = float(np.var(data))
    # autocorrelation
    centered = data - mean
    denom = float(np.sum(centered ** 2))
    def ac(lag):
        if denom == 0 or lag >= len(data):
            return 0.0
        return float(np.sum(centered[:len(data) - lag] * centered[lag:])) / denom
    roughness = float(np.mean(np.abs(np.diff(data))))
    smoothness = 1 - 1 / (1 + var) if var > 0 else 1.0
    uniformity = float(np.mean(data ** 2))
    return {
        'autocorr_lag1': ac(1), 'autocorr_lag5': ac(5),
        'roughness': roughness, 'smoothness': smoothness,
        'uniformity': uniformity,
    }


def build_feature_vector(data: np.ndarray) -> np.ndarray:
    all_feats = []
    for feat_dict in [
        extract_statistical_features(data),
        extract_derivative_features(data),
        extract_peak_features(data),
        extract_wavelet_features(data),
        extract_frequency_features(data),
        extract_texture_features(data),
    ]:
        all_feats.extend(feat_dict.values())
    vec = np.array(all_feats, dtype=float)
    # variance threshold feature selection
    if len(vec) > 10:
        mean_v = np.mean(vec)
        variances = (vec - mean_v) ** 2
        thresh = np.max(variances) * 0.1
        selected = vec[variances > thresh]
        if len(selected) > 0:
            vec = selected
    # z-score normalize
    m, s = np.mean(vec), np.std(vec)
    if s > 1e-6:
        vec = (vec - m) / s
    # pad or truncate to 64
    if len(vec) < 64:
        vec = np.pad(vec, (0, 64 - len(vec)))
    else:
        vec = vec[:64]
    return vec


# ======================================================================
# S5 - AI推理引擎 (RandomForest + 规则引擎 + 混合模式)
# ======================================================================

def _generate_training_spectra() -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Internal: generate synthetic training data for RF models. NOT user-facing."""
    rng = np.random.RandomState(42)
    samples_per_class = 180
    X_features = []
    y_class = []
    y_conc = []
    wavelengths = STANDARD_WAVELENGTHS.copy()
    for class_idx, pest_en in enumerate(PESTICIDE_CLASSES):
        for _ in range(samples_per_class):
            # generate synthetic spectrum
            baseline = 500 + 200 * np.sin(wavelengths / 200)
            noise = rng.normal(0, 30, len(wavelengths))
            spectrum = baseline + noise
            if pest_en != 'none' and pest_en in PESTICIDE_PEAKS:
                conc_val = rng.uniform(0.01, 2.0) * MRL_LIMITS.get(pest_en, 0.1)
                for pw, pi in PESTICIDE_PEAKS[pest_en]:
                    sigma = 20 + rng.uniform(-5, 5)
                    peak = conc_val * pi * 1000 * np.exp(
                        -((wavelengths - pw) ** 2) / (2 * sigma ** 2))
                    spectrum += peak
            else:
                conc_val = 0.0
            spectrum += rng.normal(0, 20, len(spectrum))
            spectrum += rng.uniform(-50, 50)
            # preprocess
            _, processed = preprocess_spectrum(wavelengths, spectrum)
            # extract features
            features = build_feature_vector(processed)
            X_features.append(features)
            y_class.append(class_idx)
            # concentration vector (10 pesticides, excluding 'none')
            conc_vec = np.zeros(10)
            if class_idx > 0:
                conc_vec[class_idx - 1] = conc_val
            y_conc.append(conc_vec)
    return np.array(X_features), np.array(y_class), np.array(y_conc)


@st.cache_resource
def _train_rf_models():
    """Train and cache RandomForest classifier + regressor. Runs once per server."""
    X, y_cls, y_conc = _generate_training_spectra()
    clf = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
    clf.fit(X, y_cls)
    reg = RandomForestRegressor(n_estimators=100, random_state=42, n_jobs=-1)
    reg.fit(X, y_conc)
    return clf, reg


def rule_engine_detect(wavelengths: np.ndarray, intensities: np.ndarray,
                       features: np.ndarray) -> Tuple[List[DetectedPesticide], float]:
    """Rule engine: spectral peak matching with data-driven confidence."""
    norm_int = minmax_normalize(intensities)
    detected = []
    match_ratios = []
    intensity_scores = []
    all_peaks = dict(PESTICIDE_PEAKS)
    all_peaks.pop('none', None)
    for pest_en, peaks in all_peaks.items():
        if not peaks:
            continue
        match_score = 0.0
        match_count = 0
        for sig_wl, _ in peaks:
            diffs = np.abs(wavelengths - sig_wl)
            closest_idx = int(np.argmin(diffs))
            min_diff = diffs[closest_idx]
            if min_diff < 10 and norm_int[closest_idx] > 0.3:
                match_score += norm_int[closest_idx]
                match_count += 1
        if match_count >= len(peaks) * 0.5:
            avg_score = match_score / match_count
            ratio = match_count / len(peaks)
            match_ratios.append(ratio)
            intensity_scores.append(avg_score)
            conc = avg_score * MRL_LIMITS.get(pest_en, 0.1)
            detected.append(DetectedPesticide(
                name=PESTICIDE_CN.get(pest_en, pest_en),
                pesticide_type=PESTICIDE_TYPES.get(pest_en, '未知'),
                concentration=round(conc, 4),
                max_residue_limit=MRL_LIMITS.get(pest_en, 0.1),
            ))
    # data-driven confidence
    if detected:
        avg_match = float(np.mean(match_ratios))
        avg_intensity = float(np.mean(intensity_scores))
        det_factor = min(1.0, len(detected) / 3.0)
        conf = 0.4 * avg_match + 0.4 * avg_intensity + 0.2 * det_factor
    else:
        spectral_quality = float(np.std(norm_int))
        conf = 0.5 + 0.3 * min(1.0, spectral_quality / 0.3)
    return detected, float(np.clip(conf, 0.3, 0.95))


def random_forest_analyze(spectral_256: np.ndarray,
                          features_64: np.ndarray) -> Tuple[List[DetectedPesticide], float]:
    """RandomForest-based classification + regression using sklearn."""
    clf, reg = _train_rf_models()
    X = features_64.reshape(1, -1)
    probs = clf.predict_proba(X)[0]
    confidence = float(np.max(probs))
    conc_pred = reg.predict(X)[0]  # shape: (10,)
    detected = []
    threshold = 0.15
    for idx in range(1, len(PESTICIDE_CLASSES)):
        if probs[idx] > threshold:
            pest_en = PESTICIDE_CLASSES[idx]
            conc = max(0.0, float(conc_pred[idx - 1]))
            if conc > 0.001:
                detected.append(DetectedPesticide(
                    name=PESTICIDE_CN.get(pest_en, pest_en),
                    pesticide_type=PESTICIDE_TYPES.get(pest_en, '未知'),
                    concentration=round(conc, 4),
                    max_residue_limit=MRL_LIMITS.get(pest_en, 0.1),
                ))
    return detected, confidence


def hybrid_analyze(wavelengths: np.ndarray, spectral_256: np.ndarray,
                   features_64: np.ndarray) -> Tuple[List[DetectedPesticide], float]:
    """Adaptive fusion of RandomForest + Rule Engine with confidence-based weighting."""
    rf_pests, rf_conf = random_forest_analyze(spectral_256, features_64)
    re_pests, re_conf = rule_engine_detect(wavelengths, spectral_256, features_64)
    merged = {}
    for p in rf_pests:
        merged[p.name] = p
    for p in re_pests:
        if p.name in merged:
            ex = merged[p.name]
            total_conf = rf_conf + re_conf + 1e-10
            fused_conc = (ex.concentration * rf_conf + p.concentration * re_conf) / total_conf
            merged[p.name] = DetectedPesticide(
                name=p.name, pesticide_type=p.pesticide_type,
                concentration=round(fused_conc, 4),
                max_residue_limit=p.max_residue_limit)
        else:
            merged[p.name] = DetectedPesticide(
                name=p.name, pesticide_type=p.pesticide_type,
                concentration=round(p.concentration * re_conf, 4),
                max_residue_limit=p.max_residue_limit)
    # adaptive weighting: higher confidence gets quadratically more weight
    w_rf = rf_conf ** 2
    w_re = re_conf ** 2
    fused_conf = (w_rf * rf_conf + w_re * re_conf) / (w_rf + w_re + 1e-10)
    return list(merged.values()), float(np.clip(fused_conf, 0.0, 1.0))


def determine_risk_level(pesticides: List[DetectedPesticide]) -> RiskLevel:
    if not pesticides:
        return RiskLevel.SAFE
    has_over = any(p.is_over_limit for p in pesticides)
    if not has_over:
        return RiskLevel.LOW
    max_ratio = max(p.over_limit_ratio for p in pesticides)
    if max_ratio > 5:
        return RiskLevel.CRITICAL
    elif max_ratio > 2:
        return RiskLevel.HIGH
    elif max_ratio > 1:
        return RiskLevel.MEDIUM
    else:
        return RiskLevel.LOW


def run_full_analysis(wavelengths: np.ndarray, raw_intensities: np.ndarray,
                      sample_name: str, sample_category: str,
                      baseline_method: str = 'ALS', denoise_method: str = 'SG',
                      norm_method: str = 'MinMax', filter_window: int = 5,
                      analysis_mode: str = 'hybrid',
                      notes: str = '') -> Tuple[DetectionResult, np.ndarray, np.ndarray, ExplainabilityResult]:
    wl, processed = preprocess_spectrum(wavelengths, raw_intensities,
                                        baseline_method, denoise_method,
                                        norm_method, filter_window)
    features = build_feature_vector(processed)
    if analysis_mode == 'random_forest':
        pests, conf = random_forest_analyze(processed, features)
    elif analysis_mode == 'rule_engine':
        pests, conf = rule_engine_detect(wl, processed, features)
    else:
        pests, conf = hybrid_analyze(wl, processed, features)
    risk = determine_risk_level(pests)
    # pass RF models to explainability when available
    rf_clf, rf_reg = None, None
    if analysis_mode in ('random_forest', 'hybrid'):
        rf_clf, rf_reg = _train_rf_models()
    explain = compute_explainability(wl, processed, features, conf, rf_clf=rf_clf)
    result = DetectionResult(
        id=str(uuid.uuid4())[:8],
        timestamp=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        sample_name=sample_name,
        sample_category=sample_category,
        risk_level=risk.value,
        confidence=round(conf, 4),
        detected_pesticides=[p.to_dict() for p in pests],
        notes=notes,
        explainability=explain.to_dict(),
    )
    return result, wl, processed, explain


# ======================================================================
# S6 - 可解释性引擎 (确定性 SHAP + RF特征重要性 + 统计置信区间)
# ======================================================================

def compute_explainability(wavelengths: np.ndarray, processed: np.ndarray,
                           features: np.ndarray, confidence: float,
                           rf_clf=None) -> ExplainabilityResult:
    n = len(processed)
    shap_values = np.zeros(n)

    if rf_clf is not None:
        # Perturbation-based SHAP: 16 spectral segments
        X_base = features.reshape(1, -1)
        base_probs = rf_clf.predict_proba(X_base)[0]
        best_class = int(np.argmax(base_probs))
        base_prob = float(base_probs[best_class])
        segment_size = 16
        num_segments = n // segment_size
        segment_contributions = np.zeros(num_segments)
        for seg in range(num_segments):
            start = seg * segment_size
            end = min(start + segment_size, n)
            perturbed = processed.copy()
            seg_mean = float(np.mean(processed))
            perturbed[start:end] = seg_mean  # zero out segment
            perturbed_features = build_feature_vector(perturbed)
            perturbed_probs = rf_clf.predict_proba(perturbed_features.reshape(1, -1))[0]
            segment_contributions[seg] = base_prob - float(perturbed_probs[best_class])
        # distribute to individual wavelength points by local gradient
        for seg in range(num_segments):
            start = seg * segment_size
            end = min(start + segment_size, n)
            seg_len = end - start
            gradients = np.zeros(seg_len)
            for i in range(seg_len):
                idx = start + i
                if idx > 0 and idx < n - 1:
                    gradients[i] = abs(processed[idx + 1] - processed[idx - 1]) / 2
                elif idx == 0 and n > 1:
                    gradients[i] = abs(processed[1] - processed[0])
                elif idx == n - 1 and n > 1:
                    gradients[i] = abs(processed[-1] - processed[-2])
            total_grad = np.sum(gradients) + 1e-10
            for i in range(seg_len):
                shap_values[start + i] = segment_contributions[seg] * gradients[i] / total_grad
    else:
        # Deterministic SHAP without RF: local variance * gradient sign
        total_energy = np.sum(np.abs(processed)) + 1e-10
        for i in range(n):
            local_var = 0.0
            if i > 0:
                local_var += abs(processed[i] - processed[i - 1])
            if i < n - 1:
                local_var += abs(processed[i] - processed[i + 1])
            rel_intensity = abs(processed[i]) / total_energy
            # deterministic sign from local gradient instead of random
            if i > 0 and i < n - 1:
                grad_sign = np.sign(processed[i + 1] - processed[i - 1])
            elif i == 0 and n > 1:
                grad_sign = np.sign(processed[1] - processed[0])
            else:
                grad_sign = 1.0
            if grad_sign == 0:
                grad_sign = 1.0
            shap_values[i] = local_var * 0.01 * rel_intensity * grad_sign

    # critical wavelengths
    critical_wls = []
    for i in range(2, n - 2):
        neighbors = [abs(shap_values[j]) for j in range(max(0, i - 5), min(n, i + 6)) if j != i]
        if neighbors and abs(shap_values[i]) > max(neighbors) * 1.2 and abs(shap_values[i]) > 0.0001:
            wl_val = float(wavelengths[i]) if i < len(wavelengths) else 200 + i * 3.125
            meaning = get_wavelength_meaning(wl_val)
            critical_wls.append({
                'wavelength': round(wl_val, 1),
                'contribution': round(float(shap_values[i]), 6),
                'is_positive': bool(shap_values[i] > 0),
                'reason': meaning,
            })
    critical_wls.sort(key=lambda x: abs(x['contribution']), reverse=True)
    critical_wls = critical_wls[:10]

    # spectral band aggregation
    bands = {}
    band_ranges = [(200, 300), (300, 400), (400, 500), (500, 600),
                   (600, 700), (700, 800), (800, 900), (900, 1000)]
    for lo, hi in band_ranges:
        mask = (wavelengths >= lo) & (wavelengths < hi)
        if np.any(mask):
            band_val = float(np.sum(np.abs(shap_values[mask])))
        else:
            band_val = 0.0
        bands[f'{lo}-{hi}nm'] = round(band_val, 6)
    total_band = sum(bands.values())
    if total_band > 0:
        bands = {k: round(v / total_band, 4) for k, v in bands.items()}

    # feature importance - from RF Gini importance or deterministic fallback
    feat_imp = {}
    feat_names = ['mean', 'std', 'variance', 'min', 'max', 'range', 'median',
                  'q1', 'q3', 'iqr', 'skewness', 'kurtosis', 'energy', 'entropy', 'rms', 'cv']
    if rf_clf is not None:
        rf_importances = rf_clf.feature_importances_  # Gini importance from ensemble
        for i, name in enumerate(feat_names):
            if i < len(rf_importances):
                feat_imp[name] = round(float(rf_importances[i]), 6)
    else:
        for i, name in enumerate(feat_names):
            if i < len(features):
                feat_imp[name] = round(abs(float(features[i])) * 0.001, 6)

    # confidence interval - from RF tree variance or approximate
    if rf_clf is not None:
        X_ci = features.reshape(1, -1)
        tree_preds = np.array([tree.predict_proba(X_ci)[0] for tree in rf_clf.estimators_])
        best_class = int(np.argmax(rf_clf.predict_proba(X_ci)[0]))
        std_val = float(np.std(tree_preds[:, best_class]))
        ci = (max(0.0, confidence - 1.96 * std_val), min(1.0, confidence + 1.96 * std_val))
    else:
        std_val = 0.1 * (1 - confidence)
        ci = (max(0.0, confidence - 1.96 * std_val), min(1.0, confidence + 1.96 * std_val))

    return ExplainabilityResult(
        shap_values=shap_values.tolist(),
        feature_importance=feat_imp,
        critical_wavelengths=critical_wls,
        confidence_interval=(round(ci[0], 4), round(ci[1], 4)),
        spectral_bands=bands,
    )


def get_wavelength_meaning(wl: float) -> str:
    for lo, hi, meaning in WAVELENGTH_MEANINGS:
        if lo <= wl < hi:
            return meaning
    return '未知波段'


# ======================================================================
# S7 - PDF报告生成
# ======================================================================

def generate_pdf_report(result: DetectionResult) -> bytes:
    try:
        from fpdf import FPDF
    except ImportError:
        return b''
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    # Try to use a Unicode font for Chinese support
    try:
        pdf.add_font('NotoSans', '', '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc', uni=True)
        font_name = 'NotoSans'
    except Exception:
        try:
            pdf.add_font('NotoSans', '', 'NotoSansSC-Regular.ttf', uni=True)
            font_name = 'NotoSans'
        except Exception:
            font_name = 'Helvetica'
    use_cn = font_name != 'Helvetica'
    def t(cn_text, en_text):
        return cn_text if use_cn else en_text
    def safe(text: str) -> str:
        """Sanitize dynamic text: if no CJK font, map Chinese to English or strip."""
        if use_cn:
            return text
        # Try known mappings
        if text in PESTICIDE_EN:
            return PESTICIDE_EN[text]
        if text in CATEGORY_EN:
            return CATEGORY_EN[text]
        if text in PESTICIDE_TYPE_EN:
            return PESTICIDE_TYPE_EN[text]
        if text in WAVELENGTH_MEANINGS_EN:
            return WAVELENGTH_MEANINGS_EN[text]
        # Check RISK_CN values
        for k, v in RISK_CN.items():
            if text == v:
                return RISK_EN.get(k, text)
        # Fallback: strip non-latin characters
        cleaned = text.encode('ascii', 'ignore').decode('ascii').strip()
        return cleaned if cleaned else 'N/A'
    def risk_t(risk_enum):
        """Get risk text respecting font availability."""
        if use_cn:
            return RISK_CN.get(risk_enum, str(risk_enum))
        return RISK_EN.get(risk_enum, str(risk_enum))
    # Page 1: Cover
    pdf.add_page()
    pdf.set_font(font_name, size=24)
    pdf.ln(30)
    pdf.cell(0, 15, t('农药残留检测报告', 'Pesticide Detection Report'), ln=True, align='C')
    pdf.set_font(font_name, size=12)
    pdf.ln(10)
    pdf.cell(0, 8, t('农药残留智能检测系统v1.0', 'Pesticide Detection System'), ln=True, align='C')
    pdf.ln(20)
    pdf.set_font(font_name, size=11)
    info = [
        (t('样品名称', 'Sample'), safe(result.sample_name)),
        (t('样品类别', 'Category'), safe(result.sample_category)),
        (t('检测时间', 'Time'), result.timestamp),
        (t('报告编号', 'Report ID'), result.id),
        (t('风险等级', 'Risk'), risk_t(result.risk_enum)),
        (t('AI置信度', 'Confidence'), f'{result.confidence * 100:.1f}%'),
    ]
    for label, value in info:
        pdf.cell(60, 8, f'{label}:', border=0)
        pdf.cell(0, 8, str(value), border=0, ln=True)
    # Page 2: Results Summary
    pdf.add_page()
    pdf.set_font(font_name, size=16)
    pdf.cell(0, 12, t('检测结果摘要', 'Results Summary'), ln=True)
    pdf.ln(5)
    pdf.set_font(font_name, size=11)
    pests = [DetectedPesticide.from_dict(p) for p in result.detected_pesticides]
    if not pests:
        pdf.cell(0, 10, t('未检出农药残留，样品安全。', 'No pesticide detected. Sample is safe.'), ln=True)
    else:
        qualified = all(not p.is_over_limit for p in pests)
        status = t('合格', 'PASS') if qualified else t('不合格', 'FAIL')
        pdf.cell(0, 10, f'{t("检测结论", "Conclusion")}: {status}', ln=True)
        pdf.cell(0, 10, f'{t("检出农药种类", "Detected types")}: {len(pests)}', ln=True)
        over_count = sum(1 for p in pests if p.is_over_limit)
        pdf.cell(0, 10, f'{t("超标种类", "Over limit")}: {over_count}', ln=True)
    # Page 3: Pesticide Details
    pdf.add_page()
    pdf.set_font(font_name, size=16)
    pdf.cell(0, 12, t('农药残留明细', 'Pesticide Details'), ln=True)
    pdf.ln(5)
    pdf.set_font(font_name, size=10)
    if pests:
        headers = [t('农药名称', 'Pesticide'), t('浓度(mg/kg)', 'Conc.'),
                   t('限量标准', 'MRL'), t('判定', 'Result')]
        col_w = [50, 35, 35, 40]
        for i, h in enumerate(headers):
            pdf.cell(col_w[i], 8, h, border=1, align='C')
        pdf.ln()
        for p in pests:
            verdict = t('超标', 'OVER') if p.is_over_limit else t('合格', 'PASS')
            row = [safe(p.name), f'{p.concentration:.4f}', f'{p.max_residue_limit}', verdict]
            for i, val in enumerate(row):
                pdf.cell(col_w[i], 8, val, border=1, align='C')
            pdf.ln()
    else:
        pdf.cell(0, 10, t('无检出农药', 'No pesticide detected'), ln=True)
    # Page 4: Explainability
    if result.explainability:
        pdf.add_page()
        pdf.set_font(font_name, size=16)
        pdf.cell(0, 12, t('AI可解释性分析', 'AI Explainability'), ln=True)
        pdf.ln(5)
        pdf.set_font(font_name, size=10)
        ci = result.explainability.get('confidence_interval', [0, 0])
        pdf.cell(0, 8, f'{t("模型置信度", "Confidence")}: {result.confidence * 100:.1f}%', ln=True)
        pdf.cell(0, 8, f'95% CI: [{ci[0] * 100:.1f}%, {ci[1] * 100:.1f}%]', ln=True)
        pdf.ln(5)
        pdf.set_font(font_name, size=11)
        pdf.cell(0, 8, t('光谱波段贡献度', 'Spectral Band Contribution'), ln=True)
        pdf.set_font(font_name, size=9)
        for band, val in result.explainability.get('spectral_bands', {}).items():
            pdf.cell(0, 7, f'  {safe(str(band))}: {val * 100:.1f}%', ln=True)
        pdf.ln(3)
        pdf.set_font(font_name, size=11)
        pdf.cell(0, 8, t('关键波长分析', 'Critical Wavelengths'), ln=True)
        pdf.set_font(font_name, size=9)
        for cw in result.explainability.get('critical_wavelengths', [])[:5]:
            sign = '+' if cw.get('is_positive') else '-'
            reason = safe(str(cw.get('reason', '')))
            pdf.cell(0, 7, f"  {sign} {cw['wavelength']}nm | {reason}", ln=True)
    # Page 5: Conclusion
    pdf.add_page()
    pdf.set_font(font_name, size=16)
    pdf.cell(0, 12, t('结论与建议', 'Conclusion'), ln=True)
    pdf.ln(5)
    pdf.set_font(font_name, size=11)
    pdf.cell(0, 10, f'{t("总体评估", "Assessment")}: {risk_t(result.risk_enum)}', ln=True)
    pdf.ln(3)
    if result.risk_level <= 1:
        advices = [
            t('样品农药残留符合国家标准，可安全食用。', 'Sample meets national standards.'),
            t('建议定期进行抽检以确保持续安全。', 'Regular testing recommended.'),
        ]
    else:
        advices = [
            t('样品存在农药残留超标风险，不建议直接食用。', 'Sample may exceed safety limits.'),
            t('建议进行进一步实验室确认检测。', 'Further lab testing recommended.'),
            t('建议追溯农药使用记录，排查超标原因。', 'Trace pesticide usage records.'),
            t('必要时按相关法规进行处理。', 'Handle according to regulations.'),
        ]
    for a in advices:
        pdf.cell(0, 8, f'  - {a}', ln=True)
    pdf.ln(10)
    pdf.set_font(font_name, size=9)
    pdf.cell(0, 7, t('免责声明：本检测结果仅供参考，不作为法律依据。', 'Disclaimer: For reference only.'), ln=True)
    pdf.cell(0, 7, t('参考标准：GB 2763《食品安全国家标准 食品中农药最大残留限量》',
                      'Reference: GB 2763 National Food Safety Standard'), ln=True)
    return pdf.output()


# ======================================================================
# S8 - 光谱文件解析
# ======================================================================

def parse_csv_spectrum(content: str) -> Tuple[np.ndarray, np.ndarray]:
    lines = [l.strip() for l in content.strip().split('\n') if l.strip()]
    wavelengths, intensities = [], []
    for line in lines:
        parts = line.replace(',', ' ').replace('\t', ' ').replace(';', ' ').split()
        nums = []
        for p in parts:
            try:
                nums.append(float(p))
            except ValueError:
                continue
        if len(nums) >= 2:
            wavelengths.append(nums[0])
            intensities.append(nums[1])
    if not wavelengths:
        raise ValueError('CSV: no valid data found')
    return np.array(wavelengths), np.array(intensities)


def parse_json_spectrum(content: str) -> Tuple[np.ndarray, np.ndarray]:
    data = json.loads(content)
    wl = data.get('wavelengths', data.get('x', []))
    it = data.get('intensities', data.get('y', data.get('absorbance', [])))
    if not wl or not it:
        raise ValueError('JSON: missing wavelengths or intensities')
    return np.array(wl, dtype=float), np.array(it, dtype=float)


def parse_jcamp_dx(content: str) -> Tuple[np.ndarray, np.ndarray]:
    lines = content.split('\n')
    metadata = {}
    data_lines = []
    in_data = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('##'):
            parts = stripped[2:].split('=', 1)
            if len(parts) == 2:
                key = parts[0].strip().upper()
                val = parts[1].strip()
                metadata[key] = val
                if key in ('XYDATA', 'XYPOINTS', 'DATA TABLE'):
                    in_data = True
                    continue
            if stripped.startswith('##END'):
                in_data = False
        elif in_data:
            data_lines.append(stripped)
    wavelengths, intensities = [], []
    for dl in data_lines:
        parts = dl.replace(',', ' ').replace('\t', ' ').split()
        nums = []
        for p in parts:
            try:
                nums.append(float(p))
            except ValueError:
                continue
        if len(nums) >= 2:
            wavelengths.append(nums[0])
            for v in nums[1:]:
                intensities.append(v)
    if len(wavelengths) > 0 and len(intensities) > len(wavelengths):
        # X++(Y..Y) format: generate wavelengths
        npts = int(metadata.get('NPOINTS', len(intensities)))
        firstx = float(metadata.get('FIRSTX', wavelengths[0]))
        lastx = float(metadata.get('LASTX', wavelengths[-1] if len(wavelengths) > 1 else firstx + npts))
        wavelengths = np.linspace(firstx, lastx, len(intensities))
        intensities = np.array(intensities)
    elif len(wavelengths) == len(intensities):
        wavelengths = np.array(wavelengths)
        intensities = np.array(intensities)
    else:
        raise ValueError('JCAMP-DX: cannot parse data')
    return wavelengths, intensities


def parse_uploaded_file(uploaded_file) -> Tuple[np.ndarray, np.ndarray]:
    name = uploaded_file.name.lower()
    content = uploaded_file.read()
    if isinstance(content, bytes):
        text = content.decode('utf-8', errors='ignore')
    else:
        text = content
    if name.endswith('.json'):
        return parse_json_spectrum(text)
    elif name.endswith(('.dx', '.jdx', '.jcamp')):
        return parse_jcamp_dx(text)
    else:
        return parse_csv_spectrum(text)


# ======================================================================
# S9 - 数据持久化
# ======================================================================

def init_session_state():
    if 'detection_history' not in st.session_state:
        st.session_state.detection_history = []
    if 'current_page' not in st.session_state:
        st.session_state.current_page = 'home'
    if 'settings' not in st.session_state:
        st.session_state.settings = {
            'analysis_mode': 'hybrid',
            'baseline_method': 'ALS',
            'denoise_method': 'SG',
            'norm_method': 'MinMax',
            'filter_window': 5,
        }


def save_result(result: DetectionResult):
    st.session_state.detection_history.insert(0, result.to_dict())


def get_history() -> List[dict]:
    return st.session_state.detection_history


def export_history_json() -> str:
    return json.dumps({
        'export_time': datetime.datetime.now().isoformat(),
        'total_count': len(st.session_state.detection_history),
        'results': st.session_state.detection_history,
    }, ensure_ascii=False, indent=2)


def export_history_csv() -> str:
    rows = []
    for r in st.session_state.detection_history:
        pests = r.get('detected_pesticides', [])
        if pests:
            for p in pests:
                rows.append({
                    'timestamp': r['timestamp'], 'sample_name': r['sample_name'],
                    'category': r['sample_category'], 'risk_level': RISK_CN.get(RiskLevel(r['risk_level']), ''),
                    'confidence': f"{r['confidence'] * 100:.1f}%",
                    'pesticide': p.get('name', ''), 'concentration': p.get('concentration', 0),
                    'mrl': p.get('mrl', 0), 'over_limit': 'Yes' if p.get('concentration', 0) > p.get('mrl', 999) else 'No',
                })
        else:
            rows.append({
                'timestamp': r['timestamp'], 'sample_name': r['sample_name'],
                'category': r['sample_category'], 'risk_level': RISK_CN.get(RiskLevel(r['risk_level']), ''),
                'confidence': f"{r['confidence'] * 100:.1f}%",
                'pesticide': '-', 'concentration': 0, 'mrl': '-', 'over_limit': '-',
            })
    df = pd.DataFrame(rows)
    return df.to_csv(index=False)


def import_history_json(content: str):
    data = json.loads(content)
    results = data.get('results', [])
    st.session_state.detection_history = results


# ======================================================================
# S10 - UI Pages
# ======================================================================

def main():
    st.set_page_config(page_title='农药残留智能检测系统v1.0', page_icon='🔬', layout='wide')
    init_session_state()

    # CSS
    st.markdown("""<style>
    .risk-safe {color:#4CAF50;font-weight:bold;font-size:1.3rem;}
    .risk-low {color:#8BC34A;font-weight:bold;font-size:1.3rem;}
    .risk-medium {color:#FF9800;font-weight:bold;font-size:1.3rem;}
    .risk-high {color:#FF5722;font-weight:bold;font-size:1.3rem;}
    .risk-critical {color:#F44336;font-weight:bold;font-size:1.3rem;}
    .info-box {background:#e8f4f8;border-left:4px solid #1f77b4;padding:1rem;border-radius:4px;margin:1rem 0;}
    </style>""", unsafe_allow_html=True)

    # Sidebar navigation
    with st.sidebar:
        st.title('🔬 农药残留检测')
        st.divider()
        pages = {
            'home': '🏠 首页仪表板',
            'detection': '🔬 检测分析',
            'history': '📋 历史记录',
            'statistics': '📈 数据统计',
            'data_mgmt': '📥 数据管理',
            'settings': '⚙️ 系统设置',
        }
        for key, label in pages.items():
            if st.button(label, use_container_width=True,
                         type='primary' if st.session_state.current_page == key else 'secondary'):
                st.session_state.current_page = key
                st.rerun()
        st.divider()
        hist = get_history()
        st.caption(f'已有 {len(hist)} 条检测记录')
        if hist:
            st.download_button('💾 快速导出数据', data=export_history_json(),
                               file_name='detection_export.json', mime='application/json',
                               use_container_width=True)

    page = st.session_state.current_page
    if page == 'home':
        page_home()
    elif page == 'detection':
        page_detection()
    elif page == 'history':
        page_history()
    elif page == 'statistics':
        page_statistics()
    elif page == 'data_mgmt':
        page_data_management()
    elif page == 'settings':
        page_settings()


# ---------- Page: Home ----------

def page_home():
    st.title('🏠 首页仪表板')
    st.caption('农药残留智能检测系统v1.0 | 基于近红外光谱AI分析')
    hist = get_history()
    total = len(hist)
    if total > 0:
        qualified = sum(1 for r in hist if r['risk_level'] <= 1)
        avg_conf = np.mean([r['confidence'] for r in hist])
        detected_rate = sum(1 for r in hist if r.get('detected_pesticides') for _ in [1]) / total * 100
    else:
        qualified = 0
        avg_conf = 0
        detected_rate = 0
    c1, c2, c3, c4 = st.columns(4)
    c1.metric('总检测次数', total)
    c2.metric('合格率', f'{qualified / total * 100:.0f}%' if total > 0 else '-')
    c3.metric('平均置信度', f'{avg_conf * 100:.1f}%' if total > 0 else '-')
    c4.metric('农药检出率', f'{detected_rate:.0f}%' if total > 0 else '-')
    st.divider()
    col1, col2 = st.columns([2, 1])
    with col1:
        st.subheader('最近检测记录')
        if hist:
            recent = hist[:5]
            for r in recent:
                risk = RiskLevel(r['risk_level'])
                icon = '✅' if risk.value <= 1 else '⚠️' if risk.value == 2 else '❌'
                pests = r.get('detected_pesticides', [])
                pest_str = ', '.join(p['name'] for p in pests) if pests else '无检出'
                st.markdown(f"{icon} **{r['timestamp']}** | {r['sample_name']} ({r['sample_category']}) | "
                            f"{RISK_CN.get(risk, '')} | {pest_str}")
        else:
            st.info('暂无检测记录，请前往「检测分析」页面开始检测。')
    with col2:
        st.subheader('快速操作')
        if st.button('🔬 开始新检测', use_container_width=True, type='primary'):
            st.session_state.current_page = 'detection'
            st.rerun()
        if st.button('📋 查看历史', use_container_width=True):
            st.session_state.current_page = 'history'
            st.rerun()
        if st.button('📈 数据统计', use_container_width=True):
            st.session_state.current_page = 'statistics'
            st.rerun()


# ======================================================================
# S_IMG - 光谱图像识别引擎 (对齐Flutter端 SpectralAnalysisService)
# ======================================================================

_STANDARD_LIBRARY_CACHE = None
_STANDARD_LIBRARY_MTIME = 0

def _load_standard_library():
    """加载标准农药UV-Vis光谱库（自动检测文件更新）"""
    global _STANDARD_LIBRARY_CACHE, _STANDARD_LIBRARY_MTIME
    lib_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'standard_spectra.json')
    if not os.path.exists(lib_path):
        return []
    current_mtime = os.path.getmtime(lib_path)
    if _STANDARD_LIBRARY_CACHE is not None and current_mtime == _STANDARD_LIBRARY_MTIME:
        return _STANDARD_LIBRARY_CACHE
    with open(lib_path, 'r', encoding='utf-8') as f:
        _STANDARD_LIBRARY_CACHE = json.load(f)
    _STANDARD_LIBRARY_MTIME = current_mtime
    return _STANDARD_LIBRARY_CACHE


def _pearson_correlation(x, y):
    """皮尔逊相关系数"""
    x, y = np.array(x, dtype=float), np.array(y, dtype=float)
    n = len(x)
    if n == 0:
        return 0.0
    sx, sy = x.sum(), y.sum()
    sxy = (x * y).sum()
    sx2, sy2 = (x * x).sum(), (y * y).sum()
    num = n * sxy - sx * sy
    den = math.sqrt(max(0, (n * sx2 - sx * sx) * (n * sy2 - sy * sy)))
    return num / den if den > 0 else 0.0


def _cosine_similarity(x, y):
    """余弦相似度"""
    x, y = np.array(x, dtype=float), np.array(y, dtype=float)
    dot = np.dot(x, y)
    nx, ny = np.linalg.norm(x), np.linalg.norm(y)
    return dot / (nx * ny) if nx > 0 and ny > 0 else 0.0


def _euclidean_similarity(x, y):
    """归一化欧氏距离相似度 (0-1, 1=完全一致)"""
    x, y = np.array(x, dtype=float), np.array(y, dtype=float)
    d = np.linalg.norm(x - y)
    return 1.0 / (1.0 + d)


def img_extract_spectrum_from_image(image_bytes):
    """
    从光谱图像中提取吸收光谱曲线 (v2: 坐标轴定位 + 饱和色优先)
    返回: (wavelengths_501, absorbances_501) 或 (None, None)
    """
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img_bgr = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        return None, None
    h, w = img_bgr.shape[:2]
    hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # ---- 1. 坐标轴定位: 形态学长线检测 ----
    _, dark_mask = cv2.threshold(gray, 80, 255, cv2.THRESH_BINARY_INV)
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (w // 4, 1))
    h_lines = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, h_kernel)
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, h // 4))
    v_lines = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, v_kernel)

    h_proj = np.sum(h_lines, axis=1)
    h_positions = np.where(h_proj > w * 0.1)[0]
    v_proj = np.sum(v_lines, axis=0)
    v_positions = np.where(v_proj > h * 0.1)[0]

    if len(h_positions) > 0 and len(v_positions) > 0:
        x_axis_y = int(h_positions[-1])
        y_axis_x = int(v_positions[0])
        h_row = h_lines[x_axis_y, :]
        x_right = np.where(h_row > 0)[0]
        plot_x1 = int(x_right[-1]) if len(x_right) > 0 else int(w * 0.92)
        v_col = v_lines[:, y_axis_x]
        y_top = np.where(v_col > 0)[0]
        plot_y0 = int(y_top[0]) if len(y_top) > 0 else int(h * 0.05)
        plot_x0 = y_axis_x
        plot_y1 = x_axis_y
    else:
        plot_x0, plot_y0 = int(w * 0.12), int(h * 0.06)
        plot_x1, plot_y1 = int(w * 0.94), int(h * 0.87)

    # ---- 2. 饱和色提取 (排除黑色文字/坐标轴) ----
    s_ch = hsv[:, :, 1]
    v_ch = hsv[:, :, 2]
    colored_mask = ((s_ch > 40) & (v_ch > 60) & (v_ch < 250)).astype(np.uint8) * 255

    region_mask = np.zeros_like(colored_mask)
    margin = 3
    py0 = min(plot_y0 + margin, plot_y1)
    py1 = max(plot_y1 - margin, py0 + 1)
    px0 = min(plot_x0 + margin, plot_x1)
    px1 = max(plot_x1 - margin, px0 + 1)
    region_mask[py0:py1, px0:px1] = 255
    colored_mask = cv2.bitwise_and(colored_mask, region_mask)

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    colored_mask = cv2.morphologyEx(colored_mask, cv2.MORPH_OPEN, kernel)

    if cv2.countNonZero(colored_mask) < 50:
        return None, None

    # ---- 3. 逐列扫描提取曲线 ----
    roi = colored_mask[plot_y0:plot_y1, plot_x0:plot_x1]
    roi_h, roi_w = roi.shape
    if roi_h < 5 or roi_w < 10:
        return None, None

    curve_x, curve_y = [], []
    for x in range(roi_w):
        col = roi[:, x]
        ys = np.where(col > 0)[0]
        if len(ys) > 0:
            diffs = np.diff(ys)
            gaps = np.where(diffs > 5)[0]
            if len(gaps) > 0:
                curve_y.append(float(np.mean(ys[:gaps[0] + 1])))
            else:
                curve_y.append(float(np.mean(ys)))
            curve_x.append(x)

    if len(curve_x) < 30:
        return None, None

    # ---- 4. 像素→物理坐标映射 ----
    curve_x = np.array(curve_x, dtype=float)
    curve_y = np.array(curve_y, dtype=float)
    wl_raw = 200.0 + (curve_x / roi_w) * 500.0
    abs_raw = 4.5 * (1.0 - curve_y / roi_h)

    # ---- 5. 线性插值到均匀间隔 (1nm, 501点) ----
    try:
        unique_wl, indices = np.unique(wl_raw.astype(int), return_index=True)
        f_interp = interp1d(wl_raw[indices], abs_raw[indices],
                            kind='linear', bounds_error=False, fill_value=0.0)
        wl_uniform = np.arange(200, 701, dtype=float)
        abs_uniform = f_interp(wl_uniform)
        abs_uniform = np.clip(abs_uniform, 0, 4.5)
    except Exception:
        return None, None

    # ---- 6. SG平滑 ----
    win = min(15, len(abs_uniform) - 1)
    if win % 2 == 0:
        win -= 1
    if win >= 5:
        abs_uniform = sg_filter_scipy(abs_uniform, win, 3)
        abs_uniform = np.clip(abs_uniform, 0, 4.5)

    return wl_uniform, abs_uniform


def img_match_pesticide(spectrum_501):
    """
    将提取的光谱与标准库比对, 返回Top匹配结果列表
    对齐Flutter端 SpectralAnalysisService.recognizePesticide
    """
    library = _load_standard_library()
    if not library:
        return []
    results = []
    for entry in library:
        std_abs = np.array(entry['absorbances'], dtype=float)
        if len(std_abs) != 501:
            continue
        pearson = _pearson_correlation(spectrum_501, std_abs)
        cosine = _cosine_similarity(spectrum_501, std_abs)
        euclidean = _euclidean_similarity(spectrum_501, std_abs)
        # 综合评分: 皮尔逊70% + 余弦20% + 欧氏10%
        score = max(0, pearson) * 0.7 + max(0, cosine) * 0.2 + euclidean * 0.1
        results.append({
            'name': entry['name'],
            'key': entry.get('key', ''),
            'cas': entry.get('cas', ''),
            'type': entry.get('type', ''),
            'pearson': round(pearson, 4),
            'cosine': round(cosine, 4),
            'euclidean': round(euclidean, 4),
            'score': round(score, 4),
            'peaks': entry.get('peaks', []),
        })
    results.sort(key=lambda r: r['score'], reverse=True)
    return results


def img_estimate_concentration(spectrum_501, pesticide_name):
    """基于吸光度估算浓度 (对齐Flutter端)"""
    library = _load_standard_library()
    for entry in library:
        if entry['name'] == pesticide_name:
            std_abs = np.array(entry['absorbances'], dtype=float)
            max_sample = float(np.max(spectrum_501))
            max_std = float(np.max(std_abs))
            if max_std > 0:
                return max(0.0, min(1.0, max_sample / max_std))
    return 0.0


# ---------- Page: Detection ----------

def page_detection():
    st.title('🔬 检测分析')
    settings = st.session_state.settings

    # Step 1: Sample info
    st.subheader('Step 1: 样品信息')
    c1, c2 = st.columns(2)
    with c1:
        sample_name = st.text_input('样品名称 *', placeholder='例如：苹果-001')
        sample_category = st.selectbox('样品分类', SAMPLE_CATEGORIES)
    with c2:
        sample_source = st.text_input('样品来源', placeholder='例如：XX农贸市场')
        notes = st.text_area('备注', height=80, placeholder='可选填写')

    # Step 2: Data source
    st.subheader('Step 2: 光谱数据来源')
    data_mode = st.radio('选择数据来源', ['文件导入', '手动输入', '光谱图像识别'], horizontal=True)
    wavelengths = raw_intensities = None
    img_recognition_results = None  # 图像识别匹配结果

    if data_mode == '文件导入':
        uploaded = st.file_uploader('上传光谱文件', type=['csv', 'txt', 'json', 'dx', 'jdx', 'jcamp'])
        if uploaded:
            try:
                wavelengths, raw_intensities = parse_uploaded_file(uploaded)
                st.success(f'解析成功: {len(wavelengths)} 个数据点, 波长范围 {wavelengths[0]:.1f}-{wavelengths[-1]:.1f} nm')
            except Exception as e:
                st.error(f'文件解析失败: {e}')

    elif data_mode == '手动输入':
        manual_data = st.text_area('粘贴光谱数据 (每行: 波长 强度)', height=150,
                                   placeholder='200.0 0.45\n203.1 0.52\n...')
        if manual_data.strip():
            try:
                wavelengths, raw_intensities = parse_csv_spectrum(manual_data)
                st.success(f'解析成功: {len(wavelengths)} 个数据点')
            except Exception as e:
                st.error(f'数据解析失败: {e}')

    elif data_mode == '光谱图像识别':
        st.info('📷 上传吸收光谱图像（UV-Vis图谱截图或照片），系统将自动提取光谱曲线并匹配农药种类。')
        img_file = st.file_uploader('上传光谱图像', type=['png', 'jpg', 'jpeg', 'bmp', 'tiff'])
        if img_file is not None:
            img_bytes = img_file.read()
            # 显示上传的图像
            col_img, col_info = st.columns([2, 1])
            with col_img:
                st.image(img_bytes, caption='上传的光谱图像', use_container_width=True)
            with col_info:
                st.markdown(f"**文件名:** {img_file.name}")
                st.markdown(f"**大小:** {len(img_bytes) / 1024:.1f} KB")

            # 提取光谱
            with st.spinner('正在提取光谱曲线...'):
                wl_501, abs_501 = img_extract_spectrum_from_image(img_bytes)

            if wl_501 is not None and abs_501 is not None:
                wavelengths = wl_501
                raw_intensities = abs_501
                st.success(f'光谱提取成功: {len(wavelengths)} 个数据点, 波长范围 200-700 nm')

                # 与标准库匹配
                with st.spinner('正在与标准光谱库比对...'):
                    match_results = img_match_pesticide(abs_501)
                    img_recognition_results = match_results

                # 显示匹配结果
                if match_results:
                    st.subheader('🎯 光谱匹配结果 (Top-5)')
                    top_n = match_results[:5]
                    # 匹配结果表格
                    match_table = []
                    for i, mr in enumerate(top_n):
                        conc = img_estimate_concentration(abs_501, mr['name'])
                        match_table.append({
                            '排名': i + 1,
                            '农药名称': mr['name'],
                            '类型': mr.get('type', ''),
                            'CAS号': mr.get('cas', ''),
                            '综合评分': f"{mr['score']:.4f}",
                            '皮尔逊': f"{mr['pearson']:.4f}",
                            '余弦': f"{mr['cosine']:.4f}",
                            '欧氏': f"{mr['euclidean']:.4f}",
                            '估算浓度': f"{conc:.4f}",
                        })
                    st.dataframe(pd.DataFrame(match_table), use_container_width=True, hide_index=True)

                    # 最佳匹配指标卡片
                    best = top_n[0]
                    bc1, bc2, bc3 = st.columns(3)
                    bc1.metric('最佳匹配', best['name'])
                    bc2.metric('综合评分', f"{best['score']:.4f}")
                    bc3.metric('皮尔逊相关', f"{best['pearson']:.4f}")

                    # 提取光谱 vs 标准光谱对比图
                    library = _load_standard_library()
                    best_std = None
                    for entry in library:
                        if entry['name'] == best['name']:
                            best_std = entry
                            break
                    fig_cmp = go.Figure()
                    fig_cmp.add_trace(go.Scatter(
                        x=list(range(200, 701)), y=abs_501.tolist(),
                        mode='lines', name='提取光谱',
                        line=dict(color='#1565C0', width=2)))
                    if best_std:
                        fig_cmp.add_trace(go.Scatter(
                            x=list(range(200, 701)),
                            y=best_std['absorbances'],
                            mode='lines', name=f"标准: {best['name']}",
                            line=dict(color='#FF7043', width=2, dash='dash')))
                    fig_cmp.update_layout(
                        title='提取光谱 vs 标准光谱对比',
                        xaxis_title='波长 (nm)', yaxis_title='吸光度',
                        height=380, margin=dict(l=40, r=20, t=40, b=40),
                        legend=dict(orientation='h', yanchor='bottom', y=1.02))
                    st.plotly_chart(fig_cmp, use_container_width=True)

                    # 判定阈值提示
                    if best['score'] >= 0.85:
                        st.success(f"✅ 高置信度匹配: **{best['name']}** (评分 {best['score']:.4f} >= 0.85)")
                    elif best['score'] >= 0.60:
                        st.warning(f"⚠️ 中等置信度匹配: **{best['name']}** (评分 {best['score']:.4f}), 建议结合其他方法确认")
                    else:
                        st.error(f"❌ 低置信度: 最高评分仅 {best['score']:.4f}, 可能不在标准库中或图像质量不足")
                else:
                    st.warning('标准光谱库为空或未加载，无法进行匹配。')
            else:
                st.error('❌ 无法从图像中提取光谱曲线。请确保上传的是清晰的UV-Vis吸收光谱图。')

    # Step 3: Preprocessing config
    if wavelengths is not None:
        with st.expander('Step 3: 预处理配置', expanded=False):
            pc1, pc2, pc3, pc4 = st.columns(4)
            with pc1:
                bl_method = st.selectbox('基线校正', ['ALS', 'Polynomial', 'Rubberband', 'Simple'],
                                         index=['ALS', 'Polynomial', 'Rubberband', 'Simple'].index(settings['baseline_method']))
            with pc2:
                dn_method = st.selectbox('噪声滤波', ['SG', 'Gaussian', 'Median', 'MovingAverage'],
                                         index=['SG', 'Gaussian', 'Median', 'MovingAverage'].index(
                                             settings['denoise_method']) if settings['denoise_method'] in ['SG', 'Gaussian', 'Median', 'MovingAverage'] else 0)
            with pc3:
                nm_method = st.selectbox('标准化', ['MinMax', 'ZScore', 'L1', 'L2', 'SNV'],
                                         index=['MinMax', 'ZScore', 'L1', 'L2', 'SNV'].index(settings['norm_method']))
            with pc4:
                fw = st.slider('滤波窗口', 3, 21, settings['filter_window'], 2)
            analysis_mode = st.selectbox('分析模式', ['hybrid', 'random_forest', 'rule_engine'],
                                         format_func=lambda x: {'hybrid': '混合模式(推荐)', 'random_forest': '随机森林', 'rule_engine': '规则引擎'}[x],
                                         index=['hybrid', 'random_forest', 'rule_engine'].index(
                                             settings['analysis_mode'] if settings['analysis_mode'] != 'deep_learning' else 'random_forest'))
        # Step 4: Spectral preview
        st.subheader('Step 4: 光谱预览')
        wl_proc, proc_data = preprocess_spectrum(wavelengths, raw_intensities,
                                                  bl_method, dn_method, nm_method, fw)
        fig = go.Figure()
        # normalize raw for display
        raw_norm = minmax_normalize(raw_intensities)
        fig.add_trace(go.Scatter(x=wavelengths, y=raw_norm, mode='lines',
                                 name='原始光谱', line=dict(color='#90CAF9', width=1)))
        fig.add_trace(go.Scatter(x=wl_proc, y=proc_data, mode='lines',
                                 name='预处理后', line=dict(color='#1565C0', width=2)))
        # mark pesticide peaks
        for pest_en in PESTICIDE_CLASSES[1:]:
            for pw, pi in PESTICIDE_PEAKS.get(pest_en, []):
                if 200 <= pw <= 1000:
                    fig.add_vline(x=pw, line_dash='dot', line_color='rgba(255,0,0,0.15)')
        fig.update_layout(title='光谱数据', xaxis_title='波长 (nm)', yaxis_title='归一化强度',
                          height=350, margin=dict(l=40, r=20, t=40, b=40))
        st.plotly_chart(fig, use_container_width=True)

        # Step 5: Run analysis
        st.subheader('Step 5: 执行分析')
        if st.button('🚀 开始分析', type='primary', use_container_width=True, disabled=not sample_name):
            if not sample_name:
                st.warning('请输入样品名称')
            else:
                progress = st.progress(0, text='初始化分析引擎...')
                # Step 1: Preprocessing (actual work)
                progress.progress(10, text='光谱预处理...')
                final_wl, final_proc = preprocess_spectrum(
                    wavelengths, raw_intensities, bl_method, dn_method, nm_method, fw)
                # Step 2: Feature extraction (actual work)
                progress.progress(30, text='特征提取...')
                feat = build_feature_vector(final_proc)
                # Step 3: Model inference (actual work)
                mode_label = {'hybrid': '混合模式', 'random_forest': '随机森林', 'rule_engine': '规则引擎'}.get(analysis_mode, 'AI')
                progress.progress(50, text=f'{mode_label}推理...')
                if analysis_mode == 'random_forest':
                    pests, conf = random_forest_analyze(final_proc, feat)
                elif analysis_mode == 'rule_engine':
                    pests, conf = rule_engine_detect(final_wl, final_proc, feat)
                else:
                    pests, conf = hybrid_analyze(final_wl, final_proc, feat)
                # Step 4: Risk assessment (actual work)
                progress.progress(70, text='风险评估...')
                risk = determine_risk_level(pests)
                # Step 5: Explainability (actual work)
                progress.progress(85, text='可解释性分析...')
                rf_clf_exp = None
                if analysis_mode in ('random_forest', 'hybrid'):
                    rf_clf_exp, _ = _train_rf_models()
                explain = compute_explainability(final_wl, final_proc, feat, conf, rf_clf=rf_clf_exp)
                # Step 6: Build result
                progress.progress(95, text='生成检测报告...')
                result = DetectionResult(
                    id=str(uuid.uuid4())[:8],
                    timestamp=datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    sample_name=sample_name,
                    sample_category=sample_category,
                    risk_level=risk.value,
                    confidence=round(conf, 4),
                    detected_pesticides=[p.to_dict() for p in pests],
                    notes=f'{sample_source} {notes}'.strip(),
                    explainability=explain.to_dict(),
                )
                progress.progress(100, text='分析完成!')
                save_result(result)
                st.session_state['last_result'] = result.to_dict()
                st.session_state['last_explain'] = explain.to_dict()
                st.session_state['last_wl'] = final_wl.tolist()
                st.session_state['last_proc'] = final_proc.tolist()
                st.rerun()

    # Step 6: Show results
    if 'last_result' in st.session_state:
        st.divider()
        st.subheader('Step 6: 检测结果')
        r = st.session_state['last_result']
        risk = RiskLevel(r['risk_level'])
        risk_class = {RiskLevel.SAFE: 'risk-safe', RiskLevel.LOW: 'risk-low',
                      RiskLevel.MEDIUM: 'risk-medium', RiskLevel.HIGH: 'risk-high',
                      RiskLevel.CRITICAL: 'risk-critical'}[risk]
        mc1, mc2, mc3, mc4 = st.columns(4)
        mc1.metric('样品', r['sample_name'])
        mc2.metric('置信度', f"{r['confidence'] * 100:.1f}%")
        mc3.metric('检出种类', len(r.get('detected_pesticides', [])))
        with mc4:
            st.markdown(f"**风险等级**")
            st.markdown(f"<span class='{risk_class}'>{RISK_CN.get(risk, '')}</span>", unsafe_allow_html=True)

        pests = [DetectedPesticide.from_dict(p) for p in r.get('detected_pesticides', [])]
        if pests:
            is_all_ok = all(not p.is_over_limit for p in pests)
            if is_all_ok:
                st.success(f'✅ 检测合格 — 检出农药均未超过国家标准限量。')
            else:
                st.error(f'❌ 检测不合格 — 存在农药残留超标。')
            pest_data = []
            for p in pests:
                pest_data.append({
                    '农药名称': p.name, '类型': p.pesticide_type,
                    '检出浓度(mg/kg)': f'{p.concentration:.4f}',
                    '限量标准(mg/kg)': f'{p.max_residue_limit}',
                    '超标倍数': f'{p.over_limit_ratio:.2f}',
                    '判定': '⚠️ 超标' if p.is_over_limit else '✅ 合格',
                })
            st.dataframe(pd.DataFrame(pest_data), use_container_width=True, hide_index=True)
        else:
            st.success('✅ 未检出农药残留，样品安全。')

        # Explainability
        if 'last_explain' in st.session_state:
            explain = st.session_state['last_explain']
            with st.expander('🤖 AI可解释性分析', expanded=True):
                ec1, ec2 = st.columns(2)
                with ec1:
                    # Spectral band importance
                    bands = explain.get('spectral_bands', {})
                    if bands:
                        fig_bands = go.Figure(go.Bar(
                            x=list(bands.keys()), y=[v * 100 for v in bands.values()],
                            marker_color='#1565C0'))
                        fig_bands.update_layout(title='光谱波段贡献度 (%)',
                                                height=300, margin=dict(l=40, r=20, t=40, b=40))
                        st.plotly_chart(fig_bands, use_container_width=True)
                with ec2:
                    # Feature importance
                    feat_imp = explain.get('feature_importance', {})
                    if feat_imp:
                        sorted_fi = sorted(feat_imp.items(), key=lambda x: abs(x[1]), reverse=True)[:10]
                        fig_fi = go.Figure(go.Bar(
                            y=[k for k, v in sorted_fi],
                            x=[v for k, v in sorted_fi],
                            orientation='h', marker_color='#FF7043'))
                        fig_fi.update_layout(title='特征重要性 Top-10',
                                             height=300, margin=dict(l=80, r=20, t=40, b=40))
                        st.plotly_chart(fig_fi, use_container_width=True)
                # SHAP heatmap on spectrum
                if 'last_wl' in st.session_state and 'last_proc' in st.session_state:
                    shap_vals = np.array(explain.get('shap_values', []))
                    wl_arr = np.array(st.session_state['last_wl'])
                    proc_arr = np.array(st.session_state['last_proc'])
                    if len(shap_vals) == len(wl_arr):
                        fig_shap = go.Figure()
                        fig_shap.add_trace(go.Scatter(
                            x=wl_arr, y=proc_arr, mode='lines',
                            name='预处理光谱', line=dict(color='#1565C0', width=2)))
                        # color by SHAP
                        pos_mask = shap_vals > 0
                        neg_mask = shap_vals < 0
                        if np.any(pos_mask):
                            fig_shap.add_trace(go.Scatter(
                                x=wl_arr[pos_mask], y=proc_arr[pos_mask],
                                mode='markers', name='正贡献',
                                marker=dict(color='red', size=3, opacity=0.5)))
                        if np.any(neg_mask):
                            fig_shap.add_trace(go.Scatter(
                                x=wl_arr[neg_mask], y=proc_arr[neg_mask],
                                mode='markers', name='负贡献',
                                marker=dict(color='blue', size=3, opacity=0.5)))
                        fig_shap.update_layout(title='SHAP值光谱叠加图', height=300,
                                               xaxis_title='波长(nm)', yaxis_title='强度',
                                               margin=dict(l=40, r=20, t=40, b=40))
                        st.plotly_chart(fig_shap, use_container_width=True)
                # Critical wavelengths table
                cws = explain.get('critical_wavelengths', [])
                if cws:
                    st.markdown('**关键波长分析**')
                    cw_data = []
                    for cw in cws[:8]:
                        sign = '+' if cw.get('is_positive') else '-'
                        cw_data.append({
                            '波长(nm)': cw['wavelength'],
                            '方向': sign,
                            '贡献度': f"{cw['contribution']:.6f}",
                            '化学意义': cw.get('reason', ''),
                        })
                    st.dataframe(pd.DataFrame(cw_data), use_container_width=True, hide_index=True)
                # Confidence interval
                ci = explain.get('confidence_interval', [0, 0])
                st.info(f"模型置信度: {r['confidence'] * 100:.1f}% | 95%置信区间: [{ci[0] * 100:.1f}%, {ci[1] * 100:.1f}%]")

        # Actions
        ac1, ac2, ac3 = st.columns(3)
        with ac1:
            pdf_bytes = generate_pdf_report(DetectionResult.from_dict(r))
            if pdf_bytes:
                st.download_button('📄 下载PDF报告', data=pdf_bytes,
                                   file_name=f"report_{r['id']}.pdf", mime='application/pdf',
                                   use_container_width=True)
        with ac2:
            st.download_button('📋 导出JSON', data=json.dumps(r, ensure_ascii=False, indent=2),
                               file_name=f"result_{r['id']}.json", mime='application/json',
                               use_container_width=True)
        with ac3:
            if st.button('🔄 新建检测', use_container_width=True):
                for k in ['last_result', 'last_explain', 'last_wl', 'last_proc']:
                    st.session_state.pop(k, None)
                st.rerun()


# ---------- Page: History ----------

def page_history():
    st.title('📋 历史记录')
    hist = get_history()
    if not hist:
        st.info('暂无检测记录。')
        return
    # Filters
    fc1, fc2, fc3 = st.columns(3)
    with fc1:
        risk_filter = st.multiselect('风险等级筛选',
                                      options=[rl.value for rl in RiskLevel],
                                      format_func=lambda x: RISK_CN.get(RiskLevel(x), ''))
    with fc2:
        search_q = st.text_input('搜索样品名称', placeholder='输入关键词...')
    with fc3:
        sort_order = st.selectbox('排序', ['最新优先', '最旧优先'])
    # Apply filters
    filtered = list(hist)
    if risk_filter:
        filtered = [r for r in filtered if r['risk_level'] in risk_filter]
    if search_q:
        filtered = [r for r in filtered if search_q.lower() in r.get('sample_name', '').lower()]
    if sort_order == '最旧优先':
        filtered = list(reversed(filtered))
    st.caption(f'共 {len(filtered)} 条记录（总计 {len(hist)} 条）')
    # Pagination
    page_size = 20
    total_pages = max(1, math.ceil(len(filtered) / page_size))
    if 'hist_page' not in st.session_state:
        st.session_state.hist_page = 1
    page_num = st.session_state.hist_page
    start = (page_num - 1) * page_size
    page_items = filtered[start:start + page_size]
    # Display
    for i, r in enumerate(page_items):
        risk = RiskLevel(r['risk_level'])
        icon = {'safe': '🟢', 'low': '🟡', 'medium': '🟠', 'high': '🔴', 'critical': '⛔'}
        risk_icon = icon.get(risk.name.lower(), '⚪')
        pests = r.get('detected_pesticides', [])
        pest_str = ', '.join(p['name'] for p in pests) if pests else '无检出'
        col1, col2, col3 = st.columns([4, 1, 1])
        with col1:
            st.markdown(f"{risk_icon} **{r['sample_name']}** ({r['sample_category']}) | "
                        f"{r['timestamp']} | {RISK_CN.get(risk, '')} | {pest_str} | "
                        f"置信度 {r['confidence'] * 100:.1f}%")
        with col2:
            if st.button('详情', key=f'detail_{start + i}'):
                st.session_state['last_result'] = r
                if r.get('explainability'):
                    st.session_state['last_explain'] = r['explainability']
                st.session_state.current_page = 'detection'
                st.rerun()
        with col3:
            if st.button('删除', key=f'del_{start + i}'):
                st.session_state.detection_history = [
                    h for h in st.session_state.detection_history if h['id'] != r['id']]
                st.rerun()
    # Pagination controls
    if total_pages > 1:
        pc1, pc2, pc3 = st.columns([1, 2, 1])
        with pc1:
            if st.button('◀ 上一页', disabled=page_num <= 1):
                st.session_state.hist_page = max(1, page_num - 1)
                st.rerun()
        with pc2:
            st.markdown(f"<center>第 {page_num}/{total_pages} 页</center>", unsafe_allow_html=True)
        with pc3:
            if st.button('下一页 ▶', disabled=page_num >= total_pages):
                st.session_state.hist_page = min(total_pages, page_num + 1)
                st.rerun()
    st.divider()
    dc1, dc2 = st.columns(2)
    with dc1:
        if st.button('🗑️ 清空全部记录', type='secondary'):
            st.session_state.detection_history = []
            st.rerun()


# ---------- Page: Statistics ----------

def page_statistics():
    st.title('📈 数据统计')
    hist = get_history()
    if not hist:
        st.info('暂无检测数据。')
        return
    total = len(hist)
    qualified = sum(1 for r in hist if r['risk_level'] <= 1)
    avg_conf = np.mean([r['confidence'] for r in hist])
    # Summary cards
    c1, c2, c3, c4 = st.columns(4)
    c1.metric('总检测次数', total)
    c2.metric('合格数', qualified)
    c3.metric('合格率', f'{qualified / total * 100:.1f}%')
    c4.metric('平均置信度', f'{avg_conf * 100:.1f}%')
    st.divider()
    col1, col2 = st.columns(2)
    with col1:
        # Risk level pie chart
        risk_counts = {}
        for r in hist:
            rl = RISK_CN.get(RiskLevel(r['risk_level']), '未知')
            risk_counts[rl] = risk_counts.get(rl, 0) + 1
        fig_pie = go.Figure(go.Pie(
            labels=list(risk_counts.keys()),
            values=list(risk_counts.values()),
            marker_colors=[RISK_COLORS.get(RiskLevel(i), '#999')
                           for i, _ in enumerate(risk_counts)
                           if i < len(RiskLevel)] or None,
            hole=0.4))
        fig_pie.update_layout(title='风险等级分布', height=350)
        st.plotly_chart(fig_pie, use_container_width=True)
    with col2:
        # Category distribution
        cat_counts = {}
        for r in hist:
            cat = r.get('sample_category', '其他')
            cat_counts[cat] = cat_counts.get(cat, 0) + 1
        fig_bar = go.Figure(go.Bar(
            x=list(cat_counts.keys()), y=list(cat_counts.values()),
            marker_color='#42A5F5'))
        fig_bar.update_layout(title='样品类型分布', height=350,
                              xaxis_title='样品类型', yaxis_title='次数')
        st.plotly_chart(fig_bar, use_container_width=True)
    # Time trend
    st.subheader('检测时间趋势')
    dates = {}
    for r in hist:
        d = r['timestamp'][:10]
        dates[d] = dates.get(d, 0) + 1
    if dates:
        sorted_dates = sorted(dates.items())
        fig_line = go.Figure(go.Scatter(
            x=[d[0] for d in sorted_dates], y=[d[1] for d in sorted_dates],
            mode='lines+markers', line=dict(color='#1565C0', width=2),
            marker=dict(size=6)))
        fig_line.update_layout(title='每日检测次数', height=300,
                               xaxis_title='日期', yaxis_title='检测次数')
        st.plotly_chart(fig_line, use_container_width=True)
    # Pesticide detection stats
    st.subheader('农药检出统计')
    pest_stats = {}
    for r in hist:
        for p in r.get('detected_pesticides', []):
            name = p.get('name', '未知')
            pest_stats[name] = pest_stats.get(name, 0) + 1
    if pest_stats:
        fig_pest = go.Figure(go.Bar(
            x=list(pest_stats.keys()), y=list(pest_stats.values()),
            marker_color='#FF7043'))
        fig_pest.update_layout(title='各农药检出次数', height=300,
                               xaxis_title='农药名称', yaxis_title='检出次数')
        st.plotly_chart(fig_pest, use_container_width=True)
    else:
        st.info('暂无农药检出记录。')


# ---------- Page: Data Management ----------

def page_data_management():
    st.title('📥 数据管理')
    tab1, tab2, tab3 = st.tabs(['📤 导出数据', '📥 导入数据', '📂 光谱文件导入'])

    with tab1:
        st.subheader('导出检测数据')
        hist = get_history()
        if hist:
            c1, c2 = st.columns(2)
            with c1:
                st.download_button('📋 导出为 JSON', data=export_history_json(),
                                   file_name='detection_history.json', mime='application/json',
                                   use_container_width=True)
            with c2:
                st.download_button('📊 导出为 CSV', data=export_history_csv(),
                                   file_name='detection_history.csv', mime='text/csv',
                                   use_container_width=True)
            st.caption(f'共 {len(hist)} 条记录可导出')
        else:
            st.info('暂无数据可导出。')

    with tab2:
        st.subheader('导入历史数据')
        st.warning('导入将覆盖当前所有历史记录，请先备份！')
        uploaded_json = st.file_uploader('上传 JSON 历史数据文件', type=['json'], key='import_hist')
        if uploaded_json:
            try:
                content = uploaded_json.read().decode('utf-8')
                data = json.loads(content)
                count = len(data.get('results', []))
                st.info(f'文件包含 {count} 条记录')
                if st.button('确认导入', type='primary'):
                    import_history_json(content)
                    st.success(f'成功导入 {count} 条记录！')
                    st.rerun()
            except Exception as e:
                st.error(f'文件格式错误: {e}')

    with tab3:
        st.subheader('光谱文件预览')
        uploaded_spec = st.file_uploader('上传光谱文件预览', type=['csv', 'txt', 'json', 'dx', 'jdx'],
                                         key='preview_spec')
        if uploaded_spec:
            try:
                wl, it = parse_uploaded_file(uploaded_spec)
                st.success(f'数据点: {len(wl)}, 波长范围: {wl[0]:.1f}-{wl[-1]:.1f} nm')
                fig = go.Figure(go.Scatter(x=wl, y=it, mode='lines', line=dict(color='#1565C0')))
                fig.update_layout(title='光谱预览', xaxis_title='波长(nm)', yaxis_title='强度',
                                  height=350)
                st.plotly_chart(fig, use_container_width=True)
                # Show first 10 data points
                df_preview = pd.DataFrame({'波长(nm)': wl[:10], '强度': it[:10]})
                st.dataframe(df_preview, hide_index=True)
            except Exception as e:
                st.error(f'解析失败: {e}')


# ---------- Page: Settings ----------

def page_settings():
    st.title('⚙️ 系统设置')
    settings = st.session_state.settings

    st.subheader('分析模式')
    _cur_mode = settings['analysis_mode'] if settings['analysis_mode'] != 'deep_learning' else 'random_forest'
    mode = st.selectbox('默认分析模式',
                         ['hybrid', 'random_forest', 'rule_engine'],
                         format_func=lambda x: {'hybrid': '混合模式(推荐)', 'random_forest': '随机森林', 'rule_engine': '规则引擎'}[x],
                         index=['hybrid', 'random_forest', 'rule_engine'].index(_cur_mode))
    settings['analysis_mode'] = mode

    st.subheader('预处理默认参数')
    c1, c2, c3, c4 = st.columns(4)
    with c1:
        settings['baseline_method'] = st.selectbox('基线校正', ['ALS', 'Polynomial', 'Rubberband', 'Simple'],
                                                    index=['ALS', 'Polynomial', 'Rubberband', 'Simple'].index(settings['baseline_method']),
                                                    key='set_bl')
    with c2:
        dn_opts = ['SG', 'Gaussian', 'Median', 'MovingAverage']
        settings['denoise_method'] = st.selectbox('噪声滤波', dn_opts,
                                                   index=dn_opts.index(settings['denoise_method']) if settings['denoise_method'] in dn_opts else 0,
                                                   key='set_dn')
    with c3:
        settings['norm_method'] = st.selectbox('标准化', ['MinMax', 'ZScore', 'L1', 'L2', 'SNV'],
                                                index=['MinMax', 'ZScore', 'L1', 'L2', 'SNV'].index(settings['norm_method']),
                                                key='set_nm')
    with c4:
        settings['filter_window'] = st.slider('滤波窗口', 3, 21, settings['filter_window'], 2, key='set_fw')

    st.divider()
    st.subheader('关于系统')
    st.markdown("""
**农药残留智能检测系统** v1.0

**核心功能：**
- 🔬 基于AI的多种农药残留检测（11种农药）
- 📊 光谱数据预处理（ALS基线校正、SG/高斯滤波、多种标准化）
- 🧮 64维特征工程（统计/导数/峰值/小波/频域/纹理）
- 🤖 AI推理引擎（随机森林 + 规则引擎 + 混合模式）
- 📈 SHAP可解释性分析（扰动式近似 + RF特征重要性）
- 📄 PDF检测报告生成
- 📥 光谱文件导入（CSV/JSON/JCAMP-DX）
- 💾 数据导入导出（JSON/CSV）

**技术栈：** Streamlit + NumPy + Plotly + FPDF2 + scikit-learn  
**参考标准：** GB 2763《食品安全国家标准 食品中农药最大残留限量》

---
*检测结果仅供参考，不作为法律依据。*
    """)


# ======================================================================
# Entry point
# ======================================================================

if __name__ == '__main__':
    main()
