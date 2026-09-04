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
    static func ingest(rawText: String, senderId: String?, receivedAt: Date,
                       queueId: UUID? = nil, context: ModelContext) async -> Bool {
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
                   outcome: "No transaction found in this message", queueId: queueId)
            return false
        }

        var created = false
        var outcomes: [String] = []
        for parsed in results {
            guard let resolution = file(parsed, rawText: rawText,
                                        receivedAt: receivedAt, context: context) else {
                outcomes.append("Already imported (duplicate of an earlier message)")
                continue
            }
            if resolution.createdNewRow { created = true }
            outcomes.append(resolution.summary)
        }
        try? context.save()
        record(rawText: rawText, senderId: senderId, receivedAt: receivedAt,
               outcome: outcomes.joined(separator: " · "), queueId: queueId)
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
        /// The `PendingSMSText` this entry came from, when it arrived through
        /// the Shortcuts automation. It's what lets the "waiting in the queue"
        /// entry written by the intent be *replaced* by the parse result later
        /// rather than duplicated. Nil for a message pasted in by hand.
        var queueId: UUID?
        /// True when this one reached the review queue — either as a new row
        /// or by merging into a copy another channel had already delivered
        /// (`ImportDeduper`), which is just as much a success.
        var succeeded: Bool {
            outcome.hasPrefix("Added to the review queue") || outcome.hasPrefix("Merged into")
        }
        /// Still sitting in the queue — the automation delivered it but the
        /// app hasn't processed it yet.
        var isWaiting: Bool { outcome == Self.waitingOutcome }

        static let waitingOutcome = "Delivered by Shortcuts — waiting for FinTrack to process it"
    }

    /// Logged by `LogTransactionFromText` the moment a message is queued, so
    /// "Recent Messages" distinguishes the two halves of the pipeline: an
    /// entry stuck on `waitingOutcome` means Shortcuts delivered the SMS and
    /// the drain never ran, while no entry at all means the automation never
    /// reached the app. Previously both looked identical (an empty list).
    static func recordQueued(id: UUID, rawText: String, senderId: String?, receivedAt: Date) {
        record(rawText: rawText, senderId: senderId, receivedAt: receivedAt,
               outcome: ReceivedSMS.waitingOutcome, queueId: id)
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

    private static func record(rawText: String, senderId: String?, receivedAt: Date,
                               outcome: String, queueId: UUID? = nil) {
        var list = receivedMessages
        // Update the intent's "waiting" entry in place instead of logging the
        // same message twice.
        if let queueId, let index = list.firstIndex(where: { $0.queueId == queueId }) {
            list[index].outcome = outcome
        } else {
            list.insert(ReceivedSMS(rawText: rawText, senderId: senderId,
                                    receivedAt: receivedAt, outcome: outcome,
                                    queueId: queueId), at: 0)
        }
        list = Array(list.prefix(maxReceivedKept))
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: receivedKey)
        }
    }

    /// Filing is shared with every other automation channel (email, Apple
    /// Pay) — see `ImportFiler`, which also collapses the same payment
    /// arriving on more than one of them into a single queue row.
    private static func file(
        _ parsed: ParsedBankEmail, rawText: String, receivedAt: Date, context: ModelContext
    ) -> ImportDeduper.Resolution? {
        ImportFiler.file(parsed, channel: .sms, rawText: rawText,
                         receivedAt: receivedAt, context: context)
    }

    /// Read by `SMSImportView` for its 24-hour "first SMS landed" check.
    static var lastImportKey: String { ImportChannel.sms.lastImportKey }

}
