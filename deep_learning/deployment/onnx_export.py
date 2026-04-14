"""
ONNX模型导出与验证模块

功能：实现PyTorch模型到ONNX格式的导出、数值一致性验证、
模型大小检查，同时导出预处理参数供移动端使用。
"""

import os
import sys
import time
from typing import Optional

import numpy as np
import torch
import torch.nn as nn

_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)


def export_to_onnx(
    model: nn.Module,
    output_path: str,
    num_wavelengths: int = 256,
    opset_version: int = 13,
    input_name: str = "spectral_input",
    output_names: list = None,
    verify: bool = True,
) -> str:
    """
    将PyTorch模型导出为ONNX格式。

    Args:
        model: 训练好的PyTorch模型
        output_path: ONNX文件保存路径
        num_wavelengths: 输入波长点数
        opset_version: ONNX opset版本
        input_name: 输入张量名称
        output_names: 输出张量名称列表
        verify: 是否验证导出后的数值一致性

    Returns:
        str: 导出的ONNX文件路径
    """
    if output_names is None:
        output_names = ["class_logits", "concentration"]

    os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else ".", exist_ok=True)

    model.eval()
    model_cpu = model.cpu()

    # 创建dummy输入
    dummy_input = torch.randn(1, num_wavelengths, dtype=torch.float32)

    # 导出ONNX
    print(f"[ONNX] 导出模型到 {output_path}...")
    # PyTorch 2.10+ 默认使用dynamo导出器，其verbose日志含emoji在Windows GBK终端崩溃
    # 使用dynamo=False回退到传统TorchScript导出器，兼容性更好
    export_kwargs = {
        "export_params": True,
        "opset_version": max(opset_version, 14),  # LSTM需要opset>=14
        "do_constant_folding": True,
        "input_names": [input_name],
        "output_names": output_names,
        "dynamic_axes": None,  # 固定batch=1，适合移动端
    }
    try:
        # 优先尝试传统导出器(兼容性好)
        torch.onnx.export(model_cpu, dummy_input, output_path, dynamo=False, **export_kwargs)
    except TypeError:
        # 旧版PyTorch不支持dynamo参数
        torch.onnx.export(model_cpu, dummy_input, output_path, **export_kwargs)

    # 检查文件大小
    file_size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"[ONNX] 模型大小: {file_size_mb:.2f} MB")

    if file_size_mb > 10.0:
        print(f"[ONNX] 警告: 模型大小 {file_size_mb:.2f} MB 超过 10MB 移动端限制!")

    # ONNX模型校验
    try:
        import onnx
        onnx_model = onnx.load(output_path)
        onnx.checker.check_model(onnx_model)
        print("[ONNX] 模型结构校验通过")
    except ImportError:
        print("[ONNX] 跳过onnx库校验(未安装onnx包)")
    except Exception as e:
        print(f"[ONNX] 模型校验失败: {e}")

    # 数值一致性验证
    if verify:
        verify_onnx_output(model_cpu, output_path, dummy_input, input_name, output_names)

    return output_path


def verify_onnx_output(
    pytorch_model: nn.Module,
    onnx_path: str,
    dummy_input: torch.Tensor,
    input_name: str,
    output_names: list,
    atol: float = 1e-5,
):
    """
    验证ONNX模型输出与PyTorch模型的数值一致性。

    Args:
        pytorch_model: PyTorch模型
        onnx_path: ONNX文件路径
        dummy_input: 测试输入
        input_name: 输入名称
        output_names: 输出名称列表
        atol: 允许的最大绝对误差
    """
    try:
        import onnxruntime as ort
    except ImportError:
        print("[ONNX] 跳过数值验证(未安装onnxruntime)")
        return

    # PyTorch推理
    pytorch_model.eval()
    with torch.no_grad():
        pt_outputs = pytorch_model(dummy_input)

    # ONNX Runtime推理
    session = ort.InferenceSession(onnx_path)
    ort_inputs = {input_name: dummy_input.numpy()}
    ort_outputs = session.run(output_names, ort_inputs)

    # 逐输出比较
    all_close = True
    for i, (pt_out, ort_out, name) in enumerate(zip(pt_outputs, ort_outputs, output_names)):
        pt_np = pt_out.numpy()
        max_diff = np.max(np.abs(pt_np - ort_out))
        is_close = max_diff < atol
        status = "通过" if is_close else "失败"
        print(f"[ONNX验证] {name}: max_diff={max_diff:.2e}, {status}")
        if not is_close:
            all_close = False

    if all_close:
        print("[ONNX验证] 全部输出数值一致性验证通过")
    else:
        print(f"[ONNX验证] 警告: 存在超过atol={atol}的数值差异")


def measure_onnx_inference_latency(
    onnx_path: str,
    num_wavelengths: int = 256,
    input_name: str = "spectral_input",
    num_runs: int = 100,
    warmup: int = 10,
) -> dict:
    """
    测量ONNX模型的推理延迟。

    Args:
        onnx_path: ONNX文件路径
        num_wavelengths: 输入维度
        input_name: 输入名称
        num_runs: 测试运行次数
        warmup: 预热次数

    Returns:
        dict: {"mean_ms", "std_ms", "min_ms", "max_ms", "p95_ms"}
    """
    try:
        import onnxruntime as ort
    except ImportError:
        print("[ONNX] 无法测量延迟(未安装onnxruntime)")
        return {}

    session = ort.InferenceSession(onnx_path)
    dummy = np.random.randn(1, num_wavelengths).astype(np.float32)

    # 预热
    for _ in range(warmup):
        session.run(None, {input_name: dummy})

    # 正式测量
    latencies = []
    for _ in range(num_runs):
        start = time.perf_counter()
        session.run(None, {input_name: dummy})
        end = time.perf_counter()
        latencies.append((end - start) * 1000)  # 转为ms

    latencies = np.array(latencies)
    result = {
        "mean_ms": float(np.mean(latencies)),
        "std_ms": float(np.std(latencies)),
        "min_ms": float(np.min(latencies)),
        "max_ms": float(np.max(latencies)),
        "p95_ms": float(np.percentile(latencies, 95)),
    }

    print(f"[ONNX延迟] 平均: {result['mean_ms']:.2f}ms, "
          f"P95: {result['p95_ms']:.2f}ms, "
          f"最大: {result['max_ms']:.2f}ms")

    return result
