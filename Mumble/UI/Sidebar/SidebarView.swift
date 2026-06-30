import SwiftUI
import SwiftData

struct SidebarView: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
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
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 22)
            Spacer(minLength: 0)
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
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary(for: colorScheme))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.textPrimary(for: colorScheme) : Theme.textSecondary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
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
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(recording.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary(for: colorScheme))
                        .lineLimit(1)
                    Text(relativeLabel(recording.createdAt) + "  ·  " + durationLabel(recording.duration))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(status == .ready ? Theme.success : (status.isBusy ? Theme.accent : Theme.textTertiary(for: colorScheme)))
                        .frame(width: 6, height: 6)
                    Text(status.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(status == .ready ? Theme.success : Theme.textSecondary(for: colorScheme))
                }
            }
            Text("WhisperKit (\(env.modelManager.displayName(for: env.settings.modelName)))")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
        }
        .contentCard(padding: 12, cornerRadius: 12)
        .padding(.horizontal, 12)
    }

    private var footer: some View {
        Text("All data stays on your Mac")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTertiary(for: colorScheme))
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
