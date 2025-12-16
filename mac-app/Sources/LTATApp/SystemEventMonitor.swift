import AppKit
import Foundation

enum SystemEvent: String {
    case willSleep
    case didWake
    case screensDidSleep
    case screensDidWake
    case screenLocked
    case screenUnlocked
}

final class SystemEventMonitor: NSObject {
    private let workspaceCenter = NSWorkspace.shared.notificationCenter
    private let distributedCenter = DistributedNotificationCenter.default()
    private var handler: ((SystemEvent) -> Void)?
    private var isStarted: Bool = false

    func start(handler: @escaping (SystemEvent) -> Void) {
        stop()
        self.handler = handler
        isStarted = true

        workspaceCenter.addObserver(self, selector: #selector(handleWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleScreensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(handleScreensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)

        distributedCenter.addObserver(self, selector: #selector(handleScreenLocked), name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        distributedCenter.addObserver(self, selector: #selector(handleScreenUnlocked), name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    func stop() {
        guard isStarted else { return }
        workspaceCenter.removeObserver(self)
        distributedCenter.removeObserver(self)
        handler = nil
        isStarted = false
    }

    deinit {
        stop()
    }

    @objc private func handleWillSleep(_ note: Notification) {
        handler?(.willSleep)
    }

    @objc private func handleDidWake(_ note: Notification) {
        handler?(.didWake)
    }

    @objc private func handleScreensDidSleep(_ note: Notification) {
        handler?(.screensDidSleep)
    }

    @objc private func handleScreensDidWake(_ note: Notification) {
        handler?(.screensDidWake)
    }

    @objc private func handleScreenLocked(_ note: Notification) {
        handler?(.screenLocked)
    }

    @objc private func handleScreenUnlocked(_ note: Notification) {
        handler?(.screenUnlocked)
    }
}

