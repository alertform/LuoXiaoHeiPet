import { useEffect, useState } from "react";
import {
  clearTokenUsageStats,
  loadConfig,
  loadSettings,
  loadTokenUsageStats,
  saveConfig,
  saveSettings,
} from "../../services/tauriCommands";
import type { TokenUsageStats } from "../../types/chat";
import type { AppSettings, LLMConfig } from "../../types/config";
import {
  DEFAULT_CONFIG,
  DEFAULT_SYSTEM_PROMPT,
  LEGACY_SYSTEM_PROMPT,
  normalizeAppSettings,
} from "../../types/config";
import styles from "./SettingsWindow.module.css";

const PROVIDERS = {
  anthropic: {
    label: "Claude",
    endpoint: "https://api.anthropic.com/v1/messages",
    envKey: "ANTHROPIC_API_KEY",
    keyHint: "Anthropic API Key",
    defaultModel: "claude-sonnet-4-5",
    models: [
      { label: "Sonnet", value: "claude-sonnet-4-5" },
      { label: "Haiku", value: "claude-haiku-4-5" },
    ],
  },
  deepseek: {
    label: "DeepSeek",
    endpoint: "https://api.deepseek.com/chat/completions",
    envKey: "DEEPSEEK_API_KEY",
    keyHint: "DeepSeek API Key",
    defaultModel: "deepseek-chat",
    models: [
      { label: "Chat", value: "deepseek-chat" },
      { label: "Reasoner", value: "deepseek-reasoner" },
    ],
  },
  minimax: {
    label: "MiniMax",
    endpoint: "https://api.minimax.io/v1/chat/completions",
    envKey: "MINIMAX_API_KEY",
    keyHint: "MiniMax API Key",
    defaultModel: "MiniMax-M2.7",
    models: [
      { label: "M2.7", value: "MiniMax-M2.7" },
      { label: "M2.5", value: "MiniMax-M2.5" },
    ],
  },
  qwen: {
    label: "Qwen",
    endpoint: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
    envKey: "DASHSCOPE_API_KEY",
    keyHint: "DashScope API Key",
    defaultModel: "qwen3.6-plus",
    models: [
      { label: "Plus", value: "qwen3.6-plus" },
      { label: "Flash", value: "qwen3.6-flash" },
      { label: "Coder", value: "qwen3-coder-plus" },
    ],
  },
  openrouter: {
    label: "OpenRouter",
    endpoint: "https://openrouter.ai/api/v1/chat/completions",
    envKey: "OPENROUTER_API_KEY",
    keyHint: "OpenRouter API Key",
    defaultModel: "anthropic/claude-sonnet-4.5",
    models: [
      { label: "Claude", value: "anthropic/claude-sonnet-4.5" },
      { label: "DeepSeek", value: "deepseek/deepseek-v4-pro" },
      { label: "MiniMax", value: "minimax/minimax-m2.7" },
      { label: "Qwen", value: "qwen/qwen3.6-plus" },
      { label: "OpenAI", value: "openai/gpt-5.2" },
    ],
  },
} as const;

type ProviderName = keyof typeof PROVIDERS;

function isProviderName(provider: string): provider is ProviderName {
  return provider in PROVIDERS;
}

function normalizeProviderConfig(config: LLMConfig): LLMConfig {
  const provider: ProviderName = isProviderName(config.provider) ? config.provider : DEFAULT_CONFIG.provider;
  const preset = PROVIDERS[provider];
  const currentModel = config.model && config.model !== "doubao-seed-2.0-pro"
    ? config.model
    : preset.defaultModel;
  const systemPrompt =
    !config.system_prompt?.trim() || config.system_prompt === LEGACY_SYSTEM_PROMPT
      ? DEFAULT_SYSTEM_PROMPT
      : config.system_prompt;

  return {
    ...config,
    provider,
    endpoint: preset.endpoint,
    model: currentModel,
    system_prompt: systemPrompt,
  };
}

export function SettingsWindow() {
  const [tab, setTab] = useState<"llm" | "tts" | "memory" | "interaction" | "usage">("llm");
  const [config, setConfig] = useState<LLMConfig>(DEFAULT_CONFIG);
  const [settings, setSettings] = useState<AppSettings>({
    tts_enabled: true,
    tts_provider: "system",
    tts_voice_type: "Tingting",
    memory_enabled: true,
    interaction_level: "low",
  });
  const [usageStats, setUsageStats] = useState<TokenUsageStats[]>([]);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    loadConfig().then((loaded) => setConfig(normalizeProviderConfig(loaded))).catch(console.error);
    loadSettings().then((s) => setSettings(normalizeAppSettings(s))).catch(console.error);
    loadTokenUsageStats().then(setUsageStats).catch(console.error);
  }, []);

  useEffect(() => {
    if (tab === "usage") {
      loadTokenUsageStats().then(setUsageStats).catch(console.error);
    }
  }, [tab]);

  const handleSave = async () => {
    const normalized = normalizeProviderConfig(config);
    setConfig(normalized);
    await saveConfig(normalized);
    await saveSettings(normalizeAppSettings(settings));
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
        {(["llm", "tts", "memory", "interaction", "usage"] as const).map((t) => (
          <button
            key={t}
            className={`${styles.tab} ${tab === t ? styles.activeTab : ""}`}
            onClick={() => setTab(t)}
          >
            {{ llm: "模型", tts: "语音", memory: "记忆", interaction: "互动", usage: "用量" }[t]}
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
        {tab === "interaction" && (
          <InteractionTab settings={settings} onChange={setSettings} />
        )}
        {tab === "usage" && (
          <UsageTab stats={usageStats} onChange={setUsageStats} />
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
    onChange(normalizeProviderConfig({ ...config, [key]: val }));
  const provider = isProviderName(config.provider) ? config.provider : DEFAULT_CONFIG.provider;
  const providerPreset = PROVIDERS[provider];
  const setProvider = (nextProvider: ProviderName) => {
    const preset = PROVIDERS[nextProvider];
    onChange(normalizeProviderConfig({
      ...config,
      provider: nextProvider,
      endpoint: preset.endpoint,
      model: preset.defaultModel,
      api_key: "",
    }));
  };

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>供应商</h2>
          <p>选择直接模型商；OpenRouter 作为统一中转保留在最后。</p>
        </div>

        <div className={styles.modelGrid}>
          {(Object.entries(PROVIDERS) as Array<[ProviderName, typeof PROVIDERS[ProviderName]]>).map(([key, preset]) => (
            <button
              key={key}
              type="button"
              className={`${styles.modelButton} ${provider === key ? styles.activeModel : ""}`}
              onClick={() => setProvider(key)}
            >
              {preset.label}
            </button>
          ))}
        </div>

        <label>API Key</label>
        <input
          type="password"
          value={config.api_key}
          onChange={(e) => set("api_key", e.target.value)}
          placeholder={providerPreset.keyHint}
        />
        <p className={styles.inlineHint}>也可以通过环境变量 {providerPreset.envKey} 提供。</p>
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>模型</h2>
          <p>选择常用模型，或在下方直接输入当前供应商支持的模型 id。</p>
        </div>

        <div className={styles.modelGrid}>
          {providerPreset.models.map((preset) => (
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
          placeholder={providerPreset.defaultModel}
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
  const provider = settings.tts_provider ?? "system";
  const systemVoices = [
    { label: "婷婷", value: "Tingting" },
    { label: "美佳", value: "Meijia" },
    { label: "自动", value: "auto" },
  ];
  const edgeVoices = [
    { label: "晓晓", value: "zh-CN-XiaoxiaoNeural" },
    { label: "云希", value: "zh-CN-YunxiNeural" },
    { label: "晓伊", value: "zh-CN-XiaoyiNeural" },
    { label: "云健", value: "zh-CN-YunjianNeural" },
  ];
  const voices = provider === "edge" ? edgeVoices : systemVoices;

  const setProvider = (nextProvider: "system" | "edge") => {
    onChange({
      ...settings,
      tts_provider: nextProvider,
      tts_voice_type: nextProvider === "edge" ? "zh-CN-XiaoxiaoNeural" : "Tingting",
    });
  };

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>语音朗读</h2>
          <p>系统语音离线稳定；Edge 在线语音更自然，需要安装 edge-tts。</p>
        </div>
        <label className={styles.checkRow}>
          <input
            type="checkbox"
            checked={settings.tts_enabled}
            onChange={(e) => onChange({ ...settings, tts_enabled: e.target.checked })}
          />
          启用语音
        </label>

        <label>引擎</label>
        <div className={styles.modelGrid}>
          {[
            { label: "系统", value: "system" },
            { label: "Edge 在线", value: "edge" },
          ].map((option) => (
            <button
              key={option.value}
              type="button"
              className={`${styles.modelButton} ${provider === option.value ? styles.activeModel : ""}`}
              onClick={() => setProvider(option.value as "system" | "edge")}
            >
              {option.label}
            </button>
          ))}
        </div>
        {provider === "edge" && (
          <p className={styles.inlineHint}>需要先安装：python3 -m pip install edge-tts</p>
        )}

        <label>音色</label>
        <div className={styles.modelGrid}>
          {voices.map((voice) => (
            <button
              key={voice.value}
              type="button"
              className={`${styles.modelButton} ${settings.tts_voice_type === voice.value ? styles.activeModel : ""}`}
              onClick={() => onChange({ ...settings, tts_voice_type: voice.value })}
            >
              {voice.label}
            </button>
          ))}
        </div>
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

function InteractionTab({ settings, onChange }: { settings: AppSettings; onChange: (s: AppSettings) => void }) {
  const levels: Array<{ label: string; value: AppSettings["interaction_level"]; description: string }> = [
    { label: "关闭", value: "off", description: "不主动说话，只保留聊天窗口。" },
    { label: "低", value: "low", description: "每日问候和点击、拖动反馈。" },
    { label: "标准", value: "standard", description: "低强度基础上，偶尔空闲互动。" },
    { label: "活跃", value: "active", description: "更频繁的空闲互动，适合喜欢桌宠存在感的人。" },
  ];

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>主动互动</h2>
          <p>控制小黑主动打招呼、点击反馈和空闲短句的频率。</p>
        </div>

        <div className={styles.choiceList}>
          {levels.map((level) => (
            <button
              key={level.value}
              type="button"
              className={`${styles.choiceButton} ${settings.interaction_level === level.value ? styles.activeChoice : ""}`}
              onClick={() => onChange({ ...settings, interaction_level: level.value })}
            >
              <strong>{level.label}</strong>
              <span>{level.description}</span>
            </button>
          ))}
        </div>
      </section>
    </div>
  );
}

function UsageTab({
  stats,
  onChange,
}: {
  stats: TokenUsageStats[];
  onChange: (stats: TokenUsageStats[]) => void;
}) {
  const totals = stats.reduce(
    (acc, item) => ({
      requests: acc.requests + item.requests,
      input: acc.input + item.input_tokens,
      output: acc.output + item.output_tokens,
      total: acc.total + item.total_tokens,
    }),
    { requests: 0, input: 0, output: 0, total: 0 },
  );

  const handleRefresh = async () => {
    const nextStats = await loadTokenUsageStats();
    onChange(nextStats);
  };

  const handleClear = async () => {
    if (!confirm("确定清空所有 token 用量统计？")) return;
    await clearTokenUsageStats();
    onChange([]);
  };

  return (
    <div className={styles.form}>
      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <h2>Token 用量</h2>
          <p>按供应商和模型聚合统计，只记录本机已完成请求返回的 usage 数据。</p>
        </div>

        <div className={styles.usageSummary}>
          <UsageMetric label="请求" value={formatNumber(totals.requests)} />
          <UsageMetric label="输入" value={formatNumber(totals.input)} />
          <UsageMetric label="输出" value={formatNumber(totals.output)} />
          <UsageMetric label="总计" value={formatNumber(totals.total)} />
        </div>

        {stats.length === 0 ? (
          <div className={styles.emptyState}>暂无统计数据。完成一次模型回复后会自动记录。</div>
        ) : (
          <div className={styles.usageTable}>
            <div className={`${styles.usageRow} ${styles.usageHead}`}>
              <span>模型</span>
              <span>请求</span>
              <span>输入</span>
              <span>输出</span>
              <span>总计</span>
            </div>
            {stats.map((item) => (
              <div className={styles.usageRow} key={`${item.provider}:${item.model}`}>
                <div className={styles.usageModel}>
                  <strong>{providerLabel(item.provider)}</strong>
                  <span>{item.model}</span>
                  <small>{formatDate(item.last_used_at)}</small>
                </div>
                <span>{formatNumber(item.requests)}</span>
                <span>{formatNumber(item.input_tokens)}</span>
                <span>{formatNumber(item.output_tokens)}</span>
                <span>{formatNumber(item.total_tokens)}</span>
              </div>
            ))}
          </div>
        )}

        <div className={styles.actionRow}>
          <button className={styles.secondaryBtn} onClick={handleRefresh}>
            刷新
          </button>
          <button className={styles.dangerBtn} onClick={handleClear}>
            清空统计
          </button>
        </div>
      </section>
    </div>
  );
}

function UsageMetric({ label, value }: { label: string; value: string }) {
  return (
    <div className={styles.usageMetric}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function providerLabel(provider: string): string {
  if (isProviderName(provider)) return PROVIDERS[provider].label;
  return provider;
}

function formatNumber(value: number): string {
  return new Intl.NumberFormat("zh-CN").format(value);
}

function formatDate(value: string): string {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "-";
  return date.toLocaleString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}
