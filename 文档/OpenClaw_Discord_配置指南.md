# 🚀 OpenClaw Discord 配置完整指南

## 📋 目录
1. [前期准备](#前期准备)
2. [Discord Bot 创建步骤](#discord-bot-创建步骤)
3. [OpenClaw 配置方法](#openclaw-配置方法)
4. [配置文件结构](#配置文件结构)
5. [验证和测试](#验证和测试)
6. [常见问题解决](#常见问题解决)

---

## ✅ 已完成的工作

### 📁 目录结构（F盘）
已在 **F:\OpenClaw_Config\** 创建以下目录：
- ✅ `F:\OpenClaw_Config\Discord\` - Discord 配置目录
- ✅ `F:\OpenClaw_Config\Logs\` - 日志文件目录

### 📱 Discord 应用状态
- ✅ Discord 应用已安装在系统中

---

## 🔧 前期准备

### 1. 你需要的东西
- ✅ 一个 Discord 账号
- ✅ 一个 Discord 服务器（用于测试 Bot）
- ⏳ Discord Bot Token（稍后创建）

---

## 🤖 Discord Bot 创建步骤（7步）

### 第1步：访问 Discord 开发者门户
1. 打开浏览器
2. 访问：**https://discord.com/developers/applications**
3. 使用你的 Discord 账号登录

### 第2步：创建新应用
1. 点击右上角的 **"New Application"** 按钮
2. 在弹出窗口中输入应用名称，例如：`OpenClaw Bot`
3. 点击 **"Create"** 按钮确认创建

### 第3步：创建 Bot 用户
1. 在左侧菜单中选择 **"Bot"**
2. 点击 **"Add Bot"** 按钮
3. 在确认弹窗中点击 **"Yes, do it!"**

### 第4步：获取 Bot Token ⭐最重要！
1. 在 Bot 页面中，找到 **"TOKEN"** 区域
2. 点击 **"Reset Token"** 按钮（如果是首次）或 **"Copy"** 按钮
3. ⚠️ **重要提醒**：
   - 立即复制这个 Token！
   - Token 只显示一次，关闭页面后无法再次查看
   - 如果忘记了，需要点击 "Reset Token" 重新生成
4. **保存 Token**：
   - 新建一个文本文件保存在安全的位置
   - 或者暂时记在记事本里

### 第5步：配置 Bot 权限
1. 在 Bot 页面中，向下滚动找到 **"Privileged Gateway Intents"**
2. 开启以下三个开关（全部打开）：
   - ✅ **Presence Intent**
   - ✅ **Server Members Intent**
   - ✅ **Message Content Intent**
3. 点击 **"Save Changes"** 按钮保存设置

### 第6步：生成 OAuth2 邀请链接
1. 在左侧菜单中选择 **"OAuth2"** → **"URL Generator"**
2. 在 **"SCOPES"** 区域中勾选：
   - ✅ `bot`
   - ✅ `applications.commands`
3. 在 **"BOT PERMISSIONS"** 区域中勾选以下权限：
   - ✅ Send Messages（发送消息）
   - ✅ Read Message History（读取消息历史）
   - ✅ Read Messages/View Channels（查看频道）
   - ✅ Attach Files（附加文件）
   - ✅ Embed Links（嵌入链接）
   - ✅ Use Slash Commands（使用斜杠命令）
4. 复制页面底部生成的 **"GENERATED URL"** 链接

### 第7步：将 Bot 添加到你的服务器
1. 在浏览器中打开刚才复制的邀请链接
2. 在 "Add to server" 下拉菜单中选择你的服务器
3. 点击 **"Continue"** 按钮
4. 点击 **"Authorize"** 按钮
5. 完成人机验证（如果需要）
6. 看到 "Authorized" 提示表示成功！

---

## ⚙️ OpenClaw 配置方法

### 方式一：使用配置向导（推荐新手）

1. 打开 PowerShell
2. 运行命令：
   ```powershell
   openclaw onboard
   ```
3. 跟随向导提示：
   - 当问到配置聊天平台时，选择 **Discord**
   - 输入你刚才保存的 **Bot Token**
   - 完成其他配置项

### 方式二：直接配置 Discord（推荐进阶用户）

1. 打开 PowerShell
2. 运行命令（替换为你的 Token）：
   ```powershell
   openclaw channels login discord --token 你的BotToken在这里
   ```

---

## 📂 推荐的配置文件存储

虽然由于安全限制无法直接在F盘创建所有文件，但你可以手动创建以下结构：

```
F:\OpenClaw_Config\
├── 📂 Discord\
│   ├── token.txt              # 存放你的 Bot Token（手动创建）
│   └── config.json            # 配置文件（可选）
├── 📂 Logs\                   # 日志目录
└── 📄 Discord_Bot_Setup_Guide.md  # 本文档（可保存到此）
```

### 创建 Token 存储文件（手动）

1. 打开记事本
2. 输入以下内容：
   ```
   # Discord Bot Token
   [在这里粘贴你的Bot Token]
   ```
3. 保存到：`F:\OpenClaw_Config\Discord\token.txt`
4. ⚠️ **重要**：不要分享这个文件！

---

## ✅ 验证和测试

### 测试1：检查 OpenClaw 状态
```powershell
openclaw status
```
你应该能看到 Discord 通道的状态。

### 测试2：查看已连接的通道
```powershell
openclaw channels list
```

### 测试3：发送测试消息（可选）
```powershell
openclaw message send --channel discord --target "#你的频道名" --message "测试消息！"
```

---

## 🔒 安全注意事项

### 必须遵守的安全规则

1. **🔒 永远不要分享你的 Bot Token**
   - 任何人拿到 Token 都可以控制你的 Bot
   - 不要在代码仓库、聊天记录等地方分享

2. **🔒 安全存储 Token**
   - 将 Token 保存在安全的地方
   - 不要上传到 GitHub 等公开平台

3. **🔒 定期检查**
   - 如果怀疑 Token 泄露，立即重置
   - 在 Discord 开发者门户点击 "Reset Token"

4. **🔒 最小权限原则**
   - 只给 Bot 必要的权限
   - 不要给不必要的管理员权限

---

## ❓ 常见问题解决

### Q1: Bot 没有任何响应？
**A:** 检查以下几点：
1. Bot 是否已正确添加到服务器？
2. Token 是否正确输入？
3. "Privileged Gateway Intents" 三个开关是否都打开？
4. Bot 是否有足够的频道权限？

### Q2: 如何重置 Bot Token？
**A:** 
1. 访问 https://discord.com/developers/applications
2. 选择你的应用 → Bot
3. 点击 "Reset Token" 按钮
4. 重新配置 OpenClaw 使用新 Token

### Q3: 可以在多个服务器使用同一个 Bot 吗？
**A:** 可以！使用同一个 OAuth2 邀请链接，将 Bot 添加到多个服务器即可。

### Q4: OpenClaw 没有检测到 Discord？
**A:** 
1. 运行：`openclaw doctor` 检查环境
2. 确认 Token 配置正确
3. 查看日志文件排查问题

---

## 📚 更多资源

- 📖 OpenClaw 官方文档：https://docs.openclaw.ai/
- 📖 Discord 开发者文档：https://discord.com/developers/docs
- 🔧 OpenClaw 诊断命令：`openclaw doctor`

---

## 🎉 开始使用

准备好后，按顺序执行：

1. ✅ 完成上面的 **7步创建 Discord Bot**
2. ✅ 获取并保存 **Bot Token**
3. ✅ 运行 **openclaw onboard** 或 **openclaw channels login discord**
4. ✅ 验证配置：**openclaw status**
5. 🎉 开始使用！

---

## 💡 提示

- 遇到问题时，先运行 `openclaw doctor` 诊断
- 查看日志文件了解详细错误信息
- 逐步测试，不要一次配置所有功能
- 有任何疑问，随时查阅官方文档

祝你配置顺利！🚀
