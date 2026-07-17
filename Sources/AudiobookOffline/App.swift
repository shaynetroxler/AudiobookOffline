import SwiftUI

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
