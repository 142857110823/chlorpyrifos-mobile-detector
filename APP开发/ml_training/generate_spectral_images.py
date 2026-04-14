#!/usr/bin/env python3
"""
光谱数据生成脚本 - 生成含毒死蜱和不含毒死蜱的光谱图片
用于训练光谱图片农药识别模型
"""

import numpy as np
import matplotlib.pyplot as plt
import os
from sklearn.preprocessing import StandardScaler

# 设置随机种子以保证可重复性
np.random.seed(42)

# 农药类别定义
PESTICIDE_CLASSES = [
    'none',           # 无农药
    'chlorpyrifos',   # 毒死蜱
]

# 每种农药的特征波长峰（模拟）
PESTICIDE_PEAKS = {
    'none': [],
    'chlorpyrifos': [(450, 0.8), (520, 0.6), (680, 0.4)],
}

# 最大残留限量 (mg/kg)
MRL_LIMITS = {
    'chlorpyrifos': 0.1,
}


def generate_base_spectrum(wavelengths):
    """生成基础光谱（背景信号）"""
    # 基线漂移
    baseline = 500 + 200 * np.sin(wavelengths / 200)
    # 高斯噪声
    noise = np.random.normal(0, 30, len(wavelengths))
    return baseline + noise


def add_pesticide_signature(spectrum, wavelengths, pesticide, concentration):
    """添加农药特征峰"""
    if pesticide == 'none' or pesticide not in PESTICIDE_PEAKS:
        return spectrum
    
    peaks = PESTICIDE_PEAKS[pesticide]
    for peak_wavelength, peak_intensity in peaks:
        # 高斯峰
        sigma = 20 + np.random.uniform(-5, 5)
        peak = concentration * peak_intensity * 1000 * np.exp(
            -((wavelengths - peak_wavelength) ** 2) / (2 * sigma ** 2)
        )
        spectrum = spectrum + peak
    
    return spectrum


def generate_spectral_data(n_samples_per_class=500):
    """生成模拟光谱数据集"""
    wavelengths = np.linspace(200, 1000, 256)
    
    X_spectral = []
    y_class = []
    
    for class_idx, pesticide in enumerate(PESTICIDE_CLASSES):
        for _ in range(n_samples_per_class):
            # 生成基础光谱
            spectrum = generate_base_spectrum(wavelengths)
            
            # 确定浓度
            if pesticide == 'none':
                concentration = 0.0
            else:
                # 浓度范围：0.01 - 2.0 mg/kg
                concentration = np.random.uniform(0.01, 2.0)
            
            # 添加农药特征
            spectrum = add_pesticide_signature(spectrum, wavelengths, pesticide, concentration)
            
            # 数据增强：添加随机噪声
            spectrum += np.random.normal(0, 20, len(spectrum))
            
            # 数据增强：随机基线偏移
            spectrum += np.random.uniform(-50, 50)
            
            X_spectral.append(spectrum)
            y_class.append(class_idx)
    
    return (np.array(X_spectral), 
            np.array(y_class),
            wavelengths)


def plot_spectrum(wavelengths, spectrum, output_path):
    """绘制光谱曲线并保存为PNG图片"""
    plt.figure(figsize=(8, 6))
    plt.plot(wavelengths, spectrum, 'k-', linewidth=2)
    plt.xlabel('Wavelength (nm)')
    plt.ylabel('Intensity')
    plt.title('Spectral Curve')
    plt.grid(True, alpha=0.3)
    plt.axis('tight')
    
    # 移除坐标轴和边框，只保留曲线
    plt.gca().spines['top'].set_visible(False)
    plt.gca().spines['right'].set_visible(False)
    plt.gca().spines['left'].set_visible(False)
    plt.gca().spines['bottom'].set_visible(False)
    plt.xticks([])
    plt.yticks([])
    
    # 保存图片
    plt.savefig(output_path, bbox_inches='tight', pad_inches=0, dpi=150)
    plt.close()


def generate_dataset():
    """生成完整的数据集"""
    # 创建数据集目录结构
    base_dir = 'dataset'
    train_dir = os.path.join(base_dir, 'train')
    val_dir = os.path.join(base_dir, 'val')
    test_dir = os.path.join(base_dir, 'test')
    
    # 创建目录
    os.makedirs(os.path.join(train_dir, 'positive'), exist_ok=True)
    os.makedirs(os.path.join(train_dir, 'negative'), exist_ok=True)
    os.makedirs(os.path.join(val_dir, 'positive'), exist_ok=True)
    os.makedirs(os.path.join(val_dir, 'negative'), exist_ok=True)
    os.makedirs(os.path.join(test_dir, 'positive'), exist_ok=True)
    os.makedirs(os.path.join(test_dir, 'negative'), exist_ok=True)
    
    # 生成光谱数据
    print('生成光谱数据...')
    X_spectral, y_class, wavelengths = generate_spectral_data(n_samples_per_class=500)
    
    # 数据增强：生成更多样本
    print('数据增强...')
    augmented_X = []
    augmented_y = []
    
    for i in range(len(X_spectral)):
        spectrum = X_spectral[i]
        label = y_class[i]
        
        # 原始样本
        augmented_X.append(spectrum)
        augmented_y.append(label)
        
        # 数据增强：亮度调整
        for brightness in [0.8, 1.2]:
            augmented_spectrum = spectrum * brightness
            augmented_X.append(augmented_spectrum)
            augmented_y.append(label)
        
        # 数据增强：添加噪声
        for noise_level in [10, 40]:
            augmented_spectrum = spectrum + np.random.normal(0, noise_level, len(spectrum))
            augmented_X.append(augmented_spectrum)
            augmented_y.append(label)
    
    X_augmented = np.array(augmented_X)
    y_augmented = np.array(augmented_y)
    
    print(f'增强后数据集大小: {len(X_augmented)}')
    
    # 划分数据集
    print('划分数据集...')
    total_samples = len(X_augmented)
    train_size = int(total_samples * 0.8)
    val_size = int(total_samples * 0.1)
    test_size = total_samples - train_size - val_size
    
    # 打乱数据
    indices = np.random.permutation(total_samples)
    X_augmented = X_augmented[indices]
    y_augmented = y_augmented[indices]
    
    # 划分数据
    X_train = X_augmented[:train_size]
    y_train = y_augmented[:train_size]
    X_val = X_augmented[train_size:train_size+val_size]
    y_val = y_augmented[train_size:train_size+val_size]
    X_test = X_augmented[train_size+val_size:]
    y_test = y_augmented[train_size+val_size:]
    
    # 保存图片
    print('保存光谱图片...')
    
    # 保存训练集
    for i in range(len(X_train)):
        spectrum = X_train[i]
        label = y_train[i]
        class_name = 'positive' if label == 1 else 'negative'
        output_path = os.path.join(train_dir, class_name, f'train_{i}.png')
        plot_spectrum(wavelengths, spectrum, output_path)
    
    # 保存验证集
    for i in range(len(X_val)):
        spectrum = X_val[i]
        label = y_val[i]
        class_name = 'positive' if label == 1 else 'negative'
        output_path = os.path.join(val_dir, class_name, f'val_{i}.png')
        plot_spectrum(wavelengths, spectrum, output_path)
    
    # 保存测试集
    for i in range(len(X_test)):
        spectrum = X_test[i]
        label = y_test[i]
        class_name = 'positive' if label == 1 else 'negative'
        output_path = os.path.join(test_dir, class_name, f'test_{i}.png')
        plot_spectrum(wavelengths, spectrum, output_path)
    
    print('数据集生成完成！')
    print(f'训练集: {len(X_train)} 样本')
    print(f'验证集: {len(X_val)} 样本')
    print(f'测试集: {len(X_test)} 样本')


if __name__ == '__main__':
    generate_dataset()
