import SwiftUI

extension Notification.Name {
    static let focusNewTask = Notification.Name("CompactFlow.focusNewTask")
    static let advanceQueue = Notification.Name("CompactFlow.advanceQueue")
}

struct AppCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") {
                NotificationCenter.default.post(name: .focusNewTask, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Flow") {
            Button("Advance Queue") {
                NotificationCenter.default.post(name: .advanceQueue, object: nil)
            }
            .keyboardShortcut(.return, modifiers: .command)

            Button("Show/Hide Compact Flow") {
                NotificationCenter.default.post(name: .focusNewTask, object: nil)
            }
            .keyboardShortcut("k", modifiers: .command)
        }
    }
}
