import XCTest
@testable import Mumble

final class SnippetExpanderTests: XCTestCase {
    func testExpandsTriggerPhrase() {
        let store = SnippetStore(entries: [
            Snippet(trigger: "my email address", expansion: "sid@example.com"),
        ])
        let expander = SnippetExpander(store: store)
        let result = expander.expand("Please send it to my email address thanks")
        XCTAssertTrue(result.contains("sid@example.com"))
    }

    func testLeavesNonTriggersUntouched() {
        let store = SnippetStore(entries: [
            Snippet(trigger: "my email address", expansion: "sid@example.com"),
        ])
        let expander = SnippetExpander(store: store)
        let result = expander.expand("hello world")
        XCTAssertEqual(result, "hello world")
    }
}
