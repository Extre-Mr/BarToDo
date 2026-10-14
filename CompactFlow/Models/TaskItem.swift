import Foundation

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case todo
    case processing
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todo: "To Do"
        case .processing: "Processing"
        case .done: "Done"
        }
    }
}

struct TaskItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var status: TaskStatus
    let createdAt: Date
    var completedAt: Date?
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        status: TaskStatus = .todo,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sortOrder = sortOrder
    }
}
