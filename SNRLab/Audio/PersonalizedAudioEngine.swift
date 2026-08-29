import Foundation
import AVFoundation
import Combine

enum DemoMusicGenre: String, CaseIterable, Identifiable {
    case classical
    case pop

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .classical: return language.text("Classical & Acoustic", "Clásica y acústica")
        case .pop: return language.text("Pop & Electronic", "Pop y electrónica")
        }
    }

    var symbol: String {
        self == .classical ? "pianokeys" : "music.note.list"
    }
}

struct DemoTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let filename: String
    let genre: DemoMusicGenre
    let duration: TimeInterval

    var sourceName: String { "FreePD Collection" }
    var licenseName: String { "CC0 / Public Domain" }

    static let catalog: [DemoTrack] = [
        .init(id: "amazing-grace", title: "Amazing Grace", filename: "amazing-grace", genre: .classical, duration: 114.47),
        .init(id: "burts-requiem", title: "Burt's Requiem", filename: "burts-requiem", genre: .classical, duration: 388.55),
        .init(id: "la-citadelle", title: "La Citadelle", filename: "la-citadelle", genre: .classical, duration: 161.93),
        .init(id: "lovely-piano-song", title: "Lovely Piano Song", filename: "lovely-piano-song", genre: .classical, duration: 95.79),
        .init(id: "night-in-venice", title: "Night in Venice", filename: "night-in-venice", genre: .classical, duration: 218.15),
        .init(id: "backbeat", title: "Backbeat", filename: "backbeat", genre: .pop, duration: 46.21),
        .init(id: "beat-one", title: "Beat One", filename: "beat-one", genre: .pop, duration: 180.07),
        .init(id: "city-sunshine", title: "City Sunshine", filename: "city-sunshine", genre: .pop, duration: 185.00),
        .init(id: "funshine", title: "Funshine", filename: "funshine", genre: .pop, duration: 165.07),
        .init(id: "limit-70", title: "Limit 70", filename: "limit-70", genre: .pop, duration: 301.66)
    ]
}

struct StereoCompensationBand: Identifiable, Hashable {
    var id: Double { frequency }
    let frequency: Double
    let leftGainDB: Double
    let rightGainDB: Double

    var frequencyLabel: String {
        frequency >= 1_000
            ? String(format: "%.0fk", frequency / 1_000)
            : String(format: "%.0f", frequency)
    }
}

enum CompensationDesigner {
    static let frequencies = [250.0, 500.0, 1_000.0, 2_000.0, 3_000.0, 4_000.0, 6_000.0, 8_000.0]

    static func bands(
        from test: BilateralPureToneTest?,
        maximumBoostDB: Double
    ) -> [StereoCompensationBand] {
        let safeMaximum = min(20, max(0, maximumBoostDB))
        guard let test,
              test.thresholds(for: .left).count >= 4,
              test.thresholds(for: .right).count >= 4 else {
            return frequencies.map { StereoCompensationBand(frequency: $0, leftGainDB: 0, rightGainDB: 0) }
        }

        let left = gains(for: .left, test: test, maximumBoostDB: safeMaximum)
        let right = gains(for: .right, test: test, maximumBoostDB: safeMaximum)
        return frequencies.indices.map { index in
            StereoCompensationBand(
                frequency: frequencies[index],
                leftGainDB: left[index],
                rightGainDB: right[index]
            )
        }
    }

    private static func gains(
        for ear: HearingEar,
        test: BilateralPureToneTest,
        maximumBoostDB: Double
    ) -> [Double] {
        let measured = test.thresholds(for: ear)
        let levels = measured.map(\.finalRelativeThreshold).sorted()
        guard !levels.isEmpty else { return frequencies.map { _ in 0 } }
        let reference = levels[min(levels.count - 1, max(0, levels.count / 4))]

        let halfGain = frequencies.map { frequency -> Double in
            let closest = measured.min { abs($0.frequency - frequency) < abs($1.frequency - frequency) }
            let threshold = closest?.finalRelativeThreshold ?? reference
            let measuredDeficit = max(0, threshold - reference)
            return min(maximumBoostDB, measuredDeficit * 0.5)
        }

        return halfGain.indices.map { index -> Double in
            var weighted = halfGain[index] * 0.60
            var weight = 0.60
            if index > halfGain.startIndex {
                weighted += halfGain[index - 1] * 0.20
                weight += 0.20
            }
            if index < halfGain.index(before: halfGain.endIndex) {
                weighted += halfGain[index + 1] * 0.20
                weight += 0.20
            }
            return min(maximumBoostDB, max(0, weighted / weight))
        }
    }
}

@MainActor
final class PersonalizedAudioEngine: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isCompensated = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var loadedTrackID: String?
    @Published private(set) var bands: [StereoCompensationBand] = []
    @Published var errorMessage: String?

    private let engine = AVAudioEngine()
    private let leftPlayer = AVAudioPlayerNode()
    private let rightPlayer = AVAudioPlayerNode()
    private let leftEqualizer = AVAudioUnitEQ(numberOfBands: CompensationDesigner.frequencies.count)
    private let rightEqualizer = AVAudioUnitEQ(numberOfBands: CompensationDesigner.frequencies.count)
    private let leftPanner = AVAudioMixerNode()
    private let rightPanner = AVAudioMixerNode()
    private let headroomMixer = AVAudioMixerNode()
    private var leftAudioFile: AVAudioFile?
    private var rightAudioFile: AVAudioFile?
    private var temporaryFileURLs: [URL] = []
    private var scheduledStartFrame: AVAudioFramePosition = 0
    private var sampleRate = 44_100.0

    init() {
        engine.attach(leftPlayer)
        engine.attach(rightPlayer)
        engine.attach(leftEqualizer)
        engine.attach(rightEqualizer)
        engine.attach(leftPanner)
        engine.attach(rightPanner)
        engine.attach(headroomMixer)
    }

    func load(
        track: DemoTrack,
        pureToneTest: BilateralPureToneTest?,
        maximumBoostDB: Double
    ) {
        stop()
        errorMessage = nil

        guard let url = Bundle.main.url(forResource: track.filename, withExtension: "mp3", subdirectory: "DemoMusic")
                ?? Bundle.main.url(forResource: track.filename, withExtension: "mp3")
                ?? Bundle.main.url(forResource: track.filename, withExtension: "m4a", subdirectory: "DemoMusic")
                ?? Bundle.main.url(forResource: track.filename, withExtension: "m4a") else {
            errorMessage = "The bundled audio file could not be found."
            return
        }

        do {
            try AudioSessionManager.shared.configureForPlayback()
            let sourceFile = try AVAudioFile(forReading: url)
            sampleRate = sourceFile.processingFormat.sampleRate
            duration = Double(sourceFile.length) / sampleRate
            currentTime = 0
            let splitURLs = try makeTemporaryMonoFiles(from: url, trackID: track.id)
            let leftFile = try AVAudioFile(forReading: splitURLs.left)
            let rightFile = try AVAudioFile(forReading: splitURLs.right)
            leftAudioFile = leftFile
            rightAudioFile = rightFile
            loadedTrackID = track.id

            engine.stop()
            engine.disconnectNodeOutput(leftPlayer)
            engine.disconnectNodeOutput(rightPlayer)
            engine.disconnectNodeOutput(leftEqualizer)
            engine.disconnectNodeOutput(rightEqualizer)
            engine.disconnectNodeOutput(leftPanner)
            engine.disconnectNodeOutput(rightPanner)
            engine.disconnectNodeOutput(headroomMixer)
            let monoFormat = leftFile.processingFormat
            let stereoFormat = AVAudioFormat(
                standardFormatWithSampleRate: monoFormat.sampleRate,
                channels: 2
            )!
            engine.connect(leftPlayer, to: leftEqualizer, format: monoFormat)
            engine.connect(rightPlayer, to: rightEqualizer, format: monoFormat)
            engine.connect(leftEqualizer, to: leftPanner, format: monoFormat)
            engine.connect(rightEqualizer, to: rightPanner, format: monoFormat)
            engine.connect(leftPanner, to: headroomMixer, fromBus: 0, toBus: 0, format: stereoFormat)
            engine.connect(rightPanner, to: headroomMixer, fromBus: 0, toBus: 1, format: stereoFormat)
            engine.connect(headroomMixer, to: engine.mainMixerNode, format: stereoFormat)
            leftPanner.pan = -1
            rightPanner.pan = 1

            updateCompensation(pureToneTest: pureToneTest, maximumBoostDB: maximumBoostDB)
            try engine.start()
            schedule(from: 0)
        } catch {
            errorMessage = error.localizedDescription
            loadedTrackID = nil
        }
    }

    func updateCompensation(
        pureToneTest: BilateralPureToneTest?,
        maximumBoostDB: Double
    ) {
        bands = CompensationDesigner.bands(from: pureToneTest, maximumBoostDB: maximumBoostDB)

        for (index, result) in bands.enumerated() {
            configure(
                leftEqualizer.bands[index],
                frequency: result.frequency,
                gainDB: result.leftGainDB,
                index: index
            )
            configure(
                rightEqualizer.bands[index],
                frequency: result.frequency,
                gainDB: result.rightGainDB,
                index: index
            )
        }

        let maximumBoost = max(
            0,
            bands.flatMap { [$0.leftGainDB, $0.rightGainDB] }.max() ?? 0
        )
        let headroomDB = -(maximumBoost + 1.0)
        headroomMixer.outputVolume = Float(pow(10, headroomDB / 20))
        leftEqualizer.bypass = !isCompensated
        rightEqualizer.bypass = !isCompensated
    }

    func setCompensated(_ compensated: Bool) {
        isCompensated = compensated
        leftEqualizer.bypass = !compensated
        rightEqualizer.bypass = !compensated
    }

    func togglePlayback() {
        guard leftAudioFile != nil, rightAudioFile != nil else { return }
        if isPlaying {
            refreshTime()
            leftPlayer.pause()
            rightPlayer.pause()
            isPlaying = false
        } else {
            if currentTime >= max(0, duration - 0.1) {
                schedule(from: 0)
                currentTime = 0
            }
            leftPlayer.play()
            rightPlayer.play()
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        guard let file = leftAudioFile else { return }
        let wasPlaying = isPlaying
        leftPlayer.stop()
        rightPlayer.stop()
        let target = min(max(0, time), duration)
        let frame = min(file.length, AVAudioFramePosition(target * sampleRate))
        schedule(from: frame)
        currentTime = target
        if wasPlaying {
            leftPlayer.play()
            rightPlayer.play()
            isPlaying = true
        }
    }

    func refreshTime() {
        guard isPlaying,
              let nodeTime = leftPlayer.lastRenderTime,
              let playerTime = leftPlayer.playerTime(forNodeTime: nodeTime) else { return }
        let frame = scheduledStartFrame + playerTime.sampleTime
        currentTime = min(duration, max(0, Double(frame) / sampleRate))
    }

    func stop() {
        leftPlayer.stop()
        rightPlayer.stop()
        engine.stop()
        isPlaying = false
        currentTime = 0
        scheduledStartFrame = 0
    }

    private func schedule(from frame: AVAudioFramePosition) {
        guard let leftFile = leftAudioFile, let rightFile = rightAudioFile else { return }
        let startFrame = min(max(0, frame), leftFile.length)
        let remainingFrames = max(0, leftFile.length - startFrame)
        scheduledStartFrame = startFrame
        rightPlayer.scheduleSegment(
            rightFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(remainingFrames),
            at: nil,
            completionHandler: nil
        )
        leftPlayer.scheduleSegment(
            leftFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(remainingFrames),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = self.duration
                self.isPlaying = false
            }
        }
    }

    private func configure(
        _ filter: AVAudioUnitEQFilterParameters,
        frequency: Double,
        gainDB: Double,
        index: Int
    ) {
        filter.frequency = Float(frequency)
        filter.gain = Float(gainDB)
        filter.bandwidth = 0.80
        filter.filterType = index == 0
            ? .lowShelf
            : (index == CompensationDesigner.frequencies.count - 1 ? .highShelf : .parametric)
        filter.bypass = abs(gainDB) < 0.05
    }

    private func makeTemporaryMonoFiles(from sourceURL: URL, trackID: String) throws -> (left: URL, right: URL) {
        removeTemporaryFiles()
        let source = try AVAudioFile(forReading: sourceURL)
        let sourceFormat = source.processingFormat
        guard sourceFormat.channelCount > 0,
              let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sourceFormat.sampleRate,
                channels: 1,
                interleaved: false
              ) else {
            throw NSError(domain: "SNRLab", code: 12, userInfo: [NSLocalizedDescriptionKey: "The music format could not be separated into left and right channels."])
        }

        let unique = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory
        let leftURL = directory.appendingPathComponent("snrlab-\(trackID)-\(unique)-left.caf")
        let rightURL = directory.appendingPathComponent("snrlab-\(trackID)-\(unique)-right.caf")
        let leftWriter = try AVAudioFile(forWriting: leftURL, settings: monoFormat.settings)
        let rightWriter = try AVAudioFile(forWriting: rightURL, settings: monoFormat.settings)
        let chunkSize: AVAudioFrameCount = 16_384

        while source.framePosition < source.length {
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: chunkSize) else { break }
            try source.read(into: sourceBuffer, frameCount: chunkSize)
            guard sourceBuffer.frameLength > 0,
                  let sourceChannels = sourceBuffer.floatChannelData,
                  let leftBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: sourceBuffer.frameLength),
                  let rightBuffer = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: sourceBuffer.frameLength),
                  let leftChannel = leftBuffer.floatChannelData?[0],
                  let rightChannel = rightBuffer.floatChannelData?[0] else { break }

            leftBuffer.frameLength = sourceBuffer.frameLength
            rightBuffer.frameLength = sourceBuffer.frameLength
            let frames = Int(sourceBuffer.frameLength)
            let rightSourceIndex = sourceFormat.channelCount > 1 ? 1 : 0
            for frame in 0..<frames {
                leftChannel[frame] = sourceChannels[0][frame]
                rightChannel[frame] = sourceChannels[Int(rightSourceIndex)][frame]
            }
            try leftWriter.write(from: leftBuffer)
            try rightWriter.write(from: rightBuffer)
        }

        temporaryFileURLs = [leftURL, rightURL]
        return (leftURL, rightURL)
    }

    private func removeTemporaryFiles() {
        for url in temporaryFileURLs { try? FileManager.default.removeItem(at: url) }
        temporaryFileURLs = []
    }
}
