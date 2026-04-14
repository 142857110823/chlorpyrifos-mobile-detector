#!/usr/bin/env python3
"""
ONNX模型导出入口脚本

用法:
    python scripts/export_onnx.py --config configs/default_config.yaml --checkpoint checkpoints/best_model.pt
"""

import argparse
import os
import sys

_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

import torch

from deployment.onnx_export import export_to_onnx, measure_onnx_inference_latency
from models.multitask_model import MultiTaskSpectralModel
from models.lightweight_model import LightweightSpectralModel
from utils.config import load_config
from utils.seed import set_global_seed


def parse_args():
    parser = argparse.ArgumentParser(description="光谱农药残留检测 - ONNX模型导出")
    parser.add_argument("--config", type=str,
                        default=os.path.join(_project_root, "configs", "default_config.yaml"))
    parser.add_argument("--checkpoint", type=str,
                        default=os.path.join(_project_root, "checkpoints", "best_model.pt"))
    parser.add_argument("--output", type=str,
                        default=os.path.join(_project_root, "outputs", "spectral_model.onnx"))
    parser.add_argument("--measure-latency", action="store_true", help="测量推理延迟")
    return parser.parse_args()


def main():
    args = parse_args()
    config = load_config(args.config)
    set_global_seed(config.seed)

    # 构建并加载模型
    model_type = getattr(config.model, 'type', 'standard')
    if model_type == "lightweight":
        model = LightweightSpectralModel(
            num_wavelengths=config.data.num_wavelengths,
            num_classes=config.model.classification_head.num_classes,
        )
    else:
        model = MultiTaskSpectralModel.from_config(config)

    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    print(f"[Export] 加载模型: {args.checkpoint}")

    # 参数量
    param_count = model.get_param_count()
    print(f"[Export] 模型参数量: {param_count['total']:,}")

    # 导出ONNX
    deploy_cfg = getattr(config, 'deployment', None)
    onnx_cfg = getattr(deploy_cfg, 'onnx', None) if deploy_cfg else None

    onnx_path = export_to_onnx(
        model=model,
        output_path=args.output,
        num_wavelengths=config.data.num_wavelengths,
        opset_version=getattr(onnx_cfg, 'opset_version', 13) if onnx_cfg else 13,
        input_name=getattr(onnx_cfg, 'input_name', 'spectral_input') if onnx_cfg else 'spectral_input',
        output_names=getattr(onnx_cfg, 'output_names', None) if onnx_cfg else None,
        verify=True,
    )

    # 测量推理延迟
    if args.measure_latency:
        print("\n[Latency] 测量推理延迟...")
        measure_onnx_inference_latency(
            onnx_path=onnx_path,
            num_wavelengths=config.data.num_wavelengths,
        )

    print(f"\n[Done] ONNX模型已导出: {onnx_path}")


if __name__ == "__main__":
    main()
