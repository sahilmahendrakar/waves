import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var selectedGenres: Set<String> = []
    @State private var selectedMood = ""

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 32)

            Spacer()

            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: genreStep
                case 2: moodStep
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer()

            navigationButtons
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 32)
        .frame(minWidth: 480, minHeight: 540)
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            Text("Welcome to Waves")
                .font(.largeTitle.weight(.bold))

            Text("Adaptive music that responds to your focus.\nTell us what you like and we'll craft the\nperfect soundscape to keep you in the zone.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var genreStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("What genres do you enjoy?")
                    .font(.title2.weight(.semibold))

                Text("Pick 2\u{2013}4 that resonate with you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            FlowLayout(spacing: 10) {
                ForEach(MusicPreferences.availableGenres, id: \.self) { genre in
                    GenreChip(
                        title: genre,
                        isSelected: selectedGenres.contains(genre)
                    ) {
                        toggleGenre(genre)
                    }
                }
            }
            .frame(maxWidth: 380)
        }
    }

    private var moodStep: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("What\u{2019}s your vibe?")
                    .font(.title2.weight(.semibold))

                Text("This shapes the feel of your waves")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(MusicPreferences.availableMoods, id: \.self) { mood in
                    MoodRow(
                        title: mood,
                        icon: iconForMood(mood),
                        isSelected: selectedMood == mood
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedMood = mood
                        }
                    }
                }
            }
            .frame(maxWidth: 340)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    completeOnboarding()
                }
            } label: {
                Text(currentStep < totalSteps - 1 ? "Continue" : "Get Started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
        }
        .frame(maxWidth: 340)
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0: true
        case 1: !selectedGenres.isEmpty
        case 2: !selectedMood.isEmpty
        default: true
        }
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

    private func completeOnboarding() {
        let prefs = MusicPreferences(
            selectedGenres: Array(selectedGenres),
            selectedMood: selectedMood
        )
        prefs.save()
        appState.applyPreferences(prefs)
        hasCompletedOnboarding = true
    }

    private func iconForMood(_ mood: String) -> String {
        switch mood {
        case "Chill & Spacey": "cloud.moon"
        case "Warm & Melodic": "sun.haze"
        case "Dark & Driving": "bolt.fill"
        case "Bright & Uplifting": "sparkles"
        default: "music.note"
        }
    }
}

private struct GenreChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MoodRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 28)

                Text(title)
                    .font(.body.weight(.medium))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
