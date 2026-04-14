# APP开发源代码汇总

## 1. 农药残留检测模型训练脚本

### 文件路径：`ml_training/train_pesticide_model.py`

```python
#!/usr/bin/env python3
"""
农药残留检测模型训练脚本
生成用于Flutter APP的TFLite模型

功能:
1. 模拟11种农药的光谱数据
2. 训练CNN-1D分类模型
3. 训练浓度回归模型
4. 转换为TFLite格式
"""

import numpy as np
import tensorflow as tf
from tensorflow import keras
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
import os

# 设置随机种子以保证可重复性
np.random.seed(42)
tf.random.set_seed(42)

# 农药类别定义
PESTICIDE_CLASSES = [
    'none',           # 无农药
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

# 每种农药的特征波长峰（模拟）
PESTICIDE_PEAKS = {
    'none': [],
    'chlorpyrifos': [(450, 0.8), (520, 0.6), (680, 0.4)],
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

# 最大残留限量 (mg/kg)
MRL_LIMITS = {
    'chlorpyrifos': 0.1,
    'dimethoate': 1.0,
    'omethoate': 0.02,
    'phoxim': 0.05,
    'malathion': 0.5,
    'carbofuran': 0.02,
    'carbendazim': 0.5,
    'imidacloprid': 0.5,
    'acetamiprid': 0.3,
    'cypermethrin': 0.5,
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
    y_concentration = []
    
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
            
            # 浓度向量（每种农药的浓度，非当前农药为0）
            conc_vector = np.zeros(len(PESTICIDE_CLASSES) - 1)  # 排除'none'
            if class_idx > 0:
                conc_vector[class_idx - 1] = concentration
            y_concentration.append(conc_vector)
    
    return (np.array(X_spectral), 
            np.array(y_class), 
            np.array(y_concentration),
            wavelengths)


def extract_features(spectra):
    """提取统计特征"""
    features = []
    for spectrum in spectra:
        feat = []
        # 统计特征
        feat.append(np.mean(spectrum))
        feat.append(np.std(spectrum))
        feat.append(np.max(spectrum))
        feat.append(np.min(spectrum))
        feat.append(np.median(spectrum))
        
        # 分位数
        feat.extend(np.percentile(spectrum, [10, 25, 75, 90]))
        
        # 一阶导数统计
        diff1 = np.diff(spectrum)
        feat.append(np.mean(diff1))
        feat.append(np.std(diff1))
        feat.append(np.max(diff1))
        feat.append(np.min(diff1))
        
        # 二阶导数统计
        diff2 = np.diff(diff1)
        feat.append(np.mean(diff2))
        feat.append(np.std(diff2))
        
        # 峰值统计
        from scipy.signal import find_peaks
        peaks, _ = find_peaks(spectrum, height=np.mean(spectrum))
        feat.append(len(peaks))
        if len(peaks) > 0:
            feat.append(np.mean(spectrum[peaks]))
            feat.append(np.max(spectrum[peaks]))
        else:
            feat.append(0)
            feat.append(0)
        
        # 能量
        feat.append(np.sum(spectrum ** 2))
        
        # 零交叉率
        zero_crossings = np.sum(np.diff(np.sign(spectrum - np.mean(spectrum))) != 0)
        feat.append(zero_crossings)
        
        # 填充到64维
        while len(feat) < 64:
            feat.append(0)
        
        features.append(feat[:64])
    
    return np.array(features)


def build_classifier_model(input_shape):
    """构建分类模型"""
    # 光谱输入
    spectral_input = keras.Input(shape=(256,), name='spectral_input')
    # 特征输入
    feature_input = keras.Input(shape=(64,), name='feature_input')
    
    # 光谱分支 - 1D CNN
    x1 = keras.layers.Reshape((256, 1))(spectral_input)
    x1 = keras.layers.Conv1D(32, 7, activation='relu', padding='same')(x1)
    x1 = keras.layers.BatchNormalization()(x1)
    x1 = keras.layers.MaxPooling1D(2)(x1)
    x1 = keras.layers.Conv1D(64, 5, activation='relu', padding='same')(x1)
    x1 = keras.layers.BatchNormalization()(x1)
    x1 = keras.layers.MaxPooling1D(2)(x1)
    x1 = keras.layers.Conv1D(128, 3, activation='relu', padding='same')(x1)
    x1 = keras.layers.GlobalAveragePooling1D()(x1)
    
    # 特征分支 - MLP
    x2 = keras.layers.Dense(64, activation='relu')(feature_input)
    x2 = keras.layers.Dropout(0.3)(x2)
    x2 = keras.layers.Dense(32, activation='relu')(x2)
    
    # 融合
    merged = keras.layers.Concatenate()([x1, x2])
    x = keras.layers.Dense(128, activation='relu')(merged)
    x = keras.layers.Dropout(0.4)(x)
    x = keras.layers.Dense(64, activation='relu')(x)
    x = keras.layers.Dropout(0.3)(x)
    
    # 分类输出
    output = keras.layers.Dense(len(PESTICIDE_CLASSES), activation='softmax', name='classification')(x)
    
    model = keras.Model(inputs=[spectral_input, feature_input], outputs=output)
    return model


def build_regressor_model():
    """构建回归模型"""
    # 光谱输入
    spectral_input = keras.Input(shape=(256,), name='spectral_input')
    # 特征输入
    feature_input = keras.Input(shape=(64,), name='feature_input')
    
    # 光谱分支
    x1 = keras.layers.Reshape((256, 1))(spectral_input)
    x1 = keras.layers.Conv1D(32, 7, activation='relu', padding='same')(x1)
    x1 = keras.layers.BatchNormalization()(x1)
    x1 = keras.layers.MaxPooling1D(2)(x1)
    x1 = keras.layers.Conv1D(64, 5, activation='relu', padding='same')(x1)
    x1 = keras.layers.BatchNormalization()(x1)
    x1 = keras.layers.MaxPooling1D(2)(x1)
    x1 = keras.layers.Conv1D(64, 3, activation='relu', padding='same')(x1)
    x1 = keras.layers.GlobalAveragePooling1D()(x1)
    
    # 特征分支
    x2 = keras.layers.Dense(64, activation='relu')(feature_input)
    x2 = keras.layers.Dropout(0.3)(x2)
    x2 = keras.layers.Dense(32, activation='relu')(x2)
    
    # 融合
    merged = keras.layers.Concatenate()([x1, x2])
    x = keras.layers.Dense(64, activation='relu')(merged)
    x = keras.layers.Dropout(0.3)(x)
    x = keras.layers.Dense(32, activation='relu')(x)
    
    # 回归输出（10种农药的浓度）
    output = keras.layers.Dense(len(PESTICIDE_CLASSES) - 1, activation='relu', name='concentration')(x)
    
    model = keras.Model(inputs=[spectral_input, feature_input], outputs=output)
    return model


def convert_to_tflite(model, output_path, model_name):
    """转换模型为TFLite格式"""
    # 创建单一输入的包装模型（合并光谱和特征为320维输入）
    combined_input = keras.Input(shape=(320,), name='combined_input')
    spectral = combined_input[:, :256]
    features = combined_input[:, 256:]
    
    # 获取原模型输出
    output = model([spectral, features])
    
    wrapper_model = keras.Model(inputs=combined_input, outputs=output)
    
    # 转换为TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(wrapper_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float32]
    
    tflite_model = converter.convert()
    
    # 保存模型
    tflite_path = os.path.join(output_path, f'{model_name}.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f'模型已保存: {tflite_path} ({len(tflite_model) / 1024:.1f} KB)')
    return tflite_path


def main():
    print('=' * 60)
    print('农药残留检测模型训练')
    print('=' * 60)
    
    # 1. 生成数据
    print('\n[1/6] 生成模拟光谱数据...')
    X_spectral, y_class, y_concentration, wavelengths = generate_spectral_data(n_samples_per_class=500)
    print(f'  光谱数据形状: {X_spectral.shape}')
    print(f'  类别标签形状: {y_class.shape}')
    print(f'  浓度标签形状: {y_concentration.shape}')
    
    # 2. 特征提取
    print('\n[2/6] 提取统计特征...')
    try:
        X_features = extract_features(X_spectral)
    except ImportError:
        print('  警告: scipy未安装，使用简化特征')
        X_features = np.zeros((len(X_spectral), 64))
        for i, spectrum in enumerate(X_spectral):
            X_features[i, 0] = np.mean(spectrum)
            X_features[i, 1] = np.std(spectrum)
            X_features[i, 2] = np.max(spectrum)
            X_features[i, 3] = np.min(spectrum)
    print(f'  特征形状: {X_features.shape}')
    
    # 3. 数据标准化
    print('\n[3/6] 数据标准化...')
    scaler_spectral = StandardScaler()
    scaler_features = StandardScaler()
    X_spectral_scaled = scaler_spectral.fit_transform(X_spectral)
    X_features_scaled = scaler_features.fit_transform(X_features)
    
    # 4. 划分数据集
    print('\n[4/6] 划分训练/验证集...')
    X_spec_train, X_spec_val, X_feat_train, X_feat_val, y_class_train, y_class_val, y_conc_train, y_conc_val = train_test_split(
        X_spectral_scaled, X_features_scaled, y_class, y_concentration,
        test_size=0.2, random_state=42, stratify=y_class
    )
    print(f'  训练集: {len(X_spec_train)} 样本')
    print(f'  验证集: {len(X_spec_val)} 样本')
    
    # 5. 训练分类模型
    print('\n[5/6] 训练分类模型...')
    classifier = build_classifier_model((256,))
    classifier.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    y_class_onehot_train = keras.utils.to_categorical(y_class_train, num_classes=len(PESTICIDE_CLASSES))
    y_class_onehot_val = keras.utils.to_categorical(y_class_val, num_classes=len(PESTICIDE_CLASSES))
    
    classifier.fit(
        [X_spec_train, X_feat_train],
        y_class_train,
        validation_data=([X_spec_val, X_feat_val], y_class_val),
        epochs=30,
        batch_size=32,
        verbose=1,
        callbacks=[
            keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
            keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3)
        ]
    )
    
    # 评估分类模型
    _, val_acc = classifier.evaluate([X_spec_val, X_feat_val], y_class_val, verbose=0)
    print(f'  分类模型验证准确率: {val_acc:.4f}')
    
    # 6. 训练回归模型
    print('\n[6/6] 训练回归模型...')
    regressor = build_regressor_model()
    regressor.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='mse',
        metrics=['mae']
    )
    
    regressor.fit(
        [X_spec_train, X_feat_train],
        y_conc_train,
        validation_data=([X_spec_val, X_feat_val], y_conc_val),
        epochs=30,
        batch_size=32,
        verbose=1,
        callbacks=[
            keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
            keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3)
        ]
    )
    
    # 评估回归模型
    _, val_mae = regressor.evaluate([X_spec_val, X_feat_val], y_conc_val, verbose=0)
    print(f'  回归模型验证MAE: {val_mae:.4f} mg/kg')
    
    # 7. 转换为TFLite
    print('\n[7/7] 转换为TFLite格式...')
    output_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models')
    os.makedirs(output_dir, exist_ok=True)
    
    convert_to_tflite(classifier, output_dir, 'pesticide_classifier')
    convert_to_tflite(regressor, output_dir, 'concentration_regressor')
    
    print('\n' + '=' * 60)
    print('训练完成！')
    print('=' * 60)
    print(f'\n模型文件位置: {os.path.abspath(output_dir)}')
    print('\n农药类别:')
    for i, name in enumerate(PESTICIDE_CLASSES):
        print(f'  {i}: {name}')


if __name__ == '__main__':
    main()
```

## 2. TFLite模型生成器

### 文件路径：`ml_training/generate_tflite.py`

```python
#!/usr/bin/env python3
"""
TFLite Model Generator for Pesticide Detection App
===================================================
Generates TensorFlow Lite models for pesticide classification and concentration regression.

Requirements: pip install tensorflow numpy scikit-learn
Usage: python generate_tflite.py
"""

import os
import numpy as np

try:
    import tensorflow as tf
    from tensorflow import keras
    TF_AVAILABLE = True
    print(f"TensorFlow version: {tf.__version__}")
except ImportError:
    TF_AVAILABLE = False
    print("WARNING: TensorFlow not installed. Run: pip install tensorflow")

def generate_synthetic_training_data(n_samples=5000):
    np.random.seed(42)
    n_wavelengths = 256
    X, y_class, y_concentration = [], [], []
    
    for i in range(n_samples):
        cls = np.random.randint(0, 5)
        wavelengths = np.linspace(200, 1100, n_wavelengths)
        base = 0.3 + 0.4 * np.exp(-((wavelengths - 550) ** 2) / (2 * 150 ** 2))
        
        if cls == 0:
            spectrum = base + np.random.normal(0, 0.02, n_wavelengths)
            concentration = 0.0
        elif cls == 1:
            peak1 = 0.15 * np.exp(-((wavelengths - 280) ** 2) / (2 * 20 ** 2))
            peak2 = 0.10 * np.exp(-((wavelengths - 450) ** 2) / (2 * 30 ** 2))
            concentration = np.random.uniform(0.01, 0.5)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        elif cls == 2:
            peak = 0.20 * np.exp(-((wavelengths - 320) ** 2) / (2 * 25 ** 2))
            concentration = np.random.uniform(0.01, 0.4)
            spectrum = base - concentration * peak + np.random.normal(0, 0.02, n_wavelengths)
        elif cls == 3:
            peak1 = 0.12 * np.exp(-((wavelengths - 250) ** 2) / (2 * 15 ** 2))
            peak2 = 0.08 * np.exp(-((wavelengths - 380) ** 2) / (2 * 20 ** 2))
            concentration = np.random.uniform(0.01, 0.3)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        else:
            peak1 = 0.18 * np.exp(-((wavelengths - 270) ** 2) / (2 * 18 ** 2))
            peak2 = 0.12 * np.exp(-((wavelengths - 420) ** 2) / (2 * 25 ** 2))
            concentration = np.random.uniform(0.01, 0.35)
            spectrum = base - concentration * (peak1 + peak2) + np.random.normal(0, 0.02, n_wavelengths)
        
        spectrum = np.clip(spectrum, 0, 1)
        X.append(spectrum)
        y_class.append(cls)
        y_concentration.append(concentration)
    
    return np.array(X, dtype=np.float32), np.array(y_class), np.array(y_concentration, dtype=np.float32)


def build_classifier_model(input_shape=(256,), num_classes=5):
    model = keras.Sequential([
        keras.layers.Input(shape=input_shape),
        keras.layers.Dense(128, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.3),
        keras.layers.Dense(64, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation="relu"),
        keras.layers.Dense(num_classes, activation="softmax")
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    return model

def build_regressor_model(input_shape=(256,)):
    model = keras.Sequential([
        keras.layers.Input(shape=input_shape),
        keras.layers.Dense(128, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.3),
        keras.layers.Dense(64, activation="relu"),
        keras.layers.BatchNormalization(),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation="relu"),
        keras.layers.Dense(1, activation="linear")
    ])
    model.compile(optimizer="adam", loss="mse", metrics=["mae"])
    return model

def convert_to_tflite(model, output_path, quantize=True):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    with open(output_path, "wb") as f:
        f.write(tflite_model)
    print(f"Saved TFLite model to: {output_path} ({len(tflite_model) / 1024:.2f} KB)")
    return tflite_model


def main():
    if not TF_AVAILABLE:
        print("ERROR: TensorFlow is required. Install with: pip install tensorflow")
        return
    
    output_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 60)
    print("Pesticide Detection TFLite Model Generator")
    print("=" * 60)
    
    print("\n[1/5] Generating synthetic training data...")
    X, y_class, y_concentration = generate_synthetic_training_data(n_samples=5000)
    print(f"Generated {len(X)} samples with shape {X.shape}")
    
    from sklearn.model_selection import train_test_split
    X_train, X_test, y_class_train, y_class_test = train_test_split(X, y_class, test_size=0.2, random_state=42)
    _, _, y_conc_train, y_conc_test = train_test_split(X, y_concentration, test_size=0.2, random_state=42)
    
    print("\n[2/5] Training classification model...")
    classifier = build_classifier_model()
    classifier.fit(X_train, y_class_train, validation_data=(X_test, y_class_test), epochs=50, batch_size=32, verbose=1)
    
    print("\n[3/5] Evaluating classification model...")
    loss, accuracy = classifier.evaluate(X_test, y_class_test)
    print(f"Test accuracy: {accuracy:.4f}")
    
    print("\n[4/5] Training regression model...")
    mask_train = y_class_train > 0
    mask_test = y_class_test > 0
    regressor = build_regressor_model()
    regressor.fit(X_train[mask_train], y_conc_train[mask_train], validation_data=(X_test[mask_test], y_conc_test[mask_test]), epochs=50, batch_size=32, verbose=1)
    
    print("\n[5/5] Converting to TFLite format...")
    classifier_path = os.path.join(output_dir, "pesticide_classifier.tflite")
    regressor_path = os.path.join(output_dir, "concentration_regressor.tflite")
    convert_to_tflite(classifier, classifier_path)
    convert_to_tflite(regressor, regressor_path)
    
    print("\n" + "=" * 60)
    print("Model generation complete!")
    print("=" * 60)

if __name__ == "__main__":
    main()
```

## 3. 项目依赖

### 文件路径：`ml_training/requirements.txt`

（注：该文件未提供内容，此处为空白）

## 总结

本项目包含两个主要的Python脚本：

1. **train_pesticide_model.py**：
   - 模拟11种农药的光谱数据
   - 训练CNN-1D分类模型和浓度回归模型
   - 提取多种统计特征增强模型性能
   - 转换为TFLite格式供Flutter APP使用

2. **generate_tflite.py**：
   - 生成合成训练数据
   - 构建简化的分类和回归模型
   - 转换为量化的TFLite模型
   - 提供更简洁的模型生成流程

这两个脚本共同构成了农药残留检测APP的机器学习后端，为移动端应用提供了模型支持。