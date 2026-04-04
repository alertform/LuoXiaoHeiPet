use tts::Tts;

pub struct TtsService {
    tts: Option<Tts>,
}

impl TtsService {
    pub fn new() -> Self {
        let tts = Tts::default().ok();
        if tts.is_none() {
            eprintln!("[TTS] 系统 TTS 初始化失败，语音功能不可用");
        }
        Self { tts }
    }

    pub fn speak(&mut self, text: &str) {
        let Some(tts) = &mut self.tts else { return };
        let _ = tts.stop();
        // 尝试设置中文语音
        if let Ok(voices) = tts.voices() {
            let zh_voice = voices
                .iter()
                .find(|v| v.language().starts_with("zh") && v.language().contains("CN"))
                .or_else(|| voices.iter().find(|v| v.language().starts_with("zh")));
            if let Some(voice) = zh_voice {
                let _ = tts.set_voice(voice);
            }
        }
        let _ = tts.speak(text, false);
    }

    pub fn stop(&mut self) {
        if let Some(tts) = &mut self.tts {
            let _ = tts.stop();
        }
    }
}

impl Default for TtsService {
    fn default() -> Self {
        Self::new()
    }
}
