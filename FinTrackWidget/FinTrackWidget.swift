// FinTrackWidget.swift
// #15 – Large widget: left = net worth, right = last 6 transactions
//
// To activate: In Xcode, add a new Widget Extension target named "FinTrackWidget",
// replace its generated file with this one, and add the App Group entitlement
// "group.com.fintrack.shared" to both the app and the widget targets so they
// can share a SwiftData / UserDefaults store.

import WidgetKit
import SwiftUI
import SwiftData

// MARK: – Shared data model (lightweight, widget-side only)
struct WidgetTransaction: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String   // "income" | "expense" | "transfer"
    var date: Date
    var categoryIcon: String
}

struct FinTrackWidgetEntry: TimelineEntry {
    var date: Date
    var netWorth: Double
    var currency: String
    var recentTransactions: [WidgetTransaction]
}

// MARK: – Provider
struct FinTrackWidgetProvider: TimelineProvider {
    private let appGroupID = "group.com.fintrack.shared"

    func placeholder(in context: Context) -> FinTrackWidgetEntry {
        sampleEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (FinTrackWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinTrackWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 5 minutes
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> FinTrackWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        let netWorth = defaults?.double(forKey: "widget_net_worth") ?? 0
        let currency = defaults?.string(forKey: "widget_currency") ?? "AED"
        var transactions: [WidgetTransaction] = []

        if let data = defaults?.data(forKey: "widget_recent_transactions"),
           let decoded = try? JSONDecoder().decode([WidgetTransaction].self, from: data) {
            transactions = decoded
        }

        return FinTrackWidgetEntry(
            date: Date(),
            netWorth: netWorth,
            currency: currency,
            recentTransactions: transactions
        )
    }

    private func sampleEntry() -> FinTrackWidgetEntry {
        let sample = [
            WidgetTransaction(id: UUID(), title: "Salary", amount: 15000, currency: "AED", type: "income", date: Date(), categoryIcon: "briefcase"),
            WidgetTransaction(id: UUID(), title: "Groceries", amount: 250, currency: "AED", type: "expense", date: Date().addingTimeInterval(-3600), categoryIcon: "cart"),
            WidgetTransaction(id: UUID(), title: "Netflix", amount: 45, currency: "AED", type: "expense", date: Date().addingTimeInterval(-7200), categoryIcon: "play.tv"),
        ]
        return FinTrackWidgetEntry(date: Date(), netWorth: 85_000, currency: "AED", recentTransactions: sample)
    }
}

// MARK: – Large widget view
struct FinTrackLargeWidgetView: View {
    var entry: FinTrackWidgetEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left – Net Worth
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.accentColor)
                    Text("Net Worth").font(.caption).foregroundColor(.secondary)
                }

                Text(entry.netWorth.asCompact(currency: entry.currency))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer()

                Text("Updated").font(.caption2).foregroundColor(.secondary)
                Text(entry.date, style: .time).font(.caption2).foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.systemBackground).opacity(0.05))

            Divider()

            // Right – last 6 transactions
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                    .padding(.top, 12).padding(.horizontal, 12)

                ForEach(entry.recentTransactions.prefix(6)) { tx in
                    HStack(spacing: 8) {
                        Image(systemName: tx.categoryIcon)
                            .font(.system(size: 11))
                            .foregroundColor(tx.type == "income" ? .green : .red)
                            .frame(width: 18)

                        Text(tx.title)
                            .font(.system(size: 11))
                            .lineLimit(1)

                        Spacer()

                        Text((tx.type == "expense" ? "-" : "+") + tx.amount.asCompact(currency: tx.currency))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(tx.type == "income" ? .green : .red)
                    }
                    .padding(.horizontal, 12)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: – Widget declaration
struct FinTrackWidget: Widget {
    let kind = "FinTrackLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinTrackWidgetProvider()) { entry in
            FinTrackLargeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "#1a1a2e"), Color(hex: "#16213e")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("FinTrack Overview")
        .description("Net worth and recent transactions at a glance.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: – Helpers (duplicated so widget compiles standalone)
private extension Double {
    func asCompact(currency: String) -> String {
        let abs = Swift.abs(self)
        let prefix = self < 0 ? "-" : ""
        if abs >= 1_000_000 { return "\(prefix)\(currency) \(String(format: "%.1fM", abs / 1_000_000))" }
        if abs >= 1_000 { return "\(prefix)\(currency) \(String(format: "%.1fK", abs / 1_000))" }
        return "\(currency) \(String(format: "%.2f", self))"
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}
