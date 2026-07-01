import XCTest
@testable import Mumble

final class GuardrailTests: XCTestCase {
    func testRejectsEmptyOutput() {
        XCTAssertFalse(Guardrail.accept(input: "hello world", output: ""))
    }

    func testRejectsBalloonOutput() {
        let input = "short text"
        let output = String(repeating: "word ", count: 50)
        XCTAssertFalse(Guardrail.accept(input: input, output: output))
    }

    func testRejectsMetaLeak() {
        XCTAssertFalse(Guardrail.accept(input: "hello", output: "Here is the cleaned text: hello"))
    }

    func testAcceptsNearIdentity() {
        XCTAssertTrue(Guardrail.accept(input: "Let's meet Tuesday actually Friday", output: "Let's meet Friday."))
    }

    func testRejectsSpelledOutTime() {
        let input = "set a reminder for 2:30 pm"
        XCTAssertFalse(Guardrail.accept(input: input, output: "Set a reminder for two thirty in the afternoon."))
    }

    func testRejectsColonToPeriodTime() {
        let input = "set a reminder for 2:30 pm"
        XCTAssertFalse(Guardrail.accept(input: input, output: "Set a reminder for 2.30 pm."))
    }

    func testAcceptsPreservedTime() {
        let input = "set a reminder for 2:30 pm"
        XCTAssertTrue(Guardrail.accept(input: input, output: "Set a reminder for 2:30 pm."))
    }

    func testPreservesNumericContent() {
        XCTAssertTrue(Guardrail.preservesNumericContent(input: "meet at 3", output: "Meet at 3."))
        XCTAssertFalse(Guardrail.preservesNumericContent(input: "meet at 3", output: "Meet at three."))
        XCTAssertFalse(Guardrail.preservesNumericContent(
            input: "set a reminder for 2:30 pm",
            output: "Set a reminder for 2.30 pm."
        ))
    }

    func testTokenOverlap() {
        let overlap = Guardrail.tokenOverlap("hello world", "hello there")
        XCTAssertGreaterThan(overlap, 0.4)
    }
}
