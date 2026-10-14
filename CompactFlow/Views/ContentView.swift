import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TaskBoardViewModel

    var body: some View {
        BoardView(viewModel: viewModel)
            .background(Color(nsColor: .windowBackgroundColor))
            .alert("Compact Flow", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
    }
}
