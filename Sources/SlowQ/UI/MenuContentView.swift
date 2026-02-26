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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Protection Enabled", isOn: $settings.isProtectionEnabled)
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)

            Divider()

            HStack {
                Text("Delay")
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
            .controlSize(.small)

            Divider()

            Button("Open Settings...", action: openSettingsAction)
            Button("Quit SlowQ", role: .destructive, action: coordinator.quit)
        }
        .padding(12)
        .frame(width: 300)
        .onAppear {
            coordinator.refreshRuntimeState()
        }
    }
}
