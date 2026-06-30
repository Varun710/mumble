import SwiftUI
import SwiftData

struct RecordingsListView: View {
    @Binding var selection: SidebarItem
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var search = ""
    @State private var isSelecting = false
    @State private var selectedIDs = Set<UUID>()

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
            Divider().overlay(Theme.separator(for: colorScheme))
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
    }

    private var header: some View {
        HStack {
            if isSelecting {
                Button("Cancel") {
                    isSelecting = false
                    selectedIDs.removeAll()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)

                Text("\(selectedIDs.count) selected")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))

                Spacer()

                Button(role: .destructive) { deleteSelected() } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedIDs.isEmpty ? Theme.textTertiary(for: colorScheme) : Theme.recording)
                .disabled(selectedIDs.isEmpty)
            } else {
                Text("Recordings")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button("Select") { isSelecting = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                searchField
            }
        }
        .padding(20)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
            TextField("Search transcripts…", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(width: 200)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        let isSelected = selectedIDs.contains(recording.id)
        return Button(action: { handleRowTap(recording) }) {
            HStack(spacing: 14) {
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary(for: colorScheme))
                        .frame(width: 28)
                } else {
                    Image(systemName: recording.source == "dictation" ? "text.cursor" : "waveform")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary(for: colorScheme))
                        .lineLimit(1)
                    Text(recording.transcript.isEmpty ? "No transcript" : recording.transcript)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    Text(durationLabel(recording.duration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentCard(padding: 0)
            .overlay {
                if isSelecting && isSelected {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelecting {
                Button(role: .destructive) { delete(recording) } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private func handleRowTap(_ recording: Recording) {
        if isSelecting {
            if selectedIDs.contains(recording.id) {
                selectedIDs.remove(recording.id)
            } else {
                selectedIDs.insert(recording.id)
            }
        } else {
            selection = .recording(recording.id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
            Text(search.isEmpty ? "No recordings yet" : "No matches")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
            if search.isEmpty {
                Text("Press the record orb or hold Right Option (⌥) to get started.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func deleteSelected() {
        let toDelete = recordings.filter { selectedIDs.contains($0.id) }
        for recording in toDelete { delete(recording) }
        selectedIDs.removeAll()
        isSelecting = false
    }

    private func delete(_ recording: Recording) {
        if let url = recording.audioURL { try? FileManager.default.removeItem(at: url) }
        context.delete(recording)
        try? context.save()
        selectedIDs.remove(recording.id)
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
