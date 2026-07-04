import Foundation

// MARK: - DuplicateVerdict

struct DuplicateVerdict {
    let isDuplicate: Bool
    let reason: String?
    /// Weighted confidence 0...1 that this is a duplicate (1 = certain)
    var score: Double = 0
}

// MARK: - ImportLearningService

/// On-device memory for the email import engine. Learns from every user
/// action in the review queue:
///   · merchant renames  → future imports show the clean name
///   · category changes  → recorded via CategoryLearningService (shared with manual entry)
///   · tag edits         → suggested again for the same merchant
///   · rejections        → repeat offenders surface a "usually rejected" hint
/// Backed by UserDefaults like CategoryLearningService — small dictionaries,
/// no raw email content.
final class ImportLearningService {
    static let shared = ImportLearningService()

    private(set) var merchantAliases: [String: String]   // normalized raw key → clean display name
    private(set) var merchantTags: [String: [String]]    // normalized raw key → last approved tags
    private(set) var rejectionCounts: [String: Int]      // merchant key → times rejected

    private let aliasKey = "ft_import_merchant_aliases_v1"
    private let tagsKey = "ft_import_merchant_tags_v1"
    private let rejectionKey = "ft_import_rejections_v1"

    private init() {
        let defaults = UserDefaults.standard
        merchantAliases = (defaults.dictionary(forKey: aliasKey) as? [String: String]) ?? [:]
        merchantTags = (defaults.dictionary(forKey: tagsKey) as? [String: [String]]) ?? [:]
        rejectionCounts = (defaults.dictionary(forKey: rejectionKey) as? [String: Int]) ?? [:]
    }

    var learnedAliasCount: Int { merchantAliases.count }

    // MARK: - Merchant normalization

    /// "AMZN Mktp AE" → key "amznmktpae"
    static func merchantKey(_ raw: String) -> String {
        raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    /// Best display name for a raw merchant string: user-learned alias first,
    /// then a light cleanup (strip trailing location/star codes, title-case shouty text).
    func normalizedMerchant(for raw: String) -> String {
        let key = Self.merchantKey(raw)
        if let alias = merchantAliases[key], !alias.isEmpty { return alias }
        return Self.cosmeticCleanup(raw)
    }

    func recordMerchantRename(raw: String, cleanName: String) {
        let key = Self.merchantKey(raw)
        let clean = cleanName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !clean.isEmpty, clean != raw else { return }
        merchantAliases[key] = clean
        UserDefaults.standard.set(merchantAliases, forKey: aliasKey)
    }

    /// Rule-based cleanup applied before any learning exists:
    /// collapse "*"-joined processor prefixes, drop trailing country codes,
    /// and soften ALL-CAPS merchant strings.
    static func cosmeticCleanup(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // "CAREEM* RIDE DUBAI" → take segment after the star if longer
        if let starIndex = name.firstIndex(of: "*") {
            let after = name[name.index(after: starIndex)...].trimmingCharacters(in: .whitespaces)
            if after.count >= 3 { name = after }
        }
        // Drop trailing 2–3 letter country/emirate tokens: "DUBAI ARE", "AE"
        let tokens = name.components(separatedBy: " ").filter { !$0.isEmpty }
        var kept = tokens
        while let last = kept.last,
              ["AE", "ARE", "UAE", "DXB", "AUH", "SHJ"].contains(last.uppercased()),
              kept.count > 1 {
            kept.removeLast()
        }
        name = kept.joined(separator: " ")
        // ALL CAPS → Capitalized Words (leave mixed case untouched)
        if name == name.uppercased(), name.count > 3 {
            name = name.capitalized
        }
        return name
    }

    // MARK: - Tags

    func suggestedTags(for rawMerchant: String) -> [String] {
        merchantTags[Self.merchantKey(rawMerchant)] ?? []
    }

    func recordApprovedTags(rawMerchant: String, tags: [String]) {
        let key = Self.merchantKey(rawMerchant)
        guard !key.isEmpty else { return }
        if tags.isEmpty {
            merchantTags.removeValue(forKey: key)
        } else {
            merchantTags[key] = tags
        }
        UserDefaults.standard.set(merchantTags, forKey: tagsKey)
    }

    // MARK: - Rejection learning

    func recordRejection(rawMerchant: String) {
        let key = Self.merchantKey(rawMerchant)
        guard !key.isEmpty else { return }
        rejectionCounts[key, default: 0] += 1
        UserDefaults.standard.set(rejectionCounts, forKey: rejectionKey)
    }

    /// True once the same merchant has been rejected 3+ times — the queue
    /// shows a hint so the user can dismiss these quickly.
    func isUsuallyRejected(rawMerchant: String) -> Bool {
        rejectionCounts[Self.merchantKey(rawMerchant), default: 0] >= 3
    }

    // MARK: - Duplicate detection (weighted confidence scoring)

    /// Score at/above which a candidate is treated as a duplicate.
    static let duplicateThreshold = 0.6

    /// Checks a parsed candidate against the permanent ledger and the pending
    /// queue. Instead of exact matching, each existing record gets a weighted
    /// similarity score — amount, currency, time delta, merchant similarity,
    /// card digits, reference number — and the best score decides.
    func duplicateCheck(
        fingerprint: String,
        amount: Double,
        currency: String,
        date: Date,
        cardLast4: String?,
        merchant: String,
        reference: String?,
        existingTransactions: [Transaction],
        pendingItems: [PendingEmailTransaction]
    ) -> DuplicateVerdict {
        // Identity short-circuits: same fingerprint in queue, or reference
        // number already recorded in the ledger → certain duplicate.
        if pendingItems.contains(where: { $0.fingerprint == fingerprint && $0.status != .rejected }) {
            return DuplicateVerdict(isDuplicate: true,
                                    reason: "Identical email already in the review queue", score: 1.0)
        }
        if let reference, !reference.isEmpty {
            if existingTransactions.contains(where: { $0.notes?.contains(reference) == true }) {
                return DuplicateVerdict(isDuplicate: true,
                                        reason: "Reference \(reference) already exists in your transactions", score: 1.0)
            }
            if pendingItems.contains(where: { $0.referenceNumber == reference && $0.status != .rejected }) {
                return DuplicateVerdict(isDuplicate: true,
                                        reason: "Reference \(reference) already in the review queue", score: 1.0)
            }
        }

        // Weighted scoring against the ledger
        var bestScore = 0.0
        var bestMatch: Transaction?
        for tx in existingTransactions {
            let score = Self.similarityScore(
                amount: amount, currency: currency, date: date,
                cardLast4: cardLast4, merchant: merchant,
                against: tx)
            if score > bestScore {
                bestScore = score
                bestMatch = tx
            }
        }

        if bestScore >= Self.duplicateThreshold, let match = bestMatch {
            return DuplicateVerdict(
                isDuplicate: true,
                reason: "\(Int(bestScore * 100))% match with “\(match.title)” (\(currency) \(String(format: "%.2f", amount))) on \(match.date.formatted(date: .abbreviated, time: .omitted))",
                score: bestScore
            )
        }
        return DuplicateVerdict(isDuplicate: false, reason: nil, score: bestScore)
    }

    /// Weighted similarity between a parsed candidate and one ledger
    /// transaction: amount 0.35, time proximity up to 0.25, merchant
    /// similarity up to 0.25, currency 0.05, card digits 0.10.
    static func similarityScore(
        amount: Double, currency: String, date: Date,
        cardLast4: String?, merchant: String,
        against tx: Transaction
    ) -> Double {
        // Amount is the gate: >1% difference means not the same transaction
        let amountDelta = abs(tx.amount - amount)
        guard amountDelta < max(0.01, amount * 0.01) else { return 0 }
        var score = 0.35

        if tx.currency == currency { score += 0.05 }

        let hours = abs(tx.date.timeIntervalSince(date)) / 3600
        if hours <= 2 { score += 0.25 }
        else if hours <= 12 { score += 0.20 }
        else if hours <= 36 { score += 0.12 }
        else if hours > 72 { return 0 }   // too far apart to be the same event

        let txMerchant = tx.merchant ?? tx.title
        let candidateKey = merchantKey(merchant)
        let txKey = merchantKey(txMerchant)
        if !candidateKey.isEmpty && !txKey.isEmpty {
            if candidateKey == txKey { score += 0.25 }
            else if txKey.contains(candidateKey) || candidateKey.contains(txKey) { score += 0.20 }
            else { score += tokenOverlap(merchant, txMerchant) * 0.20 }
        }

        if let last4 = cardLast4,
           let accountNumber = tx.account?.accountNumber,
           accountNumber.hasSuffix(last4) {
            score += 0.10
        }

        return min(1.0, score)
    }

    /// Jaccard word-token overlap between two merchant strings, 0...1.
    static func tokenOverlap(_ a: String, _ b: String) -> Double {
        func tokens(_ s: String) -> Set<String> {
            Set(s.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 })
        }
        let ta = tokens(a), tb = tokens(b)
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        return Double(ta.intersection(tb).count) / Double(ta.union(tb).count)
    }
}
