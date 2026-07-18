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
                    alert.informativeText = "Space — Play / Pause (while a book is open)\n\nToolbar bar-graph icon — View library stats (item count, hours, top authors, genres, and more)\n\nBooks / Series / Collections tabs — Browse by series or collection instead of the flat book list (these are created on the server; the app only displays them)\n\nContinue Listening — Books you've started appear in their own section at the top of the Books tab, sorted by most recently played, so you don't have to search for what you're mid-book on\n\nDone with a book? — Open it, then use the ••• menu at the top of the player and choose \"Remove from Continue Listening\" to drop it off that shelf without losing your saved position\n\nNow Playing controls — Playback shows up in macOS's Control Center Now Playing widget and any Dynamic Island-style menu bar app (e.g. Alcove), with play/pause/skip and live progress, so you can control it without switching back to this app"
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
