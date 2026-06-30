import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Binding var selection: SidebarItem
    @Environment(\.modelContext) private var context
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var search = ""

    private var filtered: [Recording] {
        guard !search.isEmpty else { return recordings }
        return recordings.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.transcript.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator)
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Theme.windowBackground)
    }

    private var header: some View {
        HStack {
            Text("Recordings")
                .font(.system(size: 18, weight: .semibold))
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                TextField("Search transcripts…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 200)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(20)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filtered) { recording in
                    row(recording)
                }
            }
            .padding(16)
        }
    }

    private func row(_ recording: Recording) -> some View {
        Button(action: { selection = .recording(recording.id) }) {
            HStack(spacing: 14) {
                Image(systemName: recording.source == "dictation" ? "text.cursor" : "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(recording.transcript.isEmpty ? "No transcript" : recording.transcript)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text(durationLabel(recording.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .flowCard(padding: 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { delete(recording) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text(search.isEmpty ? "No recordings yet" : "No matches")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if search.isEmpty {
                Text("Press the record orb or hold your dictation hotkey to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func delete(_ recording: Recording) {
        if let url = recording.audioURL { try? FileManager.default.removeItem(at: url) }
        context.delete(recording)
        try? context.save()
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
