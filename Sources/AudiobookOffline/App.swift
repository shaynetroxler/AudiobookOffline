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
                Button("Tips & Shortcuts") {
                    let alert = NSAlert()
                    alert.messageText = "Tips & Shortcuts"
                    alert.informativeText = "Space — Play / Pause (while a book is open)\n\nToolbar bar-graph icon — View library stats (item count, hours, top authors, genres, and more)\n\nBooks / Series / Collections tabs — Browse by series or collection instead of the flat book list (these are created on the server; the app only displays them)"
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
