import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var isHoveringHero = false
    @State private var isHoveringPill = false

    private var showsStatusPill: Bool {
        env.dictation.isMonitoring
            && !env.dictation.isActive
            && (isHoveringHero || isHoveringPill || env.dictation.isHotkeyPressed)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    hero
                    if !recordings.isEmpty {
                        recentGrid
                    }
                }
                .padding(28)
                .padding(.bottom, 72)
            }

            if showsStatusPill {
                DictationStatusPill()
                    .onHover { isHoveringPill = $0 }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 20)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showsStatusPill)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 24, weight: .bold))
            Text("Speak naturally. Mumble transcribes and cleans it up locally.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
        }
    }

    private var hero: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Push-to-talk dictation")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(DictationShortcuts.holdHint) Cleaned text goes into the active app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Button("Start a recording") { env.recorder.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(0.15), lineWidth: 1)
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Theme.accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accentGradient)
                    .padding(28)
                    .background(Theme.cardBackground(for: colorScheme), in: Circle())
            }
        }
        .contentCard(padding: 24, cornerRadius: 20)
        .onHover { hovering in
            if hovering {
                isHoveringHero = true
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(180))
                    if !isHoveringPill { isHoveringHero = false }
                }
            }
        }
    }

    private var recentGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent recordings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("See all") { selection = .recordings }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                ForEach(recordings.prefix(6)) { recording in
                    RecordingCard(recording: recording) { selection = .recording(recording.id) }
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

struct RecordingCard: View {
    let recording: Recording
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: recording.source == "dictation" ? "text.cursor" : "waveform")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text(durationLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                }
                Text(recording.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(recording.transcript.isEmpty ? "No transcript" : recording.transcript)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentCard()
        }
        .buttonStyle(.plain)
    }

    private var durationLabel: String {
        String(format: "%01d:%02d", Int(recording.duration) / 60, Int(recording.duration) % 60)
    }
}
