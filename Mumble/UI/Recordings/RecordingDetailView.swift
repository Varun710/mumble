import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    let recordingID: UUID
    @Binding var selection: SidebarItem
    @Environment(\.modelContext) private var context
    @Query private var recordings: [Recording]
    @State private var player = TranscriptPlayer()
    @State private var isEditingTitle = false
    @State private var draftTitle = ""

    init(recordingID: UUID, selection: Binding<SidebarItem>) {
        self.recordingID = recordingID
        self._selection = selection
        _recordings = Query(filter: #Predicate<Recording> { $0.id == recordingID })
    }

    private var recording: Recording? { recordings.first }

    var body: some View {
        Group {
            if let recording {
                content(recording)
            } else {
                missing
            }
        }
        .background(Theme.windowBackground)
        .onAppear { player.load(url: recording?.audioURL) }
        .onChange(of: recordingID) { _, _ in player.load(url: recording?.audioURL) }
        .onDisappear { player.stop() }
    }

    private func content(_ recording: Recording) -> some View {
        VStack(spacing: 0) {
            headerBar(recording)
            Divider().overlay(Theme.separator)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    waveformSection(recording)
                    playbackControls(recording)
                    transcriptSection(recording)
                    notesSection(recording)
                }
                .padding(24)
            }
        }
    }

    private func headerBar(_ recording: Recording) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if isEditingTitle {
                    TextField("Title", text: $draftTitle, onCommit: { commitTitle(recording) })
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: 360)
                } else {
                    HStack(spacing: 8) {
                        Text(recording.title)
                            .font(.system(size: 18, weight: .semibold))
                        Button { draftTitle = recording.title; isEditingTitle = true } label: {
                            Image(systemName: "pencil").font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textTertiary)
                    }
                }
                Text("\(recording.createdAt.formatted(date: .abbreviated, time: .shortened))  ·  \(durationLabel(recording.duration))  ·  Local only")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button { copyTranscript(recording) } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .help("Copy transcript")

            Button(role: .destructive) { delete(recording) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .help("Delete recording")
        }
        .padding(20)
    }

    private func waveformSection(_ recording: Recording) -> some View {
        Group {
            if recording.waveform.isEmpty {
                RoundedRectangle(cornerRadius: 10).fill(Theme.cardBackground).frame(height: 80)
                    .overlay(Text("No waveform").font(.system(size: 12)).foregroundStyle(Theme.textTertiary))
            } else {
                WaveformBars(samples: recording.waveform, progress: player.progress, height: 80) { fraction in
                    player.seek(fraction: fraction)
                }
                .overlay(marksOverlay(recording))
            }
        }
    }

    private func marksOverlay(_ recording: Recording) -> some View {
        let total = player.hasAudio ? player.duration : recording.duration
        return GeometryReader { geo in
            ForEach(Array(recording.marks.enumerated()), id: \.offset) { _, mark in
                if total > 0 {
                    Rectangle()
                        .fill(Theme.recording)
                        .frame(width: 2)
                        .position(x: geo.size.width * CGFloat(mark / total), y: geo.size.height / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func playbackControls(_ recording: Recording) -> some View {
        HStack(spacing: 18) {
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(!player.hasAudio)

            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                    Button("\(rateLabel(r))×") { player.rate = Float(r) }
                }
            } label: {
                Text("\(rateLabel(Double(player.rate)))×")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 42)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(!player.hasAudio)

            Button { player.skip(by: -10) } label: { Image(systemName: "gobackward.10") }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary).disabled(!player.hasAudio)
            Button { player.skip(by: 10) } label: { Image(systemName: "goforward.10") }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary).disabled(!player.hasAudio)

            Button { addMark(recording) } label: {
                Label("Mark", systemImage: "bookmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .disabled(!player.hasAudio)
            .help("Add a mark at the current time")

            Spacer()

            Text("\(timeLabel(player.currentTime)) / \(timeLabel(player.hasAudio ? player.duration : recording.duration))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func transcriptSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            if recording.segments.isEmpty {
                Text(recording.transcript.isEmpty ? "No transcript available." : recording.transcript)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(recording.segments.sorted(by: { $0.start < $1.start })) { segment in
                    segmentRow(segment)
                }
            }
        }
    }

    private func segmentRow(_ segment: Segment) -> some View {
        let isActive = player.currentTime >= segment.start && player.currentTime < segment.end && player.isPlaying
        return Button(action: { player.seek(to: segment.start) }) {
            HStack(alignment: .top, spacing: 14) {
                Text(segment.timestampLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 42, alignment: .leading)
                    .padding(.top, 2)
                Text(segment.text)
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? Theme.accent : Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isActive ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func notesSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            TextEditor(text: Binding(
                get: { recording.notes },
                set: { recording.notes = $0; try? context.save() }
            ))
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: 90)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                if recording.notes.isEmpty {
                    Text("Add a note…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder").font(.system(size: 36)).foregroundStyle(Theme.textTertiary)
            Text("Recording not found").foregroundStyle(Theme.textSecondary)
            Button("Back to recordings") { selection = .recordings }.buttonStyle(.plain).foregroundStyle(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func commitTitle(_ recording: Recording) {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { recording.title = trimmed; try? context.save() }
        isEditingTitle = false
    }

    private func addMark(_ recording: Recording) {
        recording.marks.append(player.currentTime)
        try? context.save()
    }

    private func copyTranscript(_ recording: Recording) {
        ClipboardService().copy(recording.transcript)
    }

    private func delete(_ recording: Recording) {
        player.stop()
        if let url = recording.audioURL { try? FileManager.default.removeItem(at: url) }
        context.delete(recording)
        try? context.save()
        selection = .recordings
    }

    private func durationLabel(_ d: TimeInterval) -> String { String(format: "%01d:%02d", Int(d) / 60, Int(d) % 60) }
    private func timeLabel(_ d: TimeInterval) -> String { String(format: "%02d:%02d", Int(d) / 60, Int(d) % 60) }
    private func rateLabel(_ r: Double) -> String { r == floor(r) ? String(format: "%.0f", r) : String(format: "%.2g", r) }
}
