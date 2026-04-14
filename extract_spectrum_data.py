import cv2
import numpy as np
import matplotlib.pyplot as plt
import os
import json
import sys
from PIL import Image

# 光谱文件夹路径
base_dir = r'd:\王元元老师大创'
spectrum_folder = os.path.join(base_dir, '光谱文件夹')
output_folder = os.path.join(base_dir, 'extracted_spectrum_data')

# 确保输出文件夹存在
os.makedirs(output_folder, exist_ok=True)

def extract_spectrum_data(image_path):
    """
    从光谱图中提取波长和吸光度数据
    """
    # 读取图像
    # 使用绝对路径
    abs_path = os.path.abspath(image_path)
    print(f"尝试读取图像: {abs_path}")
    
    try:
        # 使用PIL读取图像
        pil_img = Image.open(abs_path)
        # 转换为OpenCV格式
        img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    except Exception as e:
        print(f"读取图像失败: {e}")
        return None
    
    if img is None:
        print(f"无法读取图像: {abs_path}")
        return None
    
    # 转换为灰度图
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 二值化
    _, binary = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)
    
    # 查找轮廓
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # 找到最大的轮廓（光谱曲线）
    if not contours:
        print(f"未找到光谱曲线: {image_path}")
        return None
    
    largest_contour = max(contours, key=cv2.contourArea)
    
    # 提取轮廓点
    points = largest_contour.reshape(-1, 2)
    
    # 按x坐标排序
    points = sorted(points, key=lambda x: x[0])
    
    # 图像尺寸
    height, width = img.shape[:2]
    
    # 波长范围（200-700nm）
    wavelength_min = 200
    wavelength_max = 700
    
    # 吸光度范围（0-4.5）
    absorbance_min = 0
    absorbance_max = 4.5
    
    # 转换像素坐标到波长和吸光度
    spectrum_data = []
    for x, y in points:
        # 波长：x从0到width对应200到700nm
        wavelength = wavelength_min + (x / width) * (wavelength_max - wavelength_min)
        
        # 吸光度：y从0到height对应4.5到0
        absorbance = absorbance_max - (y / height) * (absorbance_max - absorbance_min)
        
        # 确保值在合理范围内
        wavelength = max(wavelength_min, min(wavelength_max, wavelength))
        absorbance = max(absorbance_min, min(absorbance_max, absorbance))
        
        spectrum_data.append({
            'wavelength': round(wavelength, 1),
            'absorbance': round(absorbance, 3)
        })
    
    return spectrum_data

def main():
    # 处理光谱文件夹中的所有图像
    for filename in os.listdir(spectrum_folder):
        if filename.endswith('.jpg'):
            image_path = os.path.join(spectrum_folder, filename)
            pesticide_name = filename.split('吸收光谱')[0]
            
            print(f"提取 {pesticide_name} 的光谱数据...")
            
            # 提取光谱数据
            spectrum_data = extract_spectrum_data(image_path)
            if spectrum_data:
                # 保存提取的数据
                output_file = os.path.join(output_folder, f'{pesticide_name}_spectrum_data.json')
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump({
                        'pesticide': pesticide_name,
                        'spectrum_data': spectrum_data
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"已保存 {pesticide_name} 的光谱数据: {output_file}")
                
                # 绘制提取的光谱曲线
                wavelengths = [item['wavelength'] for item in spectrum_data]
                absorbances = [item['absorbance'] for item in spectrum_data]
                
                plt.figure(figsize=(10, 6))
                plt.plot(wavelengths, absorbances, 'b-')
                plt.title(f'{pesticide_name} 提取的吸收光谱')
                plt.xlabel('波长 (nm)')
                plt.ylabel('吸光度')
                plt.grid(True)
                
                plot_file = os.path.join(output_folder, f'{pesticide_name}_extracted_spectrum.png')
                plt.savefig(plot_file)
                plt.close()
                
                print(f"已保存 {pesticide_name} 的提取光谱图: {plot_file}")

if __name__ == "__main__":
    main()