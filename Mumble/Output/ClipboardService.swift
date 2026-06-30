import AppKit

/// Reads/writes the system pasteboard and can snapshot+restore prior contents.
@MainActor
struct ClipboardService {
    private let pasteboard = NSPasteboard.general

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Deep snapshot of all current items so rich content survives a temporary overwrite.
    func snapshot() -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.compactMap { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy.types.isEmpty ? nil : copy
        } ?? []
    }

    func restore(_ items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
