import Foundation

enum FocusSmokeRunner {
    static func main() {
        let config = AppConfig.default
        let monitor = AppFocusMonitor(logger: .shared)

        print("SMOKE: focus monitor will run for 12s. Switch between a couple of apps/windows now.")

        monitor.start(config: config) { sample in
            let ts = ISO8601DateFormatter().string(from: sample.ts)
            print("SMOKE focus ts=\(ts) app=\(sample.appName) bundleId=\(sample.bundleId) category=\(sample.category)")
        }

        let start = Date()
        monitor.resetForNewQuantum(startedAt: start, config: config)
        RunLoop.current.run(until: start.addingTimeInterval(12))

        let end = Date()
        let focus = monitor.finalizeQuantum(endedAt: end, config: config, isPartial: true, isTooShort: false, isDropped: false)
        monitor.stop()

        if let focus {
            print("SMOKE primary_app=\(focus.primaryAppName ?? "—") primary_category=\(focus.primaryCategory ?? "—")")
            print("SMOKE switches q=\(focus.appSwitchCount) hour=\(focus.switchesThisHour) day=\(focus.switchesToday) anomaly=\(focus.anomalySwitchingFlag)")
            print("SMOKE OK")
            exit(0)
        } else {
            print("SMOKE FAIL: focus aggregate missing")
            exit(1)
        }
    }
}

