import Foundation
import Yams

enum ConfigLoaderError: Error {
    case fileNotFound(URL)
    case decodeFailed(Error)
    case yamlNotMapping
    case yamlUnsupportedValue(String)
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
            return try decodeYAML(string)
        default:
            throw ConfigLoaderError.decodeFailed(NSError(domain: "ConfigLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported config format \(ext)"]))
        }
    }

    private static func decodeYAML(_ string: String) throws -> AppConfig {
        let loaded = try Yams.load(yaml: string)
        guard let mapping = loaded as? [AnyHashable: Any] else {
            throw ConfigLoaderError.yamlNotMapping
        }

        let jsonObject = try jsonObject(from: mapping)
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AppConfig.self, from: data)
    }

    private static func jsonObject(from value: Any) throws -> Any {
        if value is NSNull {
            return NSNull()
        }

        switch value {
        case let mapping as [AnyHashable: Any]:
            var result: [String: Any] = [:]
            result.reserveCapacity(mapping.count)
            for (key, value) in mapping {
                result[String(describing: key)] = try jsonObject(from: value)
            }
            return result
        case let array as [Any]:
            return try array.map { try jsonObject(from: $0) }
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        default:
            throw ConfigLoaderError.yamlUnsupportedValue(String(describing: type(of: value)))
        }
    }
}
