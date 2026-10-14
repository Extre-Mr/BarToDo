import SwiftUI

struct AdvanceButton: View {
    @ObservedObject var viewModel: TaskBoardViewModel

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) { viewModel.advance() }
        } label: {
            Label(viewModel.advanceTitle, systemImage: "arrow.right.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: .command)
        .foregroundStyle(viewModel.canAdvance ? .white : .secondary)
        .background(Color.orange.opacity(viewModel.canAdvance ? 0.24 : 0.07), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(viewModel.canAdvance ? 0.38 : 0.08)))
        .disabled(!viewModel.canAdvance)
        .accessibilityHint("Completes the first processing task and pulls the next to-do")
    }
}
