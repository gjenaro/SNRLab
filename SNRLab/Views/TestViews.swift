import SwiftUI
import Charts

struct TestHubView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var audio = StimulusEngine()

    private var language: TestLanguage { model.selectedLanguage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    language.text("Tests", "Pruebas"),
                    subtitle: language.text(
                        "Choose the language and voice, then build your listening profile.",
                        "Elige el idioma y la voz, y luego crea tu perfil auditivo."
                    )
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(language.text("Test language", "Idioma de la prueba")).font(.headline)
                        Picker(language.text("Language", "Idioma"), selection: $model.selectedLanguage) {
                            ForEach(TestLanguage.allCases) { option in
                                Text(option.optionLabel).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        Divider()
                        Text(language.text("Speech voice", "Voz de la prueba")).font(.headline)
                        VoiceProfilePicker(selection: $model.selectedVoice, language: language)

                        Button {
                            Task {
                                await audio.playCleanSpeech(
                                    language.previewSentence,
                                    levelDBFS: -18,
                                    language: language,
                                    voiceProfile: model.selectedVoice
                                )
                            }
                        } label: {
                            Label(
                                audio.isPlaying
                                    ? language.text("Playing…", "Reproduciendo…")
                                    : language.text("Preview voice", "Escuchar voz"),
                                systemImage: "speaker.wave.2.fill"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(audio.isPlaying)

                        Text(language.text(
                            "Girl and Boy are simulated higher-pitch device voices; they are not recordings of children.",
                            "Niña y Niño son voces simuladas del dispositivo con tono más alto; no son grabaciones de niños."
                        ))
                        .font(.caption).foregroundStyle(.secondary)

                        AudioErrorText(message: audio.lastError)
                    }
                }

                TestLink(
                    title: TestKind.speechInNoise.displayName(in: language),
                    subtitle: language.text("Find your SNR50, SNR80 and SNR90.", "Calcula tu SNR50, SNR80 y SNR90."),
                    symbol: TestKind.speechInNoise.symbol,
                    tint: .green,
                    destination: SpeechInNoiseTestView()
                )
                TestLink(
                    title: TestKind.volume.displayName(in: language),
                    subtitle: language.text("Measure recognition across playback levels.", "Mide el reconocimiento a distintos volúmenes."),
                    symbol: TestKind.volume.symbol,
                    tint: .blue,
                    destination: VolumeSensitivityView()
                )
                TestLink(
                    title: TestKind.frequency.displayName(in: language),
                    subtitle: language.text(
                        "Adaptive left/right AirPods screening with a bilateral audiogram.",
                        "Evaluación adaptativa izquierda/derecha con AirPods y audiograma bilateral."
                    ),
                    symbol: TestKind.frequency.symbol,
                    tint: .purple,
                    destination: FrequencySensitivityView()
                )
                TestLink(
                    title: language.text("Noise Profiles", "Perfiles de ruido"),
                    subtitle: language.text("Compare speech against different noise types.", "Compara el habla con distintos tipos de ruido."),
                    symbol: TestKind.noiseProfile.symbol,
                    tint: .orange,
                    destination: NoiseProfilesView()
                )

                GlassCard {
                    Text(language.text(
                        "For best repeatability, use the same AirPods, fit, room, and iPhone volume for every session.",
                        "Para comparar resultados, usa los mismos AirPods, ajuste, lugar y volumen del iPhone en cada sesión."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(language.text("Tests", "Pruebas"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { audio.stop() }
    }
}

struct TestLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            GlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15).fill(tint.opacity(0.14)).frame(width: 54, height: 54)
                        Image(systemName: symbol).font(.title2).foregroundStyle(tint)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct VoiceProfilePicker: View {
    @Binding var selection: VoiceProfile
    let language: TestLanguage
    var disabled = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 9) {
            ForEach(VoiceProfile.allCases) { voice in
                Button {
                    selection = voice
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: voice.symbol)
                        Text(voice.displayName(in: language)).font(.subheadline.bold())
                        Spacer(minLength: 0)
                        if selection == voice { Image(systemName: "checkmark.circle.fill") }
                    }
                    .padding(11)
                    .foregroundStyle(selection == voice ? Color.blue : Color.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selection == voice ? Color.blue.opacity(0.14) : Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selection == voice ? Color.blue.opacity(0.7) : Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
    }
}

struct TestSetupCard: View {
    @Binding var testName: String
    @Binding var language: TestLanguage
    @Binding var voice: VoiceProfile
    let includesVoice: Bool
    let locked: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label(language.text("Test record", "Registro de prueba"), systemImage: "square.and.pencil")
                        .font(.headline)
                    Spacer()
                    if locked {
                        Label(language.text("Locked", "Bloqueado"), systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                TextField(language.text("Test name or person", "Nombre de la prueba o persona"), text: $testName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(locked)

                Picker(language.text("Language", "Idioma"), selection: $language) {
                    ForEach(TestLanguage.allCases) { option in
                        Text(option.optionLabel).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(locked)

                if includesVoice {
                    VoiceProfilePicker(selection: $voice, language: language, disabled: locked)
                    if voice == .girl || voice == .boy {
                        Text(language.text(
                            "This is a simulated higher-pitch profile, not a child recording.",
                            "Este perfil simula un tono más alto; no es una grabación de un niño."
                        ))
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }

                if locked {
                    Text(language.text(
                        "Language, voice, and name stay fixed during a run so one result never mixes settings.",
                        "El idioma, la voz y el nombre se mantienen durante la prueba para no mezclar ajustes."
                    ))
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct AudioErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote).foregroundStyle(.red)
        }
    }
}

struct SpeechInNoiseTestView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var audio = StimulusEngine()
    @State private var testName = ""
    @State private var noise: NoiseKind = .restaurant
    @State private var trial = 0
    @State private var currentSNR = 6.0
    @State private var response = ""
    @State private var points: [RecognitionPoint] = []
    @State private var feedback: String?
    @State private var complete = false
    private let totalTrials = 14

    private var language: TestLanguage { model.selectedLanguage }
    private var sentence: TestSentence {
        let bank = TestSentence.bank(for: language)
        return bank[trial % bank.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    TestKind.speechInNoise.displayName(in: language),
                    subtitle: language.text(
                        "Listen, type what you heard, and let the SNR adapt.",
                        "Escucha, escribe lo que oíste y deja que el SNR se adapte."
                    )
                )

                TestSetupCard(
                    testName: $testName,
                    language: $model.selectedLanguage,
                    voice: $model.selectedVoice,
                    includesVoice: true,
                    locked: trial > 0 || complete
                )

                if complete {
                    completionCard
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(language.text("Trial \(trial + 1) of \(totalTrials)", "Intento \(trial + 1) de \(totalTrials)"))
                                    .font(.headline)
                                Spacer()
                                Text(signed(currentSNR) + " dB SNR").bold().foregroundStyle(.green)
                            }
                            ProgressView(value: Double(trial), total: Double(totalTrials)).tint(.blue)
                            Picker(language.text("Noise", "Ruido"), selection: $noise) {
                                ForEach(NoiseKind.allCases) { kind in
                                    Text(kind.displayName(in: language)).tag(kind)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(trial > 0)

                            Text(language.text(
                                "The sentence is hidden. Listen once, then type what you heard.",
                                "La frase está oculta. Escucha una vez y escribe lo que oíste."
                            ))
                            .font(.footnote).foregroundStyle(.secondary)

                            Button {
                                Task {
                                    await audio.playSpeechInNoise(
                                        sentence.text,
                                        snrDB: currentSNR,
                                        noise: noise,
                                        language: language,
                                        voiceProfile: model.selectedVoice
                                    )
                                }
                            } label: {
                                Label(
                                    audio.isPlaying ? language.text("Playing…", "Reproduciendo…") : language.text("Play sentence", "Reproducir frase"),
                                    systemImage: "play.circle.fill"
                                )
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(audio.isPlaying)

                            TextField(language.text("Type what you heard", "Escribe lo que oíste"), text: $response, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...5)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            if let feedback { Text(feedback).font(.footnote).foregroundStyle(.secondary) }
                            AudioErrorText(message: audio.lastError)

                            Button(language.text("Submit answer", "Enviar respuesta")) { submit() }
                                .buttonStyle(.bordered)
                                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(language.text("Adaptive staircase", "Escalera adaptativa"), systemImage: "brain.head.profile").font(.headline)
                            Text(language.text(
                                "The next trial gets harder after a strong answer and easier after a weaker answer.",
                                "La siguiente frase será más difícil tras una respuesta buena y más fácil tras una respuesta débil."
                            ))
                            .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(TestKind.speechInNoise.displayName(in: language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { setDefaultNameIfNeeded(for: .speechInNoise) }
        .onDisappear { audio.stop() }
    }

    private var completionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(language.text("Test saved", "Prueba guardada"), systemImage: "checkmark.circle.fill")
                    .font(.title2.bold()).foregroundStyle(.green)
                Text(testName).font(.headline)
                HStack(spacing: 10) {
                    SmallMetric(title: "SNR50", value: signed(model.profile.snr50), unit: "dB", color: .blue)
                    SmallMetric(title: "SNR80", value: signed(model.profile.snr80), unit: "dB", color: .cyan)
                    SmallMetric(title: "SNR90", value: signed(model.profile.snr90), unit: "dB", color: .green)
                }
                Text(language.text(
                    "Compare repeated tests made with the same setup rather than treating this as a clinical reference.",
                    "Compara pruebas hechas con el mismo equipo; no uses el resultado como referencia clínica."
                ))
                .font(.footnote).foregroundStyle(.secondary)
                Button(language.text("Run another test", "Hacer otra prueba")) { reset() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func submit() {
        let score = WordScorer.score(reference: sentence.text, response: response)
        points.append(RecognitionPoint(snr: currentSNR, score: score, noise: noise))
        feedback = language.text(
            "Recognized \(Int((score * 100).rounded()))% of the words.",
            "Reconociste \(Int((score * 100).rounded()))% de las palabras."
        )
        currentSNR += score >= 0.72 ? -2 : 2
        currentSNR = min(18, max(-10, currentSNR))
        response = ""
        trial += 1
        if trial >= totalTrials {
            model.saveSpeechTest(
                name: testName,
                points: points,
                language: language,
                voice: model.selectedVoice,
                resolvedVoiceName: audio.lastResolvedVoiceName
            )
            audio.stop()
            complete = true
        }
    }

    private func reset() {
        trial = 0
        currentSNR = 6
        response = ""
        points = []
        feedback = nil
        complete = false
        testName = model.defaultTestName(for: .speechInNoise, language: language)
    }

    private func setDefaultNameIfNeeded(for kind: TestKind) {
        if testName.isEmpty { testName = model.defaultTestName(for: kind, language: language) }
    }
}

struct VolumeSensitivityView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var audio = StimulusEngine()
    @State private var testName = ""
    @State private var index = 0
    @State private var response = ""
    @State private var points: [VolumePoint] = []
    @State private var complete = false
    private let levels = [-42.0, -36.0, -30.0, -24.0, -18.0, -12.0]

    private var language: TestLanguage { model.selectedLanguage }
    private var sentence: TestSentence {
        let bank = TestSentence.bank(for: language)
        return bank[(index + 5) % bank.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    TestKind.volume.displayName(in: language),
                    subtitle: language.text("Speech recognition versus digital playback level.", "Reconocimiento del habla según el nivel digital.")
                )

                TestSetupCard(
                    testName: $testName,
                    language: $model.selectedLanguage,
                    voice: $model.selectedVoice,
                    includesVoice: true,
                    locked: index > 0 || complete
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(language.text("Keep iPhone volume fixed", "No cambies el volumen del iPhone"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.headline)
                        Text(language.text(
                            "Levels are dBFS, not dB SPL at your ear. Use the same headphones and device volume for comparison.",
                            "Los niveles son dBFS, no dB SPL en el oído. Usa los mismos audífonos y volumen para comparar."
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if complete {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(language.text("Test saved", "Prueba guardada"), systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(.green)
                            Text(testName).font(.headline)
                            Chart(points) { point in
                                LineMark(x: .value("dBFS", point.levelDBFS), y: .value("Recognition", point.score * 100)).foregroundStyle(.blue)
                                PointMark(x: .value("dBFS", point.levelDBFS), y: .value("Recognition", point.score * 100)).foregroundStyle(.blue)
                            }
                            .chartYScale(domain: 0...100)
                            .frame(height: 260)
                            Button(language.text("Run another test", "Hacer otra prueba")) { reset() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(language.text("Level \(index + 1) of \(levels.count)", "Nivel \(index + 1) de \(levels.count)"))
                                    .font(.headline)
                                Spacer()
                                Text(String(format: "%.0f dBFS", levels[index])).foregroundStyle(.blue).bold()
                            }
                            Button {
                                Task {
                                    await audio.playCleanSpeech(
                                        sentence.text,
                                        levelDBFS: levels[index],
                                        language: language,
                                        voiceProfile: model.selectedVoice
                                    )
                                }
                            } label: {
                                Label(language.text("Play sentence", "Reproducir frase"), systemImage: "speaker.wave.2.fill")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(audio.isPlaying)

                            TextField(language.text("Type what you heard", "Escribe lo que oíste"), text: $response, axis: .vertical)
                                .textFieldStyle(.roundedBorder).lineLimit(3...5)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            AudioErrorText(message: audio.lastError)
                            Button(language.text("Submit", "Enviar")) { submit() }
                                .buttonStyle(.bordered)
                                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(TestKind.volume.displayName(in: language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if testName.isEmpty { testName = model.defaultTestName(for: .volume, language: language) }
        }
        .onDisappear { audio.stop() }
    }

    private func submit() {
        let score = WordScorer.score(reference: sentence.text, response: response)
        points.append(VolumePoint(levelDBFS: levels[index], score: score))
        response = ""
        index += 1
        if index >= levels.count {
            model.saveVolumeTest(
                name: testName,
                points: points,
                language: language,
                voice: model.selectedVoice,
                resolvedVoiceName: audio.lastResolvedVoiceName
            )
            audio.stop()
            complete = true
            index = levels.count - 1
        }
    }

    private func reset() {
        index = 0
        response = ""
        points = []
        complete = false
        testName = model.defaultTestName(for: .volume, language: language)
    }
}

struct FrequencySensitivityView: View {
    private enum Phase: Equatable {
        case setup
        case practice
        case testing
        case earReview
        case complete
    }

    private struct ToneTarget {
        let frequency: Double
        let isRetest: Bool
    }

    @EnvironmentObject var model: AppModel
    @StateObject private var audio = StimulusEngine()
    @StateObject private var ambient = LiveSNREngine()
    @State private var testName = ""
    @State private var phase: Phase = .setup
    @State private var routeStatus: AudioOutputRouteStatus?
    @State private var routeMessage: String?
    @State private var bothAirPodsConfirmed = false
    @State private var transparencyDisabled = false
    @State private var consistentModeConfirmed = false
    @State private var quietRoomConfirmed = false
    @State private var leftChannelConfirmed = false
    @State private var rightChannelConfirmed = false
    @State private var ambientNoiseDBFS: Double?
    @State private var measuringAmbient = false
    @State private var practiceEar: HearingEar = .left
    @State private var practicePlayed = false
    @State private var currentEar: HearingEar = .left
    @State private var targetIndex = 0
    @State private var staircase: PureToneStaircase?
    @State private var results: [PureToneThresholdResult] = []
    @State private var awaitingTap = false
    @State private var trialBeganAt: Date?
    @State private var stimulusStartedAt: Date?
    @State private var currentTrialIsCatch = false
    @State private var activeTrialToken: UUID?
    @State private var trialTask: Task<Void, Never>?
    @State private var routeInterruptedMessage: String?
    @State private var savedTest: BilateralPureToneTest?
    @State private var audiogramDisplay: AudiogramDisplay = .both

    private let sequence = [
        ToneTarget(frequency: 1_000, isRetest: false),
        ToneTarget(frequency: 2_000, isRetest: false),
        ToneTarget(frequency: 3_000, isRetest: false),
        ToneTarget(frequency: 4_000, isRetest: false),
        ToneTarget(frequency: 6_000, isRetest: false),
        ToneTarget(frequency: 8_000, isRetest: false),
        ToneTarget(frequency: 1_000, isRetest: true),
        ToneTarget(frequency: 500, isRetest: false),
        ToneTarget(frequency: 250, isRetest: false)
    ]

    private var language: TestLanguage { model.selectedLanguage }
    private var currentTarget: ToneTarget { sequence[min(targetIndex, sequence.count - 1)] }
    private var setupReady: Bool {
        routeStatus?.isReadyForBilateralTest == true &&
        bothAirPodsConfirmed && transparencyDisabled && consistentModeConfirmed &&
        quietRoomConfirmed && leftChannelConfirmed && rightChannelConfirmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    language.text("Pure-tone hearing profile", "Perfil auditivo de tonos puros"),
                    subtitle: language.text(
                        "Separate left/right adaptive screening with an uncalibrated relative scale.",
                        "Evaluación adaptativa separada de cada oído con una escala relativa sin calibrar."
                    )
                )

                limitationCard

                switch phase {
                case .setup: setupContent
                case .practice: practiceContent
                case .testing: testingContent
                case .earReview: earReviewContent
                case .complete: completionContent
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(language.text("Pure-tone Test", "Prueba de tonos puros"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if testName.isEmpty { testName = model.defaultTestName(for: .frequency, language: language) }
            refreshRoute()
        }
        .onDisappear {
            cancelActiveTrial()
            audio.stop()
            ambient.stop()
        }
    }

    private var limitationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Relative hearing threshold — not dB HL", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                Text(language.text(
                    "This test is not a clinical audiogram and cannot diagnose hearing loss. Results depend on AirPods model, fit, device output, ambient noise, and calibration.",
                    "Esta prueba no es un audiograma clínico y no puede diagnosticar pérdida auditiva. Los resultados dependen del modelo y ajuste de los AirPods, la salida del dispositivo, el ruido ambiental y la calibración."
                ))
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            TestSetupCard(
                testName: $testName,
                language: $model.selectedLanguage,
                voice: $model.selectedVoice,
                includesVoice: false,
                locked: false
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label(language.text("AirPods and room check", "Revisión de AirPods y sala"), systemImage: "airpodspro")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(routeStatus?.name ?? language.text("Checking output…", "Revisando salida…"))
                                .font(.subheadline.bold())
                            Text(language.text(
                                "\(routeStatus?.channelCount ?? 0) output channels",
                                "\(routeStatus?.channelCount ?? 0) canales de salida"
                            ))
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: routeStatus?.isReadyForBilateralTest == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(routeStatus?.isReadyForBilateralTest == true ? .green : .orange)
                    }

                    if let routeMessage {
                        Text(routeMessage).font(.footnote).foregroundStyle(.orange)
                    }

                    Button { refreshRoute() } label: {
                        Label(language.text("Refresh AirPods status", "Actualizar estado de AirPods"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Divider()

                    setupToggle(
                        language.text("Both AirPods are connected, seated securely, and use the same fit.", "Ambos AirPods están conectados, bien colocados y con el mismo ajuste."),
                        isOn: $bothAirPodsConfirmed
                    )
                    setupToggle(
                        language.text("Transparency mode is off.", "El modo Transparencia está desactivado."),
                        isOn: $transparencyDisabled
                    )
                    setupToggle(
                        language.text("I will keep the same noise-control mode and iPhone volume.", "Mantendré el mismo modo de control de ruido y volumen del iPhone."),
                        isOn: $consistentModeConfirmed
                    )
                    setupToggle(
                        language.text("I am in a quiet room.", "Estoy en una habitación silenciosa."),
                        isOn: $quietRoomConfirmed
                    )
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(language.text("Left/right channel check", "Revisión de canales izquierdo/derecho"))
                        .font(.headline)
                    Text(language.text(
                        "Play each check and confirm the sound came only from the named AirPod.",
                        "Reproduce cada comprobación y confirma que el sonido vino solo del AirPod indicado."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        channelCheckButton(for: .left)
                        channelCheckButton(for: .right)
                    }
                    setupToggle(language.text("Left check heard only on the left", "Prueba izquierda solo en el izquierdo"), isOn: $leftChannelConfirmed)
                    setupToggle(language.text("Right check heard only on the right", "Prueba derecha solo en el derecho"), isOn: $rightChannelConfirmed)
                    AudioErrorText(message: audio.lastError)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(language.text("Ambient-noise estimate", "Estimación de ruido ambiental")).font(.headline)
                    if let ambientNoiseDBFS {
                        HStack {
                            Text(String(format: "%.1f dBFS", ambientNoiseDBFS)).font(.title3.bold())
                            Spacer()
                            Label(
                                ambientNoiseDBFS <= -42
                                    ? language.text("Room appears quiet", "La sala parece silenciosa")
                                    : language.text("Noise may affect thresholds", "El ruido puede afectar los umbrales"),
                                systemImage: ambientNoiseDBFS <= -42 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .font(.caption).foregroundStyle(ambientNoiseDBFS <= -42 ? .green : .orange)
                        }
                    } else {
                        Text(language.text(
                            "Optional microphone estimate; this is relative dBFS, not a calibrated sound-level reading.",
                            "Estimación opcional del micrófono; es dBFS relativo, no una medición calibrada de nivel sonoro."
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button { measureAmbientNoise() } label: {
                        Label(
                            measuringAmbient ? language.text("Measuring…", "Midiendo…") : language.text("Check room noise", "Medir ruido de la sala"),
                            systemImage: "mic.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(measuringAmbient)
                    AudioErrorText(message: ambient.errorMessage)
                }
            }

            Button {
                phase = .practice
                practiceEar = .left
                practicePlayed = false
            } label: {
                Label(language.text("Continue to practice", "Continuar a la práctica"), systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!setupReady)
        }
    }

    private var practiceContent: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text(language.text("Practice at 1 kHz", "Práctica a 1 kHz")).font(.title2.bold())
                Label(practiceEar.displayName(in: language), systemImage: "ear.fill")
                    .font(.headline)
                    .foregroundStyle(practiceEar == .left ? .blue : .red)
                Text(language.text(
                    "Listen for three short pulses. During the test, tap whenever you hear them—even if they are extremely faint.",
                    "Escucha tres pulsos cortos. Durante la prueba, toca siempre que los oigas, aunque sean extremadamente débiles."
                ))
                .foregroundStyle(.secondary)

                Button {
                    audio.playPulsedTone(frequency: 1_000, levelDBFS: -27, ear: practiceEar)
                    practicePlayed = true
                } label: {
                    Label(language.text("Play practice tone", "Reproducir tono de práctica"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button {
                    finishPracticeEar()
                } label: {
                    Text(language.text("I heard the practice tone", "Escuché el tono de práctica"))
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(practiceEar == .left ? .blue : .red)
                .disabled(!practicePlayed)
                AudioErrorText(message: audio.lastError)
            }
        }
    }

    private var testingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(progressLabel).font(.headline)
                        Spacer()
                        Text(estimatedRemainingText).font(.caption).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(results.count), total: 18)
                        .tint(currentEar == .left ? .blue : .red)
                    HStack(alignment: .firstTextBaseline) {
                        Text(frequencyText(currentTarget.frequency))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        if currentTarget.isRetest {
                            Text(language.text("repeat check", "repetición"))
                                .font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                    Text(language.text(
                        "Listen quietly. Tap the button whenever you hear the pulses. There is intentionally no visual cue for tone onset.",
                        "Escucha en silencio. Toca el botón cuando oigas los pulsos. Intencionalmente no hay señal visual del inicio del tono."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let routeInterruptedMessage {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(language.text("Test paused", "Prueba en pausa"), systemImage: "airpodspro.chargingcase.wireless")
                            .font(.headline).foregroundStyle(.orange)
                        Text(routeInterruptedMessage).font(.footnote)
                        Button(language.text("Reconnect and resume", "Reconectar y continuar")) { resumeAfterRouteCheck() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            if let liveQualityWarning {
                Label(liveQualityWarning, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.10)))
            }

            Button {
                registerHeardTap()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill").font(.largeTitle)
                    Text(language.text("I hear the tone", "Escucho el tono")).font(.title2.bold())
                    Text(language.text("Tap even when it is extremely faint", "Toca aunque sea extremadamente débil"))
                        .font(.caption)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(currentEar == .left ? .blue : .red)
            .disabled(routeInterruptedMessage != nil)

            AudioErrorText(message: audio.lastError)

            Text(language.text(
                "Short tones and occasional silent trials are presented after varying delays to estimate reliability.",
                "Se presentan tonos cortos y pruebas silenciosas ocasionales después de demoras variables para estimar la fiabilidad."
            ))
            .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var earReviewContent: some View {
        let difference = oneKilohertzDifference(for: currentEar)
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    language.text("\(currentEar.displayName(in: language)) complete", "\(currentEar.displayName(in: language)) completado"),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.title3.bold()).foregroundStyle(.green)

                if let difference {
                    LabeledContent(
                        language.text("1-kHz repeat difference", "Diferencia de repetición a 1 kHz"),
                        value: String(format: "%.0f relative units", difference)
                    )
                    if difference > 5 {
                        Label(
                            language.text(
                                "Reduced repeatability. Repeating this ear is recommended.",
                                "Repetibilidad reducida. Se recomienda repetir este oído."
                            ),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote).foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 10) {
                    Button(language.text("Repeat this ear", "Repetir este oído")) { repeatCurrentEar() }
                        .buttonStyle(.bordered)
                    Button(
                        currentEar == .left
                            ? language.text("Continue to right ear", "Continuar al oído derecho")
                            : language.text("Finish and save", "Finalizar y guardar")
                    ) {
                        acceptCompletedEar()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var completionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let savedTest {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(language.text("Bilateral test saved", "Prueba bilateral guardada"), systemImage: "checkmark.circle.fill")
                            .font(.headline).foregroundStyle(.green)
                        Text(savedTest.name).font(.title3.bold())
                        Picker(language.text("Display", "Mostrar"), selection: $audiogramDisplay) {
                            ForEach(AudiogramDisplay.allCases) { option in
                                Text(option.displayName(in: language)).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        BilateralAudiogramChart(test: savedTest, display: audiogramDisplay)
                        HStack(spacing: 10) {
                            SmallMetric(title: language.text("Reliability", "Fiabilidad"), value: "\(Int(savedTest.reliabilityScore.rounded()))", unit: "%", color: savedTest.hasReducedReliability ? .orange : .green)
                            SmallMetric(title: language.text("False +", "Falsos +"), value: "\(Int((savedTest.falsePositiveRate * 100).rounded()))", unit: "%", color: .orange)
                            SmallMetric(title: language.text("Trials", "Ensayos"), value: "\(savedTest.presentationCount)", unit: "", color: .blue)
                        }
                    }
                }
            }

            Button(language.text("Run another bilateral test", "Hacer otra prueba bilateral")) { reset() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func setupToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn).tint(.green)
    }

    private func channelCheckButton(for ear: HearingEar) -> some View {
        Button {
            refreshRoute()
            audio.playPulsedTone(frequency: 1_000, levelDBFS: -27, ear: ear, pulseCount: 2)
        } label: {
            Label(ear.displayName(in: language), systemImage: ear == .left ? "l.circle.fill" : "r.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(ear == .left ? .blue : .red)
        .disabled(routeStatus?.isReadyForBilateralTest != true)
    }

    private var progressLabel: String {
        if currentTarget.isRetest {
            return language.text(
                "\(currentEar.displayName(in: language)) · 1-kHz reliability check",
                "\(currentEar.displayName(in: language)) · control de fiabilidad a 1 kHz"
            )
        }
        let completedUnique = results.filter { $0.ear == currentEar && !$0.isOneKilohertzRetest }.count
        return language.text(
            "\(currentEar.displayName(in: language)) · \(min(8, completedUnique + 1)) of 8 frequencies",
            "\(currentEar.displayName(in: language)) · \(min(8, completedUnique + 1)) de 8 frecuencias"
        )
    }

    private var estimatedRemainingText: String {
        let remaining = max(0, 18 - results.count)
        let minutes = max(1, Int(ceil(Double(remaining) * 25 / 60)))
        return language.text("~\(minutes) min remaining", "~\(minutes) min restantes")
    }

    private var liveQualityWarning: String? {
        let trials = results.flatMap(\.trials) + (staircase?.trials ?? [])
        let catches = trials.filter(\.isCatchTrial)
        let catchRate = catches.isEmpty ? 0 : Double(catches.filter(\.heard).count) / Double(catches.count)
        let premature = trials.filter(\.prematureResponse).count
        guard (catches.count >= 2 && catchRate > 0.20) || premature >= 3 else { return nil }
        return language.text(
            "Several taps occurred without a tone. Wait for a real sound and tap only when you hear it; reliability may be reduced.",
            "Se detectaron varios toques sin tono. Espera un sonido real y toca solo cuando lo oigas; la fiabilidad puede reducirse."
        )
    }

    private func frequencyText(_ frequency: Double) -> String {
        frequency >= 1_000 ? String(format: "%.0f kHz", frequency / 1_000) : "\(Int(frequency)) Hz"
    }

    private func refreshRoute() {
        do {
            let status = try AudioSessionManager.shared.outputRouteStatus()
            routeStatus = status
            routeMessage = status.isReadyForBilateralTest ? nil : language.text(
                "Connect both AirPods and make sure stereo output is active. iOS reports the route, while you confirm each physical AirPod with the channel check.",
                "Conecta ambos AirPods y verifica que la salida estéreo esté activa. iOS informa la ruta y tú confirmas cada AirPod físico con la prueba de canales."
            )
        } catch {
            routeMessage = error.localizedDescription
        }
    }

    private func measureAmbientNoise() {
        measuringAmbient = true
        ambient.stop()
        ambient.start()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !ambient.history.isEmpty { ambientNoiseDBFS = ambient.noiseDBFS }
            ambient.stop()
            measuringAmbient = false
            refreshRoute()
        }
    }

    private func finishPracticeEar() {
        audio.stop()
        if practiceEar == .left {
            practiceEar = .right
            practicePlayed = false
        } else {
            startEar(.left)
        }
    }

    private func startEar(_ ear: HearingEar) {
        phase = .testing
        currentEar = ear
        targetIndex = 0
        routeInterruptedMessage = nil
        makeStaircaseAndBegin()
    }

    private func makeStaircaseAndBegin() {
        let target = currentTarget
        let sameEarThresholds = results.filter { $0.ear == currentEar }
        let reference: Double? = target.isRetest
            ? sameEarThresholds.first(where: { abs($0.frequency - 1_000) < 0.5 && !$0.isOneKilohertzRetest })?.finalRelativeThreshold
            : sameEarThresholds.last(where: { !$0.isOneKilohertzRetest })?.finalRelativeThreshold
        staircase = PureToneStaircase(
            frequency: target.frequency,
            ear: currentEar,
            isOneKilohertzRetest: target.isRetest,
            startingLevel: max(0, (reference ?? 35) - 10)
        )
        beginPresentation()
    }

    private func shouldUseCatchTrial() -> Bool {
        let earTrials = results.filter { $0.ear == currentEar }.flatMap(\.trials) + (staircase?.trials ?? [])
        let realCount = earTrials.filter { !$0.isCatchTrial && !$0.prematureResponse }.count
        guard realCount >= 7 else { return false }
        let trialsSinceCatch: Int
        if let lastCatch = earTrials.lastIndex(where: \.isCatchTrial) {
            trialsSinceCatch = earTrials.distance(from: lastCatch, to: earTrials.endIndex) - 1
        } else {
            trialsSinceCatch = earTrials.count
        }
        return trialsSinceCatch >= 14 || (trialsSinceCatch >= 8 && Int.random(in: 0..<4) == 0)
    }

    private func beginPresentation() {
        cancelActiveTrial()
        guard phase == .testing else { return }
        do {
            let status = try AudioSessionManager.shared.outputRouteStatus()
            guard status.isReadyForBilateralTest else {
                routeInterruptedMessage = language.text(
                    "AirPods stereo output is no longer available. Reconnect both AirPods without changing the test volume.",
                    "La salida estéreo de los AirPods ya no está disponible. Reconecta ambos AirPods sin cambiar el volumen de prueba."
                )
                return
            }
            routeStatus = status
        } catch {
            routeInterruptedMessage = error.localizedDescription
            return
        }

        let token = UUID()
        activeTrialToken = token
        awaitingTap = true
        trialBeganAt = Date()
        stimulusStartedAt = nil
        currentTrialIsCatch = shouldUseCatchTrial()
        let delay = Double.random(in: 0.85 ... 2.15)

        trialTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, activeTrialToken == token, phase == .testing else { return }
            stimulusStartedAt = Date()

            if !currentTrialIsCatch, let staircase {
                audio.playPulsedTone(
                    frequency: staircase.frequency,
                    levelDBFS: digitalLevel(for: staircase.currentLevel),
                    ear: staircase.ear
                )
            }

            try? await Task.sleep(nanoseconds: 1_550_000_000)
            guard !Task.isCancelled, activeTrialToken == token, phase == .testing else { return }
            completePresentation(heard: false, responseTime: nil, token: token)
        }
    }

    private func registerHeardTap() {
        guard phase == .testing, awaitingTap, let token = activeTrialToken else { return }
        if stimulusStartedAt == nil {
            let elapsed = Date().timeIntervalSince(trialBeganAt ?? Date())
            trialTask?.cancel()
            if var staircase {
                staircase.recordPrematureTap(responseTime: -elapsed)
                self.staircase = staircase
            }
            invalidatePresentation(token: token)
            scheduleNextPresentation()
            return
        }
        let responseTime = Date().timeIntervalSince(stimulusStartedAt ?? Date())
        completePresentation(heard: true, responseTime: responseTime, token: token)
    }

    private func completePresentation(heard: Bool, responseTime: TimeInterval?, token: UUID) {
        guard activeTrialToken == token, var staircase else { return }
        trialTask?.cancel()
        var completed: PureToneThresholdResult?
        if currentTrialIsCatch {
            staircase.recordCatch(heard: heard, responseTime: responseTime)
        } else {
            completed = staircase.recordPresentation(heard: heard, responseTime: responseTime)
        }
        self.staircase = staircase
        invalidatePresentation(token: token)

        if let completed {
            finishThreshold(completed)
        } else {
            scheduleNextPresentation()
        }
    }

    private func finishThreshold(_ result: PureToneThresholdResult) {
        results.append(result)
        audio.stop()
        if targetIndex + 1 < sequence.count {
            targetIndex += 1
            makeStaircaseAndBegin()
        } else {
            phase = .earReview
        }
    }

    private func invalidatePresentation(token: UUID) {
        guard activeTrialToken == token else { return }
        activeTrialToken = nil
        awaitingTap = false
        trialBeganAt = nil
        stimulusStartedAt = nil
        currentTrialIsCatch = false
    }

    private func scheduleNextPresentation() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard phase == .testing else { return }
            beginPresentation()
        }
    }

    private func cancelActiveTrial() {
        trialTask?.cancel()
        trialTask = nil
        activeTrialToken = nil
        awaitingTap = false
        audio.stop()
    }

    private func digitalLevel(for relativeLevel: Double) -> Double {
        min(-10, max(-70, -70 + relativeLevel * 0.75))
    }

    private func oneKilohertzDifference(for ear: HearingEar) -> Double? {
        let measurements = results.filter { $0.ear == ear && abs($0.frequency - 1_000) < 0.5 }
        guard let first = measurements.first(where: { !$0.isOneKilohertzRetest }),
              let repeatResult = measurements.first(where: { $0.isOneKilohertzRetest }) else { return nil }
        return abs(first.finalRelativeThreshold - repeatResult.finalRelativeThreshold)
    }

    private func repeatCurrentEar() {
        cancelActiveTrial()
        results.removeAll { $0.ear == currentEar }
        startEar(currentEar)
    }

    private func acceptCompletedEar() {
        if currentEar == .left {
            startEar(.right)
        } else {
            finalizeAndSave()
        }
    }

    private func finalizeAndSave() {
        cancelActiveTrial()
        let test = BilateralPureToneTest(
            name: testName,
            results: results,
            ambientNoiseDBFS: ambientNoiseDBFS,
            outputRouteName: routeStatus?.name ?? "AirPods",
            outputChannelCount: routeStatus?.channelCount ?? 2,
            airPodsSetupConfirmed: setupReady
        )
        savedTest = model.savePureToneTest(test, language: language)
        phase = .complete
    }

    private func resumeAfterRouteCheck() {
        refreshRoute()
        guard routeStatus?.isReadyForBilateralTest == true else { return }
        routeInterruptedMessage = nil
        beginPresentation()
    }

    private func reset() {
        cancelActiveTrial()
        phase = .setup
        testName = model.defaultTestName(for: .frequency, language: language)
        results = []
        savedTest = nil
        ambientNoiseDBFS = nil
        bothAirPodsConfirmed = false
        transparencyDisabled = false
        consistentModeConfirmed = false
        quietRoomConfirmed = false
        leftChannelConfirmed = false
        rightChannelConfirmed = false
        refreshRoute()
    }
}

struct NoiseProfilesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var audio = StimulusEngine()
    @State private var testName = ""
    @State private var selected: NoiseKind = .restaurant
    @State private var trial = 0
    @State private var snr = 6.0
    @State private var response = ""
    @State private var points: [RecognitionPoint] = []
    @State private var finishedNoise = false
    private let totalTrials = 8

    private var language: TestLanguage { model.selectedLanguage }
    private var sentence: TestSentence {
        let bank = TestSentence.bank(for: language)
        return bank[(trial + selected.rawValue.count) % bank.count]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    language.text("Noise Profiles", "Perfiles de ruido"),
                    subtitle: language.text(
                        "Compare the SNR you need with different noise patterns.",
                        "Compara el SNR que necesitas con distintos tipos de ruido."
                    )
                )

                TestSetupCard(
                    testName: $testName,
                    language: $model.selectedLanguage,
                    voice: $model.selectedVoice,
                    includesVoice: true,
                    locked: trial > 0 || finishedNoise
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(language.text("Latest SNR90 by noise type", "Último SNR90 por tipo de ruido")).font(.headline)
                        ForEach(NoiseKind.allCases) { kind in
                            HStack {
                                Label(kind.displayName(in: language), systemImage: kind.symbol)
                                Spacer()
                                if let value = model.profile.noiseThresholds[kind.rawValue] {
                                    Text(signed(value) + " dB").bold().foregroundStyle(.green)
                                } else {
                                    Text(language.text("Not tested", "Sin prueba")).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker(language.text("Noise type", "Tipo de ruido"), selection: $selected) {
                            ForEach(NoiseKind.allCases) { kind in
                                Text(kind.displayName(in: language)).tag(kind)
                            }
                        }
                        .disabled(trial > 0 && !finishedNoise)
                        .onChange(of: selected) { _, _ in resetRun(newName: true) }

                        if finishedNoise {
                            Label(
                                language.text("Saved \(selected.displayName(in: language)) profile", "Perfil de \(selected.displayName(in: language)) guardado"),
                                systemImage: "checkmark.circle.fill"
                            )
                            .foregroundStyle(.green).font(.headline)
                            Text(testName).font(.subheadline).foregroundStyle(.secondary)
                            Button(language.text("Test this noise again", "Probar este ruido otra vez")) { resetRun(newName: true) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            HStack {
                                Text(language.text("Trial \(trial + 1) of \(totalTrials)", "Intento \(trial + 1) de \(totalTrials)"))
                                Spacer()
                                Text(signed(snr) + " dB SNR").bold().foregroundStyle(.orange)
                            }
                            Button {
                                Task {
                                    await audio.playSpeechInNoise(
                                        sentence.text,
                                        snrDB: snr,
                                        noise: selected,
                                        language: language,
                                        voiceProfile: model.selectedVoice
                                    )
                                }
                            } label: {
                                Label(language.text("Play sentence", "Reproducir frase"), systemImage: selected.symbol)
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(audio.isPlaying)
                            TextField(language.text("Type what you heard", "Escribe lo que oíste"), text: $response, axis: .vertical)
                                .textFieldStyle(.roundedBorder).lineLimit(3...5)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            AudioErrorText(message: audio.lastError)
                            Button(language.text("Submit", "Enviar")) { submit() }
                                .buttonStyle(.bordered)
                                .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                GlassCard {
                    Text(language.text(
                        "Noise patterns are synthetic approximations. A validated product should use standardized licensed material and normative data.",
                        "Los ruidos son aproximaciones sintéticas. Un producto validado debe usar material estandarizado con licencia y datos normativos."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(language.text("Noise Profiles", "Perfiles de ruido"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if testName.isEmpty { testName = model.defaultTestName(for: .noiseProfile, language: language) }
        }
        .onDisappear { audio.stop() }
    }

    private func submit() {
        let score = WordScorer.score(reference: sentence.text, response: response)
        points.append(RecognitionPoint(snr: snr, score: score, noise: selected))
        snr += score >= 0.72 ? -2 : 2
        snr = min(18, max(-10, snr))
        response = ""
        trial += 1
        if trial >= totalTrials {
            let fit = PsychometricEstimator.fit(points)
            model.saveNoiseTest(
                name: testName,
                points: points,
                noise: selected,
                threshold: fit.snr90,
                language: language,
                voice: model.selectedVoice,
                resolvedVoiceName: audio.lastResolvedVoiceName
            )
            audio.stop()
            finishedNoise = true
        }
    }

    private func resetRun(newName: Bool) {
        trial = 0
        snr = 6
        response = ""
        points = []
        finishedNoise = false
        audio.stop()
        if newName { testName = model.defaultTestName(for: .noiseProfile, language: language) }
    }
}
