import AppKit

@main
enum CompactFlowApplication {
    static func main() {
        let application = NSApplication.shared
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isRunningTests,
           let bundleIdentifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("CompactFlow.showPopover"),
                object: bundleIdentifier
            )
            existing.activate()
            return
        }
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
