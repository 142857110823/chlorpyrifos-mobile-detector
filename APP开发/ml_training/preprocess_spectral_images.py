import cv2
import numpy as np
import os
import shutil
from sklearn.model_selection import train_test_split
import sys
import traceback
from PIL import Image

# 使用原始字符串格式的路径
SPECTRAL_FOLDER = r"D:\王元元老师大创\光谱文件夹"
# 预处理后的数据保存路径
OUTPUT_FOLDER = os.path.abspath("./dataset")

# 农药标签映射
PESTICIDE_LABELS = {
    "吡虫啉": 0,
    "扑虱灵": 1,
    "种衣剂": 2,
    "苄·二氣": 3
}

def preprocess_spectrum_img(img_path):
    """
    预处理光谱图片
    步骤：读取图片 → 灰度化 → 高斯去噪 → 二值化 → 缩放为224×224
    """
    try:
        # 1. 使用PIL读取图片（支持中文路径）
        pil_img = Image.open(img_path)
        # 转换为RGB模式
        if pil_img.mode != 'RGB':
            pil_img = pil_img.convert('RGB')
        # 转换为OpenCV格式
        img = np.array(pil_img)
        # 转换为BGR格式（OpenCV默认格式）
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        
        # 2. 转为灰度图
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # 3. 高斯去噪
        blur = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # 4. 二值化（区分曲线与背景）
        _, binary = cv2.threshold(blur, 127, 255, cv2.THRESH_BINARY_INV)
        
        # 5. 缩放为224×224（模型输入标准尺寸）
        resized = cv2.resize(binary, (224, 224))
        
        return resized
    except Exception as e:
        raise ValueError(f"无法读取图片: {img_path}, 错误: {str(e)}")

def augment_image(img):
    """
    数据增强
    生成多个增强版本的图片
    """
    augmented_images = []
    
    # 原始图片
    augmented_images.append(img)
    
    # 旋转
    for angle in [-10, 10]:
        M = cv2.getRotationMatrix2D((112, 112), angle, 1.0)
        rotated = cv2.warpAffine(img, M, (224, 224), borderValue=255)
        augmented_images.append(rotated)
    
    # 亮度调整
    for brightness in [0.8, 1.2]:
        brightened = np.clip(img * brightness, 0, 255).astype(np.uint8)
        augmented_images.append(brightened)
    
    # 添加噪声
    noise = np.random.normal(0, 10, img.shape).astype(np.uint8)
    noisy = cv2.add(img, noise)
    augmented_images.append(noisy)
    
    return augmented_images

def main():
    """
    主函数：处理光谱图片并组织数据集
    """
    # 创建输出目录结构
    for split in ["train", "val", "test"]:
        split_path = os.path.join(OUTPUT_FOLDER, split)
        os.makedirs(split_path, exist_ok=True)
        for pesticide in PESTICIDE_LABELS.keys():
            class_path = os.path.join(split_path, pesticide)
            os.makedirs(class_path, exist_ok=True)
    
    # 处理每张光谱图片
    all_images = []
    all_labels = []
    
    for filename in os.listdir(SPECTRAL_FOLDER):
        if filename.endswith(".jpg"):
            img_path = os.path.join(SPECTRAL_FOLDER, filename)
            
            # 提取农药名称
            for pesticide in PESTICIDE_LABELS.keys():
                if pesticide in filename:
                    label = pesticide
                    break
            else:
                print(f"无法识别农药名称: {filename}")
                continue
            
            try:
                # 预处理图片
                processed_img = preprocess_spectrum_img(img_path)
                
                # 数据增强
                augmented_images = augment_image(processed_img)
                
                for i, aug_img in enumerate(augmented_images):
                    img_name = f"{os.path.splitext(filename)[0]}_aug{i}.jpg"
                    all_images.append((aug_img, label, img_name))
                    all_labels.append(label)
                
                print(f"处理完成: {filename}")
            except Exception as e:
                print(f"处理失败 {filename}: {e}")
    
    # 划分数据集（跳过分层采样，因为每个类只有1个原始样本）
    train_images, test_images = train_test_split(
        all_images, test_size=0.2, random_state=42
    )
    
    val_images, test_images = train_test_split(
        test_images, test_size=0.5, random_state=42
    )
    
    # 保存图片到对应目录
    splits = [
        (train_images, "train"),
        (val_images, "val"),
        (test_images, "test")
    ]
    
    for images, split in splits:
        for img, label, img_name in images:
            save_path = os.path.join(OUTPUT_FOLDER, split, label, img_name)
            # 确保目录存在
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            try:
                # 使用PIL保存图片（支持中文路径）
                pil_img = Image.fromarray(img)
                pil_img.save(save_path)
                print(f"保存成功: {save_path}")
            except Exception as e:
                print(f"保存失败: {save_path}, 错误: {str(e)}")
    
    print(f"\n数据集处理完成！")
    print(f"训练集: {len(train_images)} 张图片")
    print(f"验证集: {len(val_images)} 张图片")
    print(f"测试集: {len(test_images)} 张图片")
    print(f"总图片数: {len(all_images)} 张图片")

if __name__ == "__main__":
    main()