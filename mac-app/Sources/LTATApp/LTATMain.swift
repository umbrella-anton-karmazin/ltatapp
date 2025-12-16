import Foundation
import SwiftUI

@main
enum LTATMain {
    static func main() {
        let args = CommandLine.arguments

        if args.contains("--helper") {
            HelperRunner.main()
            return
        }

        if args.contains("--install-launchagent") {
            LaunchAgentManager().installOrLogError()
            return
        }

        if args.contains("--uninstall-launchagent") {
            LaunchAgentManager().uninstallOrLogError()
            return
        }

        if args.contains("--smoke-activity") {
            ActivitySmokeRunner.main()
            return
        }

        if args.contains("--smoke-focus") {
            FocusSmokeRunner.main()
            return
        }

        LTATApp.main()
    }
}
