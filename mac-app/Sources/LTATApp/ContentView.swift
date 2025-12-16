import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var permissions = PermissionsManager()
    private let launchAgent = LaunchAgentManager()
    @State private var launchAgentInstalled: Bool = false
    @State private var launchAgentStatusMessage: String = ""

    var body: some View {
        if permissions.isReadyForTracking {
            mainView
        } else {
            OnboardingView(permissions: permissions)
        }
    }

    private var mainView: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            projectTaskPicker
            statusControls
            configSummary
            launchAgentControls
            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .task {
            refreshLaunchAgentStatus()
        }
        .alert(
            viewModel.resumePrompt?.title ?? "Resume tracking?",
            isPresented: Binding(
                get: { viewModel.resumePrompt != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissResumePrompt()
                    }
                }
            )
        ) {
            Button("Resume") {
                viewModel.resumeAfterPause()
            }
            Button("Stop") {
                viewModel.stopTracking()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissResumePrompt()
            }
        } message: {
            Text(viewModel.resumePrompt?.message ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lightweight Time & Activity Tracker")
                .font(.title2.weight(.semibold))
            Text("Статус: \(viewModel.status.rawValue)")
                .foregroundStyle(.secondary)
        }
    }

    private var projectTaskPicker: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Проект")
                TextField("Project", text: $viewModel.currentProject)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading) {
                Text("Задача")
                TextField("Task", text: $viewModel.currentTask)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var statusControls: some View {
        HStack(spacing: 12) {
            Button("Start") {
                viewModel.startTracking()
            }
            .disabled(viewModel.status == .tracking)

            Button("Stop") {
                viewModel.stopTracking()
            }
            .disabled(viewModel.status == .stopped)

            Button("Resume") {
                viewModel.resumeAfterPause()
            }
            .disabled(viewModel.status != .pausedBySystem)

            Spacer()
            Text(viewModel.lastLogMessage)
                .foregroundStyle(.secondary)
        }
    }

    private var configSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Конфиг (квант \(viewModel.config.quantum.quantumSeconds)s, partial drop <\(viewModel.config.quantum.minPartialSecondsDrop)s, too_short <\(viewModel.config.quantum.minPartialSecondsTooShort)s)")
                .font(.subheadline)
            Text("Screenshots: \(viewModel.config.screenshots.downscaleWidth)px \(viewModel.config.screenshots.format.uppercased()), keep \(viewModel.config.screenshots.storagePolicy.fallbackDays)d until sync.")
                .foregroundStyle(.secondary)
            Text("Activity thresholds: low <\(viewModel.config.activity.lowActivityThreshold)% | weights k/c/s/m: \(viewModel.config.activity.weights.keypress)/\(viewModel.config.activity.weights.click)/\(viewModel.config.activity.weights.scroll)/\(viewModel.config.activity.weights.mouseDistance)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
    }

    private var launchAgentControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto-start helper (LaunchAgent)")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Text(launchAgentInstalled ? "Installed" : "Not installed")
                    .foregroundStyle(launchAgentInstalled ? .green : .secondary)
                Spacer()
                Button("Install") { installLaunchAgent() }
                    .disabled(launchAgentInstalled)
                Button("Uninstall") { uninstallLaunchAgent() }
                    .disabled(!launchAgentInstalled)
                Button("Refresh") { refreshLaunchAgentStatus() }
            }
            if !launchAgentStatusMessage.isEmpty {
                Text(launchAgentStatusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
    }

    private func refreshLaunchAgentStatus() {
        launchAgentInstalled = launchAgent.isInstalled()
    }

    private func installLaunchAgent() {
        do {
            try launchAgent.install()
            launchAgentInstalled = true
            launchAgentStatusMessage = "Installed (\(launchAgent.label))"
            AppLogger.shared.log(level: .info, component: "launchagent", message: "Installed from UI", metadata: ["label": launchAgent.label])
        } catch {
            launchAgentStatusMessage = "Install failed: \(error)"
            AppLogger.shared.log(level: .error, component: "launchagent", message: "Install failed: \(error)", metadata: ["label": launchAgent.label])
        }
    }

    private func uninstallLaunchAgent() {
        do {
            try launchAgent.uninstall()
            launchAgentInstalled = false
            launchAgentStatusMessage = "Uninstalled (\(launchAgent.label))"
            AppLogger.shared.log(level: .info, component: "launchagent", message: "Uninstalled from UI", metadata: ["label": launchAgent.label])
        } catch {
            launchAgentStatusMessage = "Uninstall failed: \(error)"
            AppLogger.shared.log(level: .error, component: "launchagent", message: "Uninstall failed: \(error)", metadata: ["label": launchAgent.label])
        }
    }
}
