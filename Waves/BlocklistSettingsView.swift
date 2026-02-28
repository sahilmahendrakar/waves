#if os(macOS)
import SwiftUI

struct BlocklistSettingsView: View {
    @ObservedObject var focusGuard: FocusGuard
    @Environment(\.dismiss) private var dismiss

    @State private var newApp = ""
    @State private var newDomain = ""

    private var itemLabel: String {
        focusGuard.mode == .blocklist ? "Blocked" : "Allowed"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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
        .frame(minWidth: 400, minHeight: 480)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Guard")
                    .font(.headline)
                Text("Manage which apps & websites break your focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
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
                TextField("App name…", text: $newApp)
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
                TextField("Domain (e.g. reddit.com)…", text: $newDomain)
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

        // Strip leading www. for consistency
        if domain.hasPrefix("www.") {
            domain = String(domain.dropFirst(4))
        }
        // Strip trailing slash
        if domain.hasSuffix("/") {
            domain = String(domain.dropLast())
        }

        guard !domain.isEmpty, !focusGuard.blockedDomains.contains(domain) else { return }
        focusGuard.blockedDomains.append(domain)
        newDomain = ""
    }
}
#endif
