import Foundation

enum LogLevel: String, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

struct AuditEvent: Codable, Sendable {
    let timestamp: Date
    let level: LogLevel
    let component: String
    let message: String
    let metadata: [String: String]?
}

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private static let queueKey = DispatchSpecificKey<UInt8>()
    private let queue = DispatchQueue(label: "ltatapp.logger", qos: .background)
    private var fileHandle: FileHandle?
    private var logLevel: LogLevel = .info
    private var logURL: URL?

    init(config: AppConfig = .default, fileManager: FileManager = .default) {
        queue.setSpecific(key: AppLogger.queueKey, value: 1)
        apply(config: config, fileManager: fileManager)
    }

    func log(level: LogLevel, component: String = "app", message: String, metadata: [String: String]? = nil) {
        let event = AuditEvent(timestamp: Date(), level: level, component: component, message: message, metadata: metadata)
        queue.async { [weak self] in
            guard let self else { return }
            guard self.shouldLog(level: level) else { return }
            self.write(event: event)
        }
    }

    func apply(config: AppConfig, fileManager: FileManager = .default) {
        syncOnQueue {
            logLevel = LogLevel(rawValue: config.logging.logLevel.lowercased()) ?? .info
            let resolved = AppLogger.resolveLogURL(from: config, fileManager: fileManager)
            guard resolved != logURL else { return }
            logURL = resolved
            fileManager.createIntermediateDirectories(for: resolved)
            fileHandle = FileHandle(forWritingAtPath: resolved.path) ?? FileManager.default.createAndReturnFileHandle(at: resolved)
        }
    }

    private func shouldLog(level: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error]
        guard let current = order.firstIndex(of: logLevel),
              let incoming = order.firstIndex(of: level) else { return true }
        return incoming >= current
    }

    private func write(event: AuditEvent) {
        guard let fileHandle else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(event) else { return }
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        fileHandle.write(Data([0x0a])) // newline
    }

    private static func resolveLogURL(from config: AppConfig, fileManager: FileManager) -> URL {
        if config.logging.logFilePath.hasPrefix("/") {
            return URL(fileURLWithPath: config.logging.logFilePath)
        }
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        return base.appendingPathComponent(config.logging.logFilePath)
    }

    private func syncOnQueue(_ body: () -> Void) {
        if DispatchQueue.getSpecific(key: AppLogger.queueKey) != nil {
            body()
            return
        }
        queue.sync(execute: body)
    }
}

private extension FileManager {
    func createIntermediateDirectories(for url: URL) {
        let dir = url.deletingLastPathComponent()
        if !fileExists(atPath: dir.path) {
            try? createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func createAndReturnFileHandle(at url: URL) -> FileHandle? {
        if !fileExists(atPath: url.path) {
            createFile(atPath: url.path, contents: nil)
        }
        return FileHandle(forWritingAtPath: url.path)
    }
}
