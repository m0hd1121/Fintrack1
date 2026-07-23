import Foundation
import SwiftData
import Observation
import UIKit
import UserNotifications

// MARK: - RemoteEmailSyncService
//
// Client for the Cloudflare email-sync backend (see /backend). The Worker
// receives forwarded bank-alert emails, parses them into pending transactions,
// and pushes an APNs notification. This service:
//   • registers the device's APNs token with the backend,
//   • pulls new pending transactions into the local review queue
//     (`PendingEmailTransaction` → the existing Transactions review banner),
//   • acknowledges them so they aren't returned / re-notified again.
//
// Config lives in UserDefaults (no @Model, so no schema bump). The user's
// `userId` maps to their forwarding address: `<userId>@<forwardingDomain>`.

@Observable
@MainActor
final class RemoteEmailSyncService {
    static let shared = RemoteEmailSyncService()

    /// Set by the app entry point so background pushes can write to the store.
    var container: ModelContainer?

    /// Latest APNs device token (hex), set by the app delegate.
    var deviceToken: String?

    var lastSyncDate: Date?
    var lastError: String?
    var isSyncing = false

    private let d = UserDefaults.standard
    private enum Key {
        static let enabled = "cloud_email_sync_enabled"
        static let baseURL = "cloud_email_sync_base_url"
        static let apiKey  = "cloud_email_sync_api_key"
        static let userId  = "cloud_email_sync_user_id"
        static let domain  = "cloud_email_sync_forwarding_domain"
    }

    private init() {}

    // MARK: Config

    var isEnabled: Bool {
        get { d.bool(forKey: Key.enabled) }
        set { d.set(newValue, forKey: Key.enabled) }
    }
    var baseURL: String {
        get { d.string(forKey: Key.baseURL) ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.baseURL) }
    }
    var apiKey: String {
        get { d.string(forKey: Key.apiKey) ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.apiKey) }
    }
    var forwardingDomain: String {
        get { d.string(forKey: Key.domain) ?? "" }
        set { d.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Key.domain) }
    }

    /// Stable per-install id, generated once. Becomes the email local-part.
    var userId: String {
        if let existing = d.string(forKey: Key.userId), !existing.isEmpty { return existing }
        let generated = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12).lowercased()
        d.set(String(generated), forKey: Key.userId)
        return String(generated)
    }

    /// The address the user forwards bank alerts to.
    var forwardingAddress: String {
        forwardingDomain.isEmpty ? "" : "\(userId)@\(forwardingDomain)"
    }

    var isConfigured: Bool {
        isEnabled && !baseURL.isEmpty && !apiKey.isEmpty
    }

    // MARK: Push registration

    /// Ask for notification permission and register for remote push.
    func enablePush() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Send the current device token to the backend.
    func registerDevice() async {
        guard isConfigured, let token = deviceToken else { return }
        let body: [String: Any] = ["userId": userId, "deviceToken": token, "platform": "ios"]
        _ = try? await post("/v1/devices", body: body)
    }

    // MARK: Sync

    /// Pull new pending transactions into the local review queue. Returns the
    /// number of newly-added items.
    @discardableResult
    func syncPending() async -> Int {
        guard isConfigured, let container else { return 0 }
        isSyncing = true
        defer { isSyncing = false }

        do {
            guard var comps = URLComponents(string: baseURL.appending("/v1/pending")) else { return 0 }
            comps.queryItems = [
                URLQueryItem(name: "userId", value: userId),
                URLQueryItem(name: "status", value: "pending"),
            ]
            guard let url = comps.url else { return 0 }
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                lastError = "Sync failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1))"
                return 0
            }
            let decoded = try JSONDecoder().decode(PendingResponse.self, from: data)

            let context = ModelContext(container)
            let existing = Set((try? context.fetch(FetchDescriptor<PendingEmailTransaction>()))?.map(\.fingerprint) ?? [])

            var added: [String] = []
            for r in decoded.pending where !existing.contains(r.id) {
                context.insert(r.toPending())
                added.append(r.id)
            }
            if !added.isEmpty { try? context.save() }

            // Tell the backend we pulled these so they aren't returned again.
            if !added.isEmpty {
                _ = try? await post("/v1/pending/ack", body: ["userId": userId, "ids": added, "status": "pulled"])
            }
            lastSyncDate = Date()
            lastError = nil
            return added.count
        } catch {
            lastError = error.localizedDescription
            return 0
        }
    }

    // MARK: Networking

    @discardableResult
    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL.appending(path)) else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }
}

// MARK: - API DTOs

private struct PendingResponse: Decodable {
    let pending: [RemotePendingTxn]
}

private struct RemotePendingTxn: Decodable {
    let id: String
    let bank_name: String?
    let sender: String?
    let subject: String?
    let snippet: String?
    let message_id: String?
    let received_at: Double?
    let amount: Double?
    let currency: String?
    let merchant_raw: String?
    let merchant: String?
    let direction: String?
    let card_last4: String?
    let available_balance: Double?
    let reference: String?
    let suggested_category: String?
    let confidence: Double?

    func toPending() -> PendingEmailTransaction {
        let received = received_at.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
        let dir: ParsedDirection = (direction == "credit") ? .credit : .debit
        let category = TransactionCategory(rawValue: suggested_category ?? "Other") ?? .other
        let name = (merchant?.isEmpty == false ? merchant : merchant_raw) ?? "Transaction"
        return PendingEmailTransaction(
            id: UUID(),
            accountId: nil,
            bankName: bank_name ?? "Bank",
            senderAddress: sender ?? "",
            emailSubject: subject ?? "",
            emailSnippet: snippet ?? "",
            receivedAt: received,
            messageId: message_id ?? id,
            amount: amount ?? 0,
            currency: currency ?? "AED",
            merchantRaw: merchant_raw ?? name,
            merchantNormalized: name,
            transactionDate: received,
            cardLast4: card_last4,
            direction: dir,
            availableBalance: available_balance,
            referenceNumber: reference,
            suggestedCategory: category,
            confidence: confidence ?? 0.6,
            suggestedTags: [],
            parseExplanation: "Detected by cloud email sync",
            isSuspiciousParse: false,
            suspiciousReason: nil,
            fingerprint: id,
            isPossibleDuplicate: false,
            duplicateReason: nil
        )
    }
}
