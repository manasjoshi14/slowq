import SwiftUI

@main
struct SlowQApp: App {
    @StateObject private var coordinator: AppCoordinator

    init() {
        _coordinator = StateObject(wrappedValue: AppCoordinator())
    }

    init(coordinator: AppCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some Scene {
        MenuBarExtra("SlowQ", systemImage: coordinator.menuBarSymbolName) {
            MenuContentView(coordinator: coordinator) {
                coordinator.showSettings()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(coordinator: coordinator)
                .frame(width: 420)
                .padding()
        }
    }
}
