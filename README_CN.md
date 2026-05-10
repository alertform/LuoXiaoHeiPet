# 罗小黑桌宠

中文 | [English](./README.md)

> 跨平台桌面宠物，基于 **Tauri 2 + Rust + React** — AI 流式对话、Tool Calling、多供应商路由、TTS、10+ 手绘动画状态。

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Tauri](https://img.shields.io/badge/Tauri-2.x-blue)
![Rust](https://img.shields.io/badge/Rust-1.85%2B-orange)
![React](https://img.shields.io/badge/React-18-61dafb)

## 预览

| 桌宠动画 | 应用图标 |
|----------|----------|
| ![罗小黑 idle 动画](public/animations/xiaohei_idle.gif) | ![罗小黑桌宠图标](src-tauri/icons/128x128@2x.png) |

## 功能

- 透明无边框悬浮窗，始终置顶，可自由拖拽
- 帧动画播放（idle / sleep / walk / happy / stretch / lookAround / talking / thinking / drag / fall）
- 双击呼出 AI 聊天气泡，流式输出
- 模型思考过程可折叠显示
- Function Calling：让小黑帮你操作文件（列目录、读写、搜索等）
- 跨平台系统 TTS 语音朗读（可在设置中开关）
- 三层记忆系统（工作记忆 / 会话记忆 / 长期记忆）
- 系统托盘菜单（显示/隐藏、设置、退出）
- 支持直连 Claude、DeepSeek、MiniMax、Qwen，并保留 OpenRouter 中转方式
- 配置持久化（API Key、模型、语音、记忆设置等重启后保留）

## 环境要求

| 工具 | 版本 |
|------|------|
| Node.js | 18+ |
| Rust | 1.85+ |
| Tauri CLI | 2.x |

> Linux 透明窗口需要开启混成器（KDE Plasma / GNOME + compositor）

## 快速开始

```bash
git clone https://github.com/alertform/LuoXiaoHeiPet.git
cd LuoXiaoHeiPet
npm install
npm run tauri dev
```

首次启动后点击系统托盘图标 -> **设置**，配置模型供应商。

API Key 有两种配置方式：

- 在 **设置 -> 模型** 中填写
- 或在启动应用前设置对应供应商的环境变量

```bash
export DEEPSEEK_API_KEY="sk-..."
npm run tauri dev
```

支持的供应商：

| 供应商 | Endpoint | 环境变量 |
|--------|----------|----------|
| Claude / Anthropic | `https://api.anthropic.com/v1/messages` | `ANTHROPIC_API_KEY` |
| DeepSeek | `https://api.deepseek.com/chat/completions` | `DEEPSEEK_API_KEY` |
| MiniMax | `https://api.minimax.io/v1/chat/completions` | `MINIMAX_API_KEY` |
| Qwen / DashScope | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` | `DASHSCOPE_API_KEY` |
| OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | `OPENROUTER_API_KEY` |

设置面板内置各供应商常用模型快捷选项，也可以手动填写当前供应商支持的模型 id。

## 使用方式

- 双击小黑打开或关闭聊天气泡
- 拖拽小黑移动悬浮窗
- 通过系统托盘菜单显示/隐藏、打开设置或退出
- 在 **设置 -> 模型** 中修改 API Key、模型、温度、最大 Token 和系统提示词
- 在 **设置 -> 语音** 中开关语音朗读
- 在 **设置 -> 记忆** 中开关或清空长期记忆

### 可选 Edge TTS

语音设置支持可选的 Edge 在线 TTS，引擎声音比系统 TTS 更自然。使用前先安装：

```bash
python3 -m pip install edge-tts
```

如果 Edge TTS 不可用，应用会回退到系统 TTS。

## 动画素材

将 PNG 帧文件放入 `src-tauri/resources/animations/`，命名格式：

```
{状态}_{序号3位}.png
# 例：idle_000.png  walk_005.png  happy_003.png
```

支持的状态：`idle` `sleep` `walk` `happy` `stretch` `lookAround` `talking` `thinking` `drag` `fall`

无素材时自动显示内置占位小黑猫。

重建内置的公开来源小黑素材：

```bash
python3 -m venv /tmp/luoxiaohei-assets-venv
/tmp/luoxiaohei-assets-venv/bin/python -m pip install -r tools/requirements.txt
/tmp/luoxiaohei-assets-venv/bin/python tools/build_xiaohei_assets.py
```

构建脚本会把源图片/GIF 下载到临时目录，规范化输出到
`src-tauri/resources/animations/` 和 `public/animations/`，然后删除原始下载文件。
生成的 `xiaohei_idle.gif` 会作为 idle 预览和占位动画。

## 项目结构

```
├── src-tauri/
│   ├── src/
│   │   ├── commands/       Tauri 命令（llm / file_tools / config / memory / tts）
│   │   ├── services/       业务逻辑（多供应商 SSE、文件工具、记忆、TTS）
│   │   └── models/         数据模型（chat / config / memory）
│   ├── resources/animations/   动画帧素材（PNG）
│   ├── icons/              应用图标
│   └── tauri.conf.json
├── src/
│   ├── components/
│   │   ├── pet/            PetCanvas、PetContainer
│   │   ├── chat/           ChatBubble、MessageList、ChatInput
│   │   └── settings/       SettingsWindow（模型 / 语音 / 记忆）
│   ├── hooks/
│   │   ├── useAnimationEngine.ts   帧动画状态机
│   │   ├── useChatManager.ts       聊天 + tool calling + 思考过程
│   │   └── useDrag.ts              Tauri 原生拖拽
│   ├── services/
│   │   ├── tauriCommands.ts        invoke 类型封装
│   │   └── animationLoader.ts      帧图片预加载 + 占位图生成
│   └── types/              animation / chat / config
└── tools/                  动画素材生成脚本（Python）
```

## 构建发布

```bash
npm run tauri build
```

产物在 `src-tauri/target/release/bundle/`。

## License

MIT
