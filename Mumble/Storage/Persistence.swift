import Foundation
import SwiftData

/// Builds the SwiftData container backed by a file in Application Support.
enum Persistence {
    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([Recording.self, Segment.self])
        let config = ModelConfiguration(schema: schema, url: Paths.databaseFile)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // If the store is incompatible (e.g. schema change during early dev), reset it.
            try? FileManager.default.removeItem(at: Paths.databaseFile)
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Unable to create SwiftData container: \(error)")
            }
        }
    }
}
