import Selby2Kit
import SwiftUI

@main
struct Selby2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Selby", systemImage: "globe") {
            Button("Settings…") { SettingsWindow.shared.show() }
            Divider()
            Button("Quit Selby") { NSApp.terminate(nil) }
        }
    }
}
