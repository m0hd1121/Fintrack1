import Foundation
import SwiftData

/// Files an Apple Pay / Wallet transaction handed over by a Shortcuts
/// "Transaction" Personal Automation.
///
/// Unlike SMS, this channel arrives already **structured** — Wallet gives
/// Shortcuts the amount, merchant, date and category as real fields, so
/// there is nothing to parse and no wording for a bank to change. That makes
/// it strictly more reliable than SMS where it's available; it just covers
/// less (only payments actually made through Apple Pay).
///
/// It converges on the same `ParsedBankEmail` shape the SMS and email paths
/// use, so it reuses `ImportFiler` and lands in the same review queue.
/// Nothing here posts to the ledger without the user's approval.
@MainActor
enum ApplePayIngestService {

    /// Wallet's own category strings are close to, but not the same as, this
    /// app's `TransactionCategory`. Map the ones that correspond; anything
    /// unmatched falls through to `AICategorizationService`'s merchant-based
    /// prediction inside `ImportFiler`, which is usually better than forcing
    /// a bad match.
    static func mappedCategory(_ walletCategory: String?) -> TransactionCategory? {
        guard let raw = walletCategory?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case let c where c.contains("food"), let c where c.contains("dining"),
             let c where c.contains("restaurant"), let c where c.contains("grocer"):
            return .food
        case let c where c.contains("shop"), let c where c.contains("retail"),
             let c where c.contains("merchandise"):
            return .shopping
        case let c where c.contains("transport"), let c where c.contains("transit"),
             let c where c.contains("taxi"), let c where c.contains("ride"):
            return .transportation
        case let c where c.contains("gas"), let c where c.contains("fuel"):
            return .fuel
        case let c where c.contains("entertain"), let c where c.contains("recreation"):
            return .entertainment
        case let c where c.contains("travel"), let c where c.contains("airline"),
             let c where c.contains("hotel"), let c where c.contains("lodging"):
            return .travel
        case let c where c.contains("health"), let c where c.contains("medical"),
             let c where c.contains("pharmac"):
            return .medical
        case let c where c.contains("utilit"), let c where c.contains("bill"):
            return .utilities
        case let c where c.contains("education"), let c where c.contains("school"):
            return .education
        case let c where c.contains("subscription"), let c where c.contains("service"):
            return .subscriptions
        case let c where c.contains("personal care"), let c where c.contains("beauty"):
            return .personalCare
        case let c where c.contains("charit"), let c where c.contains("donation"):
            return .charity
        default:
            return nil
        }
    }

    /// Builds the shared parsed shape from Wallet's structured fields and
    /// files it. `isRefund` flips the direction for returns/credits.
    @discardableResult
    static func ingest(
        amount: Double,
        merchant: String,
        currency: String?,
        date: Date?,
        walletCategory: String?,
        card: String?,
        isRefund: Bool,
        context: ModelContext
    ) -> Bool {
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0, !trimmedMerchant.isEmpty else {
            record(outcome: "Ignored — needs both an amount and a merchant",
                   merchant: trimmedMerchant, amount: amount, receivedAt: date ?? Date())
            return false
        }

        let resolvedCurrency = (currency?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { ISO4217.isValid($0) ? $0.uppercased() : nil }
            ?? CurrencyService.shared.baseCurrencyCode

        var lines = ["Received from Apple Pay via a Shortcuts automation"]
        if let card, !card.isEmpty { lines.append("Card: \(card)") }
        if let walletCategory, !walletCategory.isEmpty {
            lines.append("Wallet category: \(walletCategory)")
        }
        // Structured input — no text was parsed, so nothing can be misread.
        lines.append("Amount, merchant and date came through as real fields, not parsed text")

        let parsed = ParsedBankEmail(
            amount: amount,
            currency: resolvedCurrency,
            merchant: trimmedMerchant,
            date: date ?? Date(),
            cardLast4: last4(from: card),
            direction: isRefund ? .credit : .debit,
            availableBalance: nil,
            referenceNumber: nil,
            bankName: card?.isEmpty == false ? card! : "Apple Pay",
            confidence: 0.95,
            explanationLines: lines,
            isSuspicious: false,
            suspiciousReason: nil
        )

        let created = ImportFiler.file(
            parsed, channel: .applePay,
            rawText: "\(trimmedMerchant) \(resolvedCurrency) \(amount)",
            receivedAt: date ?? Date(),
            categoryOverride: mappedCategory(walletCategory),
            context: context
        )
        if created { try? context.save() }
        record(outcome: created
                   ? "Added to the review queue"
                   : "Already imported (duplicate)",
               merchant: trimmedMerchant, amount: amount, receivedAt: date ?? Date())
        return created
    }

    /// Wallet card names often end in the last four digits ("Visa •••• 1234"),
    /// which is exactly what account matching needs.
    private static func last4(from card: String?) -> String? {
        guard let card else { return nil }
        let digits = card.filter(\.isNumber)
        return digits.count >= 4 ? String(digits.suffix(4)) : nil
    }

    // MARK: - Received log (same purpose as the SMS one)

    struct ReceivedApplePay: Codable, Identifiable {
        var id: UUID = UUID()
        var merchant: String
        var amount: Double
        var receivedAt: Date
        var outcome: String
        var succeeded: Bool { outcome == "Added to the review queue" }
    }

    static let receivedKey = "ft_applepay_received_v1"
    private static let maxReceivedKept = 20

    static var receivedTransactions: [ReceivedApplePay] {
        guard let data = UserDefaults.standard.data(forKey: receivedKey),
              let list = try? JSONDecoder().decode([ReceivedApplePay].self, from: data)
        else { return [] }
        return list.sorted { $0.receivedAt > $1.receivedAt }
    }

    static func clearReceived() {
        UserDefaults.standard.removeObject(forKey: receivedKey)
    }

    private static func record(outcome: String, merchant: String, amount: Double, receivedAt: Date) {
        var list = receivedTransactions
        list.insert(ReceivedApplePay(merchant: merchant, amount: amount,
                                     receivedAt: receivedAt, outcome: outcome), at: 0)
        list = Array(list.prefix(maxReceivedKept))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: receivedKey)
        }
    }
}
