#!/usr/bin/env python3
"""
训练入口脚本

用法:
    python scripts/train.py --config configs/default_config.yaml
    python scripts/train.py --config configs/default_config.yaml --smoke-test
"""

import argparse
import os
import sys

# 将项目根目录加入Python路径
_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from training.trainer import main_train


def parse_args():
    parser = argparse.ArgumentParser(description="光谱农药残留检测 - 多任务模型训练")
    parser.add_argument(
        "--config",
        type=str,
        default=os.path.join(_project_root, "configs", "default_config.yaml"),
        help="YAML配置文件路径",
    )
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="冒烟测试模式(少量数据, 少量epoch)",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main_train(config_path=args.config, smoke_test=args.smoke_test)
