import { useEffect, useState } from "react";
import { loadConfig, loadSettings, saveConfig, saveSettings } from "../../services/tauriCommands";
import type { AppSettings, LLMConfig } from "../../types/config";
import { DEFAULT_CONFIG } from "../../types/config";
import styles from "./SettingsWindow.module.css";

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
    loadConfig().then(setConfig).catch(console.error);
    loadSettings().then(setSettings).catch(console.error);
  }, []);

  const handleSave = async () => {
    await saveConfig(config);
    await saveSettings(settings);
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className={styles.window}>
      <h2 className={styles.title}>罗小黑桌宠 - 设置</h2>

      <div className={styles.tabs}>
        {(["llm", "tts", "memory"] as const).map((t) => (
          <button
            key={t}
            className={`${styles.tab} ${tab === t ? styles.activeTab : ""}`}
            onClick={() => setTab(t)}
          >
            {{ llm: "🤖 AI 配置", tts: "🔊 语音", memory: "🧠 记忆" }[t]}
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
        <button className={styles.saveBtn} onClick={handleSave}>
          {saved ? "✓ 已保存" : "保存"}
        </button>
      </div>
    </div>
  );
}

function LLMTab({ config, onChange }: { config: LLMConfig; onChange: (c: LLMConfig) => void }) {
  const set = (key: keyof LLMConfig, val: string | number) =>
    onChange({ ...config, [key]: val });

  return (
    <div className={styles.form}>
      <label>API Key</label>
      <input
        type="password"
        value={config.api_key}
        onChange={(e) => set("api_key", e.target.value)}
        placeholder="Bearer Token"
      />
      <label>Endpoint</label>
      <input
        value={config.endpoint}
        onChange={(e) => set("endpoint", e.target.value)}
      />
      <label>模型</label>
      <input
        value={config.model}
        onChange={(e) => set("model", e.target.value)}
        placeholder="doubao-seed-2.0-pro"
      />
      <label>温度 ({config.temperature})</label>
      <input
        type="range"
        min="0"
        max="1"
        step="0.1"
        value={config.temperature}
        onChange={(e) => set("temperature", parseFloat(e.target.value))}
      />
      <label>最大 Token 数</label>
      <input
        type="number"
        min="128"
        max="4096"
        value={config.max_tokens}
        onChange={(e) => set("max_tokens", parseInt(e.target.value))}
      />
      <label>系统提示词</label>
      <textarea
        value={config.system_prompt}
        onChange={(e) => set("system_prompt", e.target.value)}
        rows={4}
      />
    </div>
  );
}

function TTSTab({ settings, onChange }: { settings: AppSettings; onChange: (s: AppSettings) => void }) {
  return (
    <div className={styles.form}>
      <label className={styles.checkRow}>
        <input
          type="checkbox"
          checked={settings.tts_enabled}
          onChange={(e) => onChange({ ...settings, tts_enabled: e.target.checked })}
        />
        启用语音朗读
      </label>
      <p className={styles.hint}>使用系统中文语音朗读小黑的回复</p>
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
      <label className={styles.checkRow}>
        <input
          type="checkbox"
          checked={settings.memory_enabled}
          onChange={(e) => onChange({ ...settings, memory_enabled: e.target.checked })}
        />
        启用记忆功能
      </label>
      <p className={styles.hint}>小黑会记住你告诉她的事情，下次聊天时自然提起</p>
      <button className={styles.dangerBtn} onClick={handleClear}>
        清空所有记忆
      </button>
    </div>
  );
}
