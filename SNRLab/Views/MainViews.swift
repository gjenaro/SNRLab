import SwiftUI
import Charts

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { LiveView() }
                .tabItem { Label("Live", systemImage: "waveform") }
            NavigationStack { TestHubView() }
                .tabItem { Label("Test", systemImage: "ear") }
            NavigationStack { ResultsView() }
                .tabItem { Label("Results", systemImage: "chart.bar.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
    }
}

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock("SNR Lab", subtitle: "Understand your listening environment and your personal speech-in-noise needs.")

                NavigationLink(destination: LiveView()) {
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.green.opacity(0.13)).frame(width: 58, height: 58)
                                Image(systemName: "waveform").font(.title).foregroundStyle(.green)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Live Measure").font(.title3.bold())
                                Text("Estimate speech-to-noise ratio in real time.").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)

                NavigationLink(destination: TestHubView()) {
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.purple.opacity(0.13)).frame(width: 58, height: 58)
                                Image(systemName: "ear").font(.title).foregroundStyle(.purple)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Hearing Performance Tests").font(.title3.bold())
                                Text("Speech-in-noise, bilateral pure-tone, volume, and noise-profile tests.").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)

                NavigationLink(destination: PersonalizedAudioView()) {
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.cyan.opacity(0.13)).frame(width: 58, height: 58)
                                Image(systemName: "wand.and.stars").font(.title).foregroundStyle(.cyan)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.selectedLanguage.text("Personalized Audio", "Audio personalizado")).font(.title3.bold())
                                Text(model.selectedLanguage.text(
                                    "Compare 10 songs in Original and Compensated modes.",
                                    "Compara 10 pistas en modo Original y Compensado."
                                ))
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Your listening profile").font(.headline)
                        HStack(spacing: 10) {
                            MetricPill(title: "SNR50", value: signed(model.profile.snr50) + " dB", color: .blue)
                            MetricPill(title: "SNR90", value: signed(model.profile.snr90) + " dB", color: .green)
                        }
                        Text("SNR90 is the estimated speech-to-noise ratio where you recognize about 90% of the test material.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                GlassCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "cross.case").foregroundStyle(.orange)
                        Text("This app is a personal listening-performance tool, not a diagnostic hearing test. Absolute SPL or dB HL values require calibrated hardware and validated procedures.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationBarHidden(true)
        .background(Color.black)
    }
}

struct LiveView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var engine = LiveSNREngine()

    private var predicted: Double { model.profile.predictedUnderstanding(snr: engine.snrDB) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock("Live", subtitle: engine.isRunning ? "Measuring with \(engine.inputName)" : "Estimate the current acoustic speech-to-noise ratio.")

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SPEECH-TO-NOISE RATIO").font(.caption.bold()).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(signed(engine.snrDB)).font(.system(size: 58, weight: .bold, design: .rounded)).foregroundStyle(.green)
                            Text("dB").font(.title2.bold()).foregroundStyle(.green)
                        }
                        Text("Predicted understanding: \(Int(predicted.rounded()))%")
                            .font(.headline)
                        Text("Prediction uses your saved speech-in-noise curve. Live SNR is an adaptive estimate, not a calibrated sound-level-meter measurement.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    SmallMetric(title: "Speech", value: String(format: "%.1f", engine.signalDBFS), unit: "dBFS", color: .blue)
                    SmallMetric(title: "Noise", value: String(format: "%.1f", engine.noiseDBFS), unit: "dBFS", color: .purple)
                    SmallMetric(title: "Understand", value: "\(Int(predicted.rounded()))", unit: "%", color: .green)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SNR over time").font(.headline)
                        if engine.history.isEmpty {
                            ContentUnavailableView("No live samples yet", systemImage: "waveform", description: Text("Start measuring to populate the chart."))
                                .frame(height: 210)
                        } else {
                            Chart(engine.history) { point in
                                LineMark(x: .value("Time", point.time), y: .value("SNR", point.value))
                                    .foregroundStyle(.green)
                                    .interpolationMethod(.catmullRom)
                                AreaMark(x: .value("Time", point.time), y: .value("SNR", point.value))
                                    .foregroundStyle(.green.opacity(0.12))
                            }
                            .chartYScale(domain: -10...30)
                            .frame(height: 220)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Compared with your profile").font(.headline)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Your SNR90").foregroundStyle(.secondary)
                                Text(signed(model.profile.snr90) + " dB").font(.title2.bold()).foregroundStyle(.blue)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Current").foregroundStyle(.secondary)
                                Text(signed(engine.snrDB) + " dB").font(.title2.bold()).foregroundStyle(.green)
                            }
                        }
                        let margin = engine.snrDB - model.profile.snr90
                        Text(margin >= 0 ? "Current conditions are about \(String(format: "%.1f", margin)) dB above your 90% threshold." : "You are about \(String(format: "%.1f", abs(margin))) dB below your 90% threshold.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error = engine.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }

                Button {
                    engine.isRunning ? engine.stop() : engine.start()
                } label: {
                    Label(engine.isRunning ? "Stop measuring" : "Start measuring", systemImage: engine.isRunning ? "stop.fill" : "mic.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 14).font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.isRunning ? .red : .blue)
            }
            .padding()
        }
        .background(Color.black)
        .onDisappear { engine.stop() }
    }
}

struct ResultsView: View {
    @EnvironmentObject var model: AppModel
    @State private var audiogramDisplay: AudiogramDisplay = .both

    private var language: TestLanguage { model.selectedLanguage }
    private var pureToneTest: BilateralPureToneTest? { model.profile.latestPureToneTest }
    private var speechConfidence: SpeechConfidenceIntervals? {
        PsychometricEstimator.bootstrapConfidenceIntervals(model.profile.speechTestPoints)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    language.text("Results", "Resultados"),
                    subtitle: language.text(
                        "Your latest profile and all saved tests.",
                        "Tu perfil más reciente y todas las pruebas guardadas."
                    )
                )

                sectionTitle(language.text("1. Pure-tone hearing profile", "1. Perfil auditivo de tonos puros"))

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        if let pureToneTest {
                            Picker(language.text("Display", "Mostrar"), selection: $audiogramDisplay) {
                                ForEach(AudiogramDisplay.allCases) { option in
                                    Text(option.displayName(in: language)).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)

                            BilateralAudiogramChart(test: pureToneTest, display: audiogramDisplay)
                            PureToneThresholdSummary(test: pureToneTest, language: language)

                            Label(
                                pureToneTest.hasReducedReliability
                                    ? language.text("Reduced test reliability", "Fiabilidad reducida")
                                    : language.text("Reliability checks passed", "Controles de fiabilidad superados"),
                                systemImage: pureToneTest.hasReducedReliability ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                            )
                            .font(.subheadline.bold())
                            .foregroundStyle(pureToneTest.hasReducedReliability ? .orange : .green)
                        } else {
                            ContentUnavailableView(
                                language.text("Run the bilateral pure-tone test", "Haz la prueba bilateral de tonos puros"),
                                systemImage: "ear.badge.waveform",
                                description: Text(language.text(
                                    "Separate left and right thresholds will appear here.",
                                    "Aquí aparecerán los umbrales separados de cada oído."
                                ))
                            )
                            .frame(minHeight: 220)
                            if !model.profile.frequencyThresholds.isEmpty {
                                Text(language.text(
                                    "A legacy single-curve result is saved, but it is not displayed as a bilateral audiogram. Run the updated test to create separate ear profiles.",
                                    "Hay un resultado antiguo de una sola curva, pero no se muestra como audiograma bilateral. Haz la prueba actualizada para crear perfiles separados."
                                ))
                                .font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Text(language.text(
                    "Relative hearing threshold — not dB HL. Large left/right differences are highlighted for attention only and do not diagnose a cause.",
                    "Umbral auditivo relativo — no es dB HL. Las diferencias grandes entre oídos se resaltan solo para llamar la atención y no diagnostican una causa."
                ))
                .font(.footnote).foregroundStyle(.secondary)

                sectionTitle(language.text("2. Speech in noise", "2. Habla con ruido"))

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.text("Psychometric sigmoid and trial points", "Curva psicométrica y puntos de ensayo")).font(.headline)
                        if model.profile.speechTestPoints.isEmpty {
                            ContentUnavailableView(
                                language.text("Run a speech-in-noise test", "Haz una prueba de habla con ruido"),
                                systemImage: "ear.badge.waveform",
                                description: Text(language.text("Your response curve will appear here.", "Tu curva de respuesta aparecerá aquí."))
                            )
                                .frame(height: 260)
                        } else {
                            Chart {
                                ForEach(stride(from: -10.0, through: 16.0, by: 0.5).map { $0 }, id: \.self) { x in
                                    LineMark(x: .value("SNR", x), y: .value("Understanding", model.profile.predictedUnderstanding(snr: x)))
                                        .foregroundStyle(.green)
                                        .interpolationMethod(.catmullRom)
                                }
                                ForEach(model.profile.speechTestPoints) { p in
                                    PointMark(x: .value("SNR", p.snr), y: .value("Score", p.score * 100))
                                        .foregroundStyle(.blue)
                                }
                            }
                            .chartXScale(domain: -10...16)
                            .chartYScale(domain: 0...100)
                            .frame(height: 280)
                        }
                    }
                }

                HStack(spacing: 10) {
                    SmallMetric(title: "SNR50", value: signed(model.profile.snr50), unit: "dB", color: .blue)
                    SmallMetric(title: "SNR80", value: signed(model.profile.snr80), unit: "dB", color: .cyan)
                    SmallMetric(title: "SNR90", value: signed(model.profile.snr90), unit: "dB", color: .green)
                }

                if let speechConfidence {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(language.text("Bootstrap 95% confidence intervals", "Intervalos de confianza bootstrap del 95%"))
                                .font(.headline)
                            confidenceRow("SNR50", range: speechConfidence.snr50)
                            confidenceRow("SNR80", range: speechConfidence.snr80)
                            confidenceRow("SNR90", range: speechConfidence.snr90)
                        }
                    }
                } else if !model.profile.speechTestPoints.isEmpty {
                    Text(language.text(
                        "Confidence intervals appear after at least 12 speech-in-noise trials.",
                        "Los intervalos de confianza aparecen después de al menos 12 ensayos de habla con ruido."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }

                sectionTitle(language.text("3. Test quality", "3. Calidad de la prueba"))

                GlassCard {
                    if let pureToneTest {
                        VStack(alignment: .leading, spacing: 11) {
                            qualityRow(
                                language.text("Ambient-noise quality", "Calidad del ruido ambiental"),
                                value: ambientQualityText(pureToneTest)
                            )
                            qualityRow(
                                language.text("False-positive rate", "Tasa de falsos positivos"),
                                value: "\(Int((pureToneTest.falsePositiveRate * 100).rounded()))% (\(pureToneTest.falsePositiveCount)/\(pureToneTest.catchTrialCount))"
                            )
                            qualityRow(
                                language.text("1-kHz repeatability", "Repetibilidad a 1 kHz"),
                                value: pureToneTest.averageOneKilohertzRepeatDifference.map { String(format: "%.1f relative units", $0) } ?? "—"
                            )
                            qualityRow(
                                language.text("Pure-tone presentations", "Presentaciones de tonos puros"),
                                value: "\(pureToneTest.presentationCount) · \(String(format: "%.1f", pureToneTest.averagePresentationsPerThreshold))/threshold"
                            )
                            qualityRow(
                                language.text("Speech-in-noise trials", "Ensayos de habla con ruido"),
                                value: "\(model.profile.speechTestPoints.count)"
                            )
                            Divider()
                            HStack {
                                Text(language.text("Overall confidence score", "Puntuación general de confianza")).font(.headline)
                                Spacer()
                                Text("\(Int(pureToneTest.reliabilityScore.rounded()))%")
                                    .font(.title2.bold())
                                    .foregroundStyle(pureToneTest.hasReducedReliability ? .orange : .green)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            language.text("No bilateral quality data", "No hay datos bilaterales de calidad"),
                            systemImage: "checkmark.shield"
                        )
                        .frame(minHeight: 150)
                    }
                }

                NavigationLink(destination: PersonalizedAudioView()) {
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "wand.and.stars")
                                .font(.title2).foregroundStyle(.cyan)
                                .frame(width: 46, height: 46)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.cyan.opacity(0.13)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(language.text("Apply these results to music", "Aplicar estos resultados a la música"))
                                    .font(.headline)
                                Text(language.text(
                                    "Hear the same track with and without compensation.",
                                    "Escucha la misma pista con y sin compensación."
                                ))
                                .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if !model.profile.noiseThresholds.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language.text("Noise profiles", "Perfiles de ruido")).font(.headline)
                            ForEach(NoiseKind.allCases) { noise in
                                if let value = model.profile.noiseThresholds[noise.rawValue] {
                                    HStack {
                                        Label(noise.displayName(in: language), systemImage: noise.symbol)
                                        Spacer()
                                        Text(signed(value) + " dB SNR").bold()
                                    }
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(language.text("Saved test history", "Historial de pruebas"))
                                .font(.headline)
                            Spacer()
                            if !model.history.isEmpty {
                                Text("\(model.history.count)").foregroundStyle(.secondary)
                            }
                        }

                        if model.history.isEmpty {
                            ContentUnavailableView(
                                language.text("No saved tests yet", "Aún no hay pruebas guardadas"),
                                systemImage: "clock.arrow.circlepath",
                                description: Text(language.text(
                                    "Name and complete a test to add it here.",
                                    "Ponle un nombre y completa una prueba para guardarla aquí."
                                ))
                            )
                            .frame(minHeight: 150)
                        } else {
                            ForEach(model.history.prefix(3)) { record in
                                NavigationLink(destination: TestRecordDetailView(record: record)) {
                                    TestHistoryRow(record: record, displayLanguage: language)
                                }
                                .buttonStyle(.plain)
                            }

                            NavigationLink(destination: TestHistoryView()) {
                                Label(
                                    language.text("View all saved tests", "Ver todas las pruebas"),
                                    systemImage: "clock.arrow.circlepath"
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title2.bold()).padding(.top, 4)
    }

    private func confidenceRow(_ title: String, range: ConfidenceRange) -> some View {
        LabeledContent(title, value: String(format: "%+.1f to %+.1f dB", range.lower, range.upper))
    }

    private func qualityRow(_ title: String, value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.subheadline)
    }

    private func ambientQualityText(_ test: BilateralPureToneTest) -> String {
        guard let level = test.ambientNoiseDBFS else {
            return language.text("Not measured", "No medido")
        }
        let quality = level <= -42
            ? language.text("Appears quiet", "Parece silencioso")
            : language.text("Elevated", "Elevado")
        return "\(quality) · \(String(format: "%.1f", level)) dBFS"
    }
}

struct BilateralAudiogramChart: View {
    let test: BilateralPureToneTest
    let display: AudiogramDisplay

    private let frequencies = [250.0, 500.0, 1_000.0, 2_000.0, 3_000.0, 4_000.0, 6_000.0, 8_000.0]
    private let yValues = stride(from: 0.0, through: -80.0, by: -10.0).map { $0 }

    private var showLeft: Bool { display == .left || display == .both }
    private var showRight: Bool { display == .right || display == .both }
    private var left: [PureToneThresholdResult] { test.thresholds(for: .left) }
    private var right: [PureToneThresholdResult] { test.thresholds(for: .right) }
    private var asymmetryFrequencies: [Double] {
        frequencies.filter { frequency in
            guard let left = test.threshold(for: .left, frequency: frequency),
                  let right = test.threshold(for: .right, frequency: frequency) else { return false }
            return abs(left.finalRelativeThreshold - right.finalRelativeThreshold) >= 15
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                if showRight { Label("Right  O", systemImage: "circle").foregroundStyle(.red) }
                if showLeft { Label("Left  X", systemImage: "xmark").foregroundStyle(.blue) }
                Spacer()
            }
            .font(.caption.bold())

            Text("Relative hearing threshold — not dB HL")
                .font(.caption.bold()).foregroundStyle(.orange)

            Chart {
                if display == .both {
                    ForEach(asymmetryFrequencies, id: \.self) { frequency in
                        RuleMark(x: .value("Large difference", audiogramX(frequency)))
                            .foregroundStyle(.orange.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 8))
                    }
                }

                if showRight {
                    ForEach(right) { point in
                        LineMark(
                            x: .value("Frequency", audiogramX(point.frequency)),
                            y: .value("Right threshold", -point.finalRelativeThreshold),
                            series: .value("Ear", "Right")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Frequency", audiogramX(point.frequency)),
                            y: .value("Right threshold", -point.finalRelativeThreshold)
                        )
                        .foregroundStyle(.clear)
                        .annotation(position: .overlay) {
                            Text("O").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.red)
                        }
                    }
                }

                if showLeft {
                    ForEach(left) { point in
                        LineMark(
                            x: .value("Frequency", audiogramX(point.frequency)),
                            y: .value("Left threshold", -point.finalRelativeThreshold),
                            series: .value("Ear", "Left")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Frequency", audiogramX(point.frequency)),
                            y: .value("Left threshold", -point.finalRelativeThreshold)
                        )
                        .foregroundStyle(.clear)
                        .annotation(position: .overlay) {
                            Text("X").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.blue)
                        }
                    }
                }
            }
            .chartXScale(domain: 0 ... 5)
            .chartYScale(domain: -80 ... 0)
            .chartXAxis {
                AxisMarks(values: frequencies.map(audiogramX)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisTick().foregroundStyle(.secondary)
                    AxisValueLabel {
                        if let position = value.as(Double.self), let frequency = frequency(for: position) {
                            Text(frequencyLabel(frequency))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: yValues) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.15))
                    AxisTick().foregroundStyle(.secondary)
                    AxisValueLabel {
                        if let number = value.as(Double.self) { Text("\(Int(abs(number)))") }
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.white.opacity(0.025)).border(Color.white.opacity(0.12), width: 1)
            }
            .frame(height: 310)

            HStack {
                Text("QUIETER / BETTER").font(.caption2.bold()).foregroundStyle(.green)
                Spacer()
                Text("Frequency (Hz)").font(.caption).foregroundStyle(.secondary)
            }
            Text("LOUDER / POORER").font(.caption2.bold()).foregroundStyle(.orange)
        }
        .accessibilityLabel("Bilateral relative-threshold audiogram; right ear red O, left ear blue X; not dB HL")
    }

    private func audiogramX(_ frequency: Double) -> Double {
        log2(frequency / 250)
    }

    private func frequency(for position: Double) -> Double? {
        frequencies.min(by: { abs(audiogramX($0) - position) < abs(audiogramX($1) - position) })
    }

    private func frequencyLabel(_ frequency: Double) -> String {
        frequency >= 1_000 ? String(format: "%.0fk", frequency / 1_000) : "\(Int(frequency))"
    }
}

struct PureToneThresholdSummary: View {
    let test: BilateralPureToneTest
    let language: TestLanguage
    private let frequencies = [250.0, 500.0, 1_000.0, 2_000.0, 3_000.0, 4_000.0, 6_000.0, 8_000.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(language.text("Frequency", "Frecuencia"))
                Spacer()
                Text("L").frame(width: 42)
                Text("R").frame(width: 42)
                Text("Δ").frame(width: 42)
                Text("n L/R").frame(width: 50)
            }
            .font(.caption.bold()).foregroundStyle(.secondary)

            ForEach(frequencies, id: \.self) { frequency in
                let leftResult = test.threshold(for: .left, frequency: frequency)
                let rightResult = test.threshold(for: .right, frequency: frequency)
                let left = leftResult?.finalRelativeThreshold
                let right = rightResult?.finalRelativeThreshold
                let difference = left.flatMap { l in right.map { abs(l - $0) } }
                HStack {
                    Text(frequency >= 1_000 ? String(format: "%.0f kHz", frequency / 1_000) : "\(Int(frequency)) Hz")
                    Spacer()
                    Text(value(left)).foregroundStyle(.blue).frame(width: 42)
                    Text(value(right)).foregroundStyle(.red).frame(width: 42)
                    Text(value(difference))
                        .foregroundStyle((difference ?? 0) >= 15 ? .orange : .secondary)
                        .frame(width: 42)
                    Text("\(leftResult?.presentationCount ?? 0)/\(rightResult?.presentationCount ?? 0)")
                        .foregroundStyle(.secondary)
                        .frame(width: 50)
                }
                .font(.subheadline.monospacedDigit())
            }
            Text(language.text(
                "Values and Δ are uncalibrated relative units. Orange marks a difference of 15 or more relative units.",
                "Los valores y Δ son unidades relativas sin calibrar. El naranja marca una diferencia de 15 o más unidades relativas."
            ))
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func value(_ number: Double?) -> String {
        number.map { String(format: "%.0f", $0) } ?? "—"
    }
}

struct RelativeAudiogramChart: View {
    let thresholds: [FrequencyThreshold]

    private var orderedThresholds: [FrequencyThreshold] {
        thresholds.sorted { $0.frequency < $1.frequency }
    }

    private let yValues: [Double] = stride(from: 0.0, through: -90.0, by: -10.0).map { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("0").font(.caption2).foregroundStyle(.secondary)
                Text("QUIETER").font(.caption2.bold()).foregroundStyle(.purple)
                Spacer()
                Text("Relative threshold").font(.caption2).foregroundStyle(.secondary)
            }
            Chart(orderedThresholds) { point in
                LineMark(
                    x: .value("Frequency", point.frequencyLabel),
                    y: .value("Relative threshold", -point.relativeAudiogramLevel)
                )
                .foregroundStyle(.purple)
                .lineStyle(StrokeStyle(lineWidth: 3))

                PointMark(
                    x: .value("Frequency", point.frequencyLabel),
                    y: .value("Relative threshold", -point.relativeAudiogramLevel)
                )
                .foregroundStyle(.purple)
                .symbolSize(90)
            }
            .chartYScale(domain: -90 ... 0)
            .chartYAxis {
                AxisMarks(position: .leading, values: yValues) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.16))
                    AxisTick().foregroundStyle(.secondary)
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(abs(number)))")
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisTick().foregroundStyle(.secondary)
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plot in
                plot
                    .background(Color.white.opacity(0.025))
                    .border(Color.white.opacity(0.12), width: 1)
            }
            .frame(height: 280)
            HStack {
                Spacer()
                Text("Frequency (Hz)").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Text("90").font(.caption2).foregroundStyle(.secondary)
                Text("LOUDER").font(.caption2.bold()).foregroundStyle(.orange)
            }
        }
        .accessibilityLabel("Audiogram-style relative frequency threshold chart")
    }
}

struct TestHistoryView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.history.isEmpty {
                ContentUnavailableView(
                    model.selectedLanguage.text("No saved tests", "No hay pruebas guardadas"),
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                List(model.history) { record in
                    NavigationLink(destination: TestRecordDetailView(record: record)) {
                        TestHistoryRow(record: record, displayLanguage: model.selectedLanguage)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
        }
        .navigationTitle(model.selectedLanguage.text("Test History", "Historial"))
    }
}

struct TestHistoryRow: View {
    let record: TestRecord
    let displayLanguage: TestLanguage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.kind.symbol)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.blue.opacity(0.13)))
            VStack(alignment: .leading, spacing: 3) {
                Text(record.name).font(.headline).lineLimit(1)
                Text(record.kind.displayName(in: displayLanguage))
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(record.language.shortLabel)
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .padding(.vertical, 4)
    }
}

struct TestRecordDetailView: View {
    @EnvironmentObject var model: AppModel
    let record: TestRecord
    @State private var audiogramDisplay: AudiogramDisplay = .both

    private var fittedSlope: Double {
        PsychometricEstimator.fit(record.speechPoints).slope
    }

    private func predictedUnderstanding(at snr: Double) -> Double {
        guard let threshold = record.snr50 else { return 0 }
        return 100 / (1 + exp(-(snr - threshold) / max(0.4, fittedSlope)))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(record.name, subtitle: record.date.formatted(date: .long, time: .shortened))

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(record.kind.displayName(in: model.selectedLanguage), systemImage: record.kind.symbol)
                            .font(.headline)
                        LabeledContent(model.selectedLanguage.text("Test language", "Idioma"), value: record.language.optionLabel)
                        if let voice = record.voiceProfile {
                            LabeledContent(
                                model.selectedLanguage.text("Voice profile", "Perfil de voz"),
                                value: voice.displayName(in: model.selectedLanguage)
                            )
                        }
                        if let resolved = record.resolvedVoiceName {
                            LabeledContent(model.selectedLanguage.text("Device voice", "Voz del dispositivo"), value: resolved)
                                .font(.footnote)
                        }
                        if record.voiceProfile == .girl || record.voiceProfile == .boy {
                            Text(model.selectedLanguage.text(
                                "Child profile is a simulated higher-pitch device voice, not a child recording.",
                                "El perfil infantil es una voz del dispositivo con tono más alto; no es una grabación de un niño."
                            ))
                            .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }

                detailContent
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(model.selectedLanguage.text("Saved Test", "Prueba guardada"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch record.kind {
        case .speechInNoise:
            if let snr50 = record.snr50, let snr80 = record.snr80, let snr90 = record.snr90 {
                HStack(spacing: 10) {
                    SmallMetric(title: "SNR50", value: signed(snr50), unit: "dB", color: .blue)
                    SmallMetric(title: "SNR80", value: signed(snr80), unit: "dB", color: .cyan)
                    SmallMetric(title: "SNR90", value: signed(snr90), unit: "dB", color: .green)
                }
            }
            GlassCard {
                Chart {
                    ForEach(stride(from: -10.0, through: 16.0, by: 0.5).map { $0 }, id: \.self) { snr in
                        LineMark(x: .value("SNR", snr), y: .value("Understanding", predictedUnderstanding(at: snr)))
                            .foregroundStyle(.green)
                    }
                    ForEach(record.speechPoints) { point in
                        PointMark(x: .value("SNR", point.snr), y: .value("Score", point.score * 100))
                            .foregroundStyle(.blue)
                    }
                }
                .chartXScale(domain: -10 ... 16)
                .chartYScale(domain: 0 ... 100)
                .frame(height: 280)
            }
        case .volume:
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.selectedLanguage.text("Recognition vs digital level", "Reconocimiento según nivel digital")).font(.headline)
                    Chart(record.volumePoints) { point in
                        LineMark(x: .value("dBFS", point.levelDBFS), y: .value("Recognition", point.score * 100)).foregroundStyle(.blue)
                        PointMark(x: .value("dBFS", point.levelDBFS), y: .value("Recognition", point.score * 100)).foregroundStyle(.blue)
                    }
                    .chartYScale(domain: 0 ... 100)
                    .frame(height: 280)
                }
            }
        case .frequency:
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    if let pureToneTest = record.pureToneTest {
                        Text(model.selectedLanguage.text("Bilateral pure-tone hearing profile", "Perfil bilateral de tonos puros")).font(.headline)
                        Picker(model.selectedLanguage.text("Display", "Mostrar"), selection: $audiogramDisplay) {
                            ForEach(AudiogramDisplay.allCases) { option in
                                Text(option.displayName(in: model.selectedLanguage)).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        BilateralAudiogramChart(test: pureToneTest, display: audiogramDisplay)
                        PureToneThresholdSummary(test: pureToneTest, language: model.selectedLanguage)
                        LabeledContent(
                            model.selectedLanguage.text("Reliability", "Fiabilidad"),
                            value: "\(Int(pureToneTest.reliabilityScore.rounded()))%"
                        )
                        Text(model.selectedLanguage.text(
                            "This test is not a clinical audiogram and cannot diagnose hearing loss. Relative hearing threshold — not dB HL.",
                            "Esta prueba no es un audiograma clínico y no puede diagnosticar pérdida auditiva. Umbral auditivo relativo — no es dB HL."
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text(model.selectedLanguage.text("Legacy single-curve relative thresholds", "Umbrales relativos antiguos de una sola curva")).font(.headline)
                        RelativeAudiogramChart(thresholds: record.frequencyThresholds)
                        Text(model.selectedLanguage.text(
                            "Legacy uncalibrated result with no ear assignment — not dB HL.",
                            "Resultado antiguo sin calibrar y sin asignación de oído — no es dB HL."
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        case .noiseProfile:
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    if let noise = record.noiseKind {
                        Label(noise.displayName(in: model.selectedLanguage), systemImage: noise.symbol).font(.headline)
                    }
                    if let threshold = record.noiseThreshold {
                        Text("SNR90  \(signed(threshold)) dB")
                            .font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var showReset = false

    var body: some View {
        Form {
            Section("Test defaults") {
                Picker("Language", selection: $model.selectedLanguage) {
                    ForEach(TestLanguage.allCases) { language in
                        Text(language.optionLabel).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Voice", selection: $model.selectedVoice) {
                    ForEach(VoiceProfile.allCases) { voice in
                        Text(voice.displayName(in: model.selectedLanguage)).tag(voice)
                    }
                }
            }
            Section("Audio") {
                LabeledContent("Current input", value: AudioSessionManager.shared.inputName)
                Text("For pure-tone and relative-volume tests, choose a comfortable iPhone volume and do not change it during the test. Pure-tone testing requires stereo AirPods and tests each ear separately.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Measurement limits") {
                Text("Live SNR uses an adaptive microphone estimate. Volume and pure-tone tests use relative digital levels, not calibrated dB SPL or dB HL. AirPods processing, fit, system volume, ambient noise, and device model can change the result.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Safety") {
                Text("Test tones are digitally capped, but your device volume still matters. Start at a low, comfortable volume and stop immediately if any sound is uncomfortable.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("About") {
                Text("© 2026 Guillermo Jenaro. All rights reserved.")
                Text("Bundled CC0/public-domain demo music remains subject to its source licensing and is not included in this copyright claim.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reset all test data and history", role: .destructive) { showReset = true }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset all results and saved tests?", isPresented: $showReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { model.reset() }
        }
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.065)))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 15).fill(color.opacity(0.09)))
    }
}

struct SmallMetric: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.title3.bold()).foregroundStyle(color)
                Text(unit).font(.caption).foregroundStyle(color)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }
}

@ViewBuilder
func titleBlock(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.largeTitle.bold())
        Text(subtitle).foregroundStyle(.secondary)
    }
}

func signed(_ value: Double) -> String {
    String(format: "%+.1f", value)
}
