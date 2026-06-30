import SwiftUI
import SwiftData

struct NotesView: View {
    @Binding var selection: SidebarItem
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

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
                            Button(action: { selection = .recording(recording.id) }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(recording.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary(for: colorScheme))
                                    Text(recording.notes)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary(for: colorScheme))
                                        .lineLimit(3)
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
                    }
                    .padding(16)
                }
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
}
