# TensorFlow Lite 模型目录

此目录用于存放农药残留检测的TFLite模型文件。

## 需要的模型文件

1. `pesticide_classifier.tflite` - 农药分类模型
   - 输入: 光谱数据 (256维) + 特征向量 (64维) = 320维
   - 输出: 11个类别的概率分布

2. `concentration_regressor.tflite` - 浓度回归模型
   - 输入: 光谱数据 (256维) + 特征向量 (64维) = 320维
   - 输出: 10个农药的浓度预测值

## 模型训练指南

如果没有预训练模型，系统会自动使用规则引擎进行分析。

### 使用Python训练模型示例：

```python
import tensorflow as tf
import numpy as np

# 创建简单的分类模型
def create_classifier():
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(320,)),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(11, activation='softmax')
    ])
    return model

# 创建回归模型
def create_regressor():
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(320,)),
        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dense(10, activation='linear')
    ])
    return model

# 转换为TFLite
def convert_to_tflite(model, output_path):
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

# 生成模型
classifier = create_classifier()
regressor = create_regressor()

convert_to_tflite(classifier, 'pesticide_classifier.tflite')
convert_to_tflite(regressor, 'concentration_regressor.tflite')
```

## 注意事项

- 模型文件缺失时，应用会自动降级使用规则引擎
- 规则引擎基于光谱特征峰匹配进行农药检测
- 建议模型文件大小控制在10MB以内
