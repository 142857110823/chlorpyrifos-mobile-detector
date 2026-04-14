import json
import numpy as np

# 标准库文件路径
output_file = r'd:\王元元老师大创\APP开发\assets\standard_spectra.json'

# 新农药数据
new_pesticides = [
    {
        'id': 10,
        'key': 'benzyl_dichloride',
        'name': '苄·二氯',
        'cas': '无',
        'type': '除草剂',
        'wavelengthRange': [200, 700],
        'peaks': [254, 220, 280],
        'absorbances': []
    },
    {
        'id': 11,
        'key': 'buprofezin',
        'name': '扑虱灵',
        'cas': '69327-76-0',
        'type': '杀虫剂',
        'wavelengthRange': [200, 700],
        'peaks': [260, 230, 300],
        'absorbances': []
    },
    {
        'id': 12,
        'key': 'seed_coating',
        'name': '种衣剂',
        'cas': '无',
        'type': '种子处理剂',
        'wavelengthRange': [200, 700],
        'peaks': [245, 215, 275],
        'absorbances': []
    }
]

def generate_spectral_data(peaks):
    """
    生成模拟的光谱数据
    """
    wavelengths = np.arange(200, 701)
    absorbances = []
    
    for wavelength in wavelengths:
        # 基础吸光度
        base = 0.02
        
        # 为每个峰值添加高斯峰
        for peak in peaks:
            # 高斯峰公式: A = A0 * exp(-(λ-λ0)²/(2σ²))
            sigma = 10  # 峰宽
            amplitude = 1.5  # 峰高
            peak_contribution = amplitude * np.exp(-(wavelength - peak)**2 / (2 * sigma**2))
            base += peak_contribution
        
        # 确保吸光度在合理范围内
        base = min(base, 2.0)
        absorbances.append(base)
    
    return absorbances

def main():
    # 读取现有的标准光谱库
    try:
        with open(output_file, 'r', encoding='utf-8') as f:
            spectra = json.load(f)
    except Exception as e:
        print(f"读取现有光谱库失败: {e}")
        spectra = []
    
    # 为每种新农药生成光谱数据并添加到库中
    for pesticide in new_pesticides:
        # 生成光谱数据
        absorbances = generate_spectral_data(pesticide['peaks'])
        pesticide['absorbances'] = absorbances
        
        # 检查是否已存在
        existing_index = None
        for i, spectrum in enumerate(spectra):
            if spectrum['key'] == pesticide['key']:
                existing_index = i
                break
        
        if existing_index is not None:
            # 更新现有数据
            spectra[existing_index] = pesticide
            print(f"更新了 {pesticide['name']} 的光谱数据")
        else:
            # 添加新数据
            spectra.append(pesticide)
            print(f"添加了 {pesticide['name']} 的光谱数据")
    
    # 保存更新后的标准光谱库
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(spectra, f, ensure_ascii=False, indent=2)
        print(f"标准光谱库已更新: {output_file}")
    except Exception as e:
        print(f"保存光谱库失败: {e}")

if __name__ == "__main__":
    main()
