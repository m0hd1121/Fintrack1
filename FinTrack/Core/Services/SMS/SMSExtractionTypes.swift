import Foundation
import FoundationModels

// MARK: - Foundation Models extraction schema
//
// Mirrors the extraction contract in `TransactionExtractionPrompt.swift`,
// translated into Apple's on-device `@Generable` schema instead of raw JSON
// Schema — FoundationModels derives its own schema from these types, so
// there is no separate schema file to keep in sync.
//
// Used only by `FoundationModelsSMSExtractor`. Deliberately distinct from
// the app's own `TransactionType`/`ParsedDirection` (Transaction.swift /
// EmailImportModels.swift) — this is a *raw model output* shape with an
// `unknown` case those don't have, and with evidence-grounding fields that
// never reach SwiftData. `BankSMSParser` converts a validated result into
// the app's existing `ParsedBankEmail` before anything downstream sees it.

@Generable
enum SMSTxKind: String {
    case expense, income, transfer, unknown
}

@Generable
enum SMSTxDirection: String {
    case debit, credit, unknown
}

@Generable
struct SMSExtractedTransaction {
    @Guide(description: "Issuing bank, fintech, or wallet. Not the merchant, not the card network.")
    var bankName: String?

    @Guide(description: "Exactly four digits the message presents as an account/card tail, e.g. after '****' or 'ending in'. Never an OTP, reference number, phone number, date, or amount.")
    var accountOrCardLast4: String?

    @Guide(description: "The positive value that actually moved. Never the resulting balance.")
    var amount: Double?

    @Guide(description: "ISO 4217 alphabetic code, uppercase, three letters.")
    var currency: String?

    @Guide(description: "The counterparty: shop, biller, employer, sender or recipient, in its original script.")
    var merchant: String?

    var transactionType: SMSTxKind
    var transactionDirection: SMSTxDirection

    @Guide(description: "Gregorian calendar date as YYYY-MM-DD, or null if the message doesn't state one.")
    var date: String?

    @Guide(description: "24-hour local time as HH:mm:ss, or null if not stated.")
    var time: String?

    @Guide(description: "One short English clause describing what happened. No invented detail.")
    var transactionDescription: String?

    @Guide(description: "Self-assessed confidence from 0.0 to 1.0.")
    var confidence: Double

    @Guide(description: "Exact substring of the message the amount was read from.")
    var amountEvidence: String?

    @Guide(description: "Exact substring of the message the currency was read from.")
    var currencyEvidence: String?

    @Guide(description: "Exact substring of the message the last four digits were read from, including any mask characters.")
    var last4Evidence: String?

    @Guide(description: "Exact substring of the message the date and/or time were read from.")
    var datetimeEvidence: String?
}

@Generable
struct SMSExtractionResult {
    @Guide(description: "One entry per distinct transaction. Empty if the message contains no transaction.")
    var transactions: [SMSExtractedTransaction]
}
