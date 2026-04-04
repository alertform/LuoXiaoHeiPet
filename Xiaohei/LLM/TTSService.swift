import Foundation
import AVFoundation
import AppKit

/// 语音合成服务 —— 使用 macOS 系统中文语音，可选火山引擎 TTS
/// 自身作为 AVSpeechSynthesizerDelegate / AVAudioPlayerDelegate，
/// 避免独立 delegate 对象被提前释放导致 objc_retain 崩溃
class TTSService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {

    // MARK: - Properties
    private var audioPlayer: AVAudioPlayer?
    private var isSpeaking = false

    /// 延迟创建 AVSpeechSynthesizer，避免 app 启动时过早初始化
    private lazy var speechSynth: AVSpeechSynthesizer = {
        let synth = AVSpeechSynthesizer()
        synth.delegate = self
        return synth
    }()

    /// TTS 配置
    var voiceType: String = "BV051_streaming"  // 火山引擎音色
    var enabled: Bool = true

    /// 火山引擎 TTS 配置（需单独开通，与 LLM API Key 不同）
    var volcanoTTSAppId: String = ""
    var volcanoTTSToken: String = ""

    /// 回调
    var onFinish: (() -> Void)?

    // MARK: - Init
    override init() {
        super.init()
    }

    // MARK: - Public API

    /// 朗读文本
    func speak(_ text: String, apiKey: String) {
        guard enabled, !text.isEmpty else { return }

        // 先停止上一次朗读
        stop()
        isSpeaking = true

        // 如果配置了火山引擎 TTS 的独立凭据，优先使用
        if !volcanoTTSAppId.isEmpty, !volcanoTTSToken.isEmpty {
            speakWithVolcano(text)
        } else {
            // 默认使用系统 TTS（无需额外配置）
            NSLog("[TTS] 使用系统中文语音")
            speakWithSystem(text)
        }
    }

    /// 停止朗读
    func stop() {
        // 先清理 audioPlayer
        audioPlayer?.delegate = nil
        audioPlayer?.stop()
        audioPlayer = nil

        // 再停止语音合成（不要 nil delegate，因为 delegate 就是 self）
        speechSynth.stopSpeaking(at: .immediate)

        isSpeaking = false
    }

    // MARK: - 系统 TTS（AVSpeechSynthesizer）

    private func speakWithSystem(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)

        // 查找最好的中文语音
        let voice = findBestChineseVoice()
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.2  // 稍高音调，更萌
        utterance.volume = 1.0

        NSLog("[TTS] 系统语音: \(voice?.name ?? "默认") [\(voice?.language ?? "?")]")

        speechSynth.speak(utterance)
    }

    /// 查找最合适的中文语音
    private func findBestChineseVoice() -> AVSpeechSynthesisVoice? {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let chineseVoices = allVoices.filter { $0.language.hasPrefix("zh") }

        // 优先选择增强版中文大陆语音
        if let enhanced = chineseVoices.first(where: {
            $0.language == "zh-CN" && $0.quality == .enhanced
        }) {
            return enhanced
        }

        // 查找已知较好的中文语音
        let preferredNames = ["Ting-Ting", "Sinji", "Meijia", "Lili"]
        for name in preferredNames {
            if let voice = chineseVoices.first(where: { $0.name.contains(name) }) {
                return voice
            }
        }

        // 任意中文大陆语音
        if let zhCN = chineseVoices.first(where: { $0.language == "zh-CN" }) {
            return zhCN
        }

        return chineseVoices.first ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        NSLog("[TTS] 系统语音播放完成")
        isSpeaking = false
        onFinish?()
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        NSLog("[TTS] 火山引擎音频播放完成")
        isSpeaking = false
        audioPlayer = nil
        onFinish?()
    }

    // MARK: - 火山引擎 TTS（需单独凭据）

    private func speakWithVolcano(_ text: String) {
        let url = URL(string: "https://openspeech.bytedance.com/api/v1/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer;\(volcanoTTSToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "app": [
                "appid": volcanoTTSAppId,
                "token": "access_token",
                "cluster": "volcano_tts"
            ],
            "user": [
                "uid": "xiaohei_pet"
            ],
            "audio": [
                "voice_type": voiceType,
                "encoding": "mp3",
                "speed_ratio": 1.0,
                "volume_ratio": 1.0
            ],
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "operation": "query"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        NSLog("[TTS] 请求火山引擎语音合成: voice=\(voiceType), text=\(String(text.prefix(30)))...")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error = error {
                NSLog("[TTS] 火山引擎请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.speakWithSystem(text)
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                NSLog("[TTS] HTTP 状态码: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                DispatchQueue.main.async { [weak self] in
                    self?.speakWithSystem(text)
                }
                return
            }

            // 解析响应（base64 音频数据）
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["code"] as? Int {
                    if code == 3000,
                       let audioData = json["data"] as? String,
                       let audioBytes = Data(base64Encoded: audioData) {
                        DispatchQueue.main.async { [weak self] in
                            self?.playAudio(audioBytes)
                        }
                        return
                    } else {
                        let msg = json["message"] as? String ?? "未知错误"
                        NSLog("[TTS] 火山引擎 API 错误 code=\(code): \(msg)")
                    }
                }
            } catch {
                NSLog("[TTS] 解析响应失败: \(error)")
            }

            // 火山引擎失败 → 回退系统 TTS
            DispatchQueue.main.async { [weak self] in
                self?.speakWithSystem(text)
            }
        }.resume()
    }

    // MARK: - Audio Playback

    private func playAudio(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self  // delegate 就是 self，不会被提前释放
            audioPlayer?.play()
            NSLog("[TTS] 开始播放火山引擎音频")
        } catch {
            NSLog("[TTS] 播放失败: \(error), 使用系统 TTS")
            isSpeaking = false
            onFinish?()
        }
    }
}
