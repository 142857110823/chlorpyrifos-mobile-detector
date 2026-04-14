# Discord Bot 项目
一个功能完整的Discord Bot项目，包含日志系统、错误处理和基础命令。

## 功能特性

- 斜杠命令支持
- 完整的日志记录系统
- 错误处理机制
- 可扩展的命令结构

## 快速开始

1. 安装依赖：
```bash
npm install
```

2. 配置环境变量：
   - 复制 `config/.env.example` 为 `config/.env`
   - 填入你的 Bot Token 和 Client ID

3. 部署命令：
```bash
node deploy-commands.js
```

4. 启动 Bot：
```bash
npm start
```

## 可用命令

- `/ping` - 查看Bot延迟
- `/hello` - 向Bot打招呼
- `/help` - 获取帮助

## 项目结构

```
Discord_Bot_Project\
├── src/
│   ├── commands/      # 命令文件
│   ├── events/        # 事件处理
│   └── utils/         # 工具函数
├── config/           # 配置文件
└── logs/             # 日志文件
```
