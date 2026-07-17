import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var client: ABSClient?
    var isLoggedIn: Bool { client != nil }
    var loginError: String?
    var isLoggingIn = false

    let downloadManager = DownloadManager()
    let progressQueue = ProgressSyncQueue()

    var libraries: [ABSLibrary] = []
    var selectedLibrary: ABSLibrary?

    init() {
        if let creds = KeychainStore.load() {
            client = ABSClient(baseURL: creds.serverURL, token: creds.token)
        }
    }

    func login(serverURLString: String, username: String, password: String) async {
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }

        var urlString = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "http://" + urlString
        }
        guard let url = URL(string: urlString) else {
            loginError = "That doesn't look like a valid server address."
            return
        }

        do {
            let response = try await ABSClient.login(serverURL: url, username: username, password: password)
            KeychainStore.save(ServerCredentials(serverURL: url, username: username, token: response.user.token))
            client = ABSClient(baseURL: url, token: response.user.token)
            await loadLibraries()
        } catch {
            loginError = error.localizedDescription
        }
    }

    func logout() {
        KeychainStore.clear()
        client = nil
        libraries = []
        selectedLibrary = nil
    }

    func loadLibraries() async {
        guard let client else { return }
        do {
            libraries = try await client.libraries()
            if selectedLibrary == nil {
                selectedLibrary = libraries.first
            }
            await progressQueue.flush(client: client)
        } catch {
            // Offline at launch is fine — cached library list (if any) and downloaded
            // books remain usable; we'll retry next time the app becomes active.
        }
    }
}
