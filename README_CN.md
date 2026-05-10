# 罗小黑桌宠 - Tauri 跨平台版

中文 | [English](./README.md)

> 本分支为跨平台重写版本，使用 **Tauri 2 + Rust + React**。
> macOS 原生版（Swift/AppKit）请切换至 [`AppKit`](https://github.com/alertform/LuoXiaoHeiPet/tree/AppKit) 分支。

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
- 通过 OpenRouter 统一接入模型，内置 Claude、DeepSeek、MiniMax、Qwen、OpenAI 快捷选项
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
git clone -b tauri https://github.com/alertform/LuoXiaoHeiPet.git
cd LuoXiaoHeiPet
npm install
npm run tauri dev
```

首次启动后点击系统托盘图标 -> **设置**，配置 OpenRouter。

OpenRouter API Key 有两种配置方式：

- 在 **设置 -> 模型** 中填写
- 或在启动应用前设置环境变量 `OPENROUTER_API_KEY`

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
npm run tauri dev
```

Endpoint 已固定在程序内部：

```text
https://openrouter.ai/api/v1/chat/completions
```

设置面板内置常用模型快捷选项：

- Claude Sonnet: `anthropic/claude-sonnet-4.5`
- Claude Haiku: `anthropic/claude-haiku-4.5`
- DeepSeek V4: `deepseek/deepseek-v4-pro`
- DeepSeek Chat: `deepseek/deepseek-chat-v3.1`
- MiniMax M2.7: `minimax/minimax-m2.7`
- Qwen Plus: `qwen/qwen3.6-plus`
- Qwen Coder: `qwen/qwen3-coder-plus`
- OpenAI GPT-5.2: `openai/gpt-5.2`

也可以直接手动填写任意 OpenRouter model id。

## 使用方式

- 双击小黑打开或关闭聊天气泡
- 拖拽小黑移动悬浮窗
- 通过系统托盘菜单显示/隐藏、打开设置或退出
- 在 **设置 -> 模型** 中修改 API Key、模型、温度、最大 Token 和系统提示词
- 在 **设置 -> 语音** 中开关语音朗读
- 在 **设置 -> 记忆** 中开关或清空长期记忆

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
│   │   ├── services/       业务逻辑（OpenRouter SSE、文件工具、记忆、TTS）
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

## 与 AppKit 分支的差异

| | AppKit（Swift） | tauri（本分支） |
|--|--|--|
| 平台 | macOS only | macOS / Windows / Linux |
| 前端 | AppKit / SwiftUI | React 18 + TypeScript |
| 后端 | Swift | Rust |
| 打包 | Xcode | Tauri CLI |
| 体积 | ~5 MB | ~10 MB |
| 窗口透明 | 原生支持 | macOS 需 Private API |
| 思考过程 | 不支持 | 可折叠显示 |

## License

MIT
