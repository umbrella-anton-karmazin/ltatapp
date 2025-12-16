import AppKit
import Foundation

struct FocusSample: Equatable, Sendable {
    let ts: Date
    let appName: String
    let bundleId: String
    let category: String
}

struct FocusQuantumAggregate: Equatable, Sendable {
    let primaryAppName: String?
    let primaryBundleId: String?
    let primaryCategory: String?
    let primaryAppDwellMs: Int

    let appSwitchCount: Int
    let categorySwitchCount: Int
    let switchesThisHour: Int
    let switchesToday: Int

    let focusModeStreak: Int
    let focusModeFlag: Bool
    let anomalySwitchingFlag: Bool
}

final class AppFocusMonitor: @unchecked Sendable {
    private struct HourKey: Hashable {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
    }

    private struct DayKey: Hashable {
        let year: Int
        let month: Int
        let day: Int
    }

    private let logger: AppLogger
    private let workspaceCenter = NSWorkspace.shared.notificationCenter

    private var didActivateObserver: NSObjectProtocol?
    private var pollingTimer: Timer?

    private var categories: [String: String] = [:]
    private var onSample: ((FocusSample) -> Void)?

    private var quantumStart: Date?
    private var lastSample: FocusSample?
    private var dwellMsByBundleId: [String: Int] = [:]
    private var lastAppNameByBundleId: [String: String] = [:]
    private var appSwitchCount: Int = 0
    private var categorySwitchCount: Int = 0

    private var appSwitchesByHour: [HourKey: Int] = [:]
    private var appSwitchesByDay: [DayKey: Int] = [:]

    private var focusModeStreakBundleId: String?
    private var focusModeStreakCount: Int = 0

    init(logger: AppLogger = .shared) {
        self.logger = logger
    }

    func start(config: AppConfig, onSample: ((FocusSample) -> Void)? = nil) {
        precondition(Thread.isMainThread)
        guard didActivateObserver == nil else { return }

        categories = config.categories
        self.onSample = onSample

        didActivateObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pollFrontmost(ts: Date())
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollFrontmost(ts: Date())
        }

        logger.log(level: .info, component: "focus", message: "Focus monitor started")
    }

    func stop() {
        precondition(Thread.isMainThread)
        if let didActivateObserver {
            workspaceCenter.removeObserver(didActivateObserver)
            self.didActivateObserver = nil
        }
        pollingTimer?.invalidate()
        pollingTimer = nil
        onSample = nil

        quantumStart = nil
        lastSample = nil
        dwellMsByBundleId = [:]
        lastAppNameByBundleId = [:]
        appSwitchCount = 0
        categorySwitchCount = 0

        focusModeStreakBundleId = nil
        focusModeStreakCount = 0

        logger.log(level: .info, component: "focus", message: "Focus monitor stopped")
    }

    func resetForNewQuantum(startedAt: Date, config: AppConfig) {
        precondition(Thread.isMainThread)
        categories = config.categories
        quantumStart = startedAt
        lastSample = nil
        dwellMsByBundleId = [:]
        lastAppNameByBundleId = [:]
        appSwitchCount = 0
        categorySwitchCount = 0

        pollFrontmost(ts: startedAt, allowSwitchCounting: false)
    }

    func finalizeQuantum(endedAt: Date, config: AppConfig, isPartial: Bool, isTooShort: Bool, isDropped: Bool) -> FocusQuantumAggregate? {
        precondition(Thread.isMainThread)

        categories = config.categories
        closeDwell(until: endedAt)

        let primary = dwellMsByBundleId.max { $0.value < $1.value }
        let primaryBundleId = primary?.key
        let primaryDwellMs = primary?.value ?? 0
        let primaryAppName = primaryBundleId.flatMap { lastAppNameByBundleId[$0] }
        let primaryCategory = primaryBundleId.map { category(for: $0) }

        let switchesThisHour = appSwitchesByHour[hourKey(for: endedAt)] ?? 0
        let switchesToday = appSwitchesByDay[dayKey(for: endedAt)] ?? 0

        let anomalySwitchingFlag =
            appSwitchCount > config.anomalies.switchingPerQuantum ||
            switchesThisHour > config.anomalies.switchingPerHour

        let focusModeFlag: Bool
        if isDropped || isPartial || isTooShort || primaryBundleId == nil {
            focusModeStreakBundleId = nil
            focusModeStreakCount = 0
            focusModeFlag = false
        } else {
            if focusModeStreakBundleId == primaryBundleId {
                focusModeStreakCount += 1
            } else {
                focusModeStreakBundleId = primaryBundleId
                focusModeStreakCount = 1
            }
            focusModeFlag = focusModeStreakCount >= config.anomalies.focusModeMinConsecutiveQuanta
        }

        let aggregate = FocusQuantumAggregate(
            primaryAppName: primaryAppName,
            primaryBundleId: primaryBundleId,
            primaryCategory: primaryCategory,
            primaryAppDwellMs: primaryDwellMs,
            appSwitchCount: appSwitchCount,
            categorySwitchCount: categorySwitchCount,
            switchesThisHour: switchesThisHour,
            switchesToday: switchesToday,
            focusModeStreak: focusModeStreakCount,
            focusModeFlag: focusModeFlag,
            anomalySwitchingFlag: anomalySwitchingFlag
        )

        quantumStart = nil
        lastSample = nil
        dwellMsByBundleId = [:]
        lastAppNameByBundleId = [:]
        appSwitchCount = 0
        categorySwitchCount = 0

        return isDropped ? nil : aggregate
    }

    private func pollFrontmost(ts: Date, allowSwitchCounting: Bool = true) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        guard let bundleId = app.bundleIdentifier else { return }
        let appName = app.localizedName ?? bundleId
        let sample = FocusSample(ts: ts, appName: appName, bundleId: bundleId, category: category(for: bundleId))
        ingest(sample: sample, allowSwitchCounting: allowSwitchCounting)
    }

    private func ingest(sample: FocusSample, allowSwitchCounting: Bool) {
        guard quantumStart != nil else {
            onSample?(sample)
            return
        }

        if lastSample == nil {
            lastSample = sample
            lastAppNameByBundleId[sample.bundleId] = sample.appName
            onSample?(sample)
            return
        }

        guard let previous = lastSample else { return }
        guard sample.bundleId != previous.bundleId else { return }

        closeDwell(until: sample.ts)

        if allowSwitchCounting {
            appSwitchCount += 1
            if sample.category != previous.category {
                categorySwitchCount += 1
            }
            incrementSwitchCounters(at: sample.ts)
        }

        lastSample = sample
        lastAppNameByBundleId[sample.bundleId] = sample.appName
        onSample?(sample)
    }

    private func closeDwell(until end: Date) {
        guard let last = lastSample else { return }
        let ms = max(0, Int((end.timeIntervalSince(last.ts) * 1000).rounded()))
        dwellMsByBundleId[last.bundleId, default: 0] += ms
    }

    private func incrementSwitchCounters(at date: Date) {
        let hk = hourKey(for: date)
        appSwitchesByHour[hk, default: 0] += 1
        let dk = dayKey(for: date)
        appSwitchesByDay[dk, default: 0] += 1

        if appSwitchesByHour.count > 96 {
            pruneOldHourBuckets(keepingAround: date)
        }
        if appSwitchesByDay.count > 8 {
            pruneOldDayBuckets(keepingAround: date)
        }
    }

    private func hourKey(for date: Date) -> HourKey {
        let c = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour], from: date)
        return HourKey(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0, hour: c.hour ?? 0)
    }

    private func dayKey(for date: Date) -> DayKey {
        let c = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)
        return DayKey(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    private func pruneOldHourBuckets(keepingAround now: Date) {
        let calendar = Calendar.autoupdatingCurrent
        let cutoff = calendar.date(byAdding: .hour, value: -72, to: now) ?? now
        for key in appSwitchesByHour.keys {
            guard let d = calendar.date(from: DateComponents(year: key.year, month: key.month, day: key.day, hour: key.hour)) else { continue }
            if d < cutoff {
                appSwitchesByHour.removeValue(forKey: key)
            }
        }
    }

    private func pruneOldDayBuckets(keepingAround now: Date) {
        let calendar = Calendar.autoupdatingCurrent
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        for key in appSwitchesByDay.keys {
            guard let d = calendar.date(from: DateComponents(year: key.year, month: key.month, day: key.day)) else { continue }
            if d < cutoff {
                appSwitchesByDay.removeValue(forKey: key)
            }
        }
    }

    private func category(for bundleId: String) -> String {
        if let mapped = categories[bundleId] {
            return mapped
        }
        if bundleId.hasPrefix("com.apple.") {
            return "System"
        }
        return "Other"
    }
}
