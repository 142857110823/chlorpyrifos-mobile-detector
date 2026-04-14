"""
设备自适应配置模块

功能：自动识别并选择CPU/GPU运行设备，提供设备信息输出。
"""

import torch


def get_device(device_config: str = "auto") -> torch.device:
    """
    自动检测并返回最优计算设备。

    Args:
        device_config: 设备配置，支持"auto"/"cpu"/"cuda"/"cuda:0"等

    Returns:
        torch.device: 选定的计算设备
    """
    if device_config == "auto":
        if torch.cuda.is_available():
            device = torch.device("cuda")
            gpu_name = torch.cuda.get_device_name(0)
            gpu_mem = torch.cuda.get_device_properties(0).total_mem / (1024 ** 3)
            print(f"[Device] 使用GPU: {gpu_name} ({gpu_mem:.1f} GB)")
        else:
            device = torch.device("cpu")
            print("[Device] CUDA不可用，使用CPU")
    else:
        device = torch.device(device_config)
        if device.type == "cuda" and not torch.cuda.is_available():
            print("[Device] 警告: 请求CUDA但不可用，回退到CPU")
            device = torch.device("cpu")
        elif device.type == "cuda":
            gpu_name = torch.cuda.get_device_name(device.index or 0)
            print(f"[Device] 使用GPU: {gpu_name}")
        else:
            print(f"[Device] 使用: {device}")

    return device


def get_device_info() -> dict:
    """
    获取当前设备详细信息。

    Returns:
        dict: 包含设备类型、GPU信息等的字典
    """
    info = {
        "cuda_available": torch.cuda.is_available(),
        "device_count": torch.cuda.device_count() if torch.cuda.is_available() else 0,
        "pytorch_version": torch.__version__,
    }

    if torch.cuda.is_available():
        info["gpu_name"] = torch.cuda.get_device_name(0)
        props = torch.cuda.get_device_properties(0)
        info["gpu_memory_gb"] = round(props.total_mem / (1024 ** 3), 2)
        info["cuda_version"] = torch.version.cuda

    return info
