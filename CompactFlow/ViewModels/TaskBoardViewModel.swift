import Foundation
import SwiftUI

@MainActor
final class TaskBoardViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var errorMessage: String?
    @Published var draggingTaskID: UUID?
    @Published var dropTarget: DropTarget?

    struct DropTarget: Equatable {
        let status: TaskStatus
        let index: Int
    }

    private let repository: TaskRepository

    init(repository: TaskRepository) {
        self.repository = repository
        do {
            tasks = try repository.load()
            normalizeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    convenience init() {
        do {
            try self.init(repository: JSONTaskRepository())
        } catch {
            self.init(repository: InMemoryTaskRepository())
            errorMessage = error.localizedDescription
        }
    }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
            .sorted { lhs, rhs in
                lhs.sortOrder == rhs.sortOrder ? lhs.createdAt < rhs.createdAt : lhs.sortOrder < rhs.sortOrder
            }
    }

    var canAdvance: Bool {
        !tasks(in: .todo).isEmpty || !tasks(in: .processing).isEmpty
    }

    var advanceTitle: String {
        tasks(in: .processing).isEmpty ? "Start Next" : "Complete & Pull Next"
    }

    var currentTaskTitle: String? {
        tasks(in: .processing).first?.title ?? tasks(in: .todo).first?.title
    }

    var menuBarTitle: String {
        guard let title = currentTaskTitle else { return "No Tasks" }
        return title.count > 30 ? String(title.prefix(29)) + "…" : title
    }

    @discardableResult
    func addTask(title: String) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        tasks.append(TaskItem(title: clean, sortOrder: tasks(in: .todo).count))
        persist()
        return true
    }

    func updateTask(id: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = clean
        persist()
    }

    func deleteTask(id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        tasks.removeAll { $0.id == id }
        normalize(task.status)
        persist()
    }

    func clearDone() {
        tasks.removeAll { $0.status == .done }
        persist()
    }

    func advance() {
        let processing = tasks(in: .processing)
        let todo = tasks(in: .todo)
        guard !processing.isEmpty || !todo.isEmpty else { return }

        if let firstProcessing = processing.first {
            moveTask(id: firstProcessing.id, to: .done, at: 0, shouldPersist: false)
        }
        if let firstTodo = todo.first {
            moveTask(id: firstTodo.id, to: .processing, at: tasks(in: .processing).count, shouldPersist: false)
        }
        persist()
    }

    func moveTask(id: UUID, to status: TaskStatus, at requestedIndex: Int? = nil) {
        moveTask(id: id, to: status, at: requestedIndex, shouldPersist: true)
    }

    func previewMove(id: UUID, to status: TaskStatus, at requestedIndex: Int) {
        guard tasks.contains(where: { $0.id == id }) else { return }
        let current = tasks(in: status)
        let sourceIndex = current.firstIndex(where: { $0.id == id })
        var destination = max(0, min(requestedIndex, current.count))
        if let sourceIndex, sourceIndex < destination { destination -= 1 }
        let effective = max(0, min(destination, current.filter { $0.id != id }.count))
        if tasks.first(where: { $0.id == id })?.status == status, sourceIndex == effective {
            dropTarget = DropTarget(status: status, index: effective)
            return
        }
        moveTask(id: id, to: status, at: requestedIndex, shouldPersist: false)
        dropTarget = DropTarget(status: status, index: effective)
    }

    func finishDrop() {
        draggingTaskID = nil
        dropTarget = nil
        persist()
    }

    private func moveTask(id: UUID, to status: TaskStatus, at requestedIndex: Int?, shouldPersist: Bool) {
        guard let oldIndex = tasks.firstIndex(where: { $0.id == id }) else { return }
        let oldStatus = tasks[oldIndex].status
        var destinationTasks = tasks(in: status).filter { $0.id != id }
        let rawIndex = requestedIndex ?? destinationTasks.count
        let adjustedIndex: Int
        if oldStatus == status,
           let sourceIndex = tasks(in: status).firstIndex(where: { $0.id == id }),
           sourceIndex < rawIndex {
            adjustedIndex = rawIndex - 1
        } else {
            adjustedIndex = rawIndex
        }
        let insertionIndex = max(0, min(adjustedIndex, destinationTasks.count))

        var moved = tasks[oldIndex]
        moved.status = status
        moved.completedAt = status == .done ? (moved.completedAt ?? Date()) : nil
        tasks.remove(at: oldIndex)
        destinationTasks.insert(moved, at: insertionIndex)

        let destinationIDs = Set(destinationTasks.map(\.id))
        tasks.removeAll { destinationIDs.contains($0.id) }
        for (index, var task) in destinationTasks.enumerated() {
            task.sortOrder = index
            tasks.append(task)
        }
        normalize(oldStatus)
        normalize(status)
        if shouldPersist { persist() }
    }

    private func normalizeAll() {
        TaskStatus.allCases.forEach(normalize)
    }

    private func normalize(_ status: TaskStatus) {
        let ordered = tasks(in: status)
        for (order, task) in ordered.enumerated() {
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].sortOrder = order
            }
        }
    }

    private func persist() {
        normalizeAll()
        do {
            try repository.save(tasks)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
