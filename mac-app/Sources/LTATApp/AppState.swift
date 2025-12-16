import Foundation

enum TrackingStatus: String {
    case stopped
    case tracking
    case pausedBySystem
}

struct ResumePrompt: Equatable {
    let title: String
    let message: String
    let reason: String
}

enum QuantumEndReason: String {
    case quantumComplete
    case userStop
    case systemPause
}

struct QuantumSummary: Equatable {
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let isPartial: Bool
    let isTooShort: Bool
    let isDropped: Bool
    let endReason: QuantumEndReason
    let systemPauseReason: String?
    let activity: ActivityAggregate
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var status: TrackingStatus = .stopped
    @Published var currentProject: String = "Unassigned"
    @Published var currentTask: String = "Unassigned"
    @Published var config: AppConfig
    @Published var lastLogMessage: String = ""
    @Published var resumePrompt: ResumePrompt?
    @Published var lastQuantum: QuantumSummary?
    @Published var systemPauseReason: String?
    @Published var lastActivity: ActivityAggregate?

    private let logger: AppLogger
    private let systemEvents = SystemEventMonitor()
    private let activityMonitor = ActivityMonitor()
    private var currentQuantumStartedAt: Date?
    private var quantumTimer: Timer?

    init(config: AppConfig) {
        self.config = config
        self.logger = AppLogger.shared
        systemEvents.start { [weak self] event in
            Task { @MainActor in
                self?.handle(systemEvent: event)
            }
        }
        logger.log(level: .info, component: "app", message: "Initialized with config (quantum \(config.quantum.quantumSeconds)s)")
    }

    func startTracking() {
        guard status == .stopped else { return }
        status = .tracking
        systemPauseReason = nil
        resumePrompt = nil
        activityMonitor.resetForNewQuantum()
        activityMonitor.start()
        startQuantum(at: Date())
        logger.log(level: .info, component: "tracking", message: "Tracking started", metadata: ["project": currentProject, "task": currentTask])
        lastLogMessage = "Tracking started"
    }

    func stopTracking() {
        guard status != .stopped else { return }
        finalizeQuantumIfNeeded(endedAt: Date(), endReason: .userStop, systemPauseReason: nil)
        activityMonitor.stop()
        invalidateTimer()
        status = .stopped
        systemPauseReason = nil
        resumePrompt = nil
        logger.log(level: .info, component: "tracking", message: "Tracking stopped")
        lastLogMessage = "Tracking stopped"
    }

    func pauseBySystem(reason: String) {
        guard status == .tracking else { return }
        finalizeQuantumIfNeeded(endedAt: Date(), endReason: .systemPause, systemPauseReason: reason)
        activityMonitor.stop()
        invalidateTimer()
        status = .pausedBySystem
        systemPauseReason = reason
        logger.log(level: .warning, component: "tracking", message: "Paused by system", metadata: ["reason": reason])
        lastLogMessage = "Paused by system (\(reason))"
    }

    func resumeAfterPause() {
        guard status == .pausedBySystem else { return }
        status = .tracking
        systemPauseReason = nil
        resumePrompt = nil
        activityMonitor.resetForNewQuantum()
        activityMonitor.start()
        startQuantum(at: Date())
        logger.log(level: .info, component: "tracking", message: "Resumed after system pause")
        lastLogMessage = "Resumed after pause"
    }

    func dismissResumePrompt() {
        resumePrompt = nil
    }

    private func startQuantum(at date: Date) {
        currentQuantumStartedAt = date
        activityMonitor.resetForNewQuantum()
        scheduleQuantumTimer()
    }

    private func scheduleQuantumTimer() {
        invalidateTimer()
        let interval = TimeInterval(config.quantum.quantumSeconds)
        quantumTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleQuantumTimerFired()
            }
        }
    }

    private func invalidateTimer() {
        quantumTimer?.invalidate()
        quantumTimer = nil
    }

    private func handleQuantumTimerFired() {
        guard status == .tracking else { return }
        finalizeQuantumIfNeeded(endedAt: Date(), endReason: .quantumComplete, systemPauseReason: nil)
        startQuantum(at: Date())
    }

    private func finalizeQuantumIfNeeded(endedAt end: Date, endReason: QuantumEndReason, systemPauseReason: String?) {
        guard let start = currentQuantumStartedAt else { return }
        currentQuantumStartedAt = nil

        let activity = activityMonitor.computeAggregate(config: config)
        lastActivity = activity

        let measuredDuration = max(0, Int(end.timeIntervalSince(start).rounded()))
        let drop = config.quantum.minPartialSecondsDrop
        let tooShort = config.quantum.minPartialSecondsTooShort

        let isQuantumComplete = endReason == .quantumComplete
        let duration = isQuantumComplete ? config.quantum.quantumSeconds : measuredDuration
        let isPartial = !isQuantumComplete

        let isDropped = isPartial && duration < drop
        let isTooShort = isPartial && !isDropped && duration < tooShort

        let summary = QuantumSummary(
            startedAt: start,
            endedAt: end,
            durationSeconds: duration,
            isPartial: isPartial,
            isTooShort: isTooShort,
            isDropped: isDropped,
            endReason: endReason,
            systemPauseReason: systemPauseReason,
            activity: activity
        )

        if !isDropped {
            lastQuantum = summary
        }

        logger.log(
            level: .info,
            component: "quantum",
            message: isDropped ? "Quantum dropped" : "Quantum finalized",
            metadata: [
                "project": currentProject,
                "task": currentTask,
                "duration_seconds": String(duration),
                "is_partial": String(isPartial),
                "is_too_short": String(isTooShort),
                "is_dropped": String(isDropped),
                "end_reason": endReason.rawValue,
                "pause_reason": systemPauseReason ?? "",
                "activity_percent": String(activity.activityPercent),
                "activity_idle": String(activity.isIdle),
                "activity_low": String(activity.isLowActivity),
                "activity_k": String(activity.counts.keypressCount),
                "activity_c": String(activity.counts.clickCount),
                "activity_s": String(activity.counts.scrollCount),
                "activity_m": String(Int(activity.counts.mouseDistancePx.rounded()))
            ]
        )
    }

    private func handle(systemEvent: SystemEvent) {
        switch systemEvent {
        case .willSleep:
            if config.quantum.autoPauseOnSleep {
                pauseBySystem(reason: "will_sleep")
            }
        case .screensDidSleep:
            pauseBySystem(reason: "screens_did_sleep")
        case .screenLocked:
            pauseBySystem(reason: "screen_locked")
        case .didWake:
            suggestResumeIfNeeded(reason: "did_wake")
        case .screensDidWake:
            suggestResumeIfNeeded(reason: "screens_did_wake")
        case .screenUnlocked:
            suggestResumeIfNeeded(reason: "screen_unlocked")
        }
    }

    private func suggestResumeIfNeeded(reason: String) {
        guard status == .pausedBySystem else { return }
        guard config.quantum.allowResumeAfterSleep else { return }
        guard resumePrompt == nil else { return }

        let pauseReason = systemPauseReason ?? "unknown"
        resumePrompt = ResumePrompt(
            title: "Resume tracking?",
            message: "Tracking is paused (\(pauseReason)). Resume now?",
            reason: reason
        )
    }
}
