import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = TaskBoardViewModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        statusBarController = StatusBarController(viewModel: viewModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@MainActor
private final class StatusBarController: NSObject {
    private let viewModel: TaskBoardViewModel
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var tasksCancellable: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var advanceHitStartX: CGFloat = .greatestFiniteMagnitude

    init(viewModel: TaskBoardViewModel) {
        self.viewModel = viewModel
        super.init()
        configureStatusItem()
        activationObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("CompactFlow.showPopover"),
            object: Bundle.main.bundleIdentifier,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.showPopover() }
        }
        observeTasks()
    }

    deinit {
        if let activationObserver {
            DistributedNotificationCenter.default().removeObserver(activationObserver)
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 270)
        statusItem = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp])
        button.toolTip = "Open Compact Flow or advance the queue"
        button.setAccessibilityLabel("Bar To Do")
        button.setAccessibilityHelp("Click the task title to open the board, or the play button to advance the queue")
        button.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Advance Queue") { [weak self] in
                self?.advance()
                return true
            }
        ])
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
        guard let button = statusItem?.button else { return }
        let taskTitle = viewModel.menuBarTitle
        let separator = "   |   "
        let fullTitle = taskTitle + separator + "▶"
        let font = NSFont.menuBarFont(ofSize: 0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        button.attributedTitle = NSAttributedString(string: fullTitle, attributes: attributes)
        button.setAccessibilityValue(taskTitle)

        // NSStatusBarButton centers its title inside the fixed-width status item.
        // Derive the play region from the rendered text rather than the button's
        // trailing edge, so changing task titles cannot move the clickable target
        // away from the visible arrow.
        let fullWidth = (fullTitle as NSString).size(withAttributes: attributes).width
        let prefixWidth = ((taskTitle + separator) as NSString).size(withAttributes: attributes).width
        let titleOriginX = max(0, (button.bounds.width - fullWidth) / 2)
        advanceHitStartX = titleOriginX + prefixWidth - 8
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if let window = sender.window {
            let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            let buttonPoint = sender.convert(windowPoint, from: nil)
            if buttonPoint.x >= advanceHitStartX {
                advance()
                return
            }
        }
        togglePopover(from: sender)
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

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        if !popover.isShown { togglePopover(from: button) }
    }

    @objc private func advance() {
        withAnimation(.snappy(duration: 0.22)) { viewModel.advance() }
    }
}
