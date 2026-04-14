# Flutter开发环境安装指南

## 1. 核心镜像配置 (已由 Qoder 自动配置)
为了解决国内网络克隆失败的问题，已为您配置了以下环境变量：
- `PUB_HOSTED_URL`: `https://pub.flutter-io.cn`
- `FLUTTER_STORAGE_BASE_URL`: `https://storage.flutter-io.cn`

## 2. 下载与安装 Flutter SDK
1. 直接点击下载：[Flutter Windows Stable Zip](https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.3-stable.zip)
2. 解压到：`D:\src\flutter`
3. **关键动作**：在 VS Code 报错弹窗中点击 **"Locate SDK"**，指向该解压目录。

## 3. 深度学习 (Deep Learning) 环境预准备
本项目大创要求包含深度学习模块，安装完 Flutter 后，请确保以下项：
1. **Android NDK**: 在 Android Studio 的 SDK Manager 中勾选安装 NDK，这是运行 TensorFlow Lite (TFLite) 必须的。
2. **硬件加速**: 确保 Windows 的“虚拟机平台”功能已开启，以便顺畅运行模拟器进行 AI 推理测试。

## 3. 安装Android Studio

1. 下载Android Studio：https://developer.android.com/studio
2. 安装时选择标准安装
3. 安装完成后，通过Android Studio安装：
   - Android SDK
   - Android SDK Platform-Tools
   - Android SDK Build-Tools

## 4. 配置Android设备

### 选项1：使用真机调试
1. 在手机设置中开启开发者选项
2. 开启USB调试
3. 连接手机到电脑

### 选项2：使用模拟器
1. 在Android Studio中打开AVD Manager
2. 创建新的虚拟设备
3. 选择合适的设备和系统镜像

## 5. 验证环境
执行以下命令确认环境配置正确：
```
flutter doctor
```

确保所有项目都显示为绿色勾选状态。

安装完成后，请回到项目目录继续开发。