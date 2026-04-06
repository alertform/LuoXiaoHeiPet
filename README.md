# LuoXiaoHei Desktop Pet 🐱 — Tauri Cross-Platform

[中文](./README_CN.md) | English

> Cross-platform rewrite using **Tauri 2 + Rust + React**.
> For the macOS native version (Swift/AppKit), switch to the [`AppKit`](https://github.com/alertform/LuoXiaoHeiPet/tree/AppKit) branch.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Tauri](https://img.shields.io/badge/Tauri-2.x-blue)
![Rust](https://img.shields.io/badge/Rust-1.85%2B-orange)
![React](https://img.shields.io/badge/React-18-61dafb)

## Features

- Transparent borderless floating window, always on top, freely draggable
- Frame animation (idle / sleep / walk / happy / stretch / lookAround / talking / thinking / drag / fall)
- Double-click to open AI chat bubble with streaming output
- Collapsible model reasoning/thinking process display
- Function Calling: let Xiaohei operate files for you (list, read, write, search, etc.)
- Cross-platform system TTS voice (toggle in settings)
- Three-layer memory system (working / session / long-term)
- System tray menu (show/hide, settings, quit)
- Persistent configuration (API Key survives restarts)

## Requirements

| Tool | Version |
|------|---------|
| Node.js | 18+ |
| Rust | 1.85+ |
| Tauri CLI | 2.x |

> Linux transparent windows require a compositor (KDE Plasma / GNOME + compositor)

## Quick Start

```bash
git clone -b tauri https://github.com/alertform/LuoXiaoHeiPet.git
cd LuoXiaoHeiPet
npm install
npm run tauri dev
```

After first launch, click the system tray icon -> **Settings**, and enter your Volcano Engine API Key.

> Apply here: [Volcano Engine MaaS Platform](https://www.volcengine.com/product/ark)
> Default model: `doubao-seed-2.0-pro`

## Adding Animation Assets

Place PNG frame files in `src-tauri/resources/animations/`, naming format:

```
{state}_{3-digit-index}.png
# e.g.: idle_000.png  walk_005.png  happy_003.png
```

Supported states: `idle` `sleep` `walk` `happy` `stretch` `lookAround` `talking` `thinking` `drag` `fall`

A built-in placeholder cat is shown when no assets are available.

## Project Structure

```
├── src-tauri/
│   ├── src/
│   │   ├── commands/       Tauri commands (llm / file_tools / config / memory / tts)
│   │   ├── services/       Business logic (VolcanoEngine SSE, file tools, memory, TTS)
│   │   └── models/         Data models (chat / config / memory)
│   ├── resources/animations/   Animation frame assets (PNG)
│   ├── icons/              App icons
│   └── tauri.conf.json
├── src/
│   ├── components/
│   │   ├── pet/            PetCanvas, PetContainer
│   │   ├── chat/           ChatBubble, MessageList, ChatInput
│   │   └── settings/       SettingsWindow (LLM / TTS / Memory)
│   ├── hooks/
│   │   ├── useAnimationEngine.ts   Frame animation state machine
│   │   ├── useChatManager.ts       Chat + tool calling + reasoning display
│   │   └── useDrag.ts              Tauri native drag
│   ├── services/
│   │   ├── tauriCommands.ts        Typed invoke wrappers
│   │   └── animationLoader.ts      Frame preloading + placeholder generation
│   └── types/              animation / chat / config
└── tools/                  Animation asset generation scripts (Python)
```

## Build for Release

```bash
npm run tauri build
```

Output in `src-tauri/target/release/bundle/`.

## Comparison with AppKit Branch

| | AppKit (Swift) | tauri (this branch) |
|--|--|--|
| Platform | macOS only | macOS / Windows / Linux |
| Frontend | AppKit / SwiftUI | React 18 + TypeScript |
| Backend | Swift | Rust |
| Packaging | Xcode | Tauri CLI |
| Size | ~5 MB | ~10 MB |
| Transparency | Native support | macOS requires Private API |
| Reasoning | Not supported | Collapsible display |

## License

MIT
