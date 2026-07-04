import Foundation
import Observation

// MARK: - AICFOService
// Conversational CFO backed by the Claude API (claude-opus-4-8).
// The deterministic FinancialIntelligenceService computes every number and
// hands Claude a grounded snapshot — the model analyzes and advises, it never
// invents figures. The API key is user-supplied and stored in the Keychain.

struct CFOChatMessage: Identifiable, Codable {
    var id = UUID()
    let role: String        // "user" | "assistant"
    let text: String
    let date: Date
}

@Observable
@MainActor
final class AICFOService {
    static let shared = AICFOService()

    var messages: [CFOChatMessage] = []
    var isThinking = false
    var lastError: String?

    private static let keychainKey = "ft_anthropic_api_key"
    private static let historyKey = "ft_cfo_chat_history_v1"
    private static let model = "claude-opus-4-8"

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let saved = try? JSONDecoder().decode([CFOChatMessage].self, from: data) {
            messages = saved
        }
    }

    // MARK: - API key (Keychain)

    var apiKey: String {
        get { KeychainStore.load(key: Self.keychainKey) ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainStore.delete(key: Self.keychainKey)
            } else {
                try? KeychainStore.save(trimmed, key: Self.keychainKey)
            }
        }
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }

    private func persistHistory() {
        // Keep the last 40 messages — enough continuity without unbounded growth
        let tail = Array(messages.suffix(40))
        if let data = try? JSONEncoder().encode(tail) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    // MARK: - System prompt (stable — cached across requests)

    private static let systemPrompt = """
    You are the AI Financial Intelligence Engine inside FinTrack, a personal \
    finance app for a user based in the UAE (base currency AED, VAT 5%, no \
    personal income tax). You act as the user's personal CFO: financial \
    analyst, budgeting expert, spending coach, planner, and early-warning \
    system.

    Ground rules:
    - A FINANCIAL SNAPSHOT computed by the app's deterministic engine is \
    provided with each conversation. Treat those numbers as ground truth. \
    Never invent transactions, balances, or figures that are not in the \
    snapshot; if data is missing, say what additional information would \
    improve the analysis.
    - Every recommendation must be evidence-based (cite the snapshot \
    numbers), ranked by financial impact, and include the expected outcome, \
    possible downside, and your confidence level.
    - Explain the why and how behind every piece of advice; never give a \
    conclusion without reasoning. Avoid jargon, or explain it when needed.
    - Be professional, friendly, supportive, and never judgmental — \
    encourage, don't shame. Behavioral observations (impulse spending, \
    lifestyle creep) should be framed constructively.
    - Never guarantee financial outcomes. Distinguish facts (from the \
    snapshot) from assumptions clearly.
    - Keep responses focused and readable: lead with the direct answer, \
    then supporting detail. Use short lists where they help.
    """

    // MARK: - Send

    func send(_ text: String, financialContext: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        guard isConfigured else {
            lastError = "Add your Anthropic API key first."
            return
        }

        lastError = nil
        messages.append(CFOChatMessage(role: "user", text: trimmed, date: Date()))
        isThinking = true
        defer { isThinking = false }

        do {
            let reply = try await callClaude(financialContext: financialContext)
            messages.append(CFOChatMessage(role: "assistant", text: reply, date: Date()))
            persistHistory()
        } catch {
            lastError = error.localizedDescription
            // Remove the unanswered user message so retry doesn't duplicate it
            if messages.last?.role == "user" { messages.removeLast() }
        }
    }

    private func callClaude(financialContext: String) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw CFOError.badRequest("Invalid endpoint")
        }

        // Stable system prompt first with a cache breakpoint, volatile
        // snapshot after it — keeps the cached prefix intact across turns.
        let system: [[String: Any]] = [
            ["type": "text", "text": Self.systemPrompt,
             "cache_control": ["type": "ephemeral"]],
            ["type": "text", "text": financialContext],
        ]

        // The API requires the first message to be a user turn — after
        // trimming, drop any leading assistant messages.
        var window = Array(messages.suffix(20))
        while window.first?.role == "assistant" { window.removeFirst() }
        let history: [[String: Any]] = window.map {
            ["role": $0.role, "content": $0.text]
        }

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 2048,
            "system": system,
            "messages": history,
        ]

        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                switch status {
                case 401: throw CFOError.badRequest("Invalid API key — check it in settings.")
                case 429: throw CFOError.badRequest("Rate limited — wait a moment and try again.")
                case 529: throw CFOError.badRequest("Claude is temporarily overloaded — try again shortly.")
                default:  throw CFOError.badRequest(message)
                }
            }
            throw CFOError.badRequest("Request failed (HTTP \(status))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw CFOError.badRequest("Unexpected response format")
        }

        if let stopReason = json["stop_reason"] as? String, stopReason == "refusal" {
            return "I can't help with that particular request, but I'm happy to dig into any part of your finances."
        }

        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
        guard !text.isEmpty else { throw CFOError.badRequest("Empty response") }
        return text
    }

    enum CFOError: LocalizedError {
        case badRequest(String)
        var errorDescription: String? {
            switch self {
            case .badRequest(let message): return message
            }
        }
    }
}
