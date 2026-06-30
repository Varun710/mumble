import SwiftUI

/// The small recording capsule shown during push-to-talk dictation.
/// Floats above all apps with liquid glass styling.
struct OverlayView: View {
    @Bindable var model: OverlayModel
    @State private var appear = false

    var body: some View {
        DictationStatusPill(phase: pillPhase)
            .scaleEffect(appear ? 1 : 0.9)
            .opacity(appear ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appear = true }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.phase)
    }

    private var pillPhase: DictationPillPhase {
        switch model.phase {
        case .listening:
            return .ready
        case .transcribing:
            return .transcribing(modelName: model.modelName)
        case .done:
            return .pasted
        case .error:
            return .error(model.message)
        }
    }
}
