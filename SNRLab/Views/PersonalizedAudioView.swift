import SwiftUI
import Charts
import Combine

struct PersonalizedAudioView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var audio = PersonalizedAudioEngine()
    @State private var selectedTrack = DemoTrack.catalog[0]
    @State private var scrubberTime = 0.0
    @State private var isScrubbing = false
    @AppStorage("snrlab.personalizedAudio.pureToneSource.v2") private var selectedPureToneSource = "latest"
    @AppStorage("snrlab.personalizedAudio.maximumBoost.v2") private var maximumBoostDB = 6.0

    private let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var language: TestLanguage { model.selectedLanguage }
    private var pureToneRecords: [TestRecord] {
        model.history.filter { $0.kind == .frequency && $0.pureToneTest != nil }
    }
    private var selectedPureToneTest: BilateralPureToneTest? {
        if selectedPureToneSource == "latest" { return model.profile.latestPureToneTest }
        return pureToneRecords.first(where: { $0.id.uuidString == selectedPureToneSource })?.pureToneTest
    }
    private var hasBilateralProfile: Bool { selectedPureToneTest != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleBlock(
                    language.text("Personalized Audio", "Audio personalizado"),
                    subtitle: language.text(
                        "Compare each track in its original form and through your measurement-based filter.",
                        "Compara cada pista en su forma original y con el filtro basado en tus mediciones."
                    )
                )

                measurementCard
                filterCard
                playerCard
                libraryCard

                NavigationLink(destination: MusicCreditsView()) {
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(language.text("Music licenses and credits", "Licencias y créditos de música"))
                                    .font(.headline)
                                Text(language.text(
                                    "All ten bundled tracks are CC0/public-domain and work offline.",
                                    "Las diez pistas incluidas son CC0/dominio público y funcionan sin internet."
                                ))
                                .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                GlassCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(language.text(
                            "Start at a low, comfortable iPhone volume. This preset is a conservative relative listening adjustment—not a hearing aid, clinical prescription, or guarantee of improved fidelity.",
                            "Empieza con un volumen bajo y cómodo. Este ajuste es relativo y conservador; no es un audífono médico, una receta clínica ni una garantía de mayor fidelidad."
                        ))
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(language.text("Personalized Audio", "Audio personalizado"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            normalizeMeasurementSelections()
            loadSelectedTrack()
        }
        .onDisappear { audio.stop() }
        .onChange(of: selectedTrack) { _, _ in loadSelectedTrack() }
        .onChange(of: maximumBoostDB) { _, newValue in
            audio.updateCompensation(
                pureToneTest: selectedPureToneTest,
                maximumBoostDB: newValue
            )
        }
        .onChange(of: model.profile) { _, _ in
            audio.updateCompensation(
                pureToneTest: selectedPureToneTest,
                maximumBoostDB: maximumBoostDB
            )
        }
        .onChange(of: model.history) { _, _ in
            normalizeMeasurementSelections()
            audio.updateCompensation(
                pureToneTest: selectedPureToneTest,
                maximumBoostDB: maximumBoostDB
            )
        }
        .onChange(of: selectedPureToneSource) { _, _ in applySelectedMeasurements() }
        .onReceive(playbackTimer) { _ in
            audio.refreshTime()
        }
    }

    private var measurementCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(language.text("Measurements used", "Mediciones utilizadas"), systemImage: "waveform.path.ecg")
                    .font(.headline)

                Text(language.text(
                    "Choose a saved bilateral pure-tone test. Left and right filters are calculated independently, and the graph below changes immediately.",
                    "Elige una prueba bilateral guardada de tonos puros. Los filtros izquierdo y derecho se calculan por separado y la gráfica cambia inmediatamente."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    Label(language.text("Bilateral pure-tone measurement", "Medición bilateral de tonos puros"), systemImage: "slider.horizontal.3")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Picker(language.text("Pure-tone measurement", "Medición de tonos puros"), selection: $selectedPureToneSource) {
                        Text(language.text("Latest bilateral result", "Último resultado bilateral"))
                            .tag("latest")
                        ForEach(pureToneRecords) { record in
                            Text(recordOptionLabel(record)).tag(record.id.uuidString)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))

                HStack(spacing: 10) {
                    MeasurementStatus(
                        title: language.text("Left ear", "Oído izquierdo"),
                        value: hasBilateralProfile
                            ? language.text("8 bands", "8 bandas")
                            : language.text("Required", "Necesaria"),
                        ready: hasBilateralProfile
                    )
                    MeasurementStatus(
                        title: language.text("Right ear", "Oído derecho"),
                        value: hasBilateralProfile ? language.text("8 bands", "8 bandas") : language.text("Required", "Necesaria"),
                        ready: hasBilateralProfile
                    )
                }

                if !hasBilateralProfile {
                    Text(language.text(
                        "Complete the updated bilateral pure-tone test before enabling compensation. Original playback remains available.",
                        "Completa la prueba bilateral actualizada de tonos puros antes de activar la compensación. La reproducción original sigue disponible."
                    ))
                    .font(.footnote).foregroundStyle(.orange)
                    NavigationLink(destination: FrequencySensitivityView()) {
                        Label(language.text("Run frequency test", "Hacer prueba de frecuencia"), systemImage: "ear")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text(language.text(
                        "The selected left-ear thresholds control only the left channel; right-ear thresholds control only the right channel. Speech-in-noise results are not mixed into this frequency filter.",
                        "Los umbrales del oído izquierdo controlan solo el canal izquierdo; los del derecho controlan solo el canal derecho. Los resultados de habla con ruido no se mezclan con este filtro de frecuencia."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var playerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 17)
                            .fill(selectedTrack.genre == .classical ? Color.purple.opacity(0.16) : Color.blue.opacity(0.16))
                            .frame(width: 64, height: 64)
                        Image(systemName: selectedTrack.genre.symbol)
                            .font(.title).foregroundStyle(selectedTrack.genre == .classical ? .purple : .blue)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedTrack.title).font(.title3.bold())
                        Text(selectedTrack.genre.displayName(in: language)).foregroundStyle(.secondary)
                        Text(selectedTrack.licenseName).font(.caption).foregroundStyle(.green)
                    }
                }

                Slider(
                    value: Binding(
                        get: { isScrubbing ? scrubberTime : audio.currentTime },
                        set: { scrubberTime = $0 }
                    ),
                    in: 0 ... max(1, audio.duration),
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing { audio.seek(to: scrubberTime) }
                    }
                )
                HStack {
                    Text(timeString(isScrubbing ? scrubberTime : audio.currentTime))
                    Spacer()
                    Text(timeString(audio.duration > 0 ? audio.duration : selectedTrack.duration))
                }
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)

                Button {
                    audio.togglePlayback()
                } label: {
                    Label(
                        audio.isPlaying ? language.text("Pause", "Pausa") : language.text("Play", "Reproducir"),
                        systemImage: audio.isPlaying ? "pause.fill" : "play.fill"
                    )
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(audio.loadedTrackID == nil)

                VStack(alignment: .leading, spacing: 8) {
                    Text(language.text("Tap while the song is playing to compare", "Toca mientras suena la pista para comparar"))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        comparisonButton(
                            title: language.text("Original", "Original"),
                            symbol: "waveform",
                            selected: !audio.isCompensated
                        ) {
                            audio.setCompensated(false)
                        }
                        comparisonButton(
                            title: language.text("Compensated", "Compensado"),
                            symbol: "wand.and.stars",
                            selected: audio.isCompensated
                        ) {
                            audio.setCompensated(true)
                        }
                        .disabled(!hasBilateralProfile)
                    }
                }

                AudioErrorText(message: audio.errorMessage)
            }
        }
    }

    private var filterCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.text("Applied filter", "Filtro aplicado")).font(.headline)
                        Text(language.text("Maximum digital amplification", "Amplificación digital máxima"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int(maximumBoostDB.rounded())) dB")
                        .font(.headline).foregroundStyle(maximumBoostDB > 10 ? .orange : .green)
                }

                Slider(value: $maximumBoostDB, in: 0 ... 20, step: 1)
                    .tint(.green)
                    .disabled(!hasBilateralProfile)
                HStack {
                    Text("0 dB")
                    Spacer()
                    Text("20 dB")
                }
                .font(.caption).foregroundStyle(.secondary)

                Chart {
                    ForEach(audio.bands) { band in
                        LineMark(
                            x: .value("Frequency", band.frequencyLabel),
                            y: .value("Left gain", band.leftGainDB),
                            series: .value("Ear", "Left")
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(x: .value("Frequency", band.frequencyLabel), y: .value("Left gain", band.leftGainDB))
                            .foregroundStyle(.blue)

                        LineMark(
                            x: .value("Frequency", band.frequencyLabel),
                            y: .value("Right gain", band.rightGainDB),
                            series: .value("Ear", "Right")
                        )
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(x: .value("Frequency", band.frequencyLabel), y: .value("Right gain", band.rightGainDB))
                            .foregroundStyle(.red)

                        RuleMark(y: .value("Flat", 0))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .chartYScale(domain: 0 ... 20)
                .chartYAxis {
                    AxisMarks(values: [0.0, 5.0, 10.0, 15.0, 20.0]) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.12))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(String(format: "%.0f dB", number))
                            }
                        }
                    }
                }
                .frame(height: 210)

                HStack(spacing: 16) {
                    Label(language.text("Left filter", "Filtro izquierdo"), systemImage: "circle.fill").foregroundStyle(.blue)
                    Label(language.text("Right filter", "Filtro derecho"), systemImage: "circle.fill").foregroundStyle(.red)
                }
                .font(.caption.bold())

                Text(language.text(
                    "Each curve uses a smoothed half-gain estimate of within-ear frequency deviations and is limited by your 0–20 dB setting. Equal headroom is applied in Original and Compensated modes. This is an experimental digital EQ, not a hearing-aid prescription.",
                    "Cada curva usa una estimación suavizada de media ganancia de las desviaciones por frecuencia de cada oído y se limita con tu ajuste de 0–20 dB. Se aplica el mismo margen de seguridad en Original y Compensado. Es un ecualizador digital experimental, no una prescripción de audífono."
                ))
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("Included music", "Música incluida")).font(.title2.bold())
            ForEach(DemoMusicGenre.allCases) { genre in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(genre.displayName(in: language), systemImage: genre.symbol).font(.headline)
                        ForEach(DemoTrack.catalog.filter { $0.genre == genre }) { track in
                            Button {
                                selectedTrack = track
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedTrack == track ? "checkmark.circle.fill" : "play.circle")
                                        .foregroundStyle(selectedTrack == track ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title).foregroundStyle(.primary)
                                        Text(timeString(track.duration)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if track.id != DemoTrack.catalog.filter({ $0.genre == genre }).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func comparisonButton(
        title: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: selected ? "checkmark.circle.fill" : symbol)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? Color.black : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? Color.green : Color.white.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Color.green : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func loadSelectedTrack() {
        audio.load(
            track: selectedTrack,
            pureToneTest: selectedPureToneTest,
            maximumBoostDB: maximumBoostDB
        )
        scrubberTime = 0
    }

    private func applySelectedMeasurements() {
        audio.updateCompensation(pureToneTest: selectedPureToneTest, maximumBoostDB: maximumBoostDB)
    }

    private func normalizeMeasurementSelections() {
        if selectedPureToneSource != "latest",
           !pureToneRecords.contains(where: { $0.id.uuidString == selectedPureToneSource }) {
            selectedPureToneSource = "latest"
        }
    }

    private func recordOptionLabel(_ record: TestRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(record.name) · \(formatter.string(from: record.date))"
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct MeasurementStatus: View {
    let title: String
    let value: String
    let ready: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Image(systemName: ready ? "checkmark.circle.fill" : "circle.dashed")
                Text(value).font(.subheadline.bold())
            }
            .foregroundStyle(ready ? Color.green : Color.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.055)))
    }
}

struct MusicCreditsView: View {
    @EnvironmentObject var model: AppModel

    private var language: TestLanguage { model.selectedLanguage }

    var body: some View {
        List {
            Section {
                Text(language.text(
                    "All bundled recordings were downloaded from the FreePD collection, where they are identified as CC0/public-domain works permitted for use, modification, and redistribution. Playback does not require an internet connection.",
                    "Todas las grabaciones incluidas se descargaron de la colección FreePD, donde se identifican como obras CC0/de dominio público permitidas para uso, modificación y redistribución. No se necesita internet para reproducirlas."
                ))
                Link("FreePD music library", destination: URL(string: "https://en.freepd.cn/music")!)
            } header: {
                Text(language.text("License", "Licencia"))
            }

            ForEach(DemoMusicGenre.allCases) { genre in
                Section(genre.displayName(in: language)) {
                    ForEach(DemoTrack.catalog.filter { $0.genre == genre }) { track in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.headline)
                            Text("\(track.sourceName) · \(track.licenseName)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(language.text("Music Credits", "Créditos de música"))
    }
}
