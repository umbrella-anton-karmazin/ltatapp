import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PermissionStatus: String {
    case unknown
    case missing
    case granted
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var screenRecording: PermissionStatus = .unknown
    @Published private(set) var accessibility: PermissionStatus = .unknown
    @Published private(set) var inputMonitoring: PermissionStatus = .unknown

    var isReadyForTracking: Bool {
        screenRecording == .granted && accessibility == .granted && inputMonitoring == .granted
    }

    func refresh() {
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .missing
        accessibility = AXIsProcessTrusted() ? .granted : .missing
        inputMonitoring = canCreateInputMonitoringEventTap() ? .granted : .missing
    }

    func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        refresh()
    }

    func requestAccessibility() {
        let options: CFDictionary = ["AXTrustedCheckOptionPrompt" as NSString: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openSystemSettingsScreenRecording() {
        open(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    func openSystemSettingsAccessibility() {
        open(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openSystemSettingsInputMonitoring() {
        open(urlString: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private func canCreateInputMonitoringEventTap() -> Bool {
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)

    let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, _, event, _ in
            Unmanaged.passUnretained(event)
        },
        userInfo: nil
    )

    guard let tap else { return false }
    CFMachPortInvalidate(tap)
    return true
}
