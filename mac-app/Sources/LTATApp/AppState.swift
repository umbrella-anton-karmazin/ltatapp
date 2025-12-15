import Foundation

enum TrackingStatus: String {
    case stopped
    case tracking
    case pausedBySystem
}

final class AppViewModel: ObservableObject {
    @Published var status: TrackingStatus = .stopped
    @Published var currentProject: String = "Unassigned"
    @Published var currentTask: String = "Unassigned"
    @Published var config: AppConfig
    @Published var lastLogMessage: String = ""

    private let logger: AppLogger

    init(config: AppConfig) {
        self.config = config
        self.logger = AppLogger.shared
        logger.log(level: .info, component: "app", message: "Initialized with config (quantum \(config.quantum.quantumSeconds)s)")
    }

    func startTracking() {
        guard status == .stopped else { return }
        status = .tracking
        logger.log(level: .info, component: "tracking", message: "Tracking started", metadata: ["project": currentProject, "task": currentTask])
        lastLogMessage = "Tracking started"
    }

    func stopTracking() {
        guard status != .stopped else { return }
        status = .stopped
        logger.log(level: .info, component: "tracking", message: "Tracking stopped")
        lastLogMessage = "Tracking stopped"
    }

    func pauseBySystem(reason: String) {
        guard status == .tracking else { return }
        status = .pausedBySystem
        logger.log(level: .warning, component: "tracking", message: "Paused by system", metadata: ["reason": reason])
        lastLogMessage = "Paused by system (\(reason))"
    }

    func resumeAfterPause() {
        guard status == .pausedBySystem else { return }
        status = .tracking
        logger.log(level: .info, component: "tracking", message: "Resumed after system pause")
        lastLogMessage = "Resumed after pause"
    }
}
