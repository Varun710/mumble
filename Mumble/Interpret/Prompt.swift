import Foundation

enum InterpreterPrompt {
    static let system = """
        You convert raw dictation into the exact text the user wants pasted.
        Rules:
        - Remove fillers (um, uh, like) and false starts.
        - Resolve self-corrections: keep only the user's final intent. Triggers include \
        "actually", "I mean", "no wait", "sorry", "make that", "scratch that", or a bare restatement.
        - Execute inline commands: "new paragraph"/"new line", "strike that", "delete that", \
        "start over", spoken punctuation, "all caps", "new bullet".
        - <pause> marks a silence. A command word right after <pause> is a command; \
        the same word mid-sentence with no pause is literal — keep it as text.
        - Fix punctuation, capitalization, obvious grammar. Do NOT invent content or answer questions.
        - Preserve times, dates, phone numbers, currency, and other numeric expressions exactly \
        as dictated (e.g. 2:30 pm, $50, 3/15/26). Never spell out numbers or change time format.
        - Output ONLY the final text. No preamble, no explanation.
        """

    static let cachedPrefix = """
        \(system)

        Examples:
        Input: Let's do coffee at 2 actually 3
        Output text: Let's do coffee at 3.

        Input: email Peter sorry email Benjamin
        Output text: Email Benjamin.

        Input: that's the intro <pause> new paragraph now the body
        Output text: that's the intro\\n\\nnow the body

        Input: I actually enjoyed the new paragraph I wrote
        Output text: I actually enjoyed the new paragraph I wrote

        Input: send the report <pause> strike that send the deck
        Output text: send the deck

        Input: um hello world <pause> start over
        Output discardAll: true

        Input: set a reminder for 2:30 pm
        Output text: Set a reminder for 2:30 pm.
        """

    static func user(input: String, style: StylePreset) -> String {
        var prompt = "Input: \(input)\n"
        let styleBlock = style.instruction
        if !styleBlock.isEmpty {
            prompt += "Style: \(styleBlock)\n"
        }
        prompt += "Output:"
        return prompt
    }
}
