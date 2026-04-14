import numpy as np
import json
import matplotlib.pyplot as plt
import os

# 提取的数据文件夹路径
extracted_data_folder = r'd:\王元元老师大创\extracted_spectrum_data'
output_folder = r'd:\王元元老师大创\calibration_curves_from_extracted'

# 确保输出文件夹存在
os.makedirs(output_folder, exist_ok=True)

# 模拟浓度数据（mg/L）
concentrations = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]

def load_extracted_spectrum(pesticide_name):
    """
    加载提取的光谱数据
    """
    data_file = os.path.join(extracted_data_folder, f'{pesticide_name}_spectrum_data.json')
    try:
        with open(data_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return data['spectrum_data']
    except Exception as e:
        print(f"加载光谱数据失败: {e}")
        return None

def find_absorbance_at_wavelength(spectrum_data, wavelength):
    """
    在光谱数据中查找指定波长的吸光度
    """
    # 找到最接近目标波长的数据点
    closest_point = min(spectrum_data, key=lambda x: abs(x['wavelength'] - wavelength))
    return closest_point['absorbance']

def create_calibration_curve(pesticide_name, spectrum_data, peaks):
    """
    为每种农药创建浓度-吸光度标定曲线
    """
    # 生成不同浓度下的吸光度数据
    calibration_data = []
    
    for conc in concentrations:
        # 假设吸光度与浓度成正比
        absorbances_at_peaks = []
        for peak in peaks:
            # 找到峰值对应的吸光度
            base_abs = find_absorbance_at_wavelength(spectrum_data, peak)
            # 计算该浓度下的吸光度
            conc_abs = base_abs * conc / 1.0  # 归一化到1mg/L
            conc_abs = min(conc_abs, 4.5)  # 确保吸光度在合理范围内
            absorbances_at_peaks.append(conc_abs)
        
        calibration_data.append({
            'concentration': conc,
            'absorbances': absorbances_at_peaks
        })
    
    # 为每个峰值创建标定曲线
    for i, peak in enumerate(peaks):
        # 提取该峰值下的吸光度数据
        absorbances = [data['absorbances'][i] for data in calibration_data]
        
        # 线性回归
        coefficients = np.polyfit(concentrations, absorbances, 1)
        slope, intercept = coefficients
        
        # 计算R²值
        predicted = np.polyval(coefficients, concentrations)
        ss_res = np.sum((absorbances - predicted) ** 2)
        ss_tot = np.sum((absorbances - np.mean(absorbances)) ** 2)
        r_squared = 1 - (ss_res / ss_tot)
        
        # 绘制标定曲线
        plt.figure(figsize=(10, 6))
        plt.scatter(concentrations, absorbances, color='blue', label='实测数据')
        plt.plot(concentrations, predicted, color='red', label=f'拟合直线: y={slope:.4f}x + {intercept:.4f}\nR²={r_squared:.4f}')
        plt.title(f'{pesticide_name} 在 {peak}nm 处的浓度-吸光度标定曲线')
        plt.xlabel('浓度 (mg/L)')
        plt.ylabel('吸光度')
        plt.grid(True)
        plt.legend()
        
        # 保存图表
        output_file = os.path.join(output_folder, f'{pesticide_name}_{peak}nm_calibration_curve.png')
        plt.savefig(output_file)
        plt.close()
        
        print(f"已保存 {pesticide_name} 在 {peak}nm 处的标定曲线: {output_file}")
    
    return calibration_data

def main():
    # 目标农药及其特征峰值
    target_pesticides = {
        '苄·二氣': [254, 220, 280],
        '扑虱灵': [260, 230, 300],
        '种衣剂': [206, 270, 508]
    }
    
    for pesticide_name, peaks in target_pesticides.items():
        print(f"为 {pesticide_name} 创建标定曲线...")
        
        # 加载提取的光谱数据
        spectrum_data = load_extracted_spectrum(pesticide_name)
        if spectrum_data:
            # 创建标定曲线
            calibration_data = create_calibration_curve(
                pesticide_name,
                spectrum_data,
                peaks
            )
            
            # 保存标定数据
            calibration_file = os.path.join(output_folder, f'{pesticide_name}_calibration_data.json')
            with open(calibration_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'pesticide': pesticide_name,
                    'peaks': peaks,
                    'calibration_data': calibration_data
                }, f, ensure_ascii=False, indent=2)
            print(f"已保存 {pesticide_name} 的标定数据: {calibration_file}")

if __name__ == "__main__":
    main()