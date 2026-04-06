import { useEffect, useState } from "react";
import { PetContainer } from "./components/pet/PetContainer";
import { SettingsWindow } from "./components/settings/SettingsWindow";
import { loadSettings } from "./services/tauriCommands";
import "./styles/globals.css";

export default function App() {
  const [ttsEnabled, setTtsEnabled] = useState(true);
  // 通过 URL hash 区分窗口
  const isSettings = window.location.hash === "#settings";

  useEffect(() => {
    if (isSettings) return;
    // 初始加载 + 定期轮询设置变更（设置窗口是独立窗口，无法直接通信）
    const load = () =>
      loadSettings()
        .then((s) => setTtsEnabled(s.tts_enabled))
        .catch(console.error);
    load();
    const timer = setInterval(load, 3000);
    return () => clearInterval(timer);
  }, [isSettings]);

  if (isSettings) {
    return <SettingsWindow />;
  }

  return <PetContainer ttsEnabled={ttsEnabled} />;
}
