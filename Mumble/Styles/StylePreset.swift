import Foundation

enum StylePreset: String, CaseIterable, Identifiable, Sendable, Codable {
    case neutral
    case formal
    case email
    case code
    case casual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .neutral: return "Neutral"
        case .formal: return "Formal"
        case .email: return "Email"
        case .code: return "Code"
        case .casual: return "Casual"
        }
    }

    var instruction: String {
        switch self {
        case .neutral:
            return ""
        case .formal:
            return "Use formal tone: full sentences, no contractions, no slang."
        case .email:
            return "Format for email: professional tone, clear paragraph breaks, greeting/sign-off awareness."
        case .code:
            return "Code mode: preserve symbols and identifiers literally. Do not prose-format. Keep tokens like dot, open paren, underscore as spoken symbols."
        case .casual:
            return "Casual tone: contractions OK, light touch, conversational."
        }
    }
}
