import Foundation
import WidgetKit

/// Writes lightweight data into the shared App Group UserDefaults
/// so the FinTrackWidget can display it without accessing SwiftData directly.
final class WidgetDataService {
    static let shared = WidgetDataService()
    private init() {}

    private let suiteName = "group.com.fintrack.shared"

    func update(netWorth: Double, currency: String, recentTransactions: [WidgetTxSnapshot]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(netWorth, forKey: "widget_net_worth")
        defaults.set(currency, forKey: "widget_currency")
        if let data = try? JSONEncoder().encode(recentTransactions) {
            defaults.set(data, forKey: "widget_recent_transactions")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct WidgetTxSnapshot: Codable, Identifiable {
    var id: UUID
    var title: String
    var amount: Double
    var currency: String
    var type: String
    var date: Date
    var categoryIcon: String
}
