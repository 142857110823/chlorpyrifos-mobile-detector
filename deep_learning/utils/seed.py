"""
全局随机种子固定模块

功能：固定Python/NumPy/PyTorch CPU/GPU全链路随机种子，
关闭cudnn自适应优化，保证卷积计算确定性，实现实验100%可复现。
"""

import os
import random

import numpy as np
import torch


def set_global_seed(seed: int = 42) -> torch.Generator:
    """
    固定全链路随机种子，保证实验可复现。

    Args:
        seed: 随机种子值，默认42

    Returns:
        torch.Generator: 用于DataLoader worker_init_fn的生成器
    """
    # Python内置随机数
    random.seed(seed)
    os.environ['PYTHONHASHSEED'] = str(seed)

    # NumPy随机数
    np.random.seed(seed)

    # PyTorch CPU随机数
    torch.manual_seed(seed)

    # PyTorch GPU随机数(所有GPU)
    if torch.cuda.is_available():
        torch.cuda.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)

    # 关闭cudnn自适应优化，保证卷积计算确定性
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

    # 创建DataLoader专用生成器
    generator = torch.Generator()
    generator.manual_seed(seed)

    return generator


def worker_init_fn(worker_id: int):
    """
    DataLoader多进程worker的种子初始化函数。
    保证每个worker使用不同但确定的随机种子。

    Args:
        worker_id: worker编号
    """
    worker_seed = torch.initial_seed() % 2**32
    np.random.seed(worker_seed)
    random.seed(worker_seed)
