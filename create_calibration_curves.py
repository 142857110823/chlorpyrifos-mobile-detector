import numpy as np
import json
import matplotlib.pyplot as plt
import os

# 标准库文件路径
standard_spectra_file = r'd:\王元元老师大创\APP开发\assets\standard_spectra.json'
output_folder = r'd:\王元元老师大创\calibration_curves'

# 确保输出文件夹存在
os.makedirs(output_folder, exist_ok=True)

# 模拟浓度数据（mg/L）
concentrations = [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]

def create_calibration_curve(pesticide_name, peaks, base_absorbances):
    """
    为每种农药创建浓度-吸光度标定曲线
    """
    # 处理不同格式的peaks数据
    peak_wavelengths = []
    for peak in peaks:
        if isinstance(peak, dict):
            peak_wavelengths.append(peak['wavelength'])
        else:
            peak_wavelengths.append(peak)
    
    # 生成不同浓度下的吸光度数据
    calibration_data = []
    
    for conc in concentrations:
        # 假设吸光度与浓度成正比
        absorbances_at_peaks = []
        for peak in peak_wavelengths:
            # 找到峰值对应的吸光度
            peak_index = peak - 200  # 200-700nm，索引从0开始
            base_abs = base_absorbances[peak_index]
            # 计算该浓度下的吸光度
            conc_abs = base_abs * conc / 1.0  # 归一化到1mg/L
            conc_abs = min(conc_abs, 2.0)  # 确保吸光度在合理范围内
            absorbances_at_peaks.append(conc_abs)
        
        calibration_data.append({
            'concentration': conc,
            'absorbances': absorbances_at_peaks
        })
    
    # 为每个峰值创建标定曲线
    for i, peak in enumerate(peak_wavelengths):
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
    # 读取标准光谱库
    try:
        with open(standard_spectra_file, 'r', encoding='utf-8') as f:
            spectra = json.load(f)
    except Exception as e:
        print(f"读取标准光谱库失败: {e}")
        return
    
    # 为指定的三种农药创建标定曲线
    target_pesticides = ['苄·二氯', '扑虱灵', '种衣剂']
    
    for spectrum in spectra:
        if spectrum['name'] in target_pesticides:
            print(f"为 {spectrum['name']} 创建标定曲线...")
            calibration_data = create_calibration_curve(
                spectrum['name'],
                spectrum['peaks'],
                spectrum['absorbances']
            )
            
            # 保存标定数据
            calibration_file = os.path.join(output_folder, f'{spectrum["name"]}_calibration_data.json')
            with open(calibration_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'pesticide': spectrum['name'],
                    'peaks': spectrum['peaks'],
                    'calibration_data': calibration_data
                }, f, ensure_ascii=False, indent=2)
            print(f"已保存 {spectrum['name']} 的标定数据: {calibration_file}")

if __name__ == "__main__":
    main()
