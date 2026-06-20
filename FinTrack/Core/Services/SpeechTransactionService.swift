import Foundation
import Speech
import AVFoundation

/// Listens to voice input and parses natural language into a transaction draft.
///
/// Supported patterns (English):
///   "Spent 45 dirhams at Carrefour on groceries"
///   "Paid 100 AED for electricity"
///   "Received 5000 salary from my company"
///   "Transfer 200 to savings account"
///   "Bought coffee at Starbucks for 18 dirhams"
@Observable
@MainActor
final class SpeechTransactionService {
    static let shared = SpeechTransactionService()

    var isListening    = false
    var transcript     = ""
    var parsedResult: ParsedVoiceTransaction?
    var permissionDenied = false
    private(set) var errorMessage: String?

    private var audioEngine           = AVAudioEngine()
    private var recognitionRequest:    SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask:       SFSpeechRecognitionTask?
    private let speechRecognizer       = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private init() {}

    // MARK: - Public API

    func requestPermission() async -> Bool {
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        switch status {
        case .authorized:
            permissionDenied = false
            return true
        default:
            permissionDenied = true
            return false
        }
    }

    func startListening() throws {
        guard !isListening else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Reset previous state
        transcript    = ""
        parsedResult  = nil
        errorMessage  = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = audioEngine.inputNode
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
                if result.isFinal {
                    self.parsedResult = self.parse(transcript: self.transcript)
                }
            }
            if error != nil || (result?.isFinal == true) {
                self.stopListening()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Parse on explicit stop if not yet parsed
        if parsedResult == nil, !transcript.isEmpty {
            parsedResult = parse(transcript: transcript)
        }
    }

    // MARK: - NLP Parser

    func parse(transcript: String) -> ParsedVoiceTransaction {
        let lower = transcript.lowercased()
        let words  = lower.split(separator: " ").map(String.init)

        var result = ParsedVoiceTransaction()

        // — Transaction type
        let expenseWords = ["spent", "paid", "bought", "purchased", "owe", "withdrew", "paying"]
        let incomeWords  = ["received", "earned", "got", "income", "salary", "received", "credited", "deposited"]
        let transferWords = ["transferred", "transfer", "moved", "sent"]

        if expenseWords.contains(where: { lower.contains($0) })  { result.type = .expense }
        else if incomeWords.contains(where: { lower.contains($0) }) { result.type = .income }
        else if transferWords.contains(where: { lower.contains($0) }) { result.type = .transfer }

        // — Amount
        let amountPatterns: [(String, String)] = [
            ("(\\d+(?:[.,]\\d+)?)\\s*(?:aed|dirhams?|dhs?)", "AED"),
            ("(\\d+(?:[.,]\\d+)?)\\s*(?:usd|dollars?|\\$)", "USD"),
            ("(\\d+(?:[.,]\\d+)?)\\s*(?:eur|euros?|€)", "EUR"),
            ("(\\d+(?:[.,]\\d+)?)\\s*(?:gbp|pounds?|£)", "GBP"),
            ("(\\d+(?:[.,]\\d+)?)\\s*(?:sar|riyals?)", "SAR"),
        ]
        for (pattern, currency) in amountPatterns {
            if let match = firstMatch(pattern, in: lower) {
                let cleaned = match.replacingOccurrences(of: ",", with: "")
                result.amount   = Double(cleaned)
                result.currency = currency
                break
            }
        }
        // Fallback: lone number
        if result.amount == nil {
            for word in words {
                let cleaned = word.replacingOccurrences(of: ",", with: "")
                if let v = Double(cleaned), v > 0 {
                    result.amount = v
                    break
                }
            }
        }

        // — Currency keywords without amount (applied retroactively)
        if result.currency == nil {
            let currencyMap: [(String, String)] = [
                ("aed", "AED"), ("dirham", "AED"), ("dirham", "AED"),
                ("usd", "USD"), ("dollar", "USD"),
                ("eur", "EUR"), ("euro", "EUR"),
                ("gbp", "GBP"), ("pound", "GBP"),
                ("sar", "SAR"), ("riyal", "SAR"),
            ]
            for (kw, code) in currencyMap {
                if lower.contains(kw) { result.currency = code; break }
            }
        }

        // — Merchant: "at <merchant>" or "from <merchant>" or "to <merchant>"
        let merchantLeaders = ["at", "from", "to", "for"]
        for leader in merchantLeaders {
            if let match = firstMatch("\(leader)\\s+((?:[a-z]+\\s*){1,3})", in: lower) {
                let candidate = match.trimmingCharacters(in: .whitespaces)
                // Filter out known stop words
                let stopWords = ["my", "the", "a", "an", "this", "that", "for"]
                if !stopWords.contains(candidate.lowercased().components(separatedBy: " ").first ?? "") {
                    result.merchant = candidate.capitalized
                    break
                }
            }
        }

        // — Category from keywords
        result.category = AICategorizationService.shared.suggestCategory(
            for: result.merchant ?? transcript,
            amount: result.amount ?? 0,
            type: result.type
        )

        // — Title: merchant or a cleaned version of transcript
        if let merchant = result.merchant {
            result.title = merchant
        } else {
            // Truncate transcript to something reasonable
            let cleaned = transcript.components(separatedBy: .init(charactersIn: ".,!?")).first ?? transcript
            result.title = String(cleaned.prefix(50)).trimmingCharacters(in: .whitespaces)
        }

        return result
    }

    // MARK: - Regex helper

    private func firstMatch(_ pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        // Return the first capture group if present, otherwise the whole match
        let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range(at: 0)
        guard let r = Range(captureRange, in: string) else { return nil }
        return String(string[r])
    }

    // MARK: - Error

    enum SpeechError: LocalizedError {
        case recognizerUnavailable
        var errorDescription: String? { "Speech recognizer is not available on this device." }
    }
}

// MARK: - Parsed voice transaction

struct ParsedVoiceTransaction {
    var title:    String = ""
    var amount:   Double? = nil
    var currency: String? = nil
    var merchant: String? = nil
    var category: TransactionCategory = .other
    var type:     TransactionType = .expense
    var notes:    String? = nil

    var isUsable: Bool { !title.isEmpty && amount != nil }
}
