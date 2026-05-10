import { useEffect, useState } from "react";
import { loadConfig, loadSettings, saveConfig, saveSettings } from "../../services/tauriCommands";
import type { AppSettings, LLMConfig } from "../../types/config";
import { DEFAULT_CONFIG } from "../../types/config";
import styles from "./SettingsWindow.module.css";

const OPENROUTER_ENDPOINT = "https://openrouter.ai/api/v1/chat/completions";

const MODEL_PRESETS = [
  { label: "Claude Sonnet", value: "anthropic/claude-sonnet-4.5" },
  { label: "Claude Haiku", value: "anthropic/claude-haiku-4.5" },
  { label: "DeepSeek V4", value: "deepseek/deepseek-v4-pro" },
  { label: "DeepSeek Chat", value: "deepseek/deepseek-chat-v3.1" },
  { label: "MiniMax M2.7", value: "minimax/minimax-m2.7" },
  { label: "Qwen Plus", value: "qwen/qwen3.6-plus" },
  { label: "Qwen Coder", value: "qwen/qwen3-coder-plus" },
  { label: "OpenAI GPT-5.2", value: "openai/gpt-5.2" },
] as const;

function normalizeOpenRouterConfig(config: LLMConfig): LLMConfig {
  return {
    ...config,
    provider: "openrouter",
    endpoint: OPENROUTER_ENDPOINT,
    model:
      config.model && config.model !== "doubao-seed-2.0-pro"
        ? config.model
        : DEFAULT_CONFIG.model,
  };
}

export function SettingsWindow() {
  const [tab, setTab] = useState<"llm" | "tts" | "memory">("llm");
  const [config, setConfig] = useState<LLMConfig>(DEFAULT_CONFIG);
  const [settings, setSettings] = useState<AppSettings>({
    tts_enabled: true,
    tts_voice_type: "BV051_streaming",
    memory_enabled: true,
  });
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadConfig().then((loaded) => setConfig(normalizeOpenRouterConfig(loaded))).catch(console.error);
    loadSettings().then(setSettings).catch(console.error);
  }, []);

  const handleSave = async () => {
    const normalized = normalizeOpenRouterConfig(config);
    setConfig(normalized);
    await saveConfig(normalized);
    await saveSettings(settings);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  const handleClose = async () => {
    const { getCurrentWebviewWindow } = await import("@tauri-apps/api/webviewWindow");
    getCurrentWebviewWindow().close();
  };

  return (
    <div className={styles.window}>
      <div className={styles.titleBar} data-tauri-drag-region>
        <span className={styles.titleText}>设置</span>
        <button className={styles.titleCloseBtn} onClick={handleClose}>✕</button>
      </div>

      <div className={styles.tabs}>
        {(["llm", "tts", "memory"] as const).map((t) => (
          <button
            key={t}
            className={`${styles.tab} ${tab === t ? styles.activeTab : ""}`}
            onClick={() => setTab(t)}
          >
            {{ llm: "模型", tts: "语音", memory: "记忆" }[t]}
          </button>
        ))}
      </div>

      <div className={styles.content}>
        {tab === "llm" && (
          <LLMTab config={config} onChange={setConfig} />
        )}
        {tab === "tts" && (
          <TTSTab settings={settings} onChange={setSettings} />
        )}
        {tab === "memory" && (
          <MemoryTab settings={settings} onChange={setSettings} />
        )}
      </div>

      <div className={styles.footer}>
        {saved && <span className={styles.savedText}>已保存</span>}
        <button className={styles.saveBtn} onClick={handleSave}>
          保存设置
        </button>
      </div>
    </div>
  );
}

function LLMTab({ config, onChange }: { config: LLMConfig; onChange: (c: LLMConfig) => void }) {
  const set = (key: keyof LLMConfig, val: string | number) =>
    onChange(normalizeOpenRouterConfig({ ...config, [key]: val }));

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>OpenRouter</h2>
          <p>统一通过 OpenRouter 调用模型。API Key 可留空并使用 OPENROUTER_API_KEY 环境变量。</p>
        </div>

        <label>API Key</label>
        <input
          type="password"
          value={config.api_key}
          onChange={(e) => set("api_key", e.target.value)}
          placeholder="OpenRouter API Key"
        />
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>模型</h2>
          <p>选择常用模型，或在下方直接输入任意 OpenRouter model id。</p>
        </div>

        <div className={styles.modelGrid}>
          {MODEL_PRESETS.map((preset) => (
            <button
              key={preset.value}
              type="button"
              className={`${styles.modelButton} ${config.model === preset.value ? styles.activeModel : ""}`}
              onClick={() => set("model", preset.value)}
            >
              {preset.label}
            </button>
          ))}
        </div>

        <label>模型名称</label>
        <input
          value={config.model}
          onChange={(e) => set("model", e.target.value)}
          placeholder={DEFAULT_CONFIG.model}
        />

        <div className={styles.fieldGrid}>
          <div>
            <label>温度</label>
            <div className={styles.rangeRow}>
              <input
                type="range"
                min="0"
                max="1"
                step="0.1"
                value={config.temperature}
                onChange={(e) => set("temperature", parseFloat(e.target.value))}
              />
              <span>{config.temperature}</span>
            </div>
          </div>
          <div>
            <label>最大 Token</label>
            <input
              type="number"
              min="128"
              max="4096"
              value={config.max_tokens}
              onChange={(e) => set("max_tokens", parseInt(e.target.value))}
            />
          </div>
        </div>
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>角色</h2>
          <p>控制小黑的回复风格和边界。</p>
        </div>
        <label>系统提示词</label>
        <textarea
          value={config.system_prompt}
          onChange={(e) => set("system_prompt", e.target.value)}
          rows={5}
        />
      </section>
    </div>
  );
}

function TTSTab({ settings, onChange }: { settings: AppSettings; onChange: (s: AppSettings) => void }) {
  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>语音朗读</h2>
          <p>开启后，小黑回复时会使用系统中文语音朗读。</p>
        </div>
        <label className={styles.checkRow}>
          <input
            type="checkbox"
            checked={settings.tts_enabled}
            onChange={(e) => onChange({ ...settings, tts_enabled: e.target.checked })}
          />
          启用语音
        </label>
      </section>
    </div>
  );
}

function MemoryTab({ settings, onChange }: { settings: AppSettings; onChange: (s: AppSettings) => void }) {
  const handleClear = async () => {
    const { clearMemory } = await import("../../services/tauriCommands");
    if (confirm("确定清空所有记忆？")) await clearMemory();
  };

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>长期记忆</h2>
          <p>保存偏好和重要事实，用于后续对话。</p>
        </div>
        <label className={styles.checkRow}>
          <input
            type="checkbox"
            checked={settings.memory_enabled}
            onChange={(e) => onChange({ ...settings, memory_enabled: e.target.checked })}
          />
          启用记忆
        </label>
        <button className={styles.dangerBtn} onClick={handleClear}>
          清空记忆
        </button>
      </section>
    </div>
  );
}
