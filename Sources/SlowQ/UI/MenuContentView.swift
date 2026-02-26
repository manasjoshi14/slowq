import SwiftUI

struct MenuContentView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject private var settings: SettingsStore
    private let openSettingsAction: () -> Void

    init(coordinator: AppCoordinator, openSettingsAction: @escaping () -> Void = {}) {
        self.coordinator = coordinator
        _settings = ObservedObject(wrappedValue: coordinator.settings)
        self.openSettingsAction = openSettingsAction
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

    private var statusTitle: String {
        coordinator.isInterceptionRunning ? "Protection Active" : "Protection Paused"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status hero
            VStack(spacing: 4) {
                Image(systemName: coordinator.menuBarSymbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(coordinator.isInterceptionRunning ? .primary : .secondary)
                Text(statusTitle)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .opacity(coordinator.isInterceptionRunning ? 1 : 0.6)

            Divider()
                .padding(.horizontal, 12)

            // Toggles
            HStack {
                Text("Protection")
                Spacer()
                Toggle("", isOn: $settings.isProtectionEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 7)

            HStack {
                Text("Launch at Login")
                Spacer()
                Toggle("", isOn: $settings.launchAtLogin)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 7)

            // Delay slider
            VStack(spacing: 6) {
                HStack {
                    Text("Delay")
                        .font(.system(size: 12))
                    Spacer()
                    Text(formattedDelay)
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: delayBinding,
                    in: Double(SettingsStore.minDelayMs)...Double(SettingsStore.maxDelayMs),
                    step: 50
                )
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .disabled(!settings.isProtectionEnabled)
            .opacity(settings.isProtectionEnabled ? 1 : 0.5)

            // Bottom actions
            HStack {
                Button("Settings\u{2026}") {
                    openSettingsAction()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))

                Spacer()

                Button("Quit SlowQ") {
                    coordinator.quit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 220)
        .onAppear {
            coordinator.refreshRuntimeState()
        }
    }
}
