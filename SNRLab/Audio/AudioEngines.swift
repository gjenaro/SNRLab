import Foundation
import AVFoundation
import Combine

struct AudioOutputRouteStatus: Equatable {
    let name: String
    let channelCount: Int
    let isAirPods: Bool
    let isBluetooth: Bool

    var isStereo: Bool { channelCount >= 2 }
    var isReadyForBilateralTest: Bool { isAirPods && isStereo }
}

final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private init() {}

    var inputName: String {
        AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName ?? "iPhone microphone"
    }

    func configureForMeasurement() throws {
        let session = AVAudioSession.sharedInstance()
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        try session.setCategory(.playAndRecord, mode: .measurement, options: options)
        try session.setActive(true)
    }

    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
        if session.maximumOutputNumberOfChannels >= 2 {
            try? session.setPreferredOutputNumberOfChannels(2)
        }
    }

    func outputRouteStatus(activatePlayback: Bool = true) throws -> AudioOutputRouteStatus {
        if activatePlayback { try configureForPlayback() }
        let session = AVAudioSession.sharedInstance()
        let output = session.currentRoute.outputs.first
        let name = output?.portName ?? "No audio output"
        let portType = output?.portType
        let isBluetooth = portType == .bluetoothA2DP || portType == .bluetoothLE || portType == .bluetoothHFP
        let isAirPods = isBluetooth && name.lowercased().contains("airpods")
        return AudioOutputRouteStatus(
            name: name,
            channelCount: session.outputNumberOfChannels,
            isAirPods: isAirPods,
            isBluetooth: isBluetooth
        )
    }
}

@MainActor
final class LiveSNREngine: ObservableObject {
    @Published var isRunning = false
    @Published var signalDBFS = -45.0
    @Published var noiseDBFS = -55.0
    @Published var snrDB = 10.0
    @Published var inputName = "Microphone"
    @Published var history: [SNRPoint] = []
    @Published var errorMessage: String?

    private var engine: AVAudioEngine?
    private var recentLevels: [Double] = []
    private var lastPublish = Date.distantPast

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            guard let self else { return }
            Task { @MainActor in
                if granted {
                    do { try self.beginCapture() }
                    catch { self.errorMessage = error.localizedDescription }
                } else {
                    self.errorMessage = "Microphone permission is required for Live SNR."
                }
            }
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        isRunning = false
    }

    private func beginCapture() throws {
        stop()
        try AudioSessionManager.shared.configureForMeasurement()
        inputName = AudioSessionManager.shared.inputName

        let audioEngine = AVAudioEngine()
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            throw NSError(domain: "SNRLab", code: 1, userInfo: [NSLocalizedDescriptionKey: "No usable microphone input was found."])
        }

        recentLevels.removeAll(keepingCapacity: true)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self, let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            let n = Int(buffer.frameLength)
            var sum = 0.0
            for i in 0..<n {
                let x = Double(channel[i])
                sum += x * x
            }
            let rms = sqrt(sum / Double(n))
            let db = 20.0 * log10(max(rms, 1e-8))

            Task { @MainActor in
                self.ingest(levelDBFS: db)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        engine = audioEngine
        isRunning = true
    }

    private func ingest(levelDBFS: Double) {
        recentLevels.append(levelDBFS)
        if recentLevels.count > 120 { recentLevels.removeFirst(recentLevels.count - 120) }
        guard Date().timeIntervalSince(lastPublish) > 0.16, recentLevels.count >= 8 else { return }
        lastPublish = Date()

        let sorted = recentLevels.sorted()
        let low = percentile(sorted, 0.20)
        let high = percentile(sorted, 0.82)
        let estimatedSNR = min(40, max(-10, high - low))

        noiseDBFS = low
        signalDBFS = high
        snrDB = estimatedSNR
        history.append(SNRPoint(time: Date(), value: estimatedSNR))
        if history.count > 180 { history.removeFirst(history.count - 180) }
    }

    private func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return -80 }
        let index = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[min(max(index, 0), sorted.count - 1)]
    }
}

@MainActor
final class StimulusEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var lastError: String?
    @Published var lastResolvedVoiceName: String?

    private var engine: AVAudioEngine?
    private var speechPlayer: AVAudioPlayerNode?
    private var noisePlayer: AVAudioPlayerNode?
    private let synthesizer = AVSpeechSynthesizer()

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        speechPlayer?.stop()
        noisePlayer?.stop()
        engine?.stop()
        engine = nil
        speechPlayer = nil
        noisePlayer = nil
        isPlaying = false
    }

    func playSpeechInNoise(
        _ sentence: String,
        snrDB: Double,
        noise: NoiseKind,
        language: TestLanguage,
        voiceProfile: VoiceProfile
    ) async {
        stop()
        isPlaying = true
        lastError = nil
        do {
            try AudioSessionManager.shared.configureForPlayback()
            let speech = try await synthesize(sentence, language: language, profile: voiceProfile)
            guard let format = speech.first?.format else {
                isPlaying = false
                return
            }
            normalize(speech, toActiveRMS: 0.12)
            let speechRMS = activeRMS(of: speech)
            let totalFrames = speech.reduce(0) { $0 + Int($1.frameLength) }
            let noiseBuffer = makeNoiseBuffer(format: format, frames: totalFrames, kind: noise)
            let rawNoiseRMS = rms(of: [noiseBuffer])
            let targetNoiseRMS = speechRMS / pow(10.0, snrDB / 20.0)
            scale(noiseBuffer, by: rawNoiseRMS > 0 ? targetNoiseRMS / rawNoiseRMS : 0)
            try play(speechBuffers: speech, noiseBuffer: noiseBuffer)
        } catch {
            lastError = error.localizedDescription
            isPlaying = false
        }
    }

    func playCleanSpeech(
        _ sentence: String,
        levelDBFS: Double,
        language: TestLanguage,
        voiceProfile: VoiceProfile
    ) async {
        stop()
        isPlaying = true
        lastError = nil
        do {
            try AudioSessionManager.shared.configureForPlayback()
            let speech = try await synthesize(sentence, language: language, profile: voiceProfile)
            let current = activeRMS(of: speech)
            let target = pow(10.0, levelDBFS / 20.0)
            let gain = current > 0 ? target / current : 1
            scaleWithHeadroom(speech, requestedGain: gain)
            try play(speechBuffers: speech, noiseBuffer: nil)
        } catch {
            lastError = error.localizedDescription
            isPlaying = false
        }
    }

    func playTone(frequency: Double, levelDBFS: Double, duration: Double = 0.75) {
        do {
            stop()
            try AudioSessionManager.shared.configureForPlayback()
            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
            let frames = Int(format.sampleRate * duration)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
            buffer.frameLength = AVAudioFrameCount(frames)
            let amplitude = min(0.45, pow(10.0, levelDBFS / 20.0))
            if let data = buffer.floatChannelData?[0] {
                for i in 0..<frames {
                    let t = Double(i) / format.sampleRate
                    let envelope = min(1.0, min(Double(i) / 800.0, Double(frames - i) / 800.0))
                    data[i] = Float(amplitude * envelope * sin(2.0 * .pi * frequency * t))
                }
            }
            try play(speechBuffers: [buffer], noiseBuffer: nil)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Produces a stereo buffer whose pure-tone samples exist only in the test-ear
    /// channel. The optional opposite channel is reserved for future masking work;
    /// this screening test always passes nil and keeps the non-test ear silent.
    func playPulsedTone(
        frequency: Double,
        levelDBFS: Double,
        ear: HearingEar,
        pulseCount: Int = 3,
        pulseDuration: Double = 0.24,
        gapDuration: Double = 0.14,
        contralateralMaskingDBFS: Double? = nil
    ) {
        do {
            stop()
            try AudioSessionManager.shared.configureForPlayback()
            let route = try AudioSessionManager.shared.outputRouteStatus(activatePlayback: false)
            guard route.isStereo else {
                throw NSError(
                    domain: "SNRLab",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "A two-channel headphone output is required for separate left/right testing."]
                )
            }

            let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
            let totalDuration = Double(pulseCount) * pulseDuration + Double(max(0, pulseCount - 1)) * gapDuration
            let frameCount = Int((format.sampleRate * totalDuration).rounded())
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
            buffer.frameLength = AVAudioFrameCount(frameCount)

            let amplitude = min(0.32, pow(10.0, levelDBFS / 20.0))
            let targetChannel = ear == .left ? 0 : 1
            let oppositeChannel = targetChannel == 0 ? 1 : 0
            let pulseCycle = pulseDuration + gapDuration
            var rng = SystemRandomNumberGenerator()

            if let channels = buffer.floatChannelData {
                for frame in 0..<frameCount {
                    channels[0][frame] = 0
                    channels[1][frame] = 0
                    let time = Double(frame) / format.sampleRate
                    let pulseIndex = Int(time / pulseCycle)
                    let localTime = time - Double(pulseIndex) * pulseCycle
                    if pulseIndex < pulseCount && localTime < pulseDuration {
                        let rampDuration = min(0.025, pulseDuration / 4)
                        let attack = min(1, localTime / rampDuration)
                        let release = min(1, (pulseDuration - localTime) / rampDuration)
                        let envelope = max(0, min(attack, release))
                        channels[targetChannel][frame] = Float(
                            amplitude * envelope * sin(2 * .pi * frequency * time)
                        )
                    }
                    if let maskingLevel = contralateralMaskingDBFS {
                        let maskingAmplitude = min(0.12, pow(10.0, maskingLevel / 20.0))
                        channels[oppositeChannel][frame] = Float(
                            Double.random(in: -1 ... 1, using: &rng) * maskingAmplitude
                        )
                    }
                }
            }
            try play(speechBuffers: [buffer], noiseBuffer: nil)
        } catch {
            lastError = error.localizedDescription
            isPlaying = false
        }
    }

    private func synthesize(
        _ text: String,
        language: TestLanguage,
        profile: VoiceProfile
    ) async throws -> [AVAudioPCMBuffer] {
        try await withCheckedThrowingContinuation { continuation in
            let utterance = AVSpeechUtterance(string: text)
            guard let voice = resolveVoice(language: language, profile: profile) else {
                continuation.resume(throwing: NSError(
                    domain: "SNRLab",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: language.text(
                        "No installed voice is available for this language.",
                        "No hay una voz instalada para este idioma."
                    )]
                ))
                return
            }
            lastResolvedVoiceName = "\(voice.name) · \(voice.language)"
            utterance.voice = voice
            utterance.rate = profile.speechRate
            utterance.pitchMultiplier = profile.pitchMultiplier

            var result: [AVAudioPCMBuffer] = []
            var finished = false
            let lock = NSLock()

            synthesizer.write(utterance) { buffer in
                lock.lock(); defer { lock.unlock() }
                guard !finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    finished = true
                    continuation.resume(returning: result)
                    return
                }
                guard let copy = Self.copyBuffer(pcm) else {
                    finished = true
                    continuation.resume(throwing: NSError(domain: "SNRLab", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported speech audio format."]))
                    return
                }
                result.append(copy)
            }
        }
    }

    private func resolveVoice(language: TestLanguage, profile: VoiceProfile) -> AVSpeechSynthesisVoice? {
        let desiredGender: AVSpeechSynthesisVoiceGender = {
            switch profile {
            case .woman, .girl: return .female
            case .man, .boy: return .male
            }
        }()

        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            !voice.voiceTraits.contains(.isNoveltyVoice) &&
            !voice.voiceTraits.contains(.isPersonalVoice)
        }

        func ranked(_ candidates: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
            candidates.sorted {
                if $0.quality.rawValue != $1.quality.rawValue {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.identifier < $1.identifier
            }
        }

        func chosen(from candidates: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            let sorted = ranked(candidates)
            if profile.prefersAlternateVoice, sorted.count > 1 { return sorted[1] }
            return sorted.first
        }

        let exactGender = voices.filter {
            language.preferredLocaleIdentifiers.contains($0.language) && $0.gender == desiredGender
        }
        if let voice = chosen(from: exactGender) { return voice }

        let baseGender = voices.filter {
            $0.language.lowercased().hasPrefix(language.baseLanguageCode + "-") && $0.gender == desiredGender
        }
        if let voice = chosen(from: baseGender) { return voice }

        let exactLanguage = voices.filter { language.preferredLocaleIdentifiers.contains($0.language) }
        if let voice = chosen(from: exactLanguage) { return voice }

        let baseLanguage = voices.filter {
            $0.language.lowercased().hasPrefix(language.baseLanguageCode + "-")
        }
        return chosen(from: baseLanguage) ?? AVSpeechSynthesisVoice(language: language.localeIdentifier)
    }

    private func play(speechBuffers: [AVAudioPCMBuffer], noiseBuffer: AVAudioPCMBuffer?) throws {
        guard let first = speechBuffers.first else { return }
        let audioEngine = AVAudioEngine()
        let speech = AVAudioPlayerNode()
        audioEngine.attach(speech)
        audioEngine.connect(speech, to: audioEngine.mainMixerNode, format: first.format)

        var noise: AVAudioPlayerNode?
        if let noiseBuffer {
            let n = AVAudioPlayerNode()
            audioEngine.attach(n)
            audioEngine.connect(n, to: audioEngine.mainMixerNode, format: noiseBuffer.format)
            n.scheduleBuffer(noiseBuffer, at: nil, options: [], completionHandler: nil)
            noise = n
        }

        for (index, buffer) in speechBuffers.enumerated() {
            let isLast = index == speechBuffers.count - 1
            speech.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
                if isLast {
                    Task { @MainActor in self?.isPlaying = false }
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        noise?.play()
        speech.play()

        engine = audioEngine
        speechPlayer = speech
        noisePlayer = noise
        isPlaying = true
    }

    private static func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let source = buffer.floatChannelData else { return nil }
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        guard let dest = copy.floatChannelData else { return nil }
        let channels = Int(buffer.format.channelCount)
        let bytes = Int(buffer.frameLength) * MemoryLayout<Float>.size
        for ch in 0..<channels {
            memcpy(dest[ch], source[ch], bytes)
        }
        return copy
    }

    private func rms(of buffers: [AVAudioPCMBuffer]) -> Double {
        var sum = 0.0
        var count = 0
        for buffer in buffers {
            guard let data = buffer.floatChannelData else { continue }
            let channels = Int(buffer.format.channelCount)
            let frames = Int(buffer.frameLength)
            for ch in 0..<channels {
                for i in 0..<frames {
                    let x = Double(data[ch][i])
                    sum += x * x
                    count += 1
                }
            }
        }
        return count > 0 ? sqrt(sum / Double(count)) : 0
    }

    private func activeRMS(of buffers: [AVAudioPCMBuffer]) -> Double {
        var sum = 0.0
        var count = 0
        for buffer in buffers {
            guard let data = buffer.floatChannelData else { continue }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = Double(data[channel][frame])
                    if abs(sample) >= 0.002 {
                        sum += sample * sample
                        count += 1
                    }
                }
            }
        }
        return count > 0 ? sqrt(sum / Double(count)) : rms(of: buffers)
    }

    private func normalize(_ buffers: [AVAudioPCMBuffer], toActiveRMS target: Double) {
        let current = activeRMS(of: buffers)
        guard current > 0 else { return }
        scaleWithHeadroom(buffers, requestedGain: target / current)
    }

    private func scaleWithHeadroom(_ buffers: [AVAudioPCMBuffer], requestedGain: Double) {
        var peak = 0.0
        for buffer in buffers {
            guard let data = buffer.floatChannelData else { continue }
            for channel in 0..<Int(buffer.format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    peak = max(peak, abs(Double(data[channel][frame])))
                }
            }
        }
        let headroomGain = peak > 0 ? 0.90 / peak : requestedGain
        let safeGain = min(requestedGain, headroomGain)
        buffers.forEach { scale($0, by: safeGain) }
    }

    private func scale(_ buffer: AVAudioPCMBuffer, by gain: Double) {
        guard let data = buffer.floatChannelData else { return }
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        for ch in 0..<channels {
            for i in 0..<frames {
                let value = Double(data[ch][i]) * gain
                data[ch][i] = Float(min(0.95, max(-0.95, value)))
            }
        }
    }

    private func makeNoiseBuffer(format: AVAudioFormat, frames: Int, kind: NoiseKind) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        guard let data = buffer.floatChannelData else { return buffer }
        let channels = Int(format.channelCount)
        var previous = 0.0
        var slow = 0.0
        var rng = SystemRandomNumberGenerator()

        for i in 0..<frames {
            let white = Double.random(in: -1...1, using: &rng)
            previous = 0.92 * previous + 0.08 * white
            slow = 0.985 * slow + 0.015 * white
            let t = Double(i) / format.sampleRate
            let sample: Double
            switch kind {
            case .white:
                sample = white
            case .pink:
                sample = 0.65 * previous + 0.35 * white
            case .fan:
                sample = 0.45 * previous + 0.22 * sin(2 * .pi * 120 * t) + 0.10 * sin(2 * .pi * 240 * t)
            case .traffic:
                sample = 0.75 * slow + 0.18 * previous + 0.10 * sin(2 * .pi * 70 * t)
            case .crowd:
                let modulation = 0.55 + 0.45 * abs(sin(2 * .pi * 2.1 * t))
                sample = modulation * (0.55 * previous + 0.45 * white)
            case .restaurant:
                let modulation = 0.65 + 0.35 * abs(sin(2 * .pi * 3.7 * t))
                sample = modulation * (0.45 * previous + 0.55 * white) + 0.06 * sin(2 * .pi * 180 * t)
            }
            for ch in 0..<channels { data[ch][i] = Float(sample * 0.22) }
        }
        return buffer
    }
}
