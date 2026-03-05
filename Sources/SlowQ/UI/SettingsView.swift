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

    private var formattedDelay: String {
        "\(settings.delayMs) ms"
    }

    @ViewBuilder
    private func permissionRow(_ label: String, state: PermissionState, kind: PermissionKind) -> some View {
        HStack {
            Text(label)
            Spacer()
            if state == .granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    coordinator.requestPermission(kind)
                } label: {
                    Label("Grant Access", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private static let cardShape = RoundedRectangle(cornerRadius: 8)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Protection")
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Cmd+Q Protection", isOn: $settings.isProtectionEnabled)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Hold Delay")
                            Spacer()
                            Text(formattedDelay)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: delayBinding,
                            in: Double(SettingsStore.minDelayMs)...Double(SettingsStore.maxDelayMs),
                            step: 50
                        )
                    }
                    .disabled(!settings.isProtectionEnabled)
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .clipShape(Self.cardShape)

                sectionHeader("System")
                VStack(spacing: 0) {
                    HStack {
                        Text("Launch at Login")
                        Spacer()
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()
                    permissionRow("Input Monitoring", state: coordinator.inputMonitoringState, kind: .inputMonitoring)

                    Divider()
                    permissionRow("Accessibility", state: coordinator.accessibilityState, kind: .accessibility)
                }
                .background(Color(.controlBackgroundColor))
                .clipShape(Self.cardShape)

                Text("SlowQ requires Input Monitoring and Accessibility permissions to intercept Cmd+Q. The overlay appears while the shortcut is held.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if let lastError = coordinator.lastError {
                    sectionHeader("Diagnostics")
                    Text(lastError)
                        .foregroundStyle(.red)
                        .padding(12)
                        .background(Color(.controlBackgroundColor))
                        .clipShape(Self.cardShape)
                }
            }
            .padding()
        }
        .onAppear {
            coordinator.refreshRuntimeState()
        }
    }
}
