import Foundation

struct SNRPoint: Identifiable, Codable, Hashable {
    var id = UUID()
    let time: Date
    let value: Double
}

struct RecognitionPoint: Identifiable, Codable, Hashable {
    var id = UUID()
    let snr: Double
    let score: Double
    let noise: NoiseKind
}

struct VolumePoint: Identifiable, Codable, Hashable {
    var id = UUID()
    let levelDBFS: Double
    let score: Double
}

struct FrequencyThreshold: Identifiable, Codable, Hashable {
    var id: Double { frequency }
    let frequency: Double
    let thresholdDBFS: Double

    var frequencyLabel: String {
        switch Int(frequency.rounded()) {
        case 250: return "250"
        case 500: return "500"
        case 1_000: return "1k"
        case 2_000: return "2k"
        case 3_000: return "3k"
        case 4_000: return "4k"
        case 6_000: return "6k"
        case 8_000: return "8k"
        default: return "\(Int(frequency))"
        }
    }

    /// Maps the app's -60 ... -12 dBFS range to a downward 0 ... 90
    /// relative scale. It is deliberately not presented as calibrated dB HL.
    var relativeAudiogramLevel: Double {
        min(90, max(0, (thresholdDBFS + 60) / 48 * 90))
    }
}

enum HearingEar: String, CaseIterable, Codable, Identifiable, Hashable {
    case left
    case right

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .left: return language.text("Left ear", "Oído izquierdo")
        case .right: return language.text("Right ear", "Oído derecho")
        }
    }

    var shortLabel: String { self == .left ? "L" : "R" }
    var colorName: String { self == .left ? "blue" : "red" }
}

enum AudiogramDisplay: String, CaseIterable, Identifiable {
    case left
    case right
    case both

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .left: return language.text("Left", "Izquierdo")
        case .right: return language.text("Right", "Derecho")
        case .both: return language.text("Both", "Ambos")
        }
    }
}

enum PureTonePresentationDirection: String, Codable, Hashable {
    case initial
    case ascending
    case descending
    case unchanged
    case catchTrial
}

struct PureToneTrial: Identifiable, Codable, Hashable {
    let id: UUID
    let frequency: Double
    let ear: HearingEar
    let stimulusLevel: Double?
    let heard: Bool
    let direction: PureTonePresentationDirection
    let responseTime: TimeInterval?
    let isCatchTrial: Bool
    let prematureResponse: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        frequency: Double,
        ear: HearingEar,
        stimulusLevel: Double?,
        heard: Bool,
        direction: PureTonePresentationDirection,
        responseTime: TimeInterval?,
        isCatchTrial: Bool,
        prematureResponse: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.frequency = frequency
        self.ear = ear
        self.stimulusLevel = stimulusLevel
        self.heard = heard
        self.direction = direction
        self.responseTime = responseTime
        self.isCatchTrial = isCatchTrial
        self.prematureResponse = prematureResponse
        self.timestamp = timestamp
    }
}

struct PureToneThresholdResult: Identifiable, Codable, Hashable {
    let id: UUID
    let frequency: Double
    let ear: HearingEar
    let finalRelativeThreshold: Double
    let trials: [PureToneTrial]
    let reversalCount: Int
    let timestamp: Date
    let isOneKilohertzRetest: Bool
    let metAscendingCriterion: Bool

    init(
        id: UUID = UUID(),
        frequency: Double,
        ear: HearingEar,
        finalRelativeThreshold: Double,
        trials: [PureToneTrial],
        reversalCount: Int,
        timestamp: Date = Date(),
        isOneKilohertzRetest: Bool = false,
        metAscendingCriterion: Bool = true
    ) {
        self.id = id
        self.frequency = frequency
        self.ear = ear
        self.finalRelativeThreshold = finalRelativeThreshold
        self.trials = trials
        self.reversalCount = reversalCount
        self.timestamp = timestamp
        self.isOneKilohertzRetest = isOneKilohertzRetest
        self.metAscendingCriterion = metAscendingCriterion
    }

    var presentationCount: Int { trials.filter { !$0.isCatchTrial }.count }

    var frequencyLabel: String {
        switch Int(frequency.rounded()) {
        case 250: return "250"
        case 500: return "500"
        case 1_000: return "1k"
        case 2_000: return "2k"
        case 3_000: return "3k"
        case 4_000: return "4k"
        case 6_000: return "6k"
        case 8_000: return "8k"
        default: return "\(Int(frequency))"
        }
    }
}

struct BilateralPureToneTest: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var date: Date
    var results: [PureToneThresholdResult]
    var ambientNoiseDBFS: Double?
    var outputRouteName: String
    var outputChannelCount: Int
    var airPodsSetupConfirmed: Bool
    var calibrationProfileID: String?
    var transducerModelIdentifier: String?
    var boneConductionResults: [PureToneThresholdResult]?
    var maskingMetadata: String?
    var importedSourceIdentifier: String?
    var priorTestID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        results: [PureToneThresholdResult],
        ambientNoiseDBFS: Double?,
        outputRouteName: String,
        outputChannelCount: Int,
        airPodsSetupConfirmed: Bool,
        calibrationProfileID: String? = nil,
        transducerModelIdentifier: String? = nil,
        boneConductionResults: [PureToneThresholdResult]? = nil,
        maskingMetadata: String? = nil,
        importedSourceIdentifier: String? = nil,
        priorTestID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.results = results
        self.ambientNoiseDBFS = ambientNoiseDBFS
        self.outputRouteName = outputRouteName
        self.outputChannelCount = outputChannelCount
        self.airPodsSetupConfirmed = airPodsSetupConfirmed
        self.calibrationProfileID = calibrationProfileID
        self.transducerModelIdentifier = transducerModelIdentifier
        self.boneConductionResults = boneConductionResults
        self.maskingMetadata = maskingMetadata
        self.importedSourceIdentifier = importedSourceIdentifier
        self.priorTestID = priorTestID
    }

    func thresholds(for ear: HearingEar) -> [PureToneThresholdResult] {
        results
            .filter { $0.ear == ear && !$0.isOneKilohertzRetest }
            .sorted { $0.frequency < $1.frequency }
    }

    func threshold(for ear: HearingEar, frequency: Double) -> PureToneThresholdResult? {
        thresholds(for: ear).first { abs($0.frequency - frequency) < 0.5 }
    }

    func oneKilohertzRepeatDifference(for ear: HearingEar) -> Double? {
        let measurements = results.filter { $0.ear == ear && abs($0.frequency - 1_000) < 0.5 }
        guard let first = measurements.first(where: { !$0.isOneKilohertzRetest }),
              let repeatResult = measurements.first(where: { $0.isOneKilohertzRetest }) else { return nil }
        return abs(first.finalRelativeThreshold - repeatResult.finalRelativeThreshold)
    }

    var averageOneKilohertzRepeatDifference: Double? {
        let values = HearingEar.allCases.compactMap { oneKilohertzRepeatDifference(for: $0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var allTrials: [PureToneTrial] { results.flatMap(\.trials) }
    var catchTrialCount: Int { allTrials.filter(\.isCatchTrial).count }
    var falsePositiveCount: Int { allTrials.filter { $0.isCatchTrial && $0.heard }.count }
    var prematureResponseCount: Int { allTrials.filter(\.prematureResponse).count }
    var falsePositiveRate: Double {
        guard catchTrialCount > 0 else { return 0 }
        return Double(falsePositiveCount) / Double(catchTrialCount)
    }
    var presentationCount: Int { allTrials.count }
    var averagePresentationsPerThreshold: Double {
        guard !results.isEmpty else { return 0 }
        return Double(results.reduce(0) { $0 + $1.presentationCount }) / Double(results.count)
    }

    var reliabilityScore: Double {
        var score = 100.0
        score -= min(45, falsePositiveRate * 100)
        score -= min(20, Double(prematureResponseCount) * 4)
        if let difference = averageOneKilohertzRepeatDifference {
            score -= min(25, max(0, difference - 5) * 2.5)
        }
        score -= min(20, Double(results.filter { !$0.metAscendingCriterion }.count) * 5)
        if let ambientNoiseDBFS, ambientNoiseDBFS > -42 { score -= 10 }
        return min(100, max(0, score))
    }

    var hasReducedReliability: Bool {
        reliabilityScore < 75 ||
        falsePositiveRate > 0.20 ||
        prematureResponseCount >= 3 ||
        HearingEar.allCases.contains { (oneKilohertzRepeatDifference(for: $0) ?? 0) > 5 } ||
        results.contains { !$0.metAscendingCriterion }
    }
}

struct PureToneStaircase {
    let frequency: Double
    let ear: HearingEar
    let isOneKilohertzRetest: Bool
    private(set) var currentLevel: Double
    private(set) var trials: [PureToneTrial] = []
    private(set) var reversalCount = 0
    private(set) var completedResult: PureToneThresholdResult?

    private var lastPresentedLevel: Double?
    private var lastMovementDirection: PureTonePresentationDirection?
    private let minimumLevel = 0.0
    private let maximumLevel = 80.0
    private let maximumPresentations = 16

    init(
        frequency: Double,
        ear: HearingEar,
        isOneKilohertzRetest: Bool,
        startingLevel: Double
    ) {
        self.frequency = frequency
        self.ear = ear
        self.isOneKilohertzRetest = isOneKilohertzRetest
        currentLevel = min(80, max(0, (startingLevel / 5).rounded() * 5))
    }

    var presentationDirection: PureTonePresentationDirection {
        guard let lastPresentedLevel else { return .initial }
        if currentLevel > lastPresentedLevel { return .ascending }
        if currentLevel < lastPresentedLevel { return .descending }
        return .unchanged
    }

    mutating func recordCatch(heard: Bool, responseTime: TimeInterval?) {
        trials.append(PureToneTrial(
            frequency: frequency,
            ear: ear,
            stimulusLevel: nil,
            heard: heard,
            direction: .catchTrial,
            responseTime: responseTime,
            isCatchTrial: true
        ))
    }

    mutating func recordPrematureTap(responseTime: TimeInterval?) {
        trials.append(PureToneTrial(
            frequency: frequency,
            ear: ear,
            stimulusLevel: nil,
            heard: true,
            direction: presentationDirection,
            responseTime: responseTime,
            isCatchTrial: false,
            prematureResponse: true
        ))
    }

    @discardableResult
    mutating func recordPresentation(heard: Bool, responseTime: TimeInterval?) -> PureToneThresholdResult? {
        guard completedResult == nil else { return completedResult }
        let direction = presentationDirection

        if (direction == .ascending || direction == .descending),
           let previous = lastMovementDirection,
           (previous == .ascending || previous == .descending),
           previous != direction {
            reversalCount += 1
        }
        if direction == .ascending || direction == .descending {
            lastMovementDirection = direction
        }

        trials.append(PureToneTrial(
            frequency: frequency,
            ear: ear,
            stimulusLevel: currentLevel,
            heard: heard,
            direction: direction,
            responseTime: responseTime,
            isCatchTrial: false
        ))
        lastPresentedLevel = currentLevel

        if let threshold = qualifyingThreshold() {
            let result = makeResult(threshold: threshold, metCriterion: true)
            completedResult = result
            return result
        }

        let realPresentationCount = trials.filter { !$0.isCatchTrial && !$0.prematureResponse }.count
        if realPresentationCount >= maximumPresentations {
            let fallback = bestAvailableThreshold()
            let result = makeResult(threshold: fallback, metCriterion: false)
            completedResult = result
            return result
        }

        currentLevel = heard
            ? max(minimumLevel, currentLevel - 10)
            : min(maximumLevel, currentLevel + 5)
        return nil
    }

    private func qualifyingThreshold() -> Double? {
        let realTrials = trials.filter { !$0.isCatchTrial && !$0.prematureResponse }
        let ascendingLevels = Set(realTrials.compactMap { trial -> Double? in
            guard trial.direction == .ascending, let level = trial.stimulusLevel else { return nil }
            return level
        })

        let qualifying = ascendingLevels.filter { level in
            let atLevel = realTrials.filter {
                $0.direction == .ascending && $0.stimulusLevel == level
            }
            let heardCount = atLevel.filter(\.heard).count
            return heardCount >= 2 && Double(heardCount) / Double(atLevel.count) >= 0.5
        }

        if let lowest = qualifying.min() { return lowest }

        let floorTrials = realTrials.filter { $0.stimulusLevel == minimumLevel }
        if floorTrials.count >= 2 && floorTrials.filter(\.heard).count >= 2 {
            return minimumLevel
        }
        return nil
    }

    private func bestAvailableThreshold() -> Double {
        let realTrials = trials.filter { !$0.isCatchTrial && !$0.prematureResponse }
        let levels = Set(realTrials.compactMap(\.stimulusLevel)).sorted()
        for level in levels {
            let ascending = realTrials.filter {
                ($0.direction == .ascending || $0.direction == .initial) && $0.stimulusLevel == level
            }
            guard !ascending.isEmpty else { continue }
            if Double(ascending.filter(\.heard).count) / Double(ascending.count) >= 0.5 {
                return level
            }
        }
        return currentLevel
    }

    private func makeResult(threshold: Double, metCriterion: Bool) -> PureToneThresholdResult {
        PureToneThresholdResult(
            frequency: frequency,
            ear: ear,
            finalRelativeThreshold: threshold,
            trials: trials,
            reversalCount: reversalCount,
            isOneKilohertzRetest: isOneKilohertzRetest,
            metAscendingCriterion: metCriterion
        )
    }
}

enum TestLanguage: String, CaseIterable, Codable, Identifiable {
    case english
    case spanish

    var id: String { rawValue }
    var optionLabel: String { self == .english ? "English" : "Español" }
    var shortLabel: String { self == .english ? "EN" : "ES" }
    var localeIdentifier: String { self == .english ? "en-US" : "es-MX" }
    var baseLanguageCode: String { self == .english ? "en" : "es" }
    var preferredLocaleIdentifiers: [String] {
        self == .english ? ["en-US", "en-GB"] : ["es-MX", "es-US", "es-ES"]
    }

    func text(_ english: String, _ spanish: String) -> String {
        self == .english ? english : spanish
    }

    var previewSentence: String {
        text("The garden is quiet this morning.", "El jardín está tranquilo esta mañana.")
    }
}

enum VoiceProfile: String, CaseIterable, Codable, Identifiable {
    case woman
    case man
    case girl
    case boy

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .woman: return language.text("Woman", "Mujer")
        case .man: return language.text("Man", "Hombre")
        case .girl: return language.text("Girl", "Niña")
        case .boy: return language.text("Boy", "Niño")
        }
    }

    var symbol: String {
        switch self {
        case .woman, .man: return "person.fill"
        case .girl, .boy: return "figure.child"
        }
    }

    var pitchMultiplier: Float {
        switch self {
        case .woman, .man: return 1.0
        case .girl: return 1.18
        case .boy: return 1.13
        }
    }

    var speechRate: Float { 0.48 }
    var prefersAlternateVoice: Bool { self == .girl || self == .boy }
}

enum TestKind: String, CaseIterable, Codable, Identifiable {
    case speechInNoise
    case volume
    case frequency
    case noiseProfile

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .speechInNoise: return language.text("Speech in Noise", "Habla con ruido")
        case .volume: return language.text("Volume Sensitivity", "Sensibilidad al volumen")
        case .frequency: return language.text("Pure-tone Hearing Profile", "Perfil auditivo de tonos puros")
        case .noiseProfile: return language.text("Noise Profile", "Perfil de ruido")
        }
    }

    var symbol: String {
        switch self {
        case .speechInNoise: return "ear.badge.waveform"
        case .volume: return "speaker.wave.3.fill"
        case .frequency: return "waveform.path.ecg"
        case .noiseProfile: return "person.3.sequence.fill"
        }
    }
}

enum NoiseKind: String, CaseIterable, Codable, Identifiable {
    case white = "White noise"
    case pink = "Pink noise"
    case fan = "Fan / HVAC"
    case traffic = "Traffic"
    case crowd = "Crowd"
    case restaurant = "Restaurant"

    var id: String { rawValue }

    func displayName(in language: TestLanguage) -> String {
        switch self {
        case .white: return language.text("White noise", "Ruido blanco")
        case .pink: return language.text("Pink noise", "Ruido rosa")
        case .fan: return language.text("Fan / HVAC", "Ventilador / aire")
        case .traffic: return language.text("Traffic", "Tráfico")
        case .crowd: return language.text("Crowd", "Multitud")
        case .restaurant: return language.text("Restaurant", "Restaurante")
        }
    }

    var symbol: String {
        switch self {
        case .white: return "waveform"
        case .pink: return "waveform.path"
        case .fan: return "fan.fill"
        case .traffic: return "car.fill"
        case .crowd: return "person.3.fill"
        case .restaurant: return "fork.knife"
        }
    }
}

struct HearingProfile: Codable, Hashable {
    var snr50: Double = 0
    var snr80: Double = 3
    var snr90: Double = 5.5
    var logisticSlope: Double = 2.5
    var speechTestPoints: [RecognitionPoint] = []
    var volumePoints: [VolumePoint] = []
    var frequencyThresholds: [FrequencyThreshold] = []
    var latestPureToneTest: BilateralPureToneTest? = nil
    var noiseThresholds: [String: Double] = [:]
    var lastUpdated: Date? = nil

    func predictedUnderstanding(snr: Double) -> Double {
        let k = max(0.4, logisticSlope)
        return 100.0 / (1.0 + exp(-(snr - snr50) / k))
    }
}

struct TestRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let date: Date
    let kind: TestKind
    let language: TestLanguage
    let voiceProfile: VoiceProfile?
    let resolvedVoiceName: String?
    let snr50: Double?
    let snr80: Double?
    let snr90: Double?
    let speechPoints: [RecognitionPoint]
    let volumePoints: [VolumePoint]
    let frequencyThresholds: [FrequencyThreshold]
    let pureToneTest: BilateralPureToneTest?
    let noiseKind: NoiseKind?
    let noiseThreshold: Double?

    init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        kind: TestKind,
        language: TestLanguage,
        voiceProfile: VoiceProfile? = nil,
        resolvedVoiceName: String? = nil,
        snr50: Double? = nil,
        snr80: Double? = nil,
        snr90: Double? = nil,
        speechPoints: [RecognitionPoint] = [],
        volumePoints: [VolumePoint] = [],
        frequencyThresholds: [FrequencyThreshold] = [],
        pureToneTest: BilateralPureToneTest? = nil,
        noiseKind: NoiseKind? = nil,
        noiseThreshold: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.kind = kind
        self.language = language
        self.voiceProfile = voiceProfile
        self.resolvedVoiceName = resolvedVoiceName
        self.snr50 = snr50
        self.snr80 = snr80
        self.snr90 = snr90
        self.speechPoints = speechPoints
        self.volumePoints = volumePoints
        self.frequencyThresholds = frequencyThresholds
        self.pureToneTest = pureToneTest
        self.noiseKind = noiseKind
        self.noiseThreshold = noiseThreshold
    }
}

struct TestSentence: Identifiable, Hashable {
    let id = UUID()
    let text: String

    static func bank(for language: TestLanguage) -> [TestSentence] {
        language == .english ? englishBank : spanishBank
    }

    static let englishBank: [TestSentence] = [
        .init(text: "The blue car stopped beside the old house."),
        .init(text: "The chef recommended the special tonight."),
        .init(text: "A small dog waited near the garden gate."),
        .init(text: "She placed the warm cup on the wooden table."),
        .init(text: "The train arrived just before the heavy rain."),
        .init(text: "We ordered fresh bread and tomato soup."),
        .init(text: "The meeting starts after lunch on Tuesday."),
        .init(text: "He carried the boxes into the quiet room."),
        .init(text: "The children watched birds near the lake."),
        .init(text: "Please leave the red folder by the computer."),
        .init(text: "The museum closes early during the winter."),
        .init(text: "Our neighbor planted flowers along the fence."),
        .init(text: "The doctor called back before the afternoon."),
        .init(text: "They found a better route through the city."),
        .init(text: "The coffee shop was crowded after the concert."),
        .init(text: "A bright lamp stood beside the reading chair."),
        .init(text: "The package should arrive before the weekend."),
        .init(text: "We heard music coming from the next room."),
        .init(text: "The teacher wrote three words on the board."),
        .init(text: "He bought apples and cheese at the market.")
    ]

    static let spanishBank: [TestSentence] = [
        .init(text: "El coche azul paró junto a la casa vieja."),
        .init(text: "El chef recomendó el plato especial de esta noche."),
        .init(text: "Un perro pequeño esperó cerca de la puerta del jardín."),
        .init(text: "Ella puso la taza caliente sobre la mesa de madera."),
        .init(text: "El tren llegó justo antes de la lluvia fuerte."),
        .init(text: "Pedimos pan fresco y sopa de tomate."),
        .init(text: "La reunión empieza después del almuerzo el martes."),
        .init(text: "Él llevó las cajas al cuarto tranquilo."),
        .init(text: "Los niños miraron las aves cerca del lago."),
        .init(text: "Por favor deja la carpeta roja junto a la computadora."),
        .init(text: "El museo cierra temprano durante el invierno."),
        .init(text: "Nuestro vecino plantó flores junto a la cerca."),
        .init(text: "La doctora llamó antes de la tarde."),
        .init(text: "Encontraron una ruta mejor por la ciudad."),
        .init(text: "La cafetería estaba llena después del concierto."),
        .init(text: "Una lámpara brillante estaba junto a la silla de lectura."),
        .init(text: "El paquete debe llegar antes del fin de semana."),
        .init(text: "Escuchamos música desde el cuarto de al lado."),
        .init(text: "La maestra escribió tres palabras en la pizarra."),
        .init(text: "Él compró manzanas y queso en el mercado.")
    ]
}

enum WordScorer {
    static func score(reference: String, response: String) -> Double {
        let referenceWords = tokens(reference)
        let answerWords = tokens(response)
        guard !referenceWords.isEmpty else { return 0 }

        var remaining = answerWords
        var hits = 0
        for word in referenceWords {
            if let index = remaining.firstIndex(of: word) {
                hits += 1
                remaining.remove(at: index)
            }
        }
        return Double(hits) / Double(referenceWords.count)
    }

    private static func tokens(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

enum PsychometricEstimator {
    static func fit(_ points: [RecognitionPoint]) -> (snr50: Double, slope: Double, snr80: Double, snr90: Double) {
        guard points.count >= 4 else { return (0, 2.5, 3.5, 5.5) }

        var bestTheta = 0.0
        var bestK = 2.5
        var bestError = Double.greatestFiniteMagnitude

        for thetaStep in -40...80 {
            let theta = Double(thetaStep) * 0.25
            for kStep in 2...40 {
                let k = Double(kStep) * 0.25
                var error = 0.0
                for point in points {
                    let prediction = 1.0 / (1.0 + exp(-(point.snr - theta) / k))
                    let difference = prediction - point.score
                    error += difference * difference
                }
                if error < bestError {
                    bestError = error
                    bestTheta = theta
                    bestK = k
                }
            }
        }

        func snr(for probability: Double) -> Double {
            bestTheta + bestK * log(probability / (1.0 - probability))
        }
        return (bestTheta, bestK, snr(for: 0.8), snr(for: 0.9))
    }

    static func bootstrapConfidenceIntervals(
        _ points: [RecognitionPoint],
        iterations: Int = 120
    ) -> SpeechConfidenceIntervals? {
        guard points.count >= 12 else { return nil }
        var generator = SeededGenerator(seed: UInt64(points.count) &* 1_103 &+ 17)
        var snr50Values: [Double] = []
        var snr80Values: [Double] = []
        var snr90Values: [Double] = []
        snr50Values.reserveCapacity(iterations)
        snr80Values.reserveCapacity(iterations)
        snr90Values.reserveCapacity(iterations)

        for _ in 0..<iterations {
            let sample = (0..<points.count).map { _ in
                points[Int.random(in: 0..<points.count, using: &generator)]
            }
            let estimate = fit(sample)
            snr50Values.append(estimate.snr50)
            snr80Values.append(estimate.snr80)
            snr90Values.append(estimate.snr90)
        }

        return SpeechConfidenceIntervals(
            snr50: confidenceRange(snr50Values),
            snr80: confidenceRange(snr80Values),
            snr90: confidenceRange(snr90Values)
        )
    }

    private static func confidenceRange(_ values: [Double]) -> ConfidenceRange {
        let sorted = values.sorted()
        let lowerIndex = Int((Double(sorted.count - 1) * 0.025).rounded())
        let upperIndex = Int((Double(sorted.count - 1) * 0.975).rounded())
        return ConfidenceRange(lower: sorted[lowerIndex], upper: sorted[upperIndex])
    }
}

struct ConfidenceRange: Hashable {
    let lower: Double
    let upper: Double
}

struct SpeechConfidenceIntervals: Hashable {
    let snr50: ConfidenceRange
    let snr80: ConfidenceRange
    let snr90: ConfidenceRange
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
