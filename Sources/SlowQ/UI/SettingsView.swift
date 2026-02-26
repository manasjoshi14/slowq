import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var settings: SettingsStore

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        _settings = ObservedObject(wrappedValue: coordinator.settings)
    }

    private var delayBinding: Binding<Double> {
        Binding(
            get: { Double(settings.delayMs) },
            set: { settings.delayMs = Int($0.rounded()) }
        )
    }

    var body: some View {
        Form {
            Section("Protection") {
                Toggle("Enable Cmd+Q protection", isOn: $settings.isProtectionEnabled)
                HStack {
                    Text("Hold delay")
                    Spacer()
                    Text("\(settings.delayMs) ms")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: delayBinding,
                    in: Double(SettingsStore.minDelayMs)...Double(SettingsStore.maxDelayMs),
                    step: 50
                )
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Text("SlowQ always shows a progress overlay while Cmd+Q is held.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Label(
                        coordinator.permissionState == .granted
                            ? "Input Monitoring Access Granted" : "Input Monitoring Access Needed",
                        systemImage: coordinator.permissionState == .granted
                            ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(coordinator.permissionState == .granted ? .green : .yellow)

                    Spacer()

                    Button("Request Permission") {
                        coordinator.requestPermissions()
                    }
                }

                if coordinator.permissionState != .granted {
                    Button("Open Input Monitoring Settings") {
                        coordinator.openSystemSettings()
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
        .onAppear {
            coordinator.refreshRuntimeState()
        }
    }
}
