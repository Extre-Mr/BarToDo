import SwiftUI

struct AddTaskField: View {
    @ObservedObject var viewModel: TaskBoardViewModel
    @State private var title = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(spacing: 6) {
            TextField("Add a to-do…", text: $title)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit(add)
                .accessibilityLabel("New to-do title")

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(isEmpty)
            .accessibilityLabel("Add task")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator.opacity(0.65)))
        .onReceive(NotificationCenter.default.publisher(for: .focusNewTask)) { _ in focused = true }
    }

    private func add() {
        if viewModel.addTask(title: title) { title = "" }
        focused = true
    }
}
