"""
数据集划分与DataLoader配置模块

功能：实现数据集分层划分(7:2:1)和DataLoader配置，
保证训练集启用增强、验证/测试集禁用增强的完全隔离逻辑。
"""

from typing import Dict, Optional, Tuple

import numpy as np
from sklearn.model_selection import StratifiedShuffleSplit
from torch.utils.data import DataLoader

from data.augmentation import SpectralAugmentation
from data.data_generator import generate_spectral_data, load_real_data
from data.dataset import SpectralDataset
from data.preprocessing import SpectralPreprocessingPipeline
from utils.seed import worker_init_fn


def create_stratified_split(
    spectra: np.ndarray,
    labels: np.ndarray,
    concentrations: np.ndarray,
    split_ratio: list = None,
    seed: int = 42,
) -> Dict[str, Dict[str, np.ndarray]]:
    """
    按比例分层划分训练/验证/测试集，保证各集合类别分布一致。

    Args:
        spectra: 光谱数据 (N, num_wavelengths)
        labels: 分类标签 (N,)
        concentrations: 浓度值 (N,)
        split_ratio: 划分比例 [train, val, test], 默认 [0.7, 0.2, 0.1]
        seed: 随机种子

    Returns:
        dict: {"train": {...}, "val": {...}, "test": {...}}
    """
    if split_ratio is None:
        split_ratio = [0.7, 0.2, 0.1]

    assert abs(sum(split_ratio) - 1.0) < 1e-6, f"划分比例之和必须为1.0，当前为{sum(split_ratio)}"

    n = len(spectra)

    # 第一次划分：分出测试集
    test_size = split_ratio[2]
    splitter1 = StratifiedShuffleSplit(n_splits=1, test_size=test_size, random_state=seed)
    train_val_idx, test_idx = next(splitter1.split(spectra, labels))

    # 第二次划分：从剩余中分出验证集
    val_size_relative = split_ratio[1] / (split_ratio[0] + split_ratio[1])
    splitter2 = StratifiedShuffleSplit(n_splits=1, test_size=val_size_relative, random_state=seed)
    train_idx, val_idx = next(splitter2.split(spectra[train_val_idx], labels[train_val_idx]))

    # 映射回原始索引
    train_idx = train_val_idx[train_idx]
    val_idx = train_val_idx[val_idx]

    return {
        "train": {
            "spectra": spectra[train_idx],
            "labels": labels[train_idx],
            "concentrations": concentrations[train_idx],
        },
        "val": {
            "spectra": spectra[val_idx],
            "labels": labels[val_idx],
            "concentrations": concentrations[val_idx],
        },
        "test": {
            "spectra": spectra[test_idx],
            "labels": labels[test_idx],
            "concentrations": concentrations[test_idx],
        },
    }


def create_dataloaders(
    config,
    generator=None,
) -> Tuple[DataLoader, DataLoader, DataLoader, SpectralPreprocessingPipeline]:
    """
    端到端DataLoader工厂函数。

    完整流程:
        1. 生成/加载数据
        2. 分层划分7:2:1
        3. 在训练集上拟合预处理管线(防数据泄露)
        4. 对三个集合分别做transform
        5. 构建Dataset(训练集带增强，验证/测试集不带)
        6. 返回三个DataLoader + 预处理管线

    Args:
        config: 全局配置对象(ConfigNamespace)
        generator: 可选的torch.Generator用于DataLoader

    Returns:
        tuple: (train_loader, val_loader, test_loader, preprocessing_pipeline)
    """
    data_cfg = config.data

    # 1. 生成或加载数据
    if getattr(data_cfg, 'simulation', None) and getattr(data_cfg.simulation, 'enabled', True):
        sim_cfg = data_cfg.simulation
        raw_data = generate_spectral_data(
            num_wavelengths=data_cfg.num_wavelengths,
            wavelength_range=data_cfg.wavelength_range,
            samples_per_class=sim_cfg.samples_per_class,
            concentration_range=data_cfg.concentration_range,
            noise_std=sim_cfg.noise_std,
            baseline_amplitude=sim_cfg.baseline_amplitude,
            peak_intensity_scale=sim_cfg.peak_intensity_scale,
            concentration_distribution=getattr(sim_cfg, 'concentration_distribution', 'log_uniform'),
            seed=config.seed,
        )
    else:
        real_data_path = getattr(data_cfg, 'real_data_path', None)
        if real_data_path is None:
            raise ValueError("模拟数据未启用且未指定真实数据路径(data.real_data_path)")
        raw_data = load_real_data(real_data_path)

    print(f"[Data] 总样本数: {len(raw_data['spectra'])}, "
          f"光谱维度: {raw_data['spectra'].shape[1]}, "
          f"类别数: {len(np.unique(raw_data['labels']))}")

    # 2. 分层划分
    splits = create_stratified_split(
        spectra=raw_data["spectra"],
        labels=raw_data["labels"],
        concentrations=raw_data["concentrations"],
        split_ratio=data_cfg.split_ratio,
        seed=config.seed,
    )

    print(f"[Data] 训练集: {len(splits['train']['labels'])}, "
          f"验证集: {len(splits['val']['labels'])}, "
          f"测试集: {len(splits['test']['labels'])}")

    # 3. 构建预处理管线，仅在训练集上fit
    prep_cfg = data_cfg.preprocessing
    pipeline = SpectralPreprocessingPipeline(
        sg_window=prep_cfg.sg_window,
        sg_polyorder=prep_cfg.sg_polyorder,
        derivative_order=prep_cfg.derivative_order,
        scatter_correction=prep_cfg.scatter_correction,
        standardize=prep_cfg.standardize,
    )

    # 仅使用训练集数据拟合参数 — 杜绝数据泄露
    train_spectra = pipeline.fit_transform(splits["train"]["spectra"])
    val_spectra = pipeline.transform(splits["val"]["spectra"])
    test_spectra = pipeline.transform(splits["test"]["spectra"])

    # 4. 构建数据增强(仅训练集)
    aug = None
    aug_cfg = getattr(data_cfg, 'augmentation', None)
    if aug_cfg is not None and getattr(aug_cfg, 'enabled', False):
        aug = SpectralAugmentation(
            gaussian_noise_std=aug_cfg.gaussian_noise_std,
            baseline_shift_range=aug_cfg.baseline_shift_range,
            band_dropout_prob=aug_cfg.band_dropout_prob,
            band_dropout_width=aug_cfg.band_dropout_width,
        )
        print("[Data] 训练集数据增强: 已启用")

    # 5. 构建Dataset
    train_dataset = SpectralDataset(
        spectra=train_spectra,
        labels=splits["train"]["labels"],
        concentrations=splits["train"]["concentrations"],
        augmentation=aug,
    )

    val_dataset = SpectralDataset(
        spectra=val_spectra,
        labels=splits["val"]["labels"],
        concentrations=splits["val"]["concentrations"],
        augmentation=None,  # 验证集不使用增强
    )

    test_dataset = SpectralDataset(
        spectra=test_spectra,
        labels=splits["test"]["labels"],
        concentrations=splits["test"]["concentrations"],
        augmentation=None,  # 测试集不使用增强
    )

    # 6. 构建DataLoader
    batch_size = data_cfg.batch_size
    num_workers = getattr(data_cfg, 'num_workers', 0)

    # pin_memory仅在CUDA可用时启用
    import torch
    pin_mem = torch.cuda.is_available()

    loader_kwargs = {
        "num_workers": num_workers,
        "pin_memory": pin_mem,
        "worker_init_fn": worker_init_fn if num_workers > 0 else None,
    }
    if generator is not None:
        loader_kwargs["generator"] = generator

    train_loader = DataLoader(
        train_dataset,
        batch_size=batch_size,
        shuffle=True,
        drop_last=False,
        **loader_kwargs,
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=batch_size,
        shuffle=False,
        **loader_kwargs,
    )

    test_loader = DataLoader(
        test_dataset,
        batch_size=batch_size,
        shuffle=False,
        **loader_kwargs,
    )

    return train_loader, val_loader, test_loader, pipeline
