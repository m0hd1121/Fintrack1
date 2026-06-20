import Foundation

// MARK: - Category Learning Service
// Remembers merchant→category corrections the user makes, so the AI prediction
// improves over time without any server round-trips.

@Observable
final class CategoryLearningService {
    static let shared = CategoryLearningService()

    private(set) var merchantHistory: [String: String] = [:]  // merchant key → category rawValue
    private let storageKey = "ft_merchant_category_history_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            merchantHistory = decoded
        }
    }

    // Call this whenever the user saves a transaction and the category is set.
    func recordCorrection(merchant: String, category: TransactionCategory) {
        let key = normalizedKey(merchant)
        guard !key.isEmpty else { return }
        merchantHistory[key] = category.rawValue
        persist()
    }

    // Returns the learned category for a merchant, or nil if unknown.
    func learnedCategory(for merchant: String) -> TransactionCategory? {
        let key = normalizedKey(merchant)
        guard !key.isEmpty, let raw = merchantHistory[key] else { return nil }
        return TransactionCategory(rawValue: raw)
    }

    // Forget a specific merchant entry (e.g. if user wants to reset).
    func forget(merchant: String) {
        merchantHistory.removeValue(forKey: normalizedKey(merchant))
        persist()
    }

    // Clear all learned history.
    func clearAll() {
        merchantHistory = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: Private

    private func normalizedKey(_ merchant: String) -> String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(merchantHistory) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
