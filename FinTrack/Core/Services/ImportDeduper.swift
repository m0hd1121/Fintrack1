import Foundation
import SwiftData

/// Collapses the same real-world transaction arriving on more than one
/// channel into a **single** review-queue row holding the best available data.
///
/// A card payment can legitimately reach FinTrack three times: the bank's
/// email alert, its SMS alert, and the Apple Pay/Wallet automation. Flagging
/// those as "possible duplicates" (the old behaviour) still left the user
/// rejecting two rows by hand for every purchase. Instead, when a newly
/// parsed transaction matches one already waiting in the queue:
///
///   · the higher-quality reading wins and stays in the queue, and
///   · the loser's *complementary* fields are merged into it first — SMS
///     often carries a reference number Apple Pay lacks; email usually has
///     the running balance; Apple Pay has an exact merchant and category.
///
/// So the surviving row is better than any single channel produced on its own.
///
/// Scope: this only merges against items still **pending**. A match against
/// something already approved into the ledger keeps the existing
/// "possible duplicate" flag instead — silently discarding there could hide a
/// genuine second purchase, and approving one already requires an explicit
/// "Approve Anyway" tap (see `EmailReviewQueueView`).
@MainActor
enum ImportDeduper {

    enum Resolution {
        /// No match — filed as a new row.
        case inserted
        /// The new reading was better: it replaced the queued copy from
        /// `replacedChannel`, having absorbed that copy's extra fields.
        case upgradedExisting(replacedChannel: String)
        /// The queued copy from `winningChannel` was better: it absorbed
        /// this reading's extra fields and no new row was created.
        case keptExisting(winningChannel: String)

        /// True when a row now exists in the queue representing this
        /// transaction *because of this call*.
        var createdNewRow: Bool {
            switch self {
            case .inserted, .upgradedExisting: return true
            case .keptExisting:                return false
            }
        }

        var summary: String {
            switch self {
            case .inserted:
                return "Added to the review queue"
            case .upgradedExisting(let replaced):
                return "Added to the review queue (better data than the \(replaced) copy)"
            case .keptExisting(let winner):
                return "Merged into the existing \(winner) copy"
            }
        }
    }

    /// Files `newItem`, merging it with a queued match rather than creating a
    /// second row. Call this instead of `context.insert(newItem)`.
    static func file(
        _ newItem: PendingEmailTransaction,
        channel: ImportChannel,
        pendingItems: [PendingEmailTransaction],
        context: ModelContext
    ) -> Resolution {
        guard let match = bestMatch(for: newItem, in: pendingItems) else {
            context.insert(newItem)
            return .inserted
        }

        let existingChannel = ImportChannel.of(match)
        let newQuality = quality(of: newItem, channel: channel)
        let existingQuality = quality(of: match, channel: existingChannel)

        if newQuality > existingQuality {
            absorb(into: newItem, from: match)
            newItem.parseExplanation += "\nAlso received via \(existingChannel.displayName)"
                + " — this \(channel.displayName) copy was kept as the more reliable reading"
                + " (\(percent(newQuality)) vs \(percent(existingQuality)))."
            context.delete(match)
            context.insert(newItem)
            return .upgradedExisting(replacedChannel: existingChannel.displayName)
        } else {
            absorb(into: match, from: newItem)
            match.parseExplanation += "\nAlso received via \(channel.displayName)"
                + " — the existing \(existingChannel.displayName) copy was kept as the more"
                + " reliable reading (\(percent(existingQuality)) vs \(percent(newQuality)))."
            return .keptExisting(winningChannel: existingChannel.displayName)
        }
    }

    // MARK: - Matching

    /// The queued item most likely to be the same transaction, using the same
    /// weighted amount/time/merchant/card scoring the duplicate flag uses.
    static func bestMatch(
        for candidate: PendingEmailTransaction,
        in pendingItems: [PendingEmailTransaction]
    ) -> PendingEmailTransaction? {
        var best: (item: PendingEmailTransaction, score: Double)?
        for item in pendingItems
        where item.status == .pending && item.id != candidate.id && item.messageId != candidate.messageId {
            let score = ImportLearningService.similarityScore(
                amount: candidate.amount, currency: candidate.currency,
                date: candidate.transactionDate, cardLast4: candidate.cardLast4,
                merchant: candidate.merchantNormalized,
                against: item
            )
            if score >= ImportLearningService.duplicateThreshold, score > (best?.score ?? 0) {
                best = (item, score)
            }
        }
        return best?.item
    }

    // MARK: - Quality

    /// How much to trust one reading of a transaction: channel correctness
    /// plus how completely it filled the fields in, minus a penalty for a
    /// parse that flagged itself as shaky.
    static func quality(of item: PendingEmailTransaction, channel: ImportChannel) -> Double {
        var score = channel.trustWeight + item.confidence * 0.5

        if item.cardLast4?.isEmpty == false { score += 0.08 }
        if item.referenceNumber?.isEmpty == false { score += 0.08 }
        if item.availableBalance != nil { score += 0.04 }
        if !isPlaceholderMerchant(item.merchantRaw) { score += 0.08 }
        if item.isSuspiciousParse { score -= 0.15 }

        return score
    }

    /// Merchant strings the parsers fall back to when they couldn't read a
    /// real one — worth less than any actual name.
    static func isPlaceholderMerchant(_ merchant: String) -> Bool {
        let cleaned = merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return cleaned.isEmpty
            || cleaned == "unknown merchant"
            || cleaned == "unknown bank"
            || cleaned == "apple pay"
    }

    // MARK: - Merging

    /// Fills gaps in `winner` from `loser`. Only ever adds information — an
    /// existing value on the winner is never overwritten, except a
    /// placeholder merchant, which any real name beats.
    static func absorb(into winner: PendingEmailTransaction, from loser: PendingEmailTransaction) {
        if winner.cardLast4?.isEmpty != false, let last4 = loser.cardLast4, !last4.isEmpty {
            winner.cardLast4 = last4
        }
        if winner.referenceNumber?.isEmpty != false,
           let reference = loser.referenceNumber, !reference.isEmpty {
            winner.referenceNumber = reference
        }
        if winner.availableBalance == nil {
            winner.availableBalance = loser.availableBalance
        }
        if isPlaceholderMerchant(winner.merchantRaw), !isPlaceholderMerchant(loser.merchantRaw) {
            winner.merchantRaw = loser.merchantRaw
            winner.merchantNormalized = loser.merchantNormalized
        }
        if winner.matchedAccountId == nil, let accountId = loser.matchedAccountId {
            winner.matchedAccountId = accountId
            winner.accountMatchReason = loser.accountMatchReason
        }
        if winner.bankName.isEmpty || winner.bankName == "Unknown Bank",
           !loser.bankName.isEmpty, loser.bankName != "Unknown Bank" {
            winner.bankName = loser.bankName
        }
        if winner.suggestedTags.isEmpty { winner.suggestedTags = loser.suggestedTags }

        // Two independent readings agreeing is itself evidence.
        winner.confidence = max(winner.confidence, loser.confidence)

        // The "possible duplicate" flag was raised by the very sibling we just
        // absorbed, so it no longer applies. A flag naming a ledger match is
        // left alone — that one is still unresolved.
        if let reason = winner.duplicateReason,
           reason.localizedCaseInsensitiveContains("review queue")
            || reason.localizedCaseInsensitiveContains("pending") {
            winner.isPossibleDuplicate = false
            winner.duplicateReason = nil
        }
    }

    private static func percent(_ score: Double) -> String {
        "\(Int((score * 100).rounded()))%"
    }
}
