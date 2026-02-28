import SwiftUI

struct SettingsView: View {
    @Binding var apiKey: String
    @EnvironmentObject var appState: AppState
    #if os(macOS)
    @ObservedObject var focusGuard: FocusGuard
    #endif
    @AppStorage("appMode") private var mode: AppMode = .wave
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingMusicPreferences = false
    @State private var showingResetOnboardingConfirmation = false
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
                    Text("Mode")
                        .font(.subheadline.bold())
                    Picker("Mode", selection: $mode) {
                        ForEach(AppMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Wave adapts music intensity over time. Free Play gives you manual control.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline.bold())
                    SecureField("Gemini API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Enter your Gemini API key to connect to Lyria RealTime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Music Preferences")
                        .font(.subheadline.bold())

                    if let prefs = MusicPreferences.load() {
                        HStack(spacing: 6) {
                            ForEach(prefs.selectedGenres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(prefs.selectedMood)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingMusicPreferences = true
                    } label: {
                        Label("Edit Preferences", systemImage: "music.note.list")
                    }
                    .controlSize(.small)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Advanced")
                        .font(.subheadline.bold())

                    Button(role: .destructive) {
                        showingResetOnboardingConfirmation = true
                    } label: {
                        Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
                    }
                    .controlSize(.small)
                    .alert("Reset Onboarding?", isPresented: $showingResetOnboardingConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Reset", role: .destructive) {
                            resetOnboarding()
                        }
                    } message: {
                        Text("This will clear your music preferences and show the onboarding flow on the next app launch.")
                    }

                    Text("Clears preferences and restarts onboarding on next launch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingMusicPreferences) {
            MusicPreferencesEditor(appState: appState)
        }
    }

    private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "musicPreferences")
        hasCompletedOnboarding = false
        dismiss()
    }
}

struct MusicPreferencesEditor: View {
    let appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGenres: Set<String>
    @State private var selectedMood: String

    init(appState: AppState) {
        self.appState = appState
        let prefs = MusicPreferences.load() ?? .default
        self._selectedGenres = State(initialValue: Set(prefs.selectedGenres))
        self._selectedMood = State(initialValue: prefs.selectedMood)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Music Preferences")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(selectedGenres.isEmpty || selectedMood.isEmpty)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Genres")
                            .font(.subheadline.bold())

                        FlowLayout(spacing: 10) {
                            ForEach(MusicPreferences.availableGenres, id: \.self) { genre in
                                Button {
                                    toggleGenre(genre)
                                } label: {
                                    Text(genre)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedGenres.contains(genre) ? Color.accentColor : Color.secondary.opacity(0.12))
                                        .foregroundStyle(selectedGenres.contains(genre) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mood")
                            .font(.subheadline.bold())

                        ForEach(MusicPreferences.availableMoods, id: \.self) { mood in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMood = mood
                                }
                            } label: {
                                HStack {
                                    Text(mood)
                                        .font(.body)
                                    Spacer()
                                    if selectedMood == mood {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedMood == mood ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }

    private func toggleGenre(_ genre: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedGenres.contains(genre) {
                selectedGenres.remove(genre)
            } else {
                selectedGenres.insert(genre)
            }
        }
    }

    private func save() {
        let prefs = MusicPreferences(
            selectedGenres: Array(selectedGenres),
            selectedMood: selectedMood
        )
        prefs.save()
        appState.applyPreferences(prefs)
        dismiss()
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

    private var currentApps: [String] {
        focusGuard.mode == .blocklist ? focusGuard.blockedApps : focusGuard.allowedApps
    }

    private var currentDomains: [String] {
        focusGuard.mode == .blocklist ? focusGuard.blockedDomains : focusGuard.allowedDomains
    }

    private var appsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(itemLabel) Apps")
                .font(.subheadline.bold())

            ForEach(currentApps, id: \.self) { app in
                HStack {
                    Text(app)
                        .font(.body)
                    Spacer()
                    Button {
                        removeApp(app)
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

            ForEach(currentDomains, id: \.self) { domain in
                HStack {
                    Text(domain)
                        .font(.body)
                    Spacer()
                    Button {
                        removeDomain(domain)
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

    private func removeApp(_ app: String) {
        switch focusGuard.mode {
        case .blocklist:
            focusGuard.blockedApps.removeAll { $0 == app }
        case .allowlist:
            focusGuard.allowedApps.removeAll { $0 == app }
        }
    }

    private func removeDomain(_ domain: String) {
        switch focusGuard.mode {
        case .blocklist:
            focusGuard.blockedDomains.removeAll { $0 == domain }
        case .allowlist:
            focusGuard.allowedDomains.removeAll { $0 == domain }
        }
    }

    private func addApp() {
        let name = newApp.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !currentApps.contains(name) else { return }
        switch focusGuard.mode {
        case .blocklist:
            focusGuard.blockedApps.append(name)
        case .allowlist:
            focusGuard.allowedApps.append(name)
        }
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

        guard !domain.isEmpty, !currentDomains.contains(domain) else { return }
        switch focusGuard.mode {
        case .blocklist:
            focusGuard.blockedDomains.append(domain)
        case .allowlist:
            focusGuard.allowedDomains.append(domain)
        }
        newDomain = ""
    }
}
#endif
