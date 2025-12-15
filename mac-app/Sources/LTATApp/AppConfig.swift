import Foundation

/// Top-level configuration for LTATApp, aligned with PLAN.md.
struct AppConfig: Codable {
    var quantum: QuantumConfig
    var activity: ActivityConfig
    var screenshots: ScreenshotConfig
    var categories: [String: String]
    var anomalies: AnomalyThresholds
    var rawEvents: RawEventsConfig
    var logging: LoggingConfig
    var reporting: ReportingConfig
    var aiAnalysis: AIConfig
}

struct QuantumConfig: Codable {
    var quantumSeconds: Int
    var minPartialSecondsDrop: Int
    var minPartialSecondsTooShort: Int
    var allowResumeAfterSleep: Bool
    var autoPauseOnSleep: Bool
}

struct ActivityConfig: Codable {
    var kMax: Int
    var cMax: Int
    var sMax: Int
    var mMax: Int
    var weights: ActivityWeights
    var lowActivityThreshold: Int
    var inactiveWhenNoEvents: Bool
}

struct ActivityWeights: Codable {
    var keypress: Double
    var click: Double
    var scroll: Double
    var mouseDistance: Double
}

struct ScreenshotConfig: Codable {
    var downscaleWidth: Int
    var format: String
    var quality: Double
    var storagePolicy: StoragePolicy
    var captureAllDisplays: Bool
}

struct StoragePolicy: Codable {
    var keepUntilSync: Bool
    var fallbackDays: Int
}

struct AnomalyThresholds: Codable {
    var switchingPerQuantum: Int
    var switchingPerHour: Int
    var focusModeMinConsecutiveQuanta: Int
}

struct RawEventsConfig: Codable {
    var enableRawEvents: Bool
    var rawStoragePath: String
}

struct LoggingConfig: Codable {
    var logLevel: String
    var logFilePath: String
}

struct ReportingConfig: Codable {
    var reportOutputPath: String
    var reportAutoEndOfDay: Bool
}

struct AIConfig: Codable {
    var enabled: Bool
}

extension AppConfig {
    /// Default config matching the values in PLAN.md (Update 2025-02-28).
    static var `default`: AppConfig {
        AppConfig(
            quantum: QuantumConfig(
                quantumSeconds: 180,
                minPartialSecondsDrop: 30,
                minPartialSecondsTooShort: 120,
                allowResumeAfterSleep: true,
                autoPauseOnSleep: true
            ),
            activity: ActivityConfig(
                kMax: 150,
                cMax: 90,
                sMax: 120,
                mMax: 5000,
                weights: ActivityWeights(keypress: 0.4, click: 0.25, scroll: 0.2, mouseDistance: 0.15),
                lowActivityThreshold: 20,
                inactiveWhenNoEvents: true
            ),
            screenshots: ScreenshotConfig(
                downscaleWidth: 1280,
                format: "jpeg",
                quality: 0.75,
                storagePolicy: StoragePolicy(keepUntilSync: true, fallbackDays: 7),
                captureAllDisplays: true
            ),
            categories: DefaultCategories.bundleToCategory,
            anomalies: AnomalyThresholds(
                switchingPerQuantum: 8,
                switchingPerHour: 60,
                focusModeMinConsecutiveQuanta: 2
            ),
            rawEvents: RawEventsConfig(enableRawEvents: false, rawStoragePath: "RawEvents"),
            logging: LoggingConfig(logLevel: "info", logFilePath: "Logs/ltatapp.log"),
            reporting: ReportingConfig(reportOutputPath: "Reports", reportAutoEndOfDay: true),
            aiAnalysis: AIConfig(enabled: true)
        )
    }
}

enum DefaultCategories {
    static let bundleToCategory: [String: String] = [
        // Browsers
        "com.apple.Safari": "Browser",
        "com.google.Chrome": "Browser",
        "org.mozilla.firefox": "Browser",
        "com.microsoft.edgemac": "Browser",
        "com.brave.Browser": "Browser",
        "com.operasoftware.Opera": "Browser",
        "company.thebrowser.Browser": "Browser", // Arc
        "com.vivaldi.Vivaldi": "Browser",
        // IDE / Code
        "com.apple.dt.Xcode": "IDE",
        "com.microsoft.VSCode": "IDE",
        "com.jetbrains.intellij": "IDE",
        "com.jetbrains.pycharm": "IDE",
        "com.jetbrains.clion": "IDE",
        "com.jetbrains.rider": "IDE",
        "com.jetbrains.goland": "IDE",
        "com.jetbrains.WebStorm": "IDE",
        "com.jetbrains.datagrip": "IDE",
        "com.jetbrains.rubymine": "IDE",
        "com.jetbrains.phpstorm": "IDE",
        "com.google.android.studio": "IDE",
        // Office / Docs
        "com.microsoft.Word": "Office",
        "com.microsoft.Excel": "Office",
        "com.microsoft.Powerpoint": "Office",
        "com.apple.iWork.Pages": "Office",
        "com.apple.iWork.Numbers": "Office",
        "com.apple.iWork.Keynote": "Office",
        // Messengers
        "com.tinyspeck.slackmacgap": "Messengers",
        "com.hnc.Discord": "Messengers",
        "com.apple.iChat": "Messengers",
        "com.microsoft.teams": "Messengers",
        "com.telegram.desktop": "Messengers",
        // Terminal
        "com.apple.Terminal": "Terminal",
        "com.googlecode.iterm2": "Terminal",
        // Design / Media
        "com.adobe.Photoshop": "Design",
        "com.adobe.Illustrator": "Design",
        "com.bohemiancoding.sketch3": "Design",
        "com.figma.Desktop": "Design",
        "com.adobe.AfterEffects": "Media",
        "com.adobe.PremierePro": "Media"
    ]
}
