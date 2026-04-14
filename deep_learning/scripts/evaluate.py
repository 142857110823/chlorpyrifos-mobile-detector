#!/usr/bin/env python3
"""
评估入口脚本

用法:
    python scripts/evaluate.py --config configs/default_config.yaml --checkpoint checkpoints/best_model.pt
"""

import argparse
import os
import sys

_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

import torch

from data.data_generator import MRL_LIMITS, PESTICIDE_CLASSES
from data.data_utils import create_dataloaders
from evaluation.evaluator import evaluate_model, print_evaluation_report, save_evaluation_report
from models.multitask_model import MultiTaskSpectralModel
from models.lightweight_model import LightweightSpectralModel
from utils.config import load_config
from utils.device import get_device
from utils.seed import set_global_seed


def parse_args():
    parser = argparse.ArgumentParser(description="光谱农药残留检测 - 模型评估")
    parser.add_argument("--config", type=str,
                        default=os.path.join(_project_root, "configs", "default_config.yaml"))
    parser.add_argument("--checkpoint", type=str,
                        default=os.path.join(_project_root, "checkpoints", "best_model.pt"))
    parser.add_argument("--output", type=str,
                        default=os.path.join(_project_root, "outputs", "evaluation_report.json"))
    return parser.parse_args()


def main():
    args = parse_args()
    config = load_config(args.config)
    set_global_seed(config.seed)
    device = get_device(config.device)

    # 加载数据
    _, _, test_loader, _ = create_dataloaders(config)

    # 构建并加载模型
    model_type = getattr(config.model, 'type', 'standard')
    if model_type == "lightweight":
        model = LightweightSpectralModel(
            num_wavelengths=config.data.num_wavelengths,
            num_classes=config.model.classification_head.num_classes,
        )
    else:
        model = MultiTaskSpectralModel.from_config(config)

    checkpoint = torch.load(args.checkpoint, map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model = model.to(device)
    print(f"[Evaluate] 加载模型: {args.checkpoint} (epoch {checkpoint.get('epoch', '?')})")

    # MRL限量映射(class_idx -> mrl)
    mrl_by_idx = {i: MRL_LIMITS.get(name, 0.0) for i, name in enumerate(PESTICIDE_CLASSES)}

    # 评估
    report = evaluate_model(
        model=model,
        dataloader=test_loader,
        device=device,
        class_names=PESTICIDE_CLASSES,
        mrl_limits=mrl_by_idx,
    )

    print_evaluation_report(report, PESTICIDE_CLASSES)
    save_evaluation_report(report, args.output)


if __name__ == "__main__":
    main()
