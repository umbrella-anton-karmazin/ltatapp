import Foundation
import Yams

enum ConfigLoaderError: Error {
    case fileNotFound(URL)
    case decodeFailed(Error)
}

struct ConfigLoader {
    /// Attempt to load config from a given URL. If nil, searches common filenames in working dir then bundled defaults.
    static func load(from url: URL? = nil, fileManager: FileManager = .default) -> AppConfig {
        let candidates: [URL] = {
            if let url {
                return [url]
            }
            let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            let paths = [
                cwd.appendingPathComponent("config.json"),
                cwd.appendingPathComponent("config.yaml"),
                cwd.appendingPathComponent("config.yml")
            ]
            let bundled = [
                Bundle.module.url(forResource: "config", withExtension: "json"),
                Bundle.module.url(forResource: "config", withExtension: "yaml"),
                Bundle.module.url(forResource: "config", withExtension: "yml"),
                Bundle.module.url(forResource: "config.default", withExtension: "json")
            ].compactMap { $0 }
            return paths + bundled
        }()

        for candidate in candidates {
            if fileManager.fileExists(atPath: candidate.path) {
                do {
                    return try decodeConfig(at: candidate)
                } catch {
                    AppLogger.shared.log(level: .error, message: "Failed to decode config at \(candidate.lastPathComponent): \(error)")
                    continue
                }
            }
        }

        AppLogger.shared.log(level: .warning, message: "Config not found; using defaults")
        return .default
    }

    private static func decodeConfig(at url: URL) throws -> AppConfig {
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "json":
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(AppConfig.self, from: data)
        case "yaml", "yml":
            let string = String(decoding: data, as: UTF8.self)
            let decoder = YAMLDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(AppConfig.self, from: string)
        default:
            throw ConfigLoaderError.decodeFailed(NSError(domain: "ConfigLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported config format \(ext)"]))
        }
    }
}
