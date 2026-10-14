import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    @ObservedObject var viewModel: TaskBoardViewModel
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            if isEditing {
                TextField("Task title", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2)
                    .focused($editFocused)
                    .onSubmit(commitEdit)
                    .onExitCommand(perform: cancelEdit)
            } else {
                Text(task.title)
                    .font(.system(size: 12.5))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(task.title)
            }

            Button(role: .destructive) { viewModel.deleteTask(id: task.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovering && !isEditing ? 1 : 0)
            .allowsHitTesting(isHovering && !isEditing)
            .accessibilityHidden(!isHovering || isEditing)
            .accessibilityLabel("Delete \(task.title)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(borderColor))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: beginEdit)
        .draggable(viewModel.dragPayload(for: task.id)) {
            let count = viewModel.selectedTaskIDs.contains(task.id) ? viewModel.selectedTaskIDs.count : 1
            Text(count > 1 ? "\(count) tasks" : task.title)
                .lineLimit(1).padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .contextMenu {
            Button("Edit", action: beginEdit)
            Menu("Move to") {
                ForEach(TaskStatus.allCases.filter { $0 != task.status }) { status in
                    Button(status.title) { viewModel.moveTask(id: task.id, to: status) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { viewModel.deleteTask(id: task.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), \(task.status.title)")
    }

    private var accent: Color {
        switch task.status { case .todo: .gray; case .processing: .orange; case .done: .green }
    }

    private var cardBackground: Color {
        if viewModel.selectedTaskIDs.contains(task.id) {
            return Color.accentColor.opacity(0.22)
        }
        if isHovering { return Color(nsColor: .selectedContentBackgroundColor).opacity(0.16) }
        if task.status == .processing { return Color.orange.opacity(0.09) }
        return Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }

    private var borderColor: Color {
        if viewModel.selectedTaskIDs.contains(task.id) { return Color.accentColor.opacity(0.9) }
        return task.status == .processing ? Color.orange.opacity(0.22) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private func beginEdit() {
        draft = task.title
        isEditing = true
        editFocused = true
    }

    private func commitEdit() {
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { viewModel.updateTask(id: task.id, title: clean) }
        isEditing = false
    }

    private func cancelEdit() { isEditing = false }
}
