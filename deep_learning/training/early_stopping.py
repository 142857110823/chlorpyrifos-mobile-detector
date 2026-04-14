"""
早停策略模块

功能：基于验证集综合性能设置patience阈值，
实现最优模型权重自动保存、触发早停自动终止训练。
"""

from typing import Optional

import numpy as np


class EarlyStopping:
    """
    早停策略类。

    监控验证集指标，当连续patience轮无改善时触发停止。
    支持自动保存最优模型路径记录。

    Args:
        patience: 容忍的无改善轮数
        min_delta: 认定为改善的最小变化量
        mode: 'min'(损失越低越好)或'max'(指标越高越好)
        verbose: 是否打印早停信息
    """

    def __init__(
        self,
        patience: int = 20,
        min_delta: float = 0.001,
        mode: str = "min",
        verbose: bool = True,
    ):
        self.patience = patience
        self.min_delta = min_delta
        self.mode = mode
        self.verbose = verbose

        self.counter = 0
        self.best_value = None
        self.best_epoch = -1
        self.should_stop = False

        if mode == "min":
            self._is_better = lambda current, best: current < best - min_delta
            self.best_value = float("inf")
        elif mode == "max":
            self._is_better = lambda current, best: current > best + min_delta
            self.best_value = float("-inf")
        else:
            raise ValueError(f"mode必须为'min'或'max'，收到: {mode}")

    def step(self, metric_value: float, epoch: int) -> bool:
        """
        根据当前epoch指标判断是否应该早停。

        Args:
            metric_value: 当前epoch的验证指标值
            epoch: 当前epoch编号

        Returns:
            bool: 是否应该停止训练
        """
        if self._is_better(metric_value, self.best_value):
            self.best_value = metric_value
            self.best_epoch = epoch
            self.counter = 0
            if self.verbose:
                print(f"[EarlyStopping] 验证指标改善至 {metric_value:.6f} (epoch {epoch})")
            return False
        else:
            self.counter += 1
            if self.verbose:
                print(f"[EarlyStopping] 无改善 ({self.counter}/{self.patience})")
            if self.counter >= self.patience:
                self.should_stop = True
                if self.verbose:
                    print(f"[EarlyStopping] 触发早停，最佳epoch: {self.best_epoch}, "
                          f"最佳值: {self.best_value:.6f}")
                return True
            return False

    def state_dict(self) -> dict:
        """导出状态用于恢复训练。"""
        return {
            "counter": self.counter,
            "best_value": self.best_value,
            "best_epoch": self.best_epoch,
            "should_stop": self.should_stop,
        }

    def load_state_dict(self, state: dict):
        """从状态字典恢复。"""
        self.counter = state["counter"]
        self.best_value = state["best_value"]
        self.best_epoch = state["best_epoch"]
        self.should_stop = state["should_stop"]
