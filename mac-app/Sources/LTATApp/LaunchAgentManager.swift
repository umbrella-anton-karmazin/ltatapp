import Foundation
import Darwin

struct LaunchAgentManager {
    let label = "com.ltatapp.helper"

    func isInstalled(fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: plistURL(fileManager: fileManager).path)
    }

    func install(fileManager: FileManager = .default) throws {
        let plistURL = plistURL(fileManager: fileManager)
        try? fileManager.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

        let executablePath = resolveExecutablePath(fileManager: fileManager)
        let stdoutPath = logURL(fileManager: fileManager, filename: "ltat-helper.out.log").path
        let stderrPath = logURL(fileManager: fileManager, filename: "ltat-helper.err.log").path

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath, "--helper"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "StandardOutPath": stdoutPath,
            "StandardErrorPath": stderrPath
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: [.atomic])

        try bootoutIfLoaded(plistURL: plistURL)
        try bootstrap(plistURL: plistURL)
    }

    func uninstall(fileManager: FileManager = .default) throws {
        let plistURL = plistURL(fileManager: fileManager)
        try bootoutIfLoaded(plistURL: plistURL)
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    func installOrLogError(logger: AppLogger = .shared) {
        do {
            try install()
            logger.log(level: .info, component: "launchagent", message: "LaunchAgent installed", metadata: ["label": label])
        } catch {
            logger.log(level: .error, component: "launchagent", message: "LaunchAgent install failed: \(error)", metadata: ["label": label])
        }
    }

    func uninstallOrLogError(logger: AppLogger = .shared) {
        do {
            try uninstall()
            logger.log(level: .info, component: "launchagent", message: "LaunchAgent uninstalled", metadata: ["label": label])
        } catch {
            logger.log(level: .error, component: "launchagent", message: "LaunchAgent uninstall failed: \(error)", metadata: ["label": label])
        }
    }

    private func plistURL(fileManager: FileManager) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    private func logURL(fileManager: FileManager, filename: String) -> URL {
        let dir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("LTATApp")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        return dir.appendingPathComponent(filename)
    }

    private func resolveExecutablePath(fileManager: FileManager) -> String {
        if let url = Bundle.main.executableURL {
            return url.path
        }

        let raw = CommandLine.arguments.first ?? "LTATApp"
        if raw.hasPrefix("/") {
            return raw
        }
        return URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(raw).standardizedFileURL.path
    }

    private func bootstrap(plistURL: URL) throws {
        let domain = "gui/\(geteuid())"
        try runLaunchctl(arguments: ["bootstrap", domain, plistURL.path])
    }

    private func bootoutIfLoaded(plistURL: URL) throws {
        let domain = "gui/\(geteuid())"
        _ = try? runLaunchctl(arguments: ["bootout", domain, plistURL.path])
    }

    @discardableResult
    private func runLaunchctl(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: stdoutData + stderrData, as: UTF8.self)

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "LaunchAgentManager",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "launchctl \(arguments.joined(separator: " ")) failed: \(output)"]
            )
        }

        return output
    }
}
