import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            projectTaskPicker
            statusControls
            configSummary
            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
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
}
