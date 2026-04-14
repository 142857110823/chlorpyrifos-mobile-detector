import cv2
import numpy as np
import json
import os

# 光谱图片路径
spectral_folder = r'd:\王元元老师大创\光谱文件夹'
output_file = r'd:\王元元老师大创\APP开发\assets\standard_spectra.json'

# 农药信息映射
pesticide_info = {
    '苄·二氣吸收光谱.jpg': {
        'id': 10,
        'key': 'benzyl_dichloride',
        'name': '苄·二氯',
        'cas': '无',
        'type': '除草剂',
        'wavelengthRange': [200, 700]
    },
    '扑虱灵吸收光谱.jpg': {
        'id': 11,
        'key': 'buprofezin',
        'name': '扑虱灵',
        'cas': '69327-76-0',
        'type': '杀虫剂',
        'wavelengthRange': [200, 700]
    },
    '种衣剂吸收光谱.jpg': {
        'id': 12,
        'key': 'seed_coating',
        'name': '种衣剂',
        'cas': '无',
        'type': '种子处理剂',
        'wavelengthRange': [200, 700]
    }
}

def extract_spectral_data(image_path):
    """
    从光谱图片中提取吸光度数据
    """
    try:
        # 读取图片
        img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
        if img is None:
            print(f"无法读取图片: {image_path}")
            return [], []
        
        # 二值化处理
        _, binary = cv2.threshold(img, 128, 255, cv2.THRESH_BINARY_INV)
        
        # 提取光谱曲线
        height, width = binary.shape
        absorbances = []
        
        # 从左到右扫描
        for x in range(width):
            # 找到该列的第一个非零像素
            for y in range(height):
                if binary[y, x] > 0:
                    # 计算吸光度（归一化到0-2范围）
                    absorbance = 2.0 * (1 - y / height)
                    absorbances.append(absorbance)
                    break
            else:
                # 如果没有找到，添加默认值
                absorbances.append(0.02)
        
        # 确保数据长度为501个点（200-700nm，每1nm一个点）
        if len(absorbances) != 501:
            # 插值到501个点
            absorbances = np.interp(
                np.linspace(0, len(absorbances)-1, 501),
                np.arange(len(absorbances)),
                absorbances
            ).tolist()
        
        # 找到峰值波长
        peaks = []
        for i in range(1, len(absorbances)-1):
            if absorbances[i] > absorbances[i-1] and absorbances[i] > absorbances[i+1]:
                # 转换为波长（200-700nm）
                wavelength = 200 + i
                peaks.append(wavelength)
        
        # 只保留前3个最大的峰值
        peaks_with_values = [(peak, absorbances[peak-200]) for peak in peaks]
        peaks_with_values.sort(key=lambda x: x[1], reverse=True)
        top_peaks = [peak for peak, _ in peaks_with_values[:3]]
        top_peaks.sort()
        
        return absorbances, top_peaks
        
    except Exception as e:
        print(f"处理图片时出错: {e}")
        return [], []

def main():
    # 读取现有的标准光谱库
    try:
        with open(output_file, 'r', encoding='utf-8') as f:
            spectra = json.load(f)
    except Exception as e:
        print(f"读取现有光谱库失败: {e}")
        spectra = []
    
    # 处理每个光谱图片
    for filename, info in pesticide_info.items():
        image_path = os.path.join(spectral_folder, filename)
        if os.path.exists(image_path):
            print(f"处理: {filename}")
            absorbances, peaks = extract_spectral_data(image_path)
            
            if absorbances:
                # 创建新的光谱数据
                new_spectrum = {
                    'id': info['id'],
                    'key': info['key'],
                    'name': info['name'],
                    'cas': info['cas'],
                    'type': info['type'],
                    'wavelengthRange': info['wavelengthRange'],
                    'peaks': peaks,
                    'absorbances': absorbances
                }
                
                # 检查是否已存在
                existing_index = None
                for i, spectrum in enumerate(spectra):
                    if spectrum['key'] == info['key']:
                        existing_index = i
                        break
                
                if existing_index is not None:
                    # 更新现有数据
                    spectra[existing_index] = new_spectrum
                    print(f"更新了 {info['name']} 的光谱数据")
                else:
                    # 添加新数据
                    spectra.append(new_spectrum)
                    print(f"添加了 {info['name']} 的光谱数据")
            else:
                print(f"无法提取 {info['name']} 的光谱数据")
        else:
            print(f"文件不存在: {image_path}")
    
    # 保存更新后的标准光谱库
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(spectra, f, ensure_ascii=False, indent=2)
        print(f"标准光谱库已更新: {output_file}")
    except Exception as e:
        print(f"保存光谱库失败: {e}")

if __name__ == "__main__":
    main()
