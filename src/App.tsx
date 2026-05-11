import { useEffect, useState } from "react";
import { PetContainer } from "./components/pet/PetContainer";
import { SettingsWindow } from "./components/settings/SettingsWindow";
import { loadSettings } from "./services/tauriCommands";
import type { AppSettings } from "./types/config";
import { normalizeAppSettings } from "./types/config";
import "./styles/globals.css";

export default function App() {
  const [settings, setSettings] = useState<AppSettings>({
    tts_enabled: true,
    tts_provider: "system",
    tts_voice_type: "Tingting",
    memory_enabled: true,
    interaction_level: "low",
  });
  // 通过 URL hash 区分窗口
  const isSettings = window.location.hash === "#settings";

  useEffect(() => {
    if (isSettings) return;
    // 初始加载 + 定期轮询设置变更（设置窗口是独立窗口，无法直接通信）
    const load = () =>
      loadSettings()
        .then((s) => setSettings(normalizeAppSettings(s)))
        .catch(console.error);
    load();
    const timer = setInterval(load, 3000);
    return () => clearInterval(timer);
  }, [isSettings]);

  if (isSettings) {
    return <SettingsWindow />;
  }

  return <PetContainer settings={settings} />;
}
