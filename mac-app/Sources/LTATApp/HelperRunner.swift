import Foundation

enum HelperRunner {
    static func main() {
        let config = ConfigLoader.load()
        AppLogger.shared.apply(config: config)
        AppLogger.shared.log(level: .info, component: "helper", message: "Helper started", metadata: ["args": CommandLine.arguments.joined(separator: " ")])

        if CommandLine.arguments.contains("--once") {
            AppLogger.shared.log(level: .info, component: "helper", message: "Helper exiting (--once)")
            return
        }

        RunLoop.main.run()
    }
}

