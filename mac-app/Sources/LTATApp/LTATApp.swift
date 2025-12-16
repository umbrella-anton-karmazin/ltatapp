import SwiftUI

struct LTATApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let config = ConfigLoader.load()
        AppLogger.shared.apply(config: config)
        AppLogger.shared.log(level: .info, component: "bootstrap", message: "Config loaded; launching UI")
        _viewModel = StateObject(wrappedValue: AppViewModel(config: config))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
