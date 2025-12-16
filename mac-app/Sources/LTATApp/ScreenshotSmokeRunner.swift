import Foundation

enum ScreenshotSmokeRunner {
    static func main() {
        let config = AppConfig.default

        let end = Date()
        let start = end.addingTimeInterval(-1)

        let result = ScreenshotService.captureAndSave(
            quantumStartedAt: start,
            quantumEndedAt: end,
            config: config.screenshots,
            logger: .shared
        )

        print("SMOKE screenshots dir=\(result.baseDirectory.path) files=\(result.screenshots.count) errors=\(result.errors.count)")
        for shot in result.screenshots {
            print("SMOKE screenshot display=\(shot.displayId) path=\(shot.fileURL.path) w=\(shot.width) h=\(shot.height) size=\(shot.fileSizeBytes) sha256=\(shot.sha256Hex.prefix(16))")
        }
        for err in result.errors {
            print("SMOKE error: \(err)")
        }

        if result.screenshots.isEmpty {
            print("SMOKE FAIL: No screenshots captured. Try granting Screen Recording permission and re-run.")
            exit(1)
        }

        print("SMOKE OK")
        exit(0)
    }
}

