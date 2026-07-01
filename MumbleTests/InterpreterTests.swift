import XCTest
@testable import Mumble

final class InterpreterTests: XCTestCase {
    func testDisabledFallsBackToTextCleaner() async {
        let cleaner = TextCleaner(options: .init(
            removeFillers: true,
            collapseRepeats: true,
            normalizeSpacing: true,
            autoPunctuation: false,
            applyDictionary: false,
            dictionary: []
        ))
        let interpreter = Interpreter(backend: nil, cleanup: cleaner)
        let input = InterpretInput(plainText: "um hello world")
        let output = await interpreter.interpret(input, style: .neutral, enabled: false)
        XCTAssertEqual(output, "hello world")
    }

    func testUnavailableBackendFallsBackWhenEnabled() async {
        let cleaner = TextCleaner(options: .init(
            removeFillers: false,
            collapseRepeats: false,
            normalizeSpacing: true,
            autoPunctuation: false,
            applyDictionary: false,
            dictionary: []
        ))
        let interpreter = Interpreter(backend: UnavailableInterpreterBackend(), cleanup: cleaner)
        let input = InterpretInput(plainText: "hello world")
        let output = await interpreter.interpret(input, style: .neutral, enabled: true)
        XCTAssertEqual(output, "hello world")
    }
}
