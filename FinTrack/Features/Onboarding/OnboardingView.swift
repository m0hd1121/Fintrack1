import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @State private var currentPage = 0
    @State private var selectedCurrency = "AED"
    @State private var userName = ""

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to FinTrack",
            subtitle: "Your complete personal finance companion — built for the UAE and beyond.",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            gradient: [FTColor.catBlue, FTColor.accentBright]
        ),
        OnboardingPage(
            title: "Track Everything",
            subtitle: "Income, expenses, loans, credit cards, investments, crypto — all in one place.",
            icon: "list.bullet.rectangle.portrait.fill",
            gradient: [FTColor.catPurple, FTColor.catBlue]
        ),
        OnboardingPage(
            title: "AI-Powered Insights",
            subtitle: "Smart categorization, receipt scanning, and personalized financial insights.",
            icon: "brain.head.profile",
            gradient: [FTColor.catCoral, FTColor.gold]
        ),
        OnboardingPage(
            title: "Bank-Level Security",
            subtitle: "Face ID, Touch ID, PIN protection, and end-to-end encryption keep your data safe.",
            icon: "lock.shield.fill",
            gradient: [FTColor.accent, FTColor.income]
        ),
    ]

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        PageView(page: pages[index])
                            .tag(index)
                    }

                    SetupPage(
                        userName: $userName,
                        selectedCurrency: $selectedCurrency
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                bottomControls
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: some View {
        let colors = currentPage < pages.count
            ? pages[currentPage].gradient
            : [FTColor.accentDeep, FTColor.catBlue]

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    private var bottomControls: some View {
        VStack(spacing: FTSpacing.xxl) {
            // Page indicator dots
            HStack(spacing: FTSpacing.sm) {
                ForEach(0...pages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? Color.white : FTColor.textMuted)
                        .frame(width: currentPage == index ? 22 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentPage)
                }
            }

            // Action button
            Button {
                if currentPage < pages.count {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { currentPage += 1 }
                } else {
                    if !userName.isEmpty, let profile = profiles.first {
                        profile.name = userName
                        try? context.save()
                    }
                    appState.completeOnboarding(currency: selectedCurrency)
                }
            } label: {
                Text(currentPage == pages.count ? "Get Started" : "Continue")
            }
            .buttonStyle(.ftPrimary)
            .padding(.horizontal, FTSpacing.xxl + FTSpacing.sm)

            if currentPage > 0 {
                Button("Skip Setup") {
                    if !userName.isEmpty, let profile = profiles.first {
                        profile.name = userName
                        try? context.save()
                    }
                    appState.completeOnboarding(currency: selectedCurrency)
                }
                .foregroundStyle(.white.opacity(0.65))
                .font(.ftBody)
            }

            Spacer().frame(height: FTSpacing.lg)
        }
        .padding(.bottom, FTSpacing.xl)
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
}

struct PageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            // Icon with glow
            ZStack {
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 110, height: 110)
                Image(systemName: page.icon)
                    .font(.ftDisplay)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }

            VStack(spacing: FTSpacing.lg) {
                Text(page.title)
                    .font(.ftAmount)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.ftBody)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FTSpacing.xxl + FTSpacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
            Spacer()
        }
    }
}

struct SetupPage: View {
    @Binding var userName: String
    @Binding var selectedCurrency: String
    @Environment(CurrencyService.self) private var currencyService

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 80)

                VStack(spacing: FTSpacing.sm) {
                    Text("Let's Set Up")
                        .font(.ftDisplay)
                        .foregroundColor(.white)
                    Text("Personalize FinTrack for you")
                        .font(.ftBody)
                        .foregroundColor(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Your Name (Optional)")
                        .font(.ftCallout)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, FTSpacing.xxl + FTSpacing.sm)

                    TextField("Enter your name", text: $userName)
                        .textFieldStyle(.plain)
                        .font(.ftBody)
                        .padding()
                        .ftGlass(FTRadius.md)
                        .foregroundColor(.white)
                        .padding(.horizontal, FTSpacing.xxl + FTSpacing.sm)
                }

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Base Currency")
                        .font(.ftCallout)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, FTSpacing.xxl + FTSpacing.sm)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FTSpacing.md) {
                            ForEach(["AED", "USD", "EUR", "GBP", "SAR", "QAR", "KWD", "INR"], id: \.self) { code in
                                let info = currencyService.info(for: code)
                                Button {
                                    selectedCurrency = code
                                } label: {
                                    VStack(spacing: FTSpacing.xs) {
                                        Text(info?.flag ?? "")
                                            .font(.ftTitle)
                                        Text(code)
                                            .font(.ftCaption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, FTSpacing.lg)
                                    .padding(.vertical, FTSpacing.md)
                                    .ftGlassInteractive(FTRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: FTRadius.sm)
                                            .stroke(selectedCurrency == code ? Color.white : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, FTSpacing.xxl + FTSpacing.sm)
                    }
                }

                Spacer(minLength: 120)
            }
        }
    }
}
