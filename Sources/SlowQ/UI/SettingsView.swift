import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    private var delayBinding: Binding<Double> {
        Binding(
            get: { Double(coordinator.settings.delayMs) },
            set: { coordinator.settings.delayMs = Int($0.rounded()) }
        )
    }

    var body: some View {
        Form {
            Section("Protection") {
                Toggle("Enable Cmd+Q protection", isOn: $coordinator.settings.isProtectionEnabled)
                HStack {
                    Text("Hold delay")
                    Spacer()
                    Text("\(coordinator.settings.delayMs) ms")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: delayBinding,
                    in: Double(SettingsStore.minDelayMs)...Double(SettingsStore.maxDelayMs),
                    step: 25
                )
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $coordinator.settings.launchAtLogin)
                Text("SlowQ always shows a progress overlay while Cmd+Q is held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(
                        coordinator.permissionState == .granted
                            ? "Accessibility Access Granted" : "Accessibility Access Needed",
                        systemImage: coordinator.permissionState == .granted
                            ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(coordinator.permissionState == .granted ? .green : .yellow)

                    Spacer()

                    Button("Request Permission") {
                        coordinator.requestPermissions()
                    }
                }
            }

            if let lastError = coordinator.lastError {
                Section("Diagnostics") {
                    Text(lastError)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}
