import SwiftUI

/// Visually-complete but disabled AI command list. Wired to a local LLM in a later phase.
struct AICommandsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    struct Command: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let shortcut: String
    }

    private let commands: [Command] = [
        .init(title: "Summarize", icon: "doc.text", shortcut: "⌘1"),
        .init(title: "Extract Action Items", icon: "checklist", shortcut: "⌘2"),
        .init(title: "Find Decisions", icon: "signpost.right", shortcut: "⌘3"),
        .init(title: "Generate Notes", icon: "note.text", shortcut: "⌘4"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI Commands")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Spacer()
                Text("Soon")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
            }

            ForEach(commands) { command in
                HStack(spacing: 10) {
                    Image(systemName: command.icon)
                        .font(.system(size: 12))
                        .frame(width: 16)
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    Text(command.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    Spacer()
                    Text(command.shortcut)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme).opacity(0.6))
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                Text("Custom Prompt…")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                Spacer()
            }
            .padding(.top, 4)
        }
        .contentCard(cornerRadius: 16)
        .opacity(0.8)
        .help("Local AI commands are coming in a future update.")
    }
}
