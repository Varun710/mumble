import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            newRecordingButton
            navItems
            recentSection
            Spacer(minLength: 8)
            engineStatus
            footer
        }
        .padding(.vertical, 12)
        .background(Theme.sidebarBackground)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("Flow")
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var newRecordingButton: some View {
        Button(action: { env.recorder.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: env.recorder.isRecording ? "stop.fill" : "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(env.recorder.isRecording ? "Stop Recording" : "New Recording")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("⌘N")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }

    private var navItems: some View {
        VStack(spacing: 2) {
            navRow(.home, "Home", "house")
            navRow(.recordings, "Recordings", "waveform.circle")
            navRow(.notes, "Notes", "note.text")
            navRow(.settings, "Settings", "gearshape")
        }
        .padding(.horizontal, 8)
    }

    private func navRow(_ item: SidebarItem, _ title: String, _ icon: String) -> some View {
        let isSelected = selection == item
        return Button(action: { selection = item }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 4)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(recordings.prefix(8)) { recording in
                        recentRow(recording)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func recentRow(_ recording: Recording) -> some View {
        let isSelected = selection == .recording(recording.id)
        return Button(action: { selection = .recording(recording.id) }) {
            HStack(spacing: 9) {
                Image(systemName: recording.source == "dictation" ? "text.cursor" : "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(recording.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(relativeLabel(recording.createdAt) + "  ·  " + durationLabel(recording.duration))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var engineStatus: some View {
        let status = env.transcription.status
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Local Engine")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(status == .ready ? Theme.success : (status.isBusy ? Theme.accent : Theme.textTertiary))
                        .frame(width: 6, height: 6)
                    Text(status.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(status == .ready ? Theme.success : Theme.textSecondary)
                }
            }
            Text("WhisperKit (\(env.modelManager.displayName(for: env.settings.modelName)))")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var footer: some View {
        Text("All data stays on your Mac")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 16)
            .padding(.top, 10)
    }

    private func relativeLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
