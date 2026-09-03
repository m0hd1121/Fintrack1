import Foundation

/// One bank's SMS identity: sender IDs plus a display name. This is
/// deliberately the *only* part of the SMS pipeline that's data instead of
/// code — sender IDs and wording drift are what banks change without
/// warning; the extraction grammar (amount/date/merchant/last4 regex,
/// shared with `BankEmailParser`) rarely needs to change alongside them.
struct BankSMSTemplate: Codable, Identifiable, Equatable {
    var bankId: String        // stable short code, e.g. "ENBD"
    var bankName: String      // display name, e.g. "Emirates NBD"
    var senderIds: [String]   // known SMS sender IDs/shortcodes, best-effort

    var id: String { bankId }
}

enum BankSMSTemplateStore {

    /// Best-effort starting set for UAE banks, seeded from the same registry
    /// `BankEmailParser` uses for email. Real SMS sender IDs vary by telecom
    /// and by bank agreement and aren't independently verifiable here — these
    /// are reasonable starting guesses, not confirmed values. Bank *content*
    /// matching (`identify(text:)`) works even when a sender ID guess is
    /// wrong, since most bank SMS also names itself in the body.
    static let bundled: [BankSMSTemplate] = [
        BankSMSTemplate(bankId: "ENBD", bankName: "Emirates NBD", senderIds: ["EmiratesNBD", "ENBD"]),
        BankSMSTemplate(bankId: "FAB", bankName: "FAB", senderIds: ["FAB", "BankFAB"]),
        BankSMSTemplate(bankId: "ADCB", bankName: "ADCB", senderIds: ["ADCB"]),
        BankSMSTemplate(bankId: "MASHREQ", bankName: "Mashreq", senderIds: ["Mashreq", "MashreqBank"]),
        BankSMSTemplate(bankId: "DIB", bankName: "DIB", senderIds: ["DIB"]),
        BankSMSTemplate(bankId: "RAKBANK", bankName: "RAKBANK", senderIds: ["RAKBANK", "RAKBank"]),
        BankSMSTemplate(bankId: "CBD", bankName: "CBD", senderIds: ["CBD"]),
        BankSMSTemplate(bankId: "EIB", bankName: "Emirates Islamic", senderIds: ["EmiratesIslamic", "EIBANK"]),
        BankSMSTemplate(bankId: "ADIB", bankName: "ADIB", senderIds: ["ADIB"]),
        BankSMSTemplate(bankId: "WIO", bankName: "Wio Bank", senderIds: ["Wio", "WioBank"]),
        BankSMSTemplate(bankId: "LIV", bankName: "Liv", senderIds: ["Liv", "LivBank"]),
    ]

    private static let cacheKey = "ft_sms_bank_templates_v1"

    /// Bundled list merged with any previously-fetched remote list (remote
    /// entries win on a matching `bankId`). Works fully offline until a
    /// remote URL is actually configured and fetched.
    static var active: [BankSMSTemplate] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let remote = try? JSONDecoder().decode([BankSMSTemplate].self, from: data)
        else { return bundled }
        var merged = Dictionary(uniqueKeysWithValues: bundled.map { ($0.bankId, $0) })
        for template in remote { merged[template.bankId] = template }
        return Array(merged.values).sorted { $0.bankName < $1.bankName }
    }

    /// Opt-in remote refresh — nothing is fetched unless this is called with
    /// a real URL, so the feature ships fully working with the bundled list.
    /// This is the "remote JSON, not compiled regex" hook: point it at a
    /// hosted templates file to update sender IDs without an App Store
    /// review.
    @discardableResult
    static func refreshFromRemote(url: URL) async -> Bool {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let templates = try? JSONDecoder().decode([BankSMSTemplate].self, from: data),
              !templates.isEmpty
        else { return false }
        UserDefaults.standard.set((try? JSONEncoder().encode(templates)) ?? Data(), forKey: cacheKey)
        return true
    }

    /// Finds a bank by SMS sender id first, falling back to scanning the
    /// message text for the bank's display name — some bank SMS come from
    /// generic shortcodes that only identify themselves in the body.
    ///
    /// `extraTemplates` — sender IDs the user typed into a bank's setup
    /// sheet (`SMSBankRuleSheet`) — are checked first, since a user-supplied
    /// sender ID is more trustworthy than the bundled best-effort guesses.
    static func identify(senderId: String?, text: String, extraTemplates: [BankSMSTemplate] = []) -> BankSMSTemplate? {
        let candidates = extraTemplates + active
        let lowerText = text.lowercased()
        if let senderId, !senderId.isEmpty {
            let lowerSender = senderId.lowercased()
            if let match = candidates.first(where: { template in
                template.senderIds.contains {
                    lowerSender.contains($0.lowercased()) || $0.lowercased().contains(lowerSender)
                }
            }) {
                return match
            }
        }
        return candidates.first { lowerText.contains($0.bankName.lowercased()) }
    }

    /// Stable, comparable identity for a bank name — shared by
    /// `SMSIngestService` (tagging a pending item's synthetic sender) and
    /// `SMSBankRuleSheet` (saving a matching per-bank rule), so a rule
    /// created for "Emirates NBD" reliably matches transactions parsed with
    /// that same display name.
    static func slug(_ bankName: String) -> String {
        bankName.uppercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}
