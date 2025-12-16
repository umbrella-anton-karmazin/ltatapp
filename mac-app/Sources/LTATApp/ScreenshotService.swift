import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CapturedScreenshot: Equatable, Sendable {
    let id: String
    let displayId: UInt32
    let fileURL: URL
    let width: Int
    let height: Int
    let format: String
    let fileSizeBytes: Int
    let sha256Hex: String
    let capturedAt: Date
}

struct ScreenshotCaptureResult: Equatable, Sendable {
    let quantumStartedAt: Date
    let quantumEndedAt: Date
    let baseDirectory: URL
    let primaryScreenshotId: String?
    let screenshots: [CapturedScreenshot]
    let errors: [String]
}

enum ScreenshotService {
    static func captureAndSave(
        quantumStartedAt: Date,
        quantumEndedAt: Date,
        config: ScreenshotConfig,
        fileManager: FileManager = .default,
        logger: AppLogger = .shared
    ) -> ScreenshotCaptureResult {
        let baseDirectory = screenshotsBaseDirectory(fileManager: fileManager)
        let outputDirectory = baseDirectory
            .appendingPathComponent(dayKey(for: quantumStartedAt), isDirectory: true)
            .appendingPathComponent(quantumKey(startedAt: quantumStartedAt, endedAt: quantumEndedAt), isDirectory: true)

        do {
            try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            let message = "Failed to create screenshot directory: \(error)"
            logger.log(level: .error, component: "screenshots", message: message, metadata: ["path": outputDirectory.path])
            return ScreenshotCaptureResult(
                quantumStartedAt: quantumStartedAt,
                quantumEndedAt: quantumEndedAt,
                baseDirectory: baseDirectory,
                primaryScreenshotId: nil,
                screenshots: [],
                errors: [message]
            )
        }

        let displayIds = displayIdsToCapture(config: config)
        if displayIds.isEmpty {
            let message = "No displays to capture"
            logger.log(level: .warning, component: "screenshots", message: message)
            return ScreenshotCaptureResult(
                quantumStartedAt: quantumStartedAt,
                quantumEndedAt: quantumEndedAt,
                baseDirectory: baseDirectory,
                primaryScreenshotId: nil,
                screenshots: [],
                errors: [message]
            )
        }

        let format = ScreenshotFormat(rawValue: config.format)
        let quality = min(1.0, max(0.0, config.quality))

        var screenshots: [CapturedScreenshot] = []
        var errors: [String] = []

        for displayId in displayIds {
            guard let image = CGDisplayCreateImage(displayId) else {
                let message = "CGDisplayCreateImage returned nil"
                errors.append("display=\(displayId): \(message)")
                logger.log(level: .warning, component: "screenshots", message: message, metadata: ["display_id": String(displayId)])
                continue
            }

            let scaled = downscale(image: image, targetWidth: config.downscaleWidth) ?? image
            if isLikelyBlackFrame(image: scaled) {
                let message = "Captured frame looks black (possible missing Screen Recording permission)"
                errors.append("display=\(displayId): \(message)")
                logger.log(level: .warning, component: "screenshots", message: message, metadata: ["display_id": String(displayId)])
                continue
            }
            let ext = format.fileExtension
            let fileURL = outputDirectory.appendingPathComponent("display-\(displayId).\(ext)")

            do {
                try encodeAndWrite(
                    image: scaled,
                    to: fileURL,
                    utType: format.utType,
                    quality: quality,
                    fileManager: fileManager
                )
            } catch {
                errors.append("display=\(displayId): encode/write failed: \(error)")
                logger.log(level: .error, component: "screenshots", message: "Encode/write failed: \(error)", metadata: ["display_id": String(displayId)])
                continue
            }

            let fileSizeBytes = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.intValue ?? 0
            let sha256Hex: String
            if let data = try? Data(contentsOf: fileURL) {
                sha256Hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            } else {
                sha256Hex = ""
                errors.append("display=\(displayId): failed to read file for hash")
            }

            let captured = CapturedScreenshot(
                id: UUID().uuidString,
                displayId: displayId,
                fileURL: fileURL,
                width: scaled.width,
                height: scaled.height,
                format: format.rawValue,
                fileSizeBytes: fileSizeBytes,
                sha256Hex: sha256Hex,
                capturedAt: quantumEndedAt
            )
            screenshots.append(captured)
        }

        let primaryScreenshotId = choosePrimaryScreenshotId(
            screenshots: screenshots,
            preferredDisplayId: CGMainDisplayID()
        )

        return ScreenshotCaptureResult(
            quantumStartedAt: quantumStartedAt,
            quantumEndedAt: quantumEndedAt,
            baseDirectory: baseDirectory,
            primaryScreenshotId: primaryScreenshotId,
            screenshots: screenshots,
            errors: errors
        )
    }

    static func choosePrimaryScreenshotId(screenshots: [CapturedScreenshot], preferredDisplayId: CGDirectDisplayID) -> String? {
        if let match = screenshots.first(where: { $0.displayId == preferredDisplayId }) {
            return match.id
        }
        return screenshots.first?.id
    }

    private static func displayIdsToCapture(config: ScreenshotConfig) -> [CGDirectDisplayID] {
        if !config.captureAllDisplays {
            return [CGMainDisplayID()]
        }

        var displayCount: UInt32 = 0
        let countErr = CGGetActiveDisplayList(0, nil, &displayCount)
        guard countErr == .success else { return [CGMainDisplayID()] }

        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        let listErr = CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        guard listErr == .success else { return [CGMainDisplayID()] }
        return Array(displays.prefix(Int(displayCount)))
    }

    private static func encodeAndWrite(
        image: CGImage,
        to url: URL,
        utType: UTType,
        quality: Double,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, utType.identifier as CFString, 1, nil) else {
            throw ScreenshotError.failedToCreateDestination
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenshotError.failedToFinalizeDestination
        }
    }

    private static func downscale(image: CGImage, targetWidth: Int) -> CGImage? {
        guard targetWidth > 0 else { return nil }
        let sourceWidth = image.width
        let sourceHeight = image.height
        guard sourceWidth > targetWidth else { return nil }

        let scale = Double(targetWidth) / Double(sourceWidth)
        let targetHeight = max(1, Int((Double(sourceHeight) * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()
    }

    private static func isLikelyBlackFrame(image: CGImage) -> Bool {
        let sampleSide = 8
        let bytesPerRow = sampleSide * 4

        guard let context = CGContext(
            data: nil,
            width: sampleSide,
            height: sampleSide,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return false
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide))

        guard let ptr = context.data?.bindMemory(to: UInt8.self, capacity: sampleSide * sampleSide * 4) else {
            return false
        }

        let threshold: UInt8 = 6
        for offset in stride(from: 0, to: sampleSide * sampleSide * 4, by: 4) {
            let r = ptr[offset]
            let g = ptr[offset + 1]
            let b = ptr[offset + 2]
            if r > threshold || g > threshold || b > threshold {
                return false
            }
        }
        return true
    }

    private static func screenshotsBaseDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)

        let appName: String = {
            if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
                return name
            }
            if let id = Bundle.main.bundleIdentifier?.split(separator: ".").last {
                return String(id)
            }
            return "LTATApp"
        }()

        return appSupport
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func quantumKey(startedAt: Date, endedAt: Date) -> String {
        "quantum-\(timestampKey(for: startedAt))-\(timestampKey(for: endedAt))"
    }

    private static func timestampKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter.string(from: date)
    }
}

private enum ScreenshotFormat: String {
    case jpeg
    case heic

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "heic", "heif":
            self = .heic
        default:
            self = .jpeg
        }
    }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .heic: return .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .heic: return "heic"
        }
    }
}

private enum ScreenshotError: Error {
    case failedToCreateDestination
    case failedToFinalizeDestination
}
