import AppKit
import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    let recordingID: UUID
    let returnRoute: SidebarItem
    @Binding var selection: SidebarItem
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query private var recordings: [Recording]
    @State private var player = TranscriptPlayer()
    @State private var isEditingTitle = false
    @State private var draftTitle = ""
    @State private var isConfirmingDelete = false
    @State private var deletionError: String?
    @State private var isBackHovering = false

    init(recordingID: UUID, selection: Binding<SidebarItem>, returnRoute: SidebarItem = .recordings) {
        self.recordingID = recordingID
        self.returnRoute = returnRoute
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
        .onAppear { player.load(url: recording?.audioURL) }
        .onChange(of: recordingID) { _, _ in
            player.load(url: recording?.audioURL)
            isEditingTitle = false
            draftTitle = ""
        }
        .onDisappear { player.stop() }
        .confirmationDialog("Delete this recording?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Recording", role: .destructive) {
                if let recording { delete(recording) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the transcript, notes, and local audio file from this Mac.")
        }
        .alert("Couldn't delete recording", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "")
        }
    }

    private func content(_ recording: Recording) -> some View {
        VStack(spacing: 0) {
            headerBar(recording)
            Divider().overlay(Theme.separator(for: colorScheme))
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
            Button { goBack() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(returnRouteTitle)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(isBackHovering ? Theme.hover(for: colorScheme) : Color.clear, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Back to \(returnRouteTitle.lowercased())")
            .onHover { isBackHovering = $0 }
            .animation(.easeInOut(duration: 0.14), value: isBackHovering)

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
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    }
                }
                Text("\(recording.createdAt.formatted(date: .abbreviated, time: .shortened))  ·  \(durationLabel(recording.duration))  ·  Local only")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
            }
            Spacer()
            Button { copyTranscript(recording) } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary(for: colorScheme))
            .help("Copy transcript")

            Button(role: .destructive) { isConfirmingDelete = true } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary(for: colorScheme))
            .help("Delete recording")
        }
        .padding(20)
    }

    private func waveformSection(_ recording: Recording) -> some View {
        Group {
            if recording.waveform.isEmpty {
                RoundedRectangle(cornerRadius: Theme.cornerRadius).fill(Theme.cardBackground(for: colorScheme)).frame(height: 80)
                    .overlay(Text("No waveform").font(.system(size: 12)).foregroundStyle(Theme.textTertiary(for: colorScheme)))
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

            BelowDropdown(minWidth: 78) {
                Text("\(rateLabel(Double(player.rate)))×")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 34)
            } content: { dismiss in
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                    Button {
                        player.rate = Float(r)
                        dismiss()
                    } label: {
                        HStack {
                            Text("\(rateLabel(r))×")
                            Spacer()
                            if Float(r) == player.rate {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary(for: colorScheme))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Float(r) == player.rate ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!player.hasAudio)

            Button { player.skip(by: -10) } label: { Image(systemName: "gobackward.10") }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary(for: colorScheme)).disabled(!player.hasAudio)
            Button { player.skip(by: 10) } label: { Image(systemName: "goforward.10") }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary(for: colorScheme)).disabled(!player.hasAudio)

            Button { addMark(recording) } label: {
                Label("Mark", systemImage: "bookmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary(for: colorScheme))
            .disabled(!player.hasAudio)
            .help("Add a mark at the current time")

            Spacer()

            Text("\(timeLabel(player.currentTime)) / \(timeLabel(player.hasAudio ? player.duration : recording.duration))")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
        }
        .padding(.vertical, 4)
    }

    private func transcriptSection(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

            if recording.segments.isEmpty {
                Text(recording.transcript.isEmpty ? "No transcript available." : recording.transcript)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
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
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    .frame(width: 42, alignment: .leading)
                    .padding(.top, 2)
                Text(segment.text)
                    .font(.system(size: 14))
                    .foregroundStyle(isActive ? Theme.accent : Theme.textPrimary(for: colorScheme))
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
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
            FocusedNotesEditor(text: Binding(
                get: { recording.notes },
                set: { recording.notes = $0; try? context.save() }
            ), colorScheme: colorScheme)
            .id(recordingID)
            .frame(minHeight: 128)
            .contentCard(padding: 0, cornerRadius: Theme.cornerRadius)
            .overlay(alignment: .topLeading) {
                if recording.notes.isEmpty {
                    Text("Add a note…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var missing: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.folder").font(.system(size: 36)).foregroundStyle(Theme.textTertiary(for: colorScheme))
            Text("Recording not found").foregroundStyle(Theme.textSecondary(for: colorScheme))
            Button("Back to \(returnRouteTitle.lowercased())") { goBack() }.buttonStyle(.plain).foregroundStyle(Theme.accent)
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
        do {
            try RecordingDeletion.delete(recording, in: context)
            goBack()
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private func goBack() {
        selection = returnRoute
    }

    private var returnRouteTitle: String {
        switch returnRoute {
        case .home: return "Home"
        case .notes: return "Notes"
        case .settings, .recordings, .recording: return "Recordings"
        }
    }

    private func durationLabel(_ d: TimeInterval) -> String { String(format: "%01d:%02d", Int(d) / 60, Int(d) % 60) }
    private func timeLabel(_ d: TimeInterval) -> String { String(format: "%02d:%02d", Int(d) / 60, Int(d) % 60) }
    private func rateLabel(_ r: Double) -> String { r == floor(r) ? String(format: "%.0f", r) : String(format: "%.2g", r) }
}

private struct FocusedNotesEditor: NSViewRepresentable {
    @Binding var text: String
    let colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.text = $text
        if textView.string != text {
            textView.string = text
        }
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = textColor
        textView.insertionPointColor = accentColor

        guard !context.coordinator.didFocusAtEnd else { return }
        DispatchQueue.main.async {
            guard !context.coordinator.didFocusAtEnd else { return }
            guard let window = textView.window else { return }
            if let firstResponder = window.firstResponder,
               firstResponder !== textView,
               firstResponder is NSTextView {
                return
            }
            window.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
            context.coordinator.didFocusAtEnd = true
        }
    }

    private var textColor: NSColor {
        colorScheme == .dark
            ? NSColor(calibratedRed: 245 / 255, green: 242 / 255, blue: 255 / 255, alpha: 1)
            : NSColor(calibratedRed: 26 / 255, green: 26 / 255, blue: 46 / 255, alpha: 1)
    }

    private var accentColor: NSColor {
        NSColor(calibratedRed: 143 / 255, green: 109 / 255, blue: 255 / 255, alpha: 1)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: NSTextView?
        var didFocusAtEnd = false

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
