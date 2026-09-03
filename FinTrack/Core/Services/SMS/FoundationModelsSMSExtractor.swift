import Foundation
import FoundationModels

/// Wraps Apple's on-device model for messages `BankSMSParser`'s deterministic
/// template pass can't confidently parse. Runs fully on-device — nothing
/// about the message ever leaves the phone, matching the rest of the import
/// pipeline's privacy model.
enum FoundationModelsSMSExtractor {

    enum ExtractorError: Error {
        case unavailable(String)
    }

    /// True when the on-device model can actually be asked something right
    /// now (device eligible, Apple Intelligence on, model downloaded).
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Human-readable reason it's unavailable — useful for the pending
    /// item's explanation trail and for `SMSImportView`'s status card.
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is turned off in Settings"
        case .unavailable(.modelNotReady):
            return "The on-device model is still downloading"
        case .unavailable(let other):
            return "On-device model unavailable (\(other))"
        }
    }

    static func extract(_ normalizedText: String) async throws -> SMSExtractionResult {
        guard isAvailable else {
            throw ExtractorError.unavailable(unavailableReason ?? "On-device model unavailable")
        }
        let session = LanguageModelSession(instructions: TransactionExtractionPrompt.text)
        let prompt = "<message>\n\(normalizedText)\n</message>"
        let response = try await session.respond(to: prompt, generating: SMSExtractionResult.self)
        return response.content
    }
}
