use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
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

    pub fn speak(&mut self, text: &str, provider: &str, voice_type: &str) -> Result<(), String> {
        if provider == "edge" {
            if let Err(err) = self.speak_edge(text, voice_type) {
                eprintln!("[TTS] Edge TTS 失败: {err}");
                return Err(err);
            }
            return Ok(());
        }

        self.speak_system(text, voice_type);
        Ok(())
    }

    fn speak_system(&mut self, text: &str, voice_type: &str) {
        let Some(tts) = &mut self.tts else { return };
        let _ = tts.stop();

        if let Ok(voices) = tts.voices() {
            let preferred = voice_type.trim();
            let zh_voice = if preferred.is_empty() || preferred == "auto" {
                voices
                    .iter()
                    .find(|v| v.name() == "Tingting")
                    .or_else(|| {
                        voices
                            .iter()
                            .find(|v| v.language().starts_with("zh") && v.language().contains("CN"))
                    })
                    .or_else(|| voices.iter().find(|v| v.language().starts_with("zh")))
            } else {
                voices
                    .iter()
                    .find(|v| v.name() == preferred || v.id().contains(preferred))
                    .or_else(|| voices.iter().find(|v| v.language().starts_with("zh")))
            };

            if let Some(voice) = zh_voice {
                let _ = tts.set_voice(voice);
            }
        }

        let normal_rate = tts.normal_rate();
        let rate = (normal_rate * 0.9).max(tts.min_rate()).min(tts.max_rate());
        let _ = tts.set_rate(rate);
        let _ = tts.set_pitch(1.06);
        let _ = tts.set_volume(0.92);

        let _ = tts.speak(text, false);
    }

    fn speak_edge(&mut self, text: &str, voice_type: &str) -> Result<(), String> {
        let voice = if voice_type.trim().is_empty() || voice_type == "auto" {
            "zh-CN-XiaoxiaoNeural"
        } else {
            voice_type
        };
        let media_path = edge_tts_temp_path();

        let output = Command::new(edge_tts_binary())
            .args(["--voice", voice, "--text", text, "--write-media"])
            .arg(&media_path)
            .output()
            .map_err(|e| {
                format!(
                    "无法运行 edge-tts，请先执行 uv tool install edge-tts，或设置 EDGE_TTS_BIN。{e}"
                )
            })?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let _ = fs::remove_file(&media_path);
            return Err(format!("edge-tts 生成失败：{}", stderr.trim()));
        }

        let play_result = play_audio_file(&media_path);
        let _ = fs::remove_file(&media_path);
        play_result
    }

    pub fn stop(&mut self) {
        if let Some(tts) = &mut self.tts {
            let _ = tts.stop();
        }
    }
}

fn edge_tts_temp_path() -> std::path::PathBuf {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or_default();
    std::env::temp_dir().join(format!(
        "luoxiaohei-edge-tts-{}-{millis}.mp3",
        std::process::id()
    ))
}

fn edge_tts_binary() -> PathBuf {
    if let Ok(path) = std::env::var("EDGE_TTS_BIN") {
        let path = PathBuf::from(path);
        if path.exists() {
            return path;
        }
    }

    if let Ok(home) = std::env::var("HOME") {
        let uv_path = PathBuf::from(home).join(".local/bin/edge-tts");
        if uv_path.exists() {
            return uv_path;
        }
    }

    PathBuf::from("edge-tts")
}

fn play_audio_file(path: &Path) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    {
        let status = Command::new("afplay")
            .arg(path)
            .status()
            .map_err(|e| format!("无法播放 Edge TTS 音频：{e}"))?;
        if status.success() {
            Ok(())
        } else {
            Err(format!("afplay 播放失败：{status}"))
        }
    }

    #[cfg(target_os = "linux")]
    {
        for player in ["mpv", "ffplay", "mpg123"] {
            let mut command = Command::new(player);
            if player == "ffplay" {
                command.args(["-nodisp", "-autoexit", "-loglevel", "quiet"]);
            }
            if command
                .arg(path)
                .status()
                .map(|s| s.success())
                .unwrap_or(false)
            {
                return Ok(());
            }
        }
        Err("未找到可播放 mp3 的命令，请安装 mpv、ffplay 或 mpg123。".into())
    }

    #[cfg(target_os = "windows")]
    {
        let status = Command::new("powershell")
            .args([
                "-NoProfile",
                "-Command",
                &format!(
                    "Add-Type -AssemblyName PresentationCore; $p=New-Object System.Windows.Media.MediaPlayer; $p.Open([Uri]'{}'); $p.Play(); Start-Sleep -Milliseconds 500; while($p.NaturalDuration.HasTimeSpan -eq $false){{Start-Sleep -Milliseconds 100}}; Start-Sleep -Milliseconds $p.NaturalDuration.TimeSpan.TotalMilliseconds",
                    path.display()
                ),
            ])
            .status()
            .map_err(|e| format!("无法播放 Edge TTS 音频：{e}"))?;
        if status.success() {
            Ok(())
        } else {
            Err(format!("PowerShell 播放失败：{status}"))
        }
    }
}

impl Default for TtsService {
    fn default() -> Self {
        Self::new()
    }
}
