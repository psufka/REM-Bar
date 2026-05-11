import OuraKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var token = ""
    @State private var validationMessage = ""
    @State private var isValidating = false
    @State private var tokenSource: TokenSource = .missing
    @State private var detectedTokenForImport: String?
    @State private var sourceSummaries: [OuraTokenSourceSummary] = []
    @State private var draggedMetric: BarMetric?
    @FocusState private var tokenFieldFocused: Bool

    private let keychain = KeychainStore.shared
    private let validator = TokenValidator()

    var body: some View {
        TabView {
            accountPane
                .padding(20)
                .tabItem { Label("Account", systemImage: "key") }

            displayPane
                .padding()
                .tabItem { Label("Display", systemImage: "menubar.rectangle") }

            aboutPane
                .padding()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 1080, height: 620)
        .onAppear {
            tokenFieldFocused = false
            Task {
                await reloadTokenState()
            }
        }
    }

    private var accountPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsSection("Oura Connection") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: tokenSource.symbolName)
                            .font(.title2)
                            .foregroundStyle(tokenSource.tint)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tokenSource.statusTitle)
                                .font(.headline)
                            Text(tokenSource.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                settingsSection("Token") {
                    VStack(alignment: .leading, spacing: 10) {
                        SecureField("Paste Personal Access Token", text: $token)
                            .textFieldStyle(.roundedBorder)
                            .focused($tokenFieldFocused)

                        HStack(spacing: 10) {
                            Button(isValidating ? "Validating..." : "Validate & Save") {
                                validateAndSave()
                            }
                            .disabled(isValidating || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Save Detected Token to Keychain") {
                                saveDetectedToken()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(detectedTokenForImport == nil || isValidating)

                            Spacer()

                            Link("Create token", destination: URL(string: "https://cloud.ouraring.com/personal-access-tokens")!)
                        }

                        if detectedTokenForImport != nil {
                            Text("Detected source: \(tokenSource.label). Saving copies that token into the REM-Bar Keychain without displaying it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !validationMessage.isEmpty {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(validationMessage == "Token saved." ? .green : .red)
                        }
                    }
                }

                settingsSection("Token Sources") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Priority: Environment -> Keychain -> oura-mcp config -> launchctl -> shell and dotenv files")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(sourceSummaries) { summary in
                                tokenSourceRow(summary)
                            }
                        }

                        Divider()

                        HStack {
                            Button("Remove Keychain Token", role: .destructive) {
                                removeKeychainToken()
                            }
                            .disabled(!tokenSource.hasKeychainToken)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var displayPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsSection("Display") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Refresh cadence")
                                .frame(width: 130, alignment: .leading)
                            Picker("Refresh cadence", selection: $settings.refreshCadence) {
                                ForEach(SettingsStore.RefreshCadence.allCases) { cadence in
                                    Text(cadence.label).tag(cadence)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 220)
                            Spacer(minLength: 0)
                        }

                        HStack {
                            Text("Menu-bar metric")
                                .frame(width: 130, alignment: .leading)
                            Picker("Menu-bar metric", selection: $settings.selectedMetric) {
                                ForEach(settings.orderedEnabledMetrics) { metric in
                                    Label(metric.label, systemImage: metric.symbolName).tag(metric)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 280)
                            Spacer(minLength: 0)
                        }
                    }
                }

                settingsSection("Metric cards") {
                    LazyVGrid(columns: metricCardColumns, alignment: .leading, spacing: 8) {
                        ForEach(settings.metricOrder) { metric in
                            MetricOrderRow(metric: metric, isEnabled: metricEnabledBinding(metric))
                                .onDrag {
                                    draggedMetric = metric
                                    return NSItemProvider(object: metric.rawValue as NSString)
                                }
                                .onDrop(
                                    of: [.plainText],
                                    delegate: MetricDropDelegate(
                                        targetMetric: metric,
                                        settings: settings,
                                        draggedMetric: $draggedMetric))
                        }
                    }
                }

                Text("Refresh is driven by display-link ticks so requests pause while the display is asleep.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var aboutPane: some View {
        VStack(spacing: 13) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
                .padding(.bottom, 4)

            VStack(spacing: 3) {
                Text("REM-Bar")
                    .font(.title2.weight(.bold))
                Text("Version \(appVersionString)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let buildString {
                    Text("Built \(buildString)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Keep Oura sleep, recovery, activity, and readiness in view.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
            }
            .multilineTextAlignment(.center)

            VStack(alignment: .center, spacing: 10) {
                AboutLinkRow(
                    icon: "chevron.left.slash.chevron.right",
                    title: "GitHub",
                    url: "https://github.com/psufka/REM-Bar")
                AboutLinkRow(
                    icon: "key",
                    title: "Oura Tokens",
                    url: "https://cloud.ouraring.com/personal-access-tokens")
                AboutLinkRow(
                    icon: "server.rack",
                    title: "MCP Docs",
                    url: "https://modelcontextprotocol.io")
                AboutLinkRow(
                    icon: "doc.text",
                    title: "README",
                    url: "https://github.com/psufka/REM-Bar#readme")
            }
            .padding(.top, 18)
            .frame(maxWidth: .infinity)

            Divider()
                .padding(.top, 4)

            VStack(spacing: 4) {
                Text("No synthetic data mode. Real Oura API v2 data only.")
                Text("Token discovery checks environment, Keychain, oura-mcp config, launchctl, and shell files.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    private var metricCardColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 295), spacing: 10, alignment: .topLeading), count: 3)
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    private var buildString: String? {
        guard let date = try? Bundle.main.executableURL?.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter.string(from: date)
    }

    private func validateAndSave() {
        validateAndSave(token)
    }

    private func validateAndSave(_ proposedToken: String) {
        isValidating = true
        validationMessage = ""
        Task {
            let result = await validator.validate(token: proposedToken)
            var didSave = false
            await MainActor.run {
                isValidating = false
                if result.isValid {
                    do {
                        try keychain.saveToken(proposedToken.trimmingCharacters(in: .whitespacesAndNewlines))
                        validationMessage = "Token saved."
                        didSave = true
                    } catch {
                        validationMessage = error.localizedDescription
                    }
                } else {
                    validationMessage = result.message ?? "Token invalid."
                }
            }
            if didSave {
                await reloadTokenState()
                await MainActor.run {
                    NotificationCenter.default.post(name: .remBarTokenDidChange, object: nil)
                }
            }
        }
    }

    private func saveDetectedToken() {
        guard let detectedTokenForImport else { return }
        token = detectedTokenForImport
        validateAndSave(detectedTokenForImport)
    }

    private func removeKeychainToken() {
        do {
            try keychain.deleteToken()
            validationMessage = "Keychain token removed."
            Task {
                await reloadTokenState()
                await MainActor.run {
                    NotificationCenter.default.post(name: .remBarTokenDidChange, object: nil)
                }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private func reloadTokenState() async {
        let keychain = keychain
        let loadedState = await Task.detached(priority: .userInitiated) {
            let keychainToken = try? keychain.readToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
            let discovery = OuraTokenDiscovery(keychainToken: {
                keychainToken
            })
            return LoadedTokenState(
                keychainToken: keychainToken,
                resolved: try? discovery.resolve(),
                summaries: (try? discovery.sourceSummaries()) ?? [])
        }.value

        token = loadedState.keychainToken ?? ""
        tokenSource = TokenSource(resolved: loadedState.resolved)
        sourceSummaries = loadedState.summaries
        if let resolved = loadedState.resolved, !resolved.source.isKeychain {
            detectedTokenForImport = resolved.token
        } else {
            detectedTokenForImport = nil
        }
    }

    private func metricEnabledBinding(_ metric: BarMetric) -> Binding<Bool> {
        Binding {
            settings.enabledMetrics.contains(metric)
        } set: { isEnabled in
            settings.setMetric(metric, enabled: isEnabled)
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func tokenSourceRow(_ summary: OuraTokenSourceSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: summary.isAvailable ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(summary.isAvailable ? .green : .secondary)
                .font(.caption)
            Text(summary.source.displayName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            if summary.isActive {
                Text("Active")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }
}

private struct AboutLinkRow: View {
    let icon: String
    let title: String
    let url: String
    @State private var hovering = false

    var body: some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 26)
                Text(title)
                    .underline(hovering, color: .accentColor)
            }
            .font(.title3.weight(.medium))
            .foregroundColor(.accentColor)
            .frame(width: 210, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct MetricOrderRow: View {
    let metric: BarMetric
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .help("Drag to reorder")

            Toggle(isOn: $isEnabled) {
                Label(metric.label, systemImage: metric.symbolName)
                    .lineLimit(1)
            }
            .toggleStyle(.checkbox)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct MetricDropDelegate: DropDelegate {
    let targetMetric: BarMetric
    let settings: SettingsStore
    @Binding var draggedMetric: BarMetric?

    func validateDrop(info _: DropInfo) -> Bool {
        draggedMetric != nil
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedMetric, draggedMetric != targetMetric else { return }
        settings.moveMetric(draggedMetric, to: targetMetric)
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        draggedMetric = nil
        return true
    }
}

private struct LoadedTokenState: Sendable {
    let keychainToken: String?
    let resolved: OuraResolvedToken?
    let summaries: [OuraTokenSourceSummary]
}

private enum TokenSource: Equatable {
    case environment(hasKeychainToken: Bool)
    case keychain
    case config
    case launchctl
    case shellProfile(String)
    case dotenv(String)
    case missing

    init(resolved: OuraResolvedToken?) {
        guard let resolved else {
            self = .missing
            return
        }

        switch resolved.source.kind {
        case .environment:
            self = .environment(hasKeychainToken: resolved.keychainTokenAvailable)
        case .keychain:
            self = .keychain
        case .configFile:
            self = .config
        case .launchctl:
            self = .launchctl
        case .shellProfile:
            self = .shellProfile(resolved.source.displayName)
        case .dotenv:
            self = .dotenv(resolved.source.displayName)
        }
    }

    var label: String {
        switch self {
        case .environment:
            return "OURA_TOKEN environment override"
        case .keychain:
            return "REM-Bar Keychain"
        case .config:
            return "~/.oura-mcp/config.json"
        case .launchctl:
            return "launchctl OURA_TOKEN"
        case let .shellProfile(path):
            return "Shell profile: \(path)"
        case let .dotenv(path):
            return "Dotenv file: \(path)"
        case .missing:
            return "No token configured"
        }
    }

    var statusTitle: String {
        switch self {
        case .environment:
            return "Using OURA_TOKEN from the process environment"
        case .keychain:
            return "Using the REM-Bar Keychain token"
        case .config:
            return "Using the oura-mcp config token"
        case .launchctl:
            return "Using OURA_TOKEN from launchctl"
        case let .shellProfile(path):
            return "Using OURA_TOKEN from \(path)"
        case let .dotenv(path):
            return "Using OURA_TOKEN from \(path)"
        case .missing:
            return "No Oura token configured"
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
        case .launchctl:
            return "The app found OURA_TOKEN through launchctl. Save it to Keychain if you want REM-Bar to own the token explicitly."
        case .shellProfile:
            return "The app found OURA_TOKEN in a shell startup file. Save it to Keychain if you want Finder-launched builds and MCP installs to be independent of shell config."
        case .dotenv:
            return "The app found OURA_TOKEN in a dotenv file. Save it to Keychain if you want REM-Bar to own the token explicitly."
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
        case .launchctl:
            return "macwindow"
        case .shellProfile:
            return "terminal"
        case .dotenv:
            return "doc.badge.gearshape"
        case .missing:
            return "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .environment, .config, .launchctl, .shellProfile, .dotenv:
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
        case .config, .launchctl, .shellProfile, .dotenv, .missing:
            return false
        }
    }
}
