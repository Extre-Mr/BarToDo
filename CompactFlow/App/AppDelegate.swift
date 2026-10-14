import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = TaskBoardViewModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            self.statusBarController = StatusBarController(viewModel: self.viewModel)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@MainActor
private final class StatusBarController: NSObject {
    private let viewModel: TaskBoardViewModel
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var tasksCancellable: AnyCancellable?

    init(viewModel: TaskBoardViewModel) {
        self.viewModel = viewModel
        super.init()
        configureStatusItem()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.observeTasks()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 270)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = "Open Compact Flow or advance the queue"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 760, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
                .frame(width: 760, height: 500)
        )
    }

    private func observeTasks() {
        tasksCancellable = viewModel.$tasks
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        statusItem?.button?.title = viewModel.menuBarTitle + "   |   ▶"
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem?.button else { return }
        if let event = NSApplication.shared.currentEvent {
            let point = button.convert(event.locationInWindow, from: nil)
            if point.x >= button.bounds.maxX - 38 {
                advance()
                return
            }
        }
        togglePopover(from: button)
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if popover.contentViewController == nil {
                configurePopover()
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    @objc private func advance() {
        withAnimation(.snappy(duration: 0.22)) { viewModel.advance() }
    }
}
