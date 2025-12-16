import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            rows
            footer
            Spacer()
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Онбординг и разрешения")
                .font(.title2.weight(.semibold))
            Text("Чтобы трекинг работал, приложению нужны разрешения macOS. После выдачи разрешений вернись в приложение — статусы обновятся автоматически.")
                .foregroundStyle(.secondary)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 12) {
            PermissionRow(
                title: "Screen Recording",
                subtitle: "Нужно для захвата скриншотов всех дисплеев",
                status: permissions.screenRecording,
                footnote: permissions.screenRecording == .missing ? "Если разрешение уже включено, macOS может требовать перезапуск приложения." : nil,
                primaryActionTitle: "Request",
                primaryAction: { permissions.requestScreenRecording() },
                secondaryActionTitle: "Open Settings",
                secondaryAction: { permissions.openSystemSettingsScreenRecording() }
            )

            PermissionRow(
                title: "Accessibility",
                subtitle: "Нужно для мониторинга активности (event taps)",
                status: permissions.accessibility,
                primaryActionTitle: "Request",
                primaryAction: { permissions.requestAccessibility() },
                secondaryActionTitle: "Open Settings",
                secondaryAction: { permissions.openSystemSettingsAccessibility() }
            )

            PermissionRow(
                title: "Input Monitoring",
                subtitle: "Нужно для чтения событий клавиатуры/мыши; выдаётся в Privacy & Security",
                status: permissions.inputMonitoring,
                footnote: permissions.inputMonitoring == .missing ? "Если уже включено, перезапусти приложение и проверь снова." : nil,
                primaryActionTitle: "Open Settings",
                primaryAction: { permissions.openSystemSettingsInputMonitoring() }
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Refresh status") {
                permissions.refresh()
            }
            Spacer()
            Text(permissions.isReadyForTracking ? "Готово к трекингу" : "Трекинг пока недоступен")
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let status: PermissionStatus
    let footnote: String?
    let primaryActionTitle: String
    let primaryAction: () -> Void
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        status: PermissionStatus,
        footnote: String? = nil,
        primaryActionTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.status = status
        self.footnote = footnote
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(status: status)
            }
            HStack(spacing: 10) {
                Button(primaryActionTitle, action: primaryAction)
                if let secondaryActionTitle, let secondaryAction {
                    Button(secondaryActionTitle, action: secondaryAction)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor)))
    }
}

private struct StatusPill: View {
    let status: PermissionStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .unknown:
            return "UNKNOWN"
        case .missing:
            return "MISSING"
        case .granted:
            return "GRANTED"
        }
    }

    private var color: Color {
        switch status {
        case .unknown:
            return .secondary
        case .missing:
            return .red
        case .granted:
            return .green
        }
    }
}
