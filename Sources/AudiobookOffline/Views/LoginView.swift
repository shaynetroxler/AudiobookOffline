import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect to Audiobookshelf")
                .font(.title2)
                .bold()

            Form {
                TextField("Server address (e.g. http://192.168.1.10:13378)", text: $serverURL)
                    .frame(maxWidth: .infinity)
                TextField("Username", text: $username)
                    .frame(maxWidth: .infinity)
                SecureField("Password", text: $password)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 400)

            if let error = appState.loginError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Button {
                Task {
                    await appState.login(serverURLString: serverURL, username: username, password: password)
                }
            } label: {
                if appState.isLoggingIn {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Log In")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(appState.isLoggingIn || serverURL.isEmpty || username.isEmpty || password.isEmpty)
        }
        .padding(32)
        .frame(minWidth: 500, minHeight: 320)
    }
}
