import Foundation

protocol TaskRepository {
    func load() throws -> [TaskItem]
    func save(_ tasks: [TaskItem]) throws
}

enum TaskRepositoryError: LocalizedError {
    case applicationSupportUnavailable

    var errorDescription: String? {
        "Application Support klasörü kullanılamıyor."
    }
}

final class JSONTaskRepository: TaskRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) throws {
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw TaskRepositoryError.applicationSupportUnavailable
        }
        let directory = support.appendingPathComponent("CompactFlow", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("tasks.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [TaskItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([TaskItem].self, from: Data(contentsOf: fileURL))
    }

    func save(_ tasks: [TaskItem]) throws {
        let data = try encoder.encode(tasks)
        try data.write(to: fileURL, options: .atomic)
    }
}

final class InMemoryTaskRepository: TaskRepository {
    var storedTasks: [TaskItem]

    init(tasks: [TaskItem] = []) { storedTasks = tasks }
    func load() throws -> [TaskItem] { storedTasks }
    func save(_ tasks: [TaskItem]) throws { storedTasks = tasks }
}
