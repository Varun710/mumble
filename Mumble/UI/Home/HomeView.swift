import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                hero
                if !recordings.isEmpty {
                    recentGrid
                }
            }
            .padding(28)
        }
        .background(Theme.windowBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 24, weight: .bold))
            Text("Speak naturally. Flow transcribes and cleans it up locally.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var hero: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Push-to-talk dictation")
                    .font(.system(size: 16, weight: .semibold))
                Text("Hold \(shortcutLabel) anywhere to dictate. Release to paste cleaned text into the active app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Button("Start a recording") { env.recorder.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accentGradient)
                .padding(28)
                .background(Theme.cardBackground, in: Circle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.separator))
        )
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

    private var shortcutLabel: String { "⌃⌥Space" }
}

struct RecordingCard: View {
    let recording: Recording
    let action: () -> Void

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
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(recording.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(recording.transcript.isEmpty ? "No transcript" : recording.transcript)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .flowCard()
        }
        .buttonStyle(.plain)
    }

    private var durationLabel: String {
        String(format: "%01d:%02d", Int(recording.duration) / 60, Int(recording.duration) % 60)
    }
}
