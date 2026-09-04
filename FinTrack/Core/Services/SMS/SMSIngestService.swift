import Foundation
import SwiftData

/// Turns a raw SMS message into a `PendingEmailTransaction` and files it in
/// the same review queue the email importer uses — see
/// `EmailSyncService.processEmail` / `.approveToLedger`. Nothing from this
/// pipeline ever posts straight to the ledger: every SMS-derived transaction
/// waits for the user's own approval in `EmailReviewQueueView`, exactly like
/// every email-derived one.
///
/// SMS items are *tagged*, not modeled separately: `PendingEmailTransaction
/// .senderAddress` and `BankEmailRule.senderEmail` carry an `"sms:<bank
/// slug>"` sentinel instead of an email address (the same trick this
/// codebase already uses for `AppSettings.cloudSyncEnabled`), so this
/// feature needed no new `@Model` and no schema bump.
@MainActor
enum SMSIngestService {

    static func senderTag(bankName: String) -> String {
        ImportFiler.tag(channel: .sms, bankName: bankName)
    }

    /// Parses and files one SMS. Returns true when at least one pending item
    /// was created (a message can contain more than one transaction).
    @discardableResult
    static func ingest(rawText: String, senderId: String?, receivedAt: Date, context: ModelContext) async -> Bool {
        // Sender IDs the user typed into a bank's SMS setup sheet — tried
        // ahead of the bundled best-effort list (see BankSMSTemplateStore).
        let userTemplates: [BankSMSTemplate] = ((try? context.fetch(FetchDescriptor<BankEmailRule>())) ?? [])
            .filter { $0.isEnabled && $0.senderEmail.hasPrefix("sms:") && !$0.keywords.isEmpty }
            .map { BankSMSTemplate(bankId: BankSMSTemplateStore.slug($0.bankName), bankName: $0.bankName, senderIds: $0.keywords) }

        let results = await BankSMSParser.parse(rawText: rawText, senderId: senderId, userTemplates: userTemplates)
        guard !results.isEmpty else {
            // Never drop a message silently: an unparsed SMS is either a
            // non-transaction (fine) or a bank that changed its wording
            // (needs a template fix). Either way the user should be able to
            // see what actually arrived — see `SMSImportView`'s
            // "Recent Messages" section.
            record(rawText: rawText, senderId: senderId, receivedAt: receivedAt,
                   outcome: "No transaction found in this message")
            return false
        }

        var created = false
        for parsed in results
        where file(parsed, rawText: rawText, receivedAt: receivedAt, context: context) {
            created = true
        }
        if created { try? context.save() }
        record(rawText: rawText, senderId: senderId, receivedAt: receivedAt,
               outcome: created
                   ? "Added to the review queue"
                   : "Already imported (duplicate of an earlier message)")
        return created
    }

    // MARK: - Received message log

    /// Every SMS that actually reached `ingest`, with what became of it.
    /// Recording all of them (not just failures) is what makes "the
    /// automation says it sent something but nothing appeared" diagnosable:
    /// an empty log means the message never got past the queue, while an
    /// entry pins the problem to parsing. Kept in UserDefaults (no schema
    /// change) and capped — a diagnostic trail, not an archive.
    struct ReceivedSMS: Codable, Identifiable {
        var id: UUID = UUID()
        var rawText: String
        var senderId: String?
        var receivedAt: Date
        var outcome: String
        /// True when this one made it into the review queue.
        var succeeded: Bool { outcome == "Added to the review queue" }
    }

    static let receivedKey = "ft_sms_received_v1"
    private static let maxReceivedKept = 20

    static var receivedMessages: [ReceivedSMS] {
        guard let data = UserDefaults.standard.data(forKey: receivedKey),
              let list = try? JSONDecoder().decode([ReceivedSMS].self, from: data)
        else { return [] }
        return list.sorted { $0.receivedAt > $1.receivedAt }
    }

    static func clearReceived() {
        UserDefaults.standard.removeObject(forKey: receivedKey)
    }

    private static func record(rawText: String, senderId: String?, receivedAt: Date, outcome: String) {
        var list = receivedMessages
        list.insert(ReceivedSMS(rawText: rawText, senderId: senderId,
                                receivedAt: receivedAt, outcome: outcome), at: 0)
        list = Array(list.prefix(maxReceivedKept))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: receivedKey)
        }
    }

    /// Filing is shared with every other automation channel (Apple Pay
    /// today) — see `ImportFiler`.
    @discardableResult
    private static func file(
        _ parsed: ParsedBankEmail, rawText: String, receivedAt: Date, context: ModelContext
    ) -> Bool {
        ImportFiler.file(parsed, channel: .sms, rawText: rawText,
                         receivedAt: receivedAt, context: context)
    }

    /// Read by `SMSImportView` for its 24-hour "first SMS landed" check.
    static var lastImportKey: String { ImportChannel.sms.lastImportKey }

}
