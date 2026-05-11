import OuraKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var token = ""
    @State private var validationMessage = ""
    @State private var isValidating = false

    private let keychain = KeychainStore.shared
    private let validator = TokenValidator()

    var body: some View {
        TabView {
            Form {
                SecureField("Oura Personal Access Token", text: $token)
                HStack {
                    Button("Validate & Save") {
                        validateAndSave()
                    }
                    .disabled(isValidating || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Link("Create token", destination: URL(string: "https://cloud.ouraring.com/personal-access-tokens")!)
                }
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .foregroundStyle(validationMessage == "Token saved." ? .green : .red)
                }
            }
            .padding()
            .tabItem { Label("Account", systemImage: "key") }

            Form {
                Picker("Refresh", selection: $settings.refreshCadence) {
                    ForEach(SettingsStore.RefreshCadence.allCases) { cadence in
                        Text(cadence.label).tag(cadence)
                    }
                }
                Picker("Menu Bar Metric", selection: $settings.selectedMetric) {
                    ForEach(BarMetric.allCases) { metric in
                        Label(metric.label, systemImage: metric.symbolName).tag(metric)
                    }
                }
            }
            .padding()
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 500, height: 320)
        .onAppear {
            token = (try? keychain.readToken()) ?? ""
        }
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
                    } catch {
                        validationMessage = error.localizedDescription
                    }
                } else {
                    validationMessage = result.message ?? "Token invalid."
                }
            }
        }
    }
}
