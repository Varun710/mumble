import SwiftUI
import SwiftData

struct NotesView: View {
    @Binding var selection: SidebarItem
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var pendingDeleteID: UUID?
    @State private var pendingClearID: UUID?
    @State private var isConfirmingDelete = false
    @State private var isConfirmingClear = false
    @State private var deletionError: String?

    private var noted: [Recording] {
        recordings.filter { !$0.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(20)
            Divider().overlay(Theme.separator(for: colorScheme))

            if noted.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(noted) { recording in
                            noteCard(recording)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .confirmationDialog("Delete this recording?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Recording", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the transcript, notes, and local audio file from this Mac.")
        }
        .confirmationDialog("Clear this note?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear Note", role: .destructive) { confirmClearNote() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The recording and transcript stay in your library.")
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

    private func noteCard(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(recording.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                Spacer()
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
            }
            Text(recording.notes)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 14) {
                Button { selection = .recording(recording.id) } label: {
                    Label("Open", systemImage: "arrow.up.right")
                }
                Button { ClipboardService().copy(recording.notes) } label: {
                    Label("Copy note", systemImage: "doc.on.doc")
                }
                Button(role: .destructive) { requestClearNote(recording) } label: {
                    Label("Clear", systemImage: "eraser")
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textTertiary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
        .contentShape(Rectangle())
        .onTapGesture { selection = .recording(recording.id) }
        .contextMenu {
            Button { selection = .recording(recording.id) } label: {
                Label("Open Recording", systemImage: "arrow.up.right")
            }
            Button { ClipboardService().copy(recording.notes) } label: {
                Label("Copy Note", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) { requestClearNote(recording) } label: {
                Label("Clear Note", systemImage: "eraser")
            }
            Divider()
            Button(role: .destructive) { requestDelete(recording) } label: {
                Label("Delete Recording", systemImage: "trash")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "note.text").font(.system(size: 40)).foregroundStyle(Theme.textTertiary(for: colorScheme))
            Text("No notes yet").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.textSecondary(for: colorScheme))
            Text("Open a recording and add notes to see them here.")
                .font(.system(size: 12)).foregroundStyle(Theme.textTertiary(for: colorScheme))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestClearNote(_ recording: Recording) {
        pendingClearID = recording.id
        isConfirmingClear = true
    }

    private func confirmClearNote() {
        guard let pendingClearID,
              let recording = recordings.first(where: { $0.id == pendingClearID }) else {
            return
        }
        recording.notes = ""
        try? context.save()
        self.pendingClearID = nil
    }

    private func requestDelete(_ recording: Recording) {
        pendingDeleteID = recording.id
        isConfirmingDelete = true
    }

    private func confirmDelete() {
        guard let pendingDeleteID,
              let recording = recordings.first(where: { $0.id == pendingDeleteID }) else {
            return
        }
        do {
            try RecordingDeletion.delete(recording, in: context)
            if selection == .recording(pendingDeleteID) { selection = .notes }
            self.pendingDeleteID = nil
        } catch {
            deletionError = error.localizedDescription
        }
    }
}
