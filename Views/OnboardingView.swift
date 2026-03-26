import SwiftUI

// MARK: - Data Model

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let feetImageName: String?
    let gradientColors: [Color]
    let gradientStops: [Gradient.Stop]?
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        title: "Rock",
        description: "This guy doesn't move, he presses you into the ground. His motto: \"Why maneuver when you can crush?\"",
        imageName: "rock",
        feetImageName: "rock_feet",
        gradientColors: [],
        gradientStops: [
            .init(color: Color(red: 0.91, green: 0.65, blue: 0.91), location: 0),
            .init(color: Color(red: 0.50, green: 0.74, blue: 0.92), location: 0.47),
            .init(color: Color(red: 0.07, green: 0.37, blue: 0.22), location: 1.0)
        ]
    ),
    OnboardingPage(
        title: "Paper",
        description: "Looks soft, but wraps you up before you know it. Smooth operator with an iron grip disguised as a gentle touch.",
        imageName: "paper",
        feetImageName: nil,
        gradientColors: [],
        gradientStops: [
            .init(color: Color(red: 0.85, green: 0.92, blue: 1.0), location: 0),
            .init(color: Color(red: 0.55, green: 0.75, blue: 0.95), location: 0.47),
            .init(color: Color(red: 0.15, green: 0.25, blue: 0.55), location: 1.0)
        ]
    ),
    OnboardingPage(
        title: "Scissors",
        description: "Fast, sharp, and always ready to cut through the nonsense. Two blades, one mission — snip and win!",
        imageName: "scissors",
        feetImageName: nil,
        gradientColors: [],
        gradientStops: [
            .init(color: Color(red: 1.0, green: 0.92, blue: 0.70), location: 0),
            .init(color: Color(red: 0.95, green: 0.72, blue: 0.40), location: 0.47),
            .init(color: Color(red: 0.60, green: 0.20, blue: 0.15), location: 1.0)
        ]
    )
]

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let totalPages: Int
    let currentPage: Int
    /// 0...1 fill progress for the current page's bar
    let currentPageProgress: CGFloat

    var body: some View {
        HStack(spacing: 19) {
            ForEach(0..<totalPages, id: \.self) { index in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 5)

                    // Fill
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white)
                            .frame(width: fillWidth(for: index, totalWidth: geo.size.width), height: 5)
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func fillWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentPage {
            return totalWidth          // completed pages → full
        } else if index == currentPage {
            return totalWidth * currentPageProgress  // animating page
        } else {
            return 0                   // upcoming pages → empty
        }
    }
}

// MARK: - Single Page

struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool
    let isLastPage: Bool
    let onNext: () -> Void

    @State private var imageAppeared = false
    @State private var descriptionAppeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Character image
                characterImage(in: geo)
                    .offset(x: imageAppeared ? 0 : geo.size.width * 0.6)
                    .opacity(imageAppeared ? 1 : 0)

                // Description + button at bottom
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(page.title)
                            .font(.system(size: 47, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(page.description)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .lineSpacing(3)
                    }

                    Button(action: onNext) {
                        Text(isLastPage ? "Get started" : "Next")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 30)
                .offset(y: descriptionAppeared
                         ? geo.size.height * 0.72
                         : geo.size.height * 1.1)
                .opacity(descriptionAppeared ? 1 : 0)
            }
        }
        .onChange(of: isActive) { active in
            if active { animateIn() } else { resetAnimations() }
        }
        .onAppear {
            if isActive { animateIn() }
        }
    }

    @ViewBuilder
    private func characterImage(in geo: GeometryProxy) -> some View {
        if page.feetImageName != nil {
            // Rock: two-layer image composition
            ZStack {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * 0.95)
                    .offset(x: 10)

                if let feet = page.feetImageName {
                    Image(feet)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                        .offset(y: geo.size.width * 0.65)
                }
            }
            .offset(y: geo.size.height * 0.12)
        } else {
            // Paper / Scissors: single emoji fallback (until real images are added)
            Text(page.imageName == "paper" ? "✋" : "✌️")
                .font(.system(size: 260))
                .offset(y: geo.size.height * 0.15)
        }
    }

    private func animateIn() {
        imageAppeared = false
        descriptionAppeared = false

        withAnimation(.easeOut(duration: 0.7)) {
            imageAppeared = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.45)) {
            descriptionAppeared = true
        }
    }

    private func resetAnimations() {
        imageAppeared = false
        descriptionAppeared = false
    }
}

// MARK: - Onboarding Container

struct OnboardingView: View {
    var onComplete: () -> Void = {}
    @State private var currentPage = 0
    @State private var barProgress: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    private let pages = onboardingPages

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress bar
                    OnboardingProgressBar(
                        totalPages: pages.count,
                        currentPage: currentPage,
                        currentPageProgress: barProgress
                    )
                    .padding(.top, 8)

                    // Page content
                    ZStack {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            OnboardingPageView(
                                page: page,
                                isActive: index == currentPage,
                                isLastPage: index == pages.count - 1,
                                onNext: advancePage
                            )
                            .offset(x: CGFloat(index - currentPage) * geo.size.width + dragOffset)
                        }
                    }
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if value.translation.width < -threshold && currentPage < pages.count - 1 {
                            currentPage += 1
                        } else if value.translation.width > threshold && currentPage > 0 {
                            currentPage -= 1
                        }
                        dragOffset = 0
                    }
                    animateBarToFull()
                }
        )
        .onAppear {
            animateBarToFull()
        }
    }

    private var backgroundGradient: some View {
        let stops = pages[currentPage].gradientStops ?? []
        return LinearGradient(
            stops: stops,
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    private func advancePage() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.35)) {
                currentPage += 1
            }
            animateBarToFull()
        } else {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
            onComplete()
        }
    }

    private func animateBarToFull() {
        barProgress = 0
        withAnimation(.easeInOut(duration: 0.8).delay(0.1)) {
            barProgress = 1
        }
    }
}
