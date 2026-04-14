#!/usr/bin/env python3
"""
毒死蜱识别模型训练脚本
使用MobileNetV2训练二分类模型
转换为INT8量化的TFLite格式
"""

import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model
import os

# 1. 数据集路径
BASE_DIR = "dataset"
TRAIN_DIR = os.path.join(BASE_DIR, "train")
VAL_DIR = os.path.join(BASE_DIR, "val")
TEST_DIR = os.path.join(BASE_DIR, "test")

# 2. 数据增强
datagen = ImageDataGenerator(
    rescale=1./255,
    rotation_range=10,
    width_shift_range=0.1,
    height_shift_range=0.1,
    brightness_range=[0.8, 1.2]
)

train_generator = datagen.flow_from_directory(
    TRAIN_DIR,
    target_size=(224, 224),
    batch_size=32,
    class_mode="binary"  # 二分类
)

val_generator = datagen.flow_from_directory(
    VAL_DIR,
    target_size=(224, 224),
    batch_size=32,
    class_mode="binary"
)

# 3. 构建轻量化模型
base_model = MobileNetV2(
    input_shape=(224, 224, 3),
    include_top=False,
    weights="imagenet"
)
base_model.trainable = False  # 冻结预训练权重

# 添加分类头
x = base_model.output
x = GlobalAveragePooling2D()(x)
output = Dense(1, activation="sigmoid")(x)  # 二分类输出
model = Model(inputs=base_model.input, outputs=output)

# 4. 编译模型
model.compile(
    optimizer="adam",
    loss="binary_crossentropy",
    metrics=["accuracy"]
)

# 5. 训练
history = model.fit(
    train_generator,
    validation_data=val_generator,
    epochs=10,  # 轻量化模型，10轮足够
    batch_size=32
)

# 6. 评估测试集
test_generator = datagen.flow_from_directory(
    TEST_DIR,
    target_size=(224, 224),
    batch_size=32,
    class_mode="binary",
    shuffle=False
)

test_loss, test_acc = model.evaluate(test_generator)
print(f"测试准确率: {test_acc:.4f}")

# 7. 转换为INT8量化TFLite（移动端必备）
print("转换为TFLite格式...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# 使用代表性数据集进行量化
def representative_data_gen():
    for _ in range(100):
        # 从训练生成器获取一批数据
        batch = next(train_generator)
        yield [batch[0]]

converter.representative_dataset = representative_data_gen
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
converter.inference_input_type = tf.int8
converter.inference_output_type = tf.int8

tflite_model = converter.convert()

# 8. 保存模型
output_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "models")
os.makedirs(output_dir, exist_ok=True)

model_path = os.path.join(output_dir, "chlorpyrifos_detector.tflite")
with open(model_path, "wb") as f:
    f.write(tflite_model)

print(f"模型已保存: {model_path}")
print(f"模型大小: {len(tflite_model)/1024/1024:.2f} MB")

# 9. 保存标签映射
labels = {
    0: "不存在毒死蜱残留",
    1: "存在毒死蜱残留"
}

import json
label_path = os.path.join(output_dir, "chlorpyrifos_labels.json")
with open(label_path, "w", encoding="utf-8") as f:
    json.dump(labels, f, ensure_ascii=False, indent=2)

print(f"标签映射已保存: {label_path}")
