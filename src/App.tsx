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
    if (!isSettings) {
      loadSettings()
        .then((s) => setTtsEnabled(s.tts_enabled))
        .catch(console.error);
    }
  }, [isSettings]);

  if (isSettings) {
    return <SettingsWindow />;
  }

  return <PetContainer ttsEnabled={ttsEnabled} />;
}
