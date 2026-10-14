import SwiftUI

struct BoardView: View {
    @ObservedObject var viewModel: TaskBoardViewModel

    var body: some View {
        VStack(spacing: 12) {
            header

            HStack(spacing: 10) {
                StatusColumn(status: .todo, viewModel: viewModel)
                StatusColumn(status: .processing, viewModel: viewModel)
                StatusColumn(status: .done, viewModel: viewModel)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .animation(.snappy(duration: 0.22), value: viewModel.tasks)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Bar To Do")
                    .font(.system(size: 13, weight: .semibold))
                Text(viewModel.currentTaskTitle.map { "Current: \($0)" } ?? "Queue is clear")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.snappy(duration: 0.22)) { viewModel.advance() }
            } label: {
                Label("Next", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)
            .disabled(!viewModel.canAdvance)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Advance queue (⌘↩)")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Quit Bar To Do")
            .accessibilityLabel("Quit Bar To Do")
        }
        .padding(.horizontal, 2)
        .frame(height: 32)
    }
}
