import XCTest
@testable import Mumble

final class PauseMarkersTests: XCTestCase {
    func testInsertsPauseOnLongGap() {
        let words = [
            ASRWord(text: "hello", start: 0.0, end: 0.3),
            ASRWord(text: "world", start: 0.9, end: 1.1),
        ]
        let result = PauseMarkers.inject(words: words)
        XCTAssertTrue(result.contains("<pause>"))
        XCTAssertTrue(result.contains("hello"))
        XCTAssertTrue(result.contains("world"))
    }

    func testSkipsPauseOnShortGap() {
        let words = [
            ASRWord(text: "hello", start: 0.0, end: 0.3),
            ASRWord(text: "world", start: 0.5, end: 0.8),
        ]
        let result = PauseMarkers.inject(words: words)
        XCTAssertFalse(result.contains("<pause>"))
    }

    func testEmptyWordsReturnsEmpty() {
        XCTAssertEqual(PauseMarkers.inject(words: []), "")
    }

    func testFallsBackToPlainTextWithoutWords() {
        let asr = InterpretInput(plainText: "plain text", words: [])
        XCTAssertEqual(PauseMarkers.inject(asr), "plain text")
    }
}
