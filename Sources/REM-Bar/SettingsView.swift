import OuraKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var token = ""
    @State private var validationMessage = ""
    @State private var isValidating = false
    @State private var tokenSource: TokenSource = .missing

    private let keychain = KeychainStore.shared
    private let validator = TokenValidator()

    var body: some View {
        TabView {
            accountPane
            .padding()
            .tabItem { Label("Account", systemImage: "key") }

            displayPane
            .padding()
            .tabItem { Label("Display", systemImage: "menubar.rectangle") }

            aboutPane
                .padding()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 400)
        .onAppear {
            reloadTokenState()
        }
    }

    private var accountPane: some View {
        Form {
            LabeledContent("Active token source") {
                HStack(spacing: 6) {
                    Image(systemName: tokenSource.symbolName)
                        .foregroundStyle(tokenSource.tint)
                    Text(tokenSource.label)
                }
            }

            Text(tokenSource.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("Oura Personal Access Token", text: $token)

            HStack {
                Button(isValidating ? "Validating..." : "Validate & Save to Keychain") {
                    validateAndSave()
                }
                .disabled(isValidating || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Remove Keychain Token", role: .destructive) {
                    removeKeychainToken()
                }
                .disabled(!tokenSource.hasKeychainToken)

                Spacer()

                Link("Create token", destination: URL(string: "https://cloud.ouraring.com/personal-access-tokens")!)
            }

            if !validationMessage.isEmpty {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationMessage == "Token saved." ? .green : .red)
            }
        }
    }

    private var displayPane: some View {
        Form {
            Picker("Refresh cadence", selection: $settings.refreshCadence) {
                ForEach(SettingsStore.RefreshCadence.allCases) { cadence in
                    Text(cadence.label).tag(cadence)
                }
            }
            Picker("Menu-bar metric", selection: $settings.selectedMetric) {
                ForEach(BarMetric.allCases) { metric in
                    Label(metric.label, systemImage: metric.symbolName).tag(metric)
                }
            }
            Text("Refresh is driven by display-link ticks so requests pause while the display is asleep.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var aboutPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("REM-Bar")
                .font(.title2.weight(.semibold))
            Text("Native macOS menu-bar app for Oura Ring sleep, REM, HRV, resting heart rate, and readiness data.")
            Text("No synthetic data mode is implemented. Values shown in the menu bar and popover come from Oura API v2 using the active token source, or remain empty when no token/data is available.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func validateAndSave() {
        isValidating = true
        validationMessage = ""
        let proposedToken = token
        Task {
            let result = await validator.validate(token: proposedToken)
            await MainActor.run {
                isValidating = false
                if result.isValid {
                    do {
                        try keychain.saveToken(proposedToken.trimmingCharacters(in: .whitespacesAndNewlines))
                        validationMessage = "Token saved."
                        reloadTokenState()
                        NotificationCenter.default.post(name: .remBarTokenDidChange, object: nil)
                    } catch {
                        validationMessage = error.localizedDescription
                    }
                } else {
                    validationMessage = result.message ?? "Token invalid."
                }
            }
        }
    }

    private func removeKeychainToken() {
        do {
            try keychain.deleteToken()
            validationMessage = "Keychain token removed."
            reloadTokenState()
            NotificationCenter.default.post(name: .remBarTokenDidChange, object: nil)
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func reloadTokenState() {
        let envToken = ProcessInfo.processInfo.environment["OURA_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainToken = try? keychain.readToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
        let configToken = OuraClient.configFileToken()?.trimmingCharacters(in: .whitespacesAndNewlines)

        token = keychainToken ?? ""
        if let envToken, !envToken.isEmpty {
            tokenSource = .environment(hasKeychainToken: !(keychainToken ?? "").isEmpty)
        } else if let keychainToken, !keychainToken.isEmpty {
            tokenSource = .keychain
        } else if let configToken, !configToken.isEmpty {
            tokenSource = .config
        } else {
            tokenSource = .missing
        }
    }
}

private enum TokenSource: Equatable {
    case environment(hasKeychainToken: Bool)
    case keychain
    case config
    case missing

    var label: String {
        switch self {
        case .environment:
            return "OURA_TOKEN environment override"
        case .keychain:
            return "REM-Bar Keychain"
        case .config:
            return "~/.oura-mcp/config.json"
        case .missing:
            return "No token configured"
        }
    }

    var detail: String {
        switch self {
        case .environment:
            return "The app is using OURA_TOKEN before Keychain or config fallback. Saved Keychain tokens will not be active until that environment variable is removed."
        case .keychain:
            return "The app and bundled MCP server are using the shared REM-Bar Keychain token."
        case .config:
            return "The app is using the oura-mcp compatibility config fallback. Save a token here to move it into the REM-Bar Keychain."
        case .missing:
            return "Paste a Personal Access Token to load real Oura data. The app does not generate demo values."
        }
    }

    var symbolName: String {
        switch self {
        case .environment:
            return "terminal"
        case .keychain:
            return "key.fill"
        case .config:
            return "doc.text"
        case .missing:
            return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .environment, .config:
            return .orange
        case .keychain:
            return .green
        case .missing:
            return .red
        }
    }

    var hasKeychainToken: Bool {
        switch self {
        case .keychain:
            return true
        case let .environment(hasKeychainToken):
            return hasKeychainToken
        case .config, .missing:
            return false
        }
    }
}
