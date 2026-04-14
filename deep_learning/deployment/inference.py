"""
端侧推理接口模块

功能：封装预处理、模型加载、推理、结果解析全流程，
保证与训练端结果100%对齐，实现端到端推理。
"""

import json
import os
import sys
import time
from typing import Dict, List, Optional

import numpy as np

_project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)

from data.data_generator import PESTICIDE_CLASSES, PESTICIDE_NAMES_ZH, MRL_LIMITS
from data.preprocessing import SpectralPreprocessingPipeline


class SpectralInference:
    """
    端侧推理接口类。

    封装预处理 → ONNX Runtime推理 → 后处理全流程，
    保证与训练端结果100%对齐。

    Args:
        onnx_path: ONNX模型文件路径
        preprocessing_path: 预处理参数JSON文件路径
        input_name: ONNX模型输入名称
    """

    def __init__(
        self,
        onnx_path: str,
        preprocessing_path: str,
        input_name: str = "spectral_input",
    ):
        try:
            import onnxruntime as ort
        except ImportError:
            raise ImportError("请安装onnxruntime: pip install onnxruntime")

        # 加载ONNX模型
        self.session = ort.InferenceSession(onnx_path)
        self.input_name = input_name

        # 加载预处理管线
        self.pipeline = SpectralPreprocessingPipeline.load(preprocessing_path)

        # 类别信息
        self.class_names = PESTICIDE_CLASSES
        self.class_names_zh = PESTICIDE_NAMES_ZH
        self.mrl_limits = MRL_LIMITS

        print(f"[Inference] 模型已加载: {onnx_path}")

    def predict(self, raw_spectrum: np.ndarray) -> Dict[str, object]:
        """
        对单条原始光谱进行端到端推理。

        Args:
            raw_spectrum: 原始光谱数据, shape (num_wavelengths,)

        Returns:
            dict: {
                "predicted_class": str,  # 预测农药类别(英文)
                "predicted_class_zh": str,  # 预测农药类别(中文)
                "class_index": int,  # 类别索引
                "confidence": float,  # 预测置信度
                "class_probabilities": dict,  # 各类别概率
                "concentration": float,  # 预测浓度(mg/kg)
                "mrl_limit": float,  # 该农药MRL限量
                "exceeds_mrl": bool,  # 是否超标
                "risk_level": str,  # 风险等级
                "inference_time_ms": float,  # 推理耗时(ms)
            }
        """
        start_time = time.perf_counter()

        # 1. 预处理(使用训练端相同的参数)
        processed = self.pipeline.transform(raw_spectrum)
        input_data = processed.reshape(1, -1).astype(np.float32)

        # 2. ONNX Runtime推理
        outputs = self.session.run(None, {self.input_name: input_data})
        class_logits = outputs[0][0]  # (num_classes,)
        concentration = float(outputs[1][0][0]) if outputs[1].ndim > 1 else float(outputs[1][0])

        # 3. 后处理
        # Softmax概率
        exp_logits = np.exp(class_logits - np.max(class_logits))
        probs = exp_logits / np.sum(exp_logits)

        class_index = int(np.argmax(probs))
        predicted_class = self.class_names[class_index]
        confidence = float(probs[class_index])

        # 浓度非负约束
        concentration = max(0.0, concentration)

        # none类浓度强制为0
        if class_index == 0:
            concentration = 0.0

        # MRL判定
        mrl = self.mrl_limits.get(predicted_class, 0.0)
        exceeds_mrl = concentration > mrl if class_index != 0 else False

        # 风险等级
        if class_index == 0:
            risk_level = "安全"
        elif exceeds_mrl:
            risk_level = "超标"
        elif concentration > mrl * 0.5:
            risk_level = "警告"
        else:
            risk_level = "合格"

        inference_time = (time.perf_counter() - start_time) * 1000

        # 各类别概率
        class_probs = {}
        for i, name in enumerate(self.class_names):
            class_probs[name] = float(probs[i])

        return {
            "predicted_class": predicted_class,
            "predicted_class_zh": self.class_names_zh.get(predicted_class, predicted_class),
            "class_index": class_index,
            "confidence": confidence,
            "class_probabilities": class_probs,
            "concentration": concentration,
            "mrl_limit": mrl,
            "exceeds_mrl": exceeds_mrl,
            "risk_level": risk_level,
            "inference_time_ms": inference_time,
        }

    def predict_batch(self, raw_spectra: np.ndarray) -> List[Dict[str, object]]:
        """
        批量推理。

        Args:
            raw_spectra: 多条原始光谱, shape (N, num_wavelengths)

        Returns:
            list: 每条光谱的推理结果列表
        """
        results = []
        for spectrum in raw_spectra:
            results.append(self.predict(spectrum))
        return results
