import XCTest
@testable import CompactFlow

@MainActor
final class TaskBoardViewModelTests: XCTestCase {
    private var repository: InMemoryTaskRepository!
    private var viewModel: TaskBoardViewModel!

    override func setUp() async throws {
        repository = InMemoryTaskRepository()
        viewModel = TaskBoardViewModel(repository: repository)
    }

    func testFirstTaskIsAddedToTodo() {
        XCTAssertTrue(viewModel.addTask(title: "First"))
        XCTAssertEqual(viewModel.tasks(in: .todo).map(\.title), ["First"])
        XCTAssertFalse(viewModel.addTask(title: "   "))
    }

    func testAdvanceStartsFirstTodoWhenProcessingIsEmpty() {
        viewModel.addTask(title: "First")
        viewModel.addTask(title: "Second")
        viewModel.advance()
        XCTAssertEqual(viewModel.tasks(in: .processing).map(\.title), ["First"])
        XCTAssertEqual(viewModel.tasks(in: .todo).map(\.title), ["Second"])
    }

    func testAdvanceCompletesFirstProcessingAndPullsTodo() {
        ["P1", "P2"].forEach { title in
            viewModel.addTask(title: title)
            viewModel.moveTask(id: viewModel.tasks(in: .todo).last!.id, to: .processing)
        }
        viewModel.addTask(title: "Next")
        viewModel.advance()
        XCTAssertEqual(viewModel.tasks(in: .done).map(\.title), ["P1"])
        XCTAssertEqual(viewModel.tasks(in: .processing).map(\.title), ["P2", "Next"])
    }

    func testAdvanceWithEmptyTodoOnlyCompletesFirstProcessing() {
        ["P1", "P2"].forEach { title in
            viewModel.addTask(title: title)
            viewModel.moveTask(id: viewModel.tasks(in: .todo).last!.id, to: .processing)
        }
        viewModel.advance()
        XCTAssertEqual(viewModel.tasks(in: .done).map(\.title), ["P1"])
        XCTAssertEqual(viewModel.tasks(in: .processing).map(\.title), ["P2"])
    }

    func testCannotAdvanceWhenQueuesAreEmpty() {
        XCTAssertFalse(viewModel.canAdvance)
        viewModel.advance()
        XCTAssertTrue(viewModel.tasks.isEmpty)
    }

    func testReorderedTodoChangesNextTask() {
        viewModel.addTask(title: "First")
        viewModel.addTask(title: "Second")
        let second = viewModel.tasks(in: .todo)[1]
        viewModel.moveTask(id: second.id, to: .todo, at: 0)
        viewModel.advance()
        XCTAssertEqual(viewModel.tasks(in: .processing).first?.title, "Second")
    }

    func testTaskCanMoveDownWithinSameColumn() {
        viewModel.addTask(title: "First")
        viewModel.addTask(title: "Second")
        viewModel.addTask(title: "Third")
        let first = viewModel.tasks(in: .todo)[0]

        viewModel.moveTask(id: first.id, to: .todo, at: 2)

        XCTAssertEqual(viewModel.tasks(in: .todo).map(\.title), ["Second", "First", "Third"])
    }

    func testTasksMoveAcrossAllColumns() {
        viewModel.addTask(title: "Task")
        let id = viewModel.tasks[0].id
        viewModel.moveTask(id: id, to: .processing)
        XCTAssertEqual(viewModel.tasks(in: .processing).count, 1)
        viewModel.moveTask(id: id, to: .done)
        XCTAssertNotNil(viewModel.tasks(in: .done).first?.completedAt)
        viewModel.moveTask(id: id, to: .todo)
        XCTAssertNil(viewModel.tasks(in: .todo).first?.completedAt)
    }

    func testDroppingIntoPopulatedColumnAppendsTask() {
        viewModel.addTask(title: "Existing processing")
        let existing = viewModel.tasks(in: .todo)[0]
        viewModel.moveTask(id: existing.id, to: .processing)

        viewModel.addTask(title: "Dropped task")
        let dropped = viewModel.tasks(in: .todo)[0]
        viewModel.moveTask(id: dropped.id, to: .processing, at: viewModel.tasks(in: .processing).count)

        XCTAssertEqual(viewModel.tasks(in: .processing).map(\.title), ["Existing processing", "Dropped task"])
    }

    func testOrderPersistsAfterRecreatingViewModel() {
        viewModel.addTask(title: "First")
        viewModel.addTask(title: "Second")
        let second = viewModel.tasks(in: .todo)[1]
        viewModel.moveTask(id: second.id, to: .todo, at: 0)
        let restored = TaskBoardViewModel(repository: repository)
        XCTAssertEqual(restored.tasks(in: .todo).map(\.title), ["Second", "First"])
    }
}
