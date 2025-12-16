import CoreGraphics
import Foundation

struct ActivityCounts: Equatable, Sendable {
    var keypressCount: Int = 0
    var clickCount: Int = 0
    var scrollCount: Int = 0
    var mouseDistancePx: Double = 0

    var hasAnyEvents: Bool {
        keypressCount > 0 || clickCount > 0 || scrollCount > 0 || mouseDistancePx > 0
    }
}

struct ActivityAggregate: Equatable, Sendable {
    let counts: ActivityCounts
    let activityPercent: Int
    let isIdle: Bool
    let isLowActivity: Bool
}

final class ActivityMonitor {
    private let logger: AppLogger
    private let lock = NSLock()

    private var counts = ActivityCounts()
    private var lastMouseLocation: CGPoint?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private(set) var lastStartError: String?

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    func resetForNewQuantum() {
        lock.lock()
        defer { lock.unlock() }
        counts = ActivityCounts()
        lastMouseLocation = nil
    }

    @discardableResult
    func start() -> Bool {
        precondition(Thread.isMainThread)
        guard tap == nil else { return true }

        let mask = ActivityMonitor.eventMask
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<ActivityMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handle(eventType: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            let message = "Activity monitor unavailable (CGEvent tap not created). Check System Settings → Privacy & Security → Input Monitoring."
            lastStartError = message
            logger.log(level: .warning, component: "activity", message: message)
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.source = source
        lastStartError = nil
        logger.log(level: .info, component: "activity", message: "Activity monitor started")
        return true
    }

    func stop() {
        precondition(Thread.isMainThread)
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
        logger.log(level: .info, component: "activity", message: "Activity monitor stopped")
    }

    func snapshotCounts() -> ActivityCounts {
        lock.lock()
        defer { lock.unlock() }
        return counts
    }

    func computeAggregate(config: AppConfig) -> ActivityAggregate {
        let counts = snapshotCounts()
        let percent = ActivityMonitor.computeActivityPercent(counts: counts, config: config)
        let isIdle = config.activity.inactiveWhenNoEvents && !counts.hasAnyEvents
        let isLow = percent < config.activity.lowActivityThreshold
        return ActivityAggregate(counts: counts, activityPercent: percent, isIdle: isIdle, isLowActivity: isLow)
    }

    private func handle(eventType type: CGEventType, event: CGEvent) {
        lock.lock()
        defer { lock.unlock() }

        switch type {
        case .keyDown:
            counts.keypressCount += 1
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            counts.clickCount += 1
        case .scrollWheel:
            counts.scrollCount += 1
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let location = event.location
            if let prev = lastMouseLocation {
                let dx = location.x - prev.x
                let dy = location.y - prev.y
                counts.mouseDistancePx += (dx * dx + dy * dy).squareRoot()
            }
            lastMouseLocation = location
        default:
            break
        }
    }

    private static var eventMask: CGEventMask {
        var mask: CGEventMask = 0
        let types: [CGEventType] = [
            .keyDown,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        for type in types {
            mask |= 1 << type.rawValue
        }
        return mask
    }

    private static func computeActivityPercent(counts: ActivityCounts, config: AppConfig) -> Int {
        func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }

        let k = config.activity.kMax > 0 ? Double(counts.keypressCount) / Double(config.activity.kMax) : 0
        let c = config.activity.cMax > 0 ? Double(counts.clickCount) / Double(config.activity.cMax) : 0
        let s = config.activity.sMax > 0 ? Double(counts.scrollCount) / Double(config.activity.sMax) : 0
        let m = config.activity.mMax > 0 ? Double(counts.mouseDistancePx) / Double(config.activity.mMax) : 0

        let weighted =
            clamp01(k) * config.activity.weights.keypress +
            clamp01(c) * config.activity.weights.click +
            clamp01(s) * config.activity.weights.scroll +
            clamp01(m) * config.activity.weights.mouseDistance

        return Int((clamp01(weighted) * 100).rounded())
    }
}
