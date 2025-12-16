import CoreGraphics
import Foundation

enum ActivitySmokeRunner {
    static func main() {
        let config = AppConfig.default
        let monitor = ActivityMonitor(logger: .shared)

        monitor.resetForNewQuantum()
        guard monitor.start() else {
            let message = monitor.lastStartError ?? "Activity monitor failed to start."
            print("SMOKE FAIL: \(message)")
            exit(2)
        }

        postSyntheticEvents()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        let counts = monitor.snapshotCounts()
        let aggregate = monitor.computeAggregate(config: config)
        monitor.stop()

        print("SMOKE activity_percent=\(aggregate.activityPercent) idle=\(aggregate.isIdle) low=\(aggregate.isLowActivity)")
        print("SMOKE counts k=\(counts.keypressCount) c=\(counts.clickCount) s=\(counts.scrollCount) m=\(Int(counts.mouseDistancePx.rounded()))px")

        if counts.hasAnyEvents {
            print("SMOKE OK")
            exit(0)
        } else {
            print("SMOKE FAIL: No events captured. Try granting Input Monitoring and re-run.")
            exit(1)
        }
    }

    private static func postSyntheticEvents() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        for _ in 0..<6 {
            CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false)?.post(tap: .cghidEventTap)
        }

        let p1 = CGPoint(x: 100, y: 100)
        let p2 = CGPoint(x: 140, y: 140)

        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p1, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: p2, mouseButton: .left)?.post(tap: .cghidEventTap)

        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: p2, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: p2, mouseButton: .left)?.post(tap: .cghidEventTap)

        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: 12, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    }
}

