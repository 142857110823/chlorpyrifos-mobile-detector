# 果蔬农药残留检测APP - 资源文件说明

## 目录结构

```
assets/
├── images/           # 图片资源
│   ├── logo.png     # 应用Logo
│   ├── splash.png   # 启动页背景
│   └── empty.png    # 空状态图片
├── icons/           # 图标资源
│   ├── safe.svg     # 安全图标
│   ├── warning.svg  # 警告图标
│   └── danger.svg   # 危险图标
└── fonts/           # 字体文件
    └── PingFang-Regular.ttf
```

## 使用说明

1. **图片资源**: 将应用所需的图片文件放在 `images/` 目录下
2. **图标资源**: SVG格式的图标放在 `icons/` 目录下，通过 flutter_svg 包使用
3. **字体文件**: 自定义字体放在 `fonts/` 目录下，在 pubspec.yaml 中配置

## 注意事项

- 图片建议使用PNG格式，支持透明背景
- 图标建议使用SVG格式，以支持不同分辨率
- 所有资源文件需要在 pubspec.yaml 中声明才能使用

## 资源占位

当前为项目框架阶段，实际图片资源需要后续补充：
- 应用Logo
- 启动页图片
- 各类状态图标
- 果蔬分类图标
