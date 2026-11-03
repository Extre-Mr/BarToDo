import Foundation
import SwiftUI

@MainActor
final class TaskBoardViewModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published var errorMessage: String?
    @Published var selectedTaskIDs: Set<UUID> = []

    private let repository: TaskRepository
    private var persistenceIsSafe = true

    private struct StateSnapshot {
        let tasks: [TaskItem]
        let selectedTaskIDs: Set<UUID>
    }

    init(repository: TaskRepository) {
        self.repository = repository
        do {
            tasks = try repository.load()
            normalizeAll()
        } catch {
            persistenceIsSafe = false
            errorMessage = error.localizedDescription
        }
    }

    convenience init() {
        do {
            try self.init(repository: JSONTaskRepository())
        } catch {
            self.init(repository: InMemoryTaskRepository())
            persistenceIsSafe = false
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
        let previous = snapshot()
        tasks.append(TaskItem(title: clean, sortOrder: tasks(in: .todo).count))
        return persist(restoring: previous)
    }

    func updateTask(id: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let previous = snapshot()
        tasks[index].title = clean
        persist(restoring: previous)
    }

    func deleteTask(id: UUID) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let previous = snapshot()
        tasks.removeAll { $0.id == id }
        selectedTaskIDs.remove(id)
        normalize(task.status)
        persist(restoring: previous)
    }

    func clearDone() {
        let previous = snapshot()
        tasks.removeAll { $0.status == .done }
        selectedTaskIDs = selectedTaskIDs.filter { id in tasks.contains { $0.id == id } }
        persist(restoring: previous)
    }

    func select(_ ids: Set<UUID>, extending: Bool) {
        selectedTaskIDs = extending ? selectedTaskIDs.union(ids) : ids
    }

    func toggleSelection(of id: UUID) {
        guard tasks.contains(where: { $0.id == id }) else { return }
        if selectedTaskIDs.contains(id) {
            selectedTaskIDs.remove(id)
        } else {
            selectedTaskIDs.insert(id)
        }
    }

    func clearSelection() {
        selectedTaskIDs.removeAll()
    }

    func dragPayload(for id: UUID) -> String {
        let ids = selectedTaskIDs.contains(id) ? selectedTaskIDs : [id]
        return ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    func moveTasks(ids: [UUID], to status: TaskStatus, at requestedIndex: Int) {
        let requestedIDs = Set(ids)
        let orderedTasks = TaskStatus.allCases.flatMap { sourceStatus in
            tasks(in: sourceStatus).filter { requestedIDs.contains($0.id) }
        }
        guard !orderedTasks.isEmpty else { return }

        let previous = snapshot()
        let destinationBeforeMove = tasks(in: status)
        let boundedIndex = max(0, min(requestedIndex, destinationBeforeMove.count))
        let removedBeforeInsertion = destinationBeforeMove.prefix(boundedIndex)
            .filter { requestedIDs.contains($0.id) }.count
        let insertionIndex = boundedIndex - removedBeforeInsertion

        var columns = Dictionary(uniqueKeysWithValues: TaskStatus.allCases.map {
            ($0, tasks(in: $0).filter { !requestedIDs.contains($0.id) })
        })
        var destination = columns[status] ?? []
        let moved = orderedTasks.map { task -> TaskItem in
            var task = task
            task.status = status
            task.completedAt = status == .done ? (task.completedAt ?? Date()) : nil
            return task
        }
        destination.insert(contentsOf: moved, at: max(0, min(insertionIndex, destination.count)))
        columns[status] = destination
        tasks = TaskStatus.allCases.flatMap { columnStatus in
            (columns[columnStatus] ?? []).enumerated().map { index, task in
                var task = task
                task.sortOrder = index
                return task
            }
        }
        selectedTaskIDs = Set(orderedTasks.map(\.id))
        persist(restoring: previous)
    }

    func advance() {
        let processing = tasks(in: .processing)
        let todo = tasks(in: .todo)
        guard !processing.isEmpty || !todo.isEmpty else { return }

        let previous = snapshot()
        if let firstProcessing = processing.first {
            moveTaskInMemory(id: firstProcessing.id, to: .done, at: 0)
        }
        if let firstTodo = todo.first {
            moveTaskInMemory(id: firstTodo.id, to: .processing, at: tasks(in: .processing).count)
        }
        persist(restoring: previous)
    }

    func moveTask(id: UUID, to status: TaskStatus, at requestedIndex: Int? = nil) {
        moveTasks(ids: [id], to: status, at: requestedIndex ?? tasks(in: status).count)
    }

    private func moveTaskInMemory(id: UUID, to status: TaskStatus, at requestedIndex: Int?) {
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

    @discardableResult
    private func persist(restoring previous: StateSnapshot) -> Bool {
        normalizeAll()
        guard persistenceIsSafe else {
            restore(previous)
            if errorMessage == nil {
                errorMessage = "Tasks cannot be saved until the existing data file is repaired."
            }
            return false
        }
        do {
            try repository.save(tasks)
            errorMessage = nil
            return true
        } catch {
            restore(previous)
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func snapshot() -> StateSnapshot {
        StateSnapshot(tasks: tasks, selectedTaskIDs: selectedTaskIDs)
    }

    private func restore(_ snapshot: StateSnapshot) {
        tasks = snapshot.tasks
        selectedTaskIDs = snapshot.selectedTaskIDs
    }

}
