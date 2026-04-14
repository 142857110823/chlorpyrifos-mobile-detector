import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model
from tensorflow.keras.optimizers import Adam
import os
import json

# 数据集路径
BASE_DIR = os.path.abspath("./dataset")
TRAIN_DIR = os.path.join(BASE_DIR, "train")
VAL_DIR = os.path.join(BASE_DIR, "val")
TEST_DIR = os.path.join(BASE_DIR, "test")

# 模型保存路径
MODEL_SAVE_PATH = os.path.abspath("../assets/models/pesticide_classifier.tflite")
LABEL_MAP_PATH = os.path.abspath("../assets/models/pesticide_labels.json")

# 超参数
IMG_SIZE = (224, 224)
BATCH_SIZE = 8
EPOCHS = 50
LEARNING_RATE = 0.0001

# 农药标签映射
PESTICIDE_LABELS = {
    "吡虫啉": 0,
    "扑虱灵": 1,
    "种衣剂": 2,
    "苄·二氣": 3
}

# 反转标签映射（用于预测时使用）
REVERSE_LABEL_MAP = {v: k for k, v in PESTICIDE_LABELS.items()}

def create_model(num_classes):
    """
    创建多分类模型
    使用MobileNetV2作为基础模型
    基于MobileNetV2核心原理：深度可分离卷积、倒置残差块、线性瓶颈
    """
    # 加载预训练的MobileNetV2模型
    # 使用标准1.0×宽度乘数，保持轻量性和速度
    base_model = MobileNetV2(
        input_shape=(*IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
        alpha=1.0  # 宽度乘数，控制通道数
    )
    
    # 冻结预训练权重
    base_model.trainable = False
    
    # 添加分类头
    x = base_model.output
    x = GlobalAveragePooling2D()(x)
    # 保持线性瓶颈设计理念，避免在低维空间使用ReLU
    x = Dense(128)(x)  # 线性激活，无ReLU
    output = Dense(num_classes, activation="softmax")(x)
    
    model = Model(inputs=base_model.input, outputs=output)
    
    # 编译模型
    model.compile(
        optimizer=Adam(learning_rate=LEARNING_RATE),
        loss="categorical_crossentropy",
        metrics=["accuracy"]
    )
    
    return model

def train_model():
    """
    训练多分类模型
    """
    # 数据增强
    datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=10,
        width_shift_range=0.1,
        height_shift_range=0.1,
        brightness_range=[0.8, 1.2],
        zoom_range=0.1,
        horizontal_flip=False,
        vertical_flip=False
    )
    
    # 生成训练数据
    train_generator = datagen.flow_from_directory(
        TRAIN_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        shuffle=True
    )
    
    # 生成验证数据
    val_generator = datagen.flow_from_directory(
        VAL_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        shuffle=False
    )
    
    # 生成测试数据
    test_generator = datagen.flow_from_directory(
        TEST_DIR,
        target_size=IMG_SIZE,
        batch_size=BATCH_SIZE,
        class_mode="categorical",
        shuffle=False
    )
    
    # 获取类别数量
    num_classes = len(train_generator.class_indices)
    print(f"类别数量: {num_classes}")
    print(f"类别映射: {train_generator.class_indices}")
    
    # 创建模型
    model = create_model(num_classes)
    
    # 训练模型
    history = model.fit(
        train_generator,
        validation_data=val_generator,
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        steps_per_epoch=train_generator.samples // BATCH_SIZE,
        validation_steps=val_generator.samples // BATCH_SIZE
    )
    
    # 评估模型
    test_loss, test_accuracy = model.evaluate(test_generator)
    print(f"测试准确率: {test_accuracy:.4f}")
    
    # 保存标签映射
    with open(LABEL_MAP_PATH, "w", encoding="utf-8") as f:
        json.dump(REVERSE_LABEL_MAP, f, ensure_ascii=False, indent=2)
    print(f"标签映射已保存到: {LABEL_MAP_PATH}")
    
    # 转换为TFLite模型
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # 启用INT8量化
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # 生成代表性数据集用于量化
    def representative_data_gen():
        for _ in range(10):
            # 从训练数据中获取一批数据
            batch = next(train_generator)
            yield [batch[0]]
    
    converter.representative_dataset = representative_data_gen
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    
    # 转换模型
    tflite_model = converter.convert()
    
    # 保存TFLite模型
    os.makedirs(os.path.dirname(MODEL_SAVE_PATH), exist_ok=True)
    with open(MODEL_SAVE_PATH, "wb") as f:
        f.write(tflite_model)
    
    print(f"TFLite模型已保存到: {MODEL_SAVE_PATH}")
    print(f"模型大小: {len(tflite_model) / 1024 / 1024:.2f} MB")
    
    return model, history, test_accuracy

def main():
    """
    主函数：训练模型并保存
    """
    print("开始训练多分类农药识别模型...")
    
    try:
        model, history, test_accuracy = train_model()
        
        print("\n模型训练完成！")
        print(f"测试准确率: {test_accuracy:.4f}")
        print(f"TFLite模型大小: {os.path.getsize(MODEL_SAVE_PATH) / 1024 / 1024:.2f} MB")
        
        # 保存训练历史
        history_path = os.path.abspath("./model_history.json")
        with open(history_path, "w") as f:
            json.dump({
                "accuracy": history.history["accuracy"],
                "val_accuracy": history.history["val_accuracy"],
                "loss": history.history["loss"],
                "val_loss": history.history["val_loss"]
            }, f, indent=2)
        print(f"训练历史已保存到: {history_path}")
        
    except Exception as e:
        print(f"训练失败: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()