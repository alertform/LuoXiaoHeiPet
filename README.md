# LuoXiaoHei Desktop Pet - Tauri Cross-Platform

[中文](./README_CN.md) | English

> Cross-platform rewrite using **Tauri 2 + Rust + React**.
> For the macOS native version (Swift/AppKit), switch to the [`AppKit`](https://github.com/alertform/LuoXiaoHeiPet/tree/AppKit) branch.

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey)
![Tauri](https://img.shields.io/badge/Tauri-2.x-blue)
![Rust](https://img.shields.io/badge/Rust-1.85%2B-orange)
![React](https://img.shields.io/badge/React-18-61dafb)

## Preview

| Desktop Pet | App Icon |
|-------------|----------|
| ![Xiaohei idle animation](public/animations/xiaohei_idle.gif) | ![LuoXiaoHei Pet icon](src-tauri/icons/128x128@2x.png) |

## Features

- Transparent borderless floating window, always on top, freely draggable
- Frame animation (idle / sleep / walk / happy / stretch / lookAround / talking / thinking / drag / fall)
- Double-click to open AI chat bubble with streaming output
- Collapsible model reasoning/thinking process display
- Function Calling: let Xiaohei operate files for you (list, read, write, search, etc.)
- Cross-platform system TTS voice (toggle in settings)
- Three-layer memory system (working / session / long-term)
- System tray menu (show/hide, settings, quit)
- Direct model provider access for Claude, DeepSeek, MiniMax, and Qwen, plus OpenRouter
- Persistent settings (API Key, model, TTS, and memory options survive restarts)

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

After first launch, open **Settings** from the system tray menu and configure a model provider.

You can provide the API key in either way:

- Enter it in **Settings -> Model**
- Or set the matching environment variable before starting the app

```bash
export DEEPSEEK_API_KEY="sk-..."
npm run tauri dev
```

Supported providers:

| Provider | Endpoint | Environment variable |
|----------|----------|----------------------|
| Claude / Anthropic | `https://api.anthropic.com/v1/messages` | `ANTHROPIC_API_KEY` |
| DeepSeek | `https://api.deepseek.com/chat/completions` | `DEEPSEEK_API_KEY` |
| MiniMax | `https://api.minimax.io/v1/chat/completions` | `MINIMAX_API_KEY` |
| Qwen / DashScope | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` | `DASHSCOPE_API_KEY` |
| OpenRouter | `https://openrouter.ai/api/v1/chat/completions` | `OPENROUTER_API_KEY` |

The settings panel includes provider-specific model presets, and you can also
type any supported model id manually.

## Usage

- Double-click Xiaohei to open or close the chat bubble
- Drag Xiaohei to move the floating pet window
- Open the system tray menu for show/hide, settings, and quit
- Use **Settings -> Model** to change API Key, model, temperature, max tokens, and system prompt
- Use **Settings -> Voice** to toggle TTS
- Use **Settings -> Memory** to toggle or clear long-term memory

### Optional Edge TTS

The Voice settings support an optional Edge online TTS engine for more natural
Chinese voices. Install the Python package first:

```bash
python3 -m pip install edge-tts
```

If Edge TTS is unavailable, the app falls back to the system TTS voice.

## Animation Assets

Place PNG frame files in `src-tauri/resources/animations/`, naming format:

```
{state}_{3-digit-index}.png
# e.g.: idle_000.png  walk_005.png  happy_003.png
```

Supported states: `idle` `sleep` `walk` `happy` `stretch` `lookAround` `talking` `thinking` `drag` `fall`

A built-in placeholder cat is shown when no assets are available.

To rebuild the bundled public-source Xiaohei assets:

```bash
python3 -m venv /tmp/luoxiaohei-assets-venv
/tmp/luoxiaohei-assets-venv/bin/python -m pip install -r tools/requirements.txt
/tmp/luoxiaohei-assets-venv/bin/python tools/build_xiaohei_assets.py
```

The builder downloads source images/GIFs into a temporary directory, normalizes
them into both `src-tauri/resources/animations/` and `public/animations/`,
then deletes the raw downloads. The generated `xiaohei_idle.gif` is used as
the idle preview/placeholder.

## Project Structure

```
├── src-tauri/
│   ├── src/
│   │   ├── commands/       Tauri commands (llm / file_tools / config / memory / tts)
│   │   ├── services/       Business logic (provider SSE, file tools, memory, TTS)
│   │   └── models/         Data models (chat / config / memory)
│   ├── resources/animations/   Animation frame assets (PNG)
│   ├── icons/              App icons
│   └── tauri.conf.json
├── src/
│   ├── components/
│   │   ├── pet/            PetCanvas, PetContainer
│   │   ├── chat/           ChatBubble, MessageList, ChatInput
│   │   └── settings/       SettingsWindow (Model / Voice / Memory)
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
