# 🦞 OpenClaw GUI

一个图形界面的 OpenClaw 和 Discord Bot 管理工具

---

## ✨ 功能特性

- 🎨 **图形用户界面** - 友好的Windows桌面应用
- ⚙️ **OpenClaw 配置** - 一键检查、诊断、配置向导
- 🤖 **Discord Bot 管理** - 保存Token、测试连接
- 💾 **配置持久化** - 自动保存您的设置
- 🛠️ **实用工具** - 配置管理、快捷链接

---

## 📦 安装和运行

### 开发模式

1. 安装依赖：
```bash
cd d:\王元元老师大创\OpenClaw_GUI_App
npm install
```

2. 运行应用：
```bash
npm start
```

### 打包成安装程序

```bash
npm run build:win
```

安装程序将生成在 `dist/` 目录

---

## 🚀 使用说明

### 1. OpenClaw 配置页面
- 点击"检查 OpenClaw"验证安装
- 点击"运行诊断"检查健康状态
- 点击"配置向导"进行完整配置
- 点击"打开面板"访问Web界面

### 2. Discord Bot 页面
- 输入您的 Bot Token 和 Client ID
- 点击"保存配置"保存设置
- 点击"测试连接"验证配置
- 使用快捷链接访问开发者门户

### 3. 工具页面
- 查看和管理应用配置
- 重置所有配置
- 在文件管理器中打开项目

---

## 📁 项目结构

```
OpenClaw_GUI_App/
├── src/
│   ├── main/
│   │   └── main.js          # Electron 主进程
│   └── renderer/
│       ├── index.html       # 主界面
│       ├── styles.css       # 样式
│       └── renderer.js      # 渲染进程逻辑
├── assets/                  # 资源文件
├── package.json             # 项目配置
└── README.md               # 本文件
```

---

## 🛠️ 技术栈

- **Electron** - 跨平台桌面应用框架
- **HTML/CSS/JavaScript** - 前端技术
- **electron-store** - 配置持久化

---

## 📖 相关链接

- [OpenClaw 官方文档](https://docs.openclaw.ai/)
- [Discord 开发者门户](https://discord.com/developers/applications)
- [Electron 文档](https://www.electronjs.org/docs)

---

## 📄 许可证

MIT License
