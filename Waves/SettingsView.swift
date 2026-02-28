import SwiftUI

struct SettingsView: View {
    @Binding var apiKey: String
    #if os(macOS)
    @ObservedObject var focusGuard: FocusGuard
    #endif
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            #if os(macOS)
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }
                FocusGuardSettingsTab(focusGuard: focusGuard)
                    .tabItem { Label("Focus Guard", systemImage: "eye.slash") }
            }
            #else
            generalTab
            #endif
        }
        .frame(minWidth: 440, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.headline)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline.bold())
                    SecureField("Gemini API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Enter your Gemini API key to connect to Lyria RealTime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Focus Guard Tab (macOS)

#if os(macOS)
private struct FocusGuardSettingsTab: View {
    @ObservedObject var focusGuard: FocusGuard

    @State private var newApp = ""
    @State private var newDomain = ""

    private var itemLabel: String {
        focusGuard.mode == .blocklist ? "Blocked" : "Allowed"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                modePicker
                appsSection
                Divider()
                domainsSection
                resetButton
            }
            .padding(20)
        }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode")
                .font(.subheadline.bold())
            Picker("Mode", selection: $focusGuard.mode) {
                ForEach(FocusGuardMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(modeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var modeDescription: String {
        switch focusGuard.mode {
        case .blocklist:
            "Music stops if you use any listed app or visit any listed website for more than 10 seconds."
        case .allowlist:
            "Music stops if you use any app or website NOT on this list for more than 10 seconds."
        }
    }

    // MARK: - Apps section

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(itemLabel) Apps")
                .font(.subheadline.bold())

            ForEach(focusGuard.blockedApps, id: \.self) { app in
                HStack {
                    Text(app)
                        .font(.body)
                    Spacer()
                    Button {
                        focusGuard.blockedApps.removeAll { $0 == app }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField("App name\u{2026}", text: $newApp)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addApp() }
                Button("Add") { addApp() }
                    .disabled(newApp.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Domains section

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(itemLabel) Websites")
                .font(.subheadline.bold())

            ForEach(focusGuard.blockedDomains, id: \.self) { domain in
                HStack {
                    Text(domain)
                        .font(.body)
                    Spacer()
                    Button {
                        focusGuard.blockedDomains.removeAll { $0 == domain }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField("Domain (e.g. reddit.com)\u{2026}", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addDomain() }
                Button("Add") { addDomain() }
                    .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button("Reset to Defaults") {
            focusGuard.resetToDefaults()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func addApp() {
        let name = newApp.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !focusGuard.blockedApps.contains(name) else { return }
        focusGuard.blockedApps.append(name)
        newApp = ""
    }

    private func addDomain() {
        var domain = newDomain
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")

        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        if domain.hasSuffix("/") {
            domain = String(domain.dropLast())
        }

        guard !domain.isEmpty, !focusGuard.blockedDomains.contains(domain) else { return }
        focusGuard.blockedDomains.append(domain)
        newDomain = ""
    }
}
#endif
