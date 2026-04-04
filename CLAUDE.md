# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目简介

罗小黑（Xiaohei）是一个 macOS 桌面宠物应用，使用 Cocoa/AppKit 开发，集成火山引擎豆包大模型实现 AI 聊天功能。运行为状态栏 accessory app（无 Dock 图标）。

## 构建与运行

```bash
# 用 Xcode 打开
open Xiaohei.xcodeproj

# 命令行构建
xcodebuild -project Xiaohei.xcodeproj -scheme Xiaohei build

# 命令行运行（构建后）
xcodebuild -project Xiaohei.xcodeproj -scheme Xiaohei -destination 'platform=macOS' run
```

## 动画素材工具（tools/）

```bash
# 生成动画帧占位图（开发时无美术素材时使用）
python3 tools/generate_placeholder.py

# 生成小黑 v2 动画帧
python3 tools/generate_xiaohei_v2.py

# 转换已有素材格式
python3 tools/convert_assets.py
```

## 整体架构

`AppDelegate`（`XiaoheiApp.swift`）是唯一入口，在启动时创建所有服务并持有强引用（防止 ARC 释放）：

```
AppDelegate
├── AnimationEngine       ← 帧动画播放引擎
├── ChatManager           ← 对话管理器（协调 LLM + 记忆 + TTS）
│   ├── LLMService        ← VolcanoEngineService（豆包 API）
│   ├── TTSService        ← 语音合成（火山 TTS 或系统 AVSpeechSynthesizer）
│   └── MemoryManager     ← 三层记忆系统（单例）
├── PetWindow             ← 无边框透明悬浮窗（NSPanel）
│   └── PetViewController ← 鼠标事件 + 动画帧显示
│       └── PetView       ← NSView，直接渲染 NSImage 帧
└── StatusBarController   ← 状态栏菜单
```

### 关键数据流

**聊天流程：**
1. 用户双击宠物 → `PetViewController` 打开 `ChatBubbleWindow`
2. 用户发送消息 → `ChatManager.send(text:)`
3. 优先尝试流式（SSE）请求；若流式返回空（tool call 场景），切换为非流式
4. 若 LLM 返回 `tool_calls`，`ChatManager` 执行工具（`FileToolService`）后重新发送，最多循环 5 轮
5. 回复完成后触发 `MemoryManager.processConversation` 提取记忆，并可选调用 TTS 朗读

**动画帧命名规则：**
文件放在 `Xiaohei/AnimationFrames/`，格式为 `{state}_{NNN}.png`（如 `idle_000.png`、`walk_005.png`）。`AnimationEngine` 按序号连续加载，遇到断号停止。帧加载后缓存在内存中。

### 核心模块说明

**`Animation/AnimationState.swift`** — `PetAnimationState` 枚举定义所有动画状态，每个状态包含：是否循环、帧间隔、播放完成后的默认过渡状态。非循环状态（happy/stretch/lookAround/fall）播放完自动回到 idle。

**`LLM/LLMService.swift`** — `LLMService` 协议抽象了 LLM 接口，目前唯一实现是 `VolcanoEngineService`（豆包 API，endpoint 默认为北京区）。SSE 流式解析在内部 `StreamDelegate` 类中处理。

**`LLM/LLMConfig.swift`** — 配置持久化在 `UserDefaults`（key: `com.luoxiaohei.pet.llmConfig`）。默认模型 `doubao-seed-2.0-pro`，可在设置界面切换。

**`LLM/FileToolService.swift`** — 向 LLM 暴露 9 个文件操作工具（list/read/write/append/create/delete/move/info/search）。所有操作限制在 `NSHomeDirectory()` 内，不允许操作系统目录。

**`Memory/MemoryManager.swift`** — 三层记忆：
- 工作记忆（Working）：由 `ChatManager.history` 承担，最近 20 条
- 会话记忆（Session）：基于规则提取本次会话话题和摘要，保存在内存
- 长期记忆（Long-term）：持久化到 UserDefaults（key: `com.luoxiaohei.pet.longTermMemory`），存用户画像/事实/情感/会话摘要，**纯规则提取，不调用 LLM**

**`LLM/TTSService.swift`** — 优先使用火山引擎 TTS（需单独配置 AppId + Token），失败时自动回退到 macOS 系统 AVSpeechSynthesizer（中文增强版语音）。

## 配置方式

所有运行时配置通过设置界面写入 `UserDefaults`，无配置文件。修改后发送 `Notification.Name.llmConfigDidChange` 通知，`AppDelegate` 监听并重建服务。

| 配置项 | UserDefaults key |
|--------|-----------------|
| LLM 全部配置 | `com.luoxiaohei.pet.llmConfig` |
| 长期记忆 | `com.luoxiaohei.pet.longTermMemory` |
| 聊天历史 | `com.luoxiaohei.pet.chatHistory` |
| TTS 开关 | `tts.enabled` |
| TTS 音色 | `tts.voiceType` |
| 记忆开关 | `memory.enabled` |
