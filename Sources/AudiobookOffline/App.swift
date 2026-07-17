import SwiftUI
import AppKit

@main
struct AudiobookOfflineApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    if appState.isLoggedIn {
                        await appState.loadLibraries()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    let alert = NSAlert()
                    alert.messageText = "Keyboard Shortcuts"
                    alert.informativeText = "Space — Play / Pause (while a book is open)"
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                Divider()
                Button("AudiobookOffline on GitHub") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/shaynetroxler/AudiobookOffline")!)
                }
            }
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.isLoggedIn {
            LibraryView()
        } else {
            LoginView()
        }
    }
}
