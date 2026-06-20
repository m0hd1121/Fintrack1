import Foundation

// MARK: - Tag Suggestion Service
// Suggests relevant tags based on merchant history, amount, and seasonal context.

@Observable
final class TagSuggestionService {
    static let shared = TagSuggestionService()

    // merchant key → (tag → usage count)
    private var merchantTags: [String: [String: Int]] = [:]
    private let storageKey = "ft_merchant_tag_history_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [String: Int]].self, from: data) {
            merchantTags = decoded
        }
    }

    // Returns up to 5 suggested tags, excluding any already-added ones.
    func suggestTags(for merchant: String, amount: Double, existing: [String]) -> [String] {
        var scores: [String: Int] = [:]

        // From merchant history (weighted 2x)
        let key = normalizedKey(merchant)
        if !key.isEmpty, let tagCounts = merchantTags[key] {
            for (tag, count) in tagCounts {
                scores[tag, default: 0] += count * 2
            }
        }

        // Seasonal/contextual hints
        for tag in seasonalTags() { scores[tag, default: 0] += 1 }

        // Amount-based context
        if amount >= 500  { scores["large-purchase", default: 0] += 1 }
        if amount >= 2000 { scores["major-expense",  default: 0] += 1 }

        return scores
            .filter { !existing.contains($0.key) }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    // Call when the user adds a tag to a transaction with a known merchant.
    func recordTagUsed(_ tag: String, for merchant: String) {
        let key = normalizedKey(merchant)
        guard !key.isEmpty, !tag.isEmpty else { return }
        merchantTags[key, default: [:]][tag, default: 0] += 1
        persist()
    }

    // Clear all learned tag history.
    func clearAll() {
        merchantTags = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: Private

    private func normalizedKey(_ merchant: String) -> String {
        merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func seasonalTags() -> [String] {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 11, 12: return ["holiday", "gift", "festive"]
        case 1:      return ["new-year"]
        case 3, 4:   return ["ramadan", "eid"]
        case 6, 7:   return ["summer", "vacation"]
        default:     return []
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(merchantTags) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
