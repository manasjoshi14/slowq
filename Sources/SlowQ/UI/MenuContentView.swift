import SwiftUI

struct MenuContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Protection Enabled", isOn: $coordinator.settings.isProtectionEnabled)
            Toggle("Launch at Login", isOn: $coordinator.settings.launchAtLogin)

            Text("Delay: \(coordinator.settings.delayMs) ms")
                .font(.caption)
                .foregroundStyle(.secondary)

            if coordinator.permissionState != .granted {
                Button("Grant Accessibility Permission") {
                    coordinator.requestPermissions()
                }
                Button("Open Accessibility Settings") {
                    coordinator.openSystemSettings()
                }
            }

            if let lastError = coordinator.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            Button("Open Settings") {
                coordinator.showSettings()
            }
            Button("Quit SlowQ") {
                coordinator.quit()
            }
        }
        .padding(12)
        .frame(minWidth: 300)
    }
}
