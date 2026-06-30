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
    @State private var pendingDeleteIDs = Set<UUID>()
    @State private var isConfirmingDelete = false
    @State private var deletionError: String?
    @FocusState private var searchFocused: Bool

    private var filtered: [Recording] {
        guard !search.isEmpty else { return recordings }
        return recordings.filter {
            $0.title.localizedCaseInsensitiveContains(search)
                || $0.transcript.localizedCaseInsensitiveContains(search)
        }
    }

    private var visibleIDs: Set<UUID> {
        Set(filtered.map(\.id))
    }

    private var allVisibleSelected: Bool {
        !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }

    private var isSelectionActive: Bool {
        isSelecting || !selectedIDs.isEmpty
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
        .onChange(of: search) { _, _ in
            if isSelectionActive { selectedIDs.formIntersection(visibleIDs) }
        }
        .confirmationDialog(deleteDialogTitle, isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(deleteDialogButtonTitle, role: .destructive) { confirmDelete() }
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
        .onDeleteCommand {
            if !searchFocused && !selectedIDs.isEmpty { requestDeleteSelected() }
        }
        .onExitCommand {
            if isSelectionActive { exitSelection() }
        }
        .focusedSceneValue(\.recordingLibraryCommandContext, RecordingLibraryCommandContext(
            selectAll: selectAllVisible,
            deleteSelection: requestDeleteSelected,
            canSelectAll: !searchFocused && !visibleIDs.isEmpty,
            canDelete: !searchFocused && !selectedIDs.isEmpty
        ))
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Recordings")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                searchField
                if !isSelectionActive {
                    Button {
                        searchFocused = false
                        withAnimation(.easeInOut(duration: 0.16)) { isSelecting = true }
                    } label: {
                        Label("Select", systemImage: "checkmark.circle")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
                    .disabled(filtered.isEmpty)
                }
            }
            .padding(20)

            if isSelectionActive {
                selectionBar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelectionActive)
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button("Done") { exitSelection() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text(selectedIDs.isEmpty ? "Choose recordings" : "\(selectedIDs.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

            Spacer()

            Button(allVisibleSelected ? "Deselect All" : "Select All") {
                toggleSelectAllVisible()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(visibleIDs.isEmpty ? Theme.textTertiary(for: colorScheme) : Theme.accent)
            .disabled(visibleIDs.isEmpty)

            Button(role: .destructive) { requestDeleteSelected() } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.recording)
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.cardBackground(for: colorScheme))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.separator(for: colorScheme))
                .frame(height: 1)
        }
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
                .focused($searchFocused)
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
                if isSelectionActive {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary(for: colorScheme))
                        .frame(width: 20)
                }
                Image(systemName: recording.source == "dictation" ? "text.cursor" : "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
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
            .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay {
                if isSelectionActive && isSelected {
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.45), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelectionActive {
                Button(role: .destructive) { requestDelete(recording) } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private func handleRowTap(_ recording: Recording) {
        if isSelectionActive {
            withAnimation(.easeInOut(duration: 0.12)) {
                if selectedIDs.contains(recording.id) {
                    selectedIDs.remove(recording.id)
                } else {
                    selectedIDs.insert(recording.id)
                }
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

    private func toggleSelectAllVisible() {
        if allVisibleSelected {
            selectedIDs.subtract(visibleIDs)
        } else {
            selectAllVisible()
        }
    }

    private func selectAllVisible() {
        guard !visibleIDs.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            isSelecting = true
            selectedIDs.formUnion(visibleIDs)
        }
    }

    private func exitSelection() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isSelecting = false
            selectedIDs.removeAll()
        }
    }

    private func requestDeleteSelected() {
        requestDelete(ids: selectedIDs)
    }

    private func requestDelete(_ recording: Recording) {
        requestDelete(ids: [recording.id])
    }

    private func requestDelete(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        pendingDeleteIDs = ids
        isConfirmingDelete = true
    }

    private func confirmDelete() {
        let ids = pendingDeleteIDs
        let toDelete = recordings.filter { ids.contains($0.id) }
        do {
            try RecordingDeletion.delete(toDelete, in: context)
            if case .recording(let id) = selection, ids.contains(id) {
                selection = .recordings
            }
            selectedIDs.subtract(ids)
            pendingDeleteIDs.removeAll()
            if selectedIDs.isEmpty {
                withAnimation(.easeInOut(duration: 0.16)) { isSelecting = false }
            }
        } catch {
            deletionError = error.localizedDescription
        }
    }

    private var deleteDialogTitle: String {
        pendingDeleteIDs.count == 1 ? "Delete this recording?" : "Delete \(pendingDeleteIDs.count) recordings?"
    }

    private var deleteDialogButtonTitle: String {
        pendingDeleteIDs.count == 1 ? "Delete Recording" : "Delete Recordings"
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(duration) / 60, Int(duration) % 60)
    }
}
