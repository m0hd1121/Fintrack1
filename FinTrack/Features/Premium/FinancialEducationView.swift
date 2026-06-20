import SwiftUI
import SwiftData

struct FinancialEducationView: View {
    @Environment(AppState.self) private var appState
    @Query private var transactions: [Transaction]
    @Query private var loans: [Loan]
    @Query private var investments: [Investment]
    @Query private var goals: [SavingsGoal]

    @State private var selectedCategory: LessonCategory? = nil
    @State private var selectedLesson: FinancialLesson? = nil

    private var contextualLessons: [FinancialLesson] { generateContextualLessons() }

    private var allLessons: [FinancialLesson] {
        if let cat = selectedCategory {
            return FinancialLesson.allLessons.filter { $0.category == cat }
        }
        return FinancialLesson.allLessons
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xl) {
                if !contextualLessons.isEmpty {
                    contextualSection
                }
                categoryFilter
                lessonsGrid
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.vertical, FTSpacing.lg)
        }
        .scrollContentBackground(.hidden)
        .background { FTBackdrop() }
        .navigationTitle("Financial Education")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedLesson) { LessonDetailView(lesson: $0) }
    }

    // MARK: – Sections

    private var contextualSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Image(systemName: "brain.head.profile").foregroundStyle(FTColor.accent)
                Text("Recommended For You").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.md) {
                    ForEach(contextualLessons.prefix(3)) { lesson in
                        ContextualLessonCard(lesson: lesson)
                            .onTapGesture { selectedLesson = lesson }
                    }
                }
                .padding(.horizontal, FTSpacing.xs)
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FTSpacing.sm) {
                FTChip(symbol: "square.grid.2x2", title: "All", selected: selectedCategory == nil)
                    .onTapGesture { selectedCategory = nil }
                ForEach(LessonCategory.allCases, id: \.self) { cat in
                    FTChip(symbol: cat.icon, title: cat.rawValue, selected: selectedCategory == cat)
                        .onTapGesture { selectedCategory = selectedCategory == cat ? nil : cat }
                }
            }
            .padding(.horizontal, FTSpacing.xs)
        }
    }

    private var lessonsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
            ForEach(allLessons) { lesson in
                LessonCard(lesson: lesson)
                    .onTapGesture { selectedLesson = lesson }
            }
        }
    }

    private func generateContextualLessons() -> [FinancialLesson] {
        var lessons: [FinancialLesson] = []
        if loans.contains(where: { $0.interestRate > 5 }) {
            lessons.append(FinancialLesson.allLessons.first { $0.id == "debt-avalanche" } ?? FinancialLesson.allLessons[0])
        }
        if investments.isEmpty {
            lessons.append(FinancialLesson.allLessons.first { $0.id == "index-funds" } ?? FinancialLesson.allLessons[1])
        }
        if goals.isEmpty {
            lessons.append(FinancialLesson.allLessons.first { $0.id == "goal-setting" } ?? FinancialLesson.allLessons[2])
        }
        return lessons
    }
}

// MARK: – Models

enum LessonCategory: String, CaseIterable {
    case basics     = "Basics"
    case budgeting  = "Budgeting"
    case debt       = "Debt"
    case investing  = "Investing"
    case uae        = "UAE Finance"
    case tax        = "Tax & Zakat"

    var icon: String {
        switch self {
        case .basics:    return "book.fill"
        case .budgeting: return "chart.pie.fill"
        case .debt:      return "banknote.fill"
        case .investing: return "chart.line.uptrend.xyaxis"
        case .uae:       return "flag.fill"
        case .tax:       return "doc.text.fill"
        }
    }
    var color: Color {
        switch self {
        case .basics:    return FTColor.accent
        case .budgeting: return FTColor.catTeal
        case .debt:      return FTColor.expense
        case .investing: return FTColor.income
        case .uae:       return FTColor.gold
        case .tax:       return FTColor.catPurple
        }
    }
}

struct FinancialLesson: Identifiable {
    let id: String
    let category: LessonCategory
    let title: String
    let summary: String
    let content: String
    let readMinutes: Int
    let keyTakeaways: [String]

    static let allLessons: [FinancialLesson] = [
        FinancialLesson(id: "emergency-fund", category: .basics, title: "Emergency Fund", summary: "Why 6 months of expenses is your first goal",
            content: "An emergency fund is a safety net of 3–6 months of living expenses kept in a liquid, accessible account...",
            readMinutes: 3, keyTakeaways: ["Keep 3–6 months of expenses", "Use a high-yield savings account", "Don't invest your emergency fund", "Replenish after using it"]),
        FinancialLesson(id: "goal-setting", category: .basics, title: "SMART Financial Goals", summary: "Set goals that actually work",
            content: "SMART goals are Specific, Measurable, Achievable, Relevant, and Time-bound. When applied to finances...",
            readMinutes: 4, keyTakeaways: ["Be specific about amounts and dates", "Break large goals into milestones", "Track progress monthly", "Celebrate small wins"]),
        FinancialLesson(id: "50-30-20", category: .budgeting, title: "The 50/30/20 Rule", summary: "A simple framework for any income",
            content: "Allocate 50% of take-home pay to needs, 30% to wants, and 20% to savings and debt repayment...",
            readMinutes: 3, keyTakeaways: ["50% needs: rent, groceries, utilities", "30% wants: dining, entertainment", "20% savings and debt", "Adjust ratios for your situation"]),
        FinancialLesson(id: "zero-based", category: .budgeting, title: "Zero-Based Budgeting", summary: "Give every dirham a job",
            content: "In zero-based budgeting, income minus expenses equals zero — every dirham is allocated to a category...",
            readMinutes: 4, keyTakeaways: ["Total income minus expenses = 0", "Allocate remaining to savings", "Review and adjust monthly", "Use categories for all spending"]),
        FinancialLesson(id: "debt-avalanche", category: .debt, title: "Debt Avalanche Method", summary: "Mathematically optimal debt payoff",
            content: "List all debts by interest rate (highest first). Pay minimums on all, then put extra toward the highest rate...",
            readMinutes: 4, keyTakeaways: ["Pay highest interest rate first", "Save the most in total interest", "List all debts with rates", "Redirect freed payments to next debt"]),
        FinancialLesson(id: "debt-snowball", category: .debt, title: "Debt Snowball Method", summary: "The psychology of quick wins",
            content: "Pay off the smallest debt first for quick wins, then roll that payment to the next smallest...",
            readMinutes: 3, keyTakeaways: ["Pay smallest balance first", "Builds momentum and motivation", "Costs more in total interest", "Great for those needing psychological wins"]),
        FinancialLesson(id: "index-funds", category: .investing, title: "Index Fund Investing", summary: "The simplest path to wealth",
            content: "Index funds track a market index (like S&P 500) providing instant diversification at low cost...",
            readMinutes: 5, keyTakeaways: ["Low fees beat active management long-term", "Instant diversification", "Stay invested through volatility", "Dollar-cost average consistently"]),
        FinancialLesson(id: "compound-interest", category: .investing, title: "Compound Interest", summary: "The 8th wonder of the world",
            content: "Compound interest earns interest on interest. AED 10,000 at 7% for 30 years = AED 76,000...",
            readMinutes: 3, keyTakeaways: ["Start investing early", "Reinvest all dividends", "Don't withdraw invested money", "Time in market beats timing the market"]),
        FinancialLesson(id: "uae-eosg", category: .uae, title: "UAE End of Service Gratuity", summary: "Know your entitlements",
            content: "UAE law mandates EOSG for employees with 1+ year service. Formula: 21 days per year for first 5 years, 30 days after...",
            readMinutes: 4, keyTakeaways: ["21 days salary per year (first 5 yrs)", "30 days per year (after 5 yrs)", "Capped at 2 years total salary", "Calculate on basic salary only"]),
        FinancialLesson(id: "uae-remittance", category: .uae, title: "Smart Money Transfers", summary: "Save on sending money home",
            content: "Compare exchange rates and fees across services. Even a 0.5% better rate saves hundreds on large transfers...",
            readMinutes: 3, keyTakeaways: ["Compare Wise vs exchange houses", "Avoid airport/hotel exchanges", "Use the mid-market rate as benchmark", "Large transfers: negotiate rates"]),
        FinancialLesson(id: "zakat-basics", category: .tax, title: "Zakat Calculation", summary: "UAE Islamic wealth obligation",
            content: "Zakat is 2.5% of zakatable wealth (cash, gold, investments) held above nisab for one lunar year...",
            readMinutes: 4, keyTakeaways: ["2.5% of zakatable wealth", "Must exceed nisab (≈ AED 7,200)", "Held for one full lunar year", "Real estate and business assets have different rules"]),
        FinancialLesson(id: "uae-vat", category: .tax, title: "UAE VAT Basics", summary: "5% VAT — what's exempt",
            content: "UAE introduced 5% VAT in 2018. Basic food items, healthcare, and education are exempt. Register if revenue >AED 375k...",
            readMinutes: 3, keyTakeaways: ["5% VAT on most goods/services", "Basic food, health, education exempt", "Register if revenue >AED 375k", "Keep receipts for business VAT recovery"]),
    ]
}

// MARK: – Cards & Detail

struct LessonCard: View {
    let lesson: FinancialLesson

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Image(systemName: lesson.category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(lesson.category.color)
                Spacer()
                Text("\(lesson.readMinutes) min")
                    .font(.system(size: 9))
                    .foregroundStyle(FTColor.textMuted)
            }
            Text(lesson.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            Text(lesson.summary).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineLimit(2)
        }
        .padding(FTSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}

struct ContextualLessonCard: View {
    let lesson: FinancialLesson

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            BadgeView(text: "Recommended", color: FTColor.accent)
            Text(lesson.title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
            Text(lesson.summary).font(.ftCaption).foregroundStyle(FTColor.textSecondary).lineLimit(2)
            HStack {
                Image(systemName: lesson.category.icon).foregroundStyle(lesson.category.color).font(.caption)
                Text(lesson.category.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                Spacer()
                Text("\(lesson.readMinutes) min").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding(FTSpacing.md)
        .frame(width: 200, alignment: .leading)
        .ftGlass(FTRadius.md)
    }
}

struct LessonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let lesson: FinancialLesson

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FTSpacing.xl) {
                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        HStack {
                            BadgeView(text: lesson.category.rawValue, color: lesson.category.color)
                            Spacer()
                            Text("\(lesson.readMinutes) min read")
                                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        Text(lesson.title).font(.ftTitle).foregroundStyle(FTColor.textPrimary)
                        Text(lesson.summary).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.lg)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("Overview").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text(lesson.content).font(.ftBody).foregroundStyle(FTColor.textSecondary).lineSpacing(5)
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("Key Takeaways").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        ForEach(lesson.keyTakeaways, id: \.self) { point in
                            HStack(alignment: .top, spacing: FTSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(FTColor.income).font(.caption).padding(.top, 2)
                                Text(point).font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            }
                        }
                    }
                    .padding(FTSpacing.lg)
                    .ftGlass(FTRadius.md)
                }
                .padding(.horizontal, FTSpacing.screen)
                .padding(.vertical, FTSpacing.lg)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(FTColor.accent)
                }
            }
        }
    }
}
