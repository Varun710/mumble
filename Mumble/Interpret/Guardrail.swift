import Foundation

enum Guardrail: Sendable {
    nonisolated static func accept(input: String, output: String) -> Bool {
        guard !output.isEmpty else { return false }

        let inputCount = max(input.count, 1)
        let ratio = Double(output.count) / Double(inputCount)
        guard ratio > 0.25 && ratio < 1.6 else { return false }

        guard tokenOverlap(input, output) > 0.45 else { return false }

        guard preservesNumericContent(input: input, output: output) else { return false }

        let lowered = output.localizedLowercase
        guard !lowered.contains("here is the") else { return false }
        guard !lowered.contains("here's the") else { return false }

        return true
    }

    nonisolated static func tokenOverlap(_ input: String, _ output: String) -> Double {
        let inputTokens = tokenSet(input)
        let outputTokens = tokenSet(output)
        guard !inputTokens.isEmpty else { return outputTokens.isEmpty ? 1.0 : 0.0 }
        let intersection = inputTokens.intersection(outputTokens).count
        return Double(intersection) / Double(inputTokens.count)
    }

    nonisolated private static func tokenSet(_ text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    /// Rejects LLM output that spells out or reformats dictated numbers/times.
    nonisolated static func preservesNumericContent(input: String, output: String) -> Bool {
        let inputHasDigits = input.contains(where: \.isNumber)
        guard inputHasDigits else { return true }

        // Model spelled out numbers instead of keeping digits.
        guard output.contains(where: \.isNumber) else { return false }

        let inputTimes = timePatterns(in: input)
        if !inputTimes.isEmpty {
            let outputTimes = timePatterns(in: output)
            // Every dictated clock time (e.g. 2:30) must survive in the output.
            for time in inputTimes where !outputTimes.contains(time) {
                return false
            }
        }

        return true
    }

    nonisolated private static func timePatterns(in text: String) -> Set<String> {
        guard let regex = try? NSRegularExpression(pattern: #"\d{1,2}:\d{2}"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        return Set(matches.compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        })
    }
}
