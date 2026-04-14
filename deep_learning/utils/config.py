"""
YAML超参配置管理模块

功能：统一管理数据、模型、训练、部署四大类超参，
支持YAML文件加载解析、点号访问、命令行覆盖，杜绝硬编码。
"""

import copy
from typing import Any, Optional

import yaml


class ConfigNamespace:
    """
    配置命名空间类，支持点号访问配置项。

    Example:
        cfg = ConfigNamespace({"model": {"lr": 0.001}})
        print(cfg.model.lr)  # 0.001
    """

    def __init__(self, data: dict):
        for key, value in data.items():
            if isinstance(value, dict):
                setattr(self, key, ConfigNamespace(value))
            else:
                setattr(self, key, value)

    def to_dict(self) -> dict:
        """递归转换回普通字典。"""
        result = {}
        for key, value in self.__dict__.items():
            if isinstance(value, ConfigNamespace):
                result[key] = value.to_dict()
            else:
                result[key] = value
        return result

    def get(self, key: str, default: Any = None) -> Any:
        """安全获取配置项，支持点号分隔的路径。"""
        keys = key.split(".")
        obj = self
        for k in keys:
            if isinstance(obj, ConfigNamespace) and hasattr(obj, k):
                obj = getattr(obj, k)
            elif isinstance(obj, dict) and k in obj:
                obj = obj[k]
            else:
                return default
        return obj

    def __repr__(self) -> str:
        return f"ConfigNamespace({self.to_dict()})"

    def __contains__(self, key: str) -> bool:
        return hasattr(self, key)


def load_config(yaml_path: str) -> ConfigNamespace:
    """
    加载YAML配置文件并返回ConfigNamespace对象。

    Args:
        yaml_path: YAML配置文件路径

    Returns:
        ConfigNamespace: 可通过点号访问的配置对象
    """
    with open(yaml_path, 'r', encoding='utf-8') as f:
        raw_config = yaml.safe_load(f)

    if raw_config is None:
        raw_config = {}

    return ConfigNamespace(raw_config)


def merge_configs(base: dict, override: dict) -> dict:
    """
    递归合并两个配置字典，override的值优先。

    Args:
        base: 基础配置字典
        override: 覆盖配置字典

    Returns:
        dict: 合并后的配置字典
    """
    result = copy.deepcopy(base)
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = merge_configs(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def apply_overrides(config_dict: dict, overrides: list) -> dict:
    """
    应用命令行覆盖参数到配置字典。

    Args:
        config_dict: 原始配置字典
        overrides: 覆盖参数列表，格式如 ["model.lr=0.001", "training.epochs=100"]

    Returns:
        dict: 应用覆盖后的配置字典
    """
    result = copy.deepcopy(config_dict)

    for override in overrides:
        if "=" not in override:
            raise ValueError(f"覆盖参数格式错误，需为 key=value: {override}")

        key_path, value_str = override.split("=", 1)
        keys = key_path.strip().split(".")

        # 类型推断
        value = _parse_value(value_str.strip())

        # 递归设置值
        obj = result
        for k in keys[:-1]:
            if k not in obj:
                obj[k] = {}
            obj = obj[k]
        obj[keys[-1]] = value

    return result


def _parse_value(value_str: str) -> Any:
    """解析字符串值为适当的Python类型。"""
    if value_str.lower() == "true":
        return True
    if value_str.lower() == "false":
        return False
    if value_str.lower() == "none":
        return None

    # 尝试int
    try:
        return int(value_str)
    except ValueError:
        pass

    # 尝试float
    try:
        return float(value_str)
    except ValueError:
        pass

    # 尝试列表(简单格式)
    if value_str.startswith("[") and value_str.endswith("]"):
        items = value_str[1:-1].split(",")
        return [_parse_value(item.strip()) for item in items if item.strip()]

    return value_str


def save_config(config: ConfigNamespace, yaml_path: str):
    """
    将配置对象保存为YAML文件。

    Args:
        config: 配置对象
        yaml_path: 保存路径
    """
    config_dict = config.to_dict() if isinstance(config, ConfigNamespace) else config
    with open(yaml_path, 'w', encoding='utf-8') as f:
        yaml.dump(config_dict, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
