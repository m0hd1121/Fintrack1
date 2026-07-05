import Foundation
import SwiftData
import AuthenticationServices
import CryptoKit
import UIKit
import Observation

// MARK: - GoogleDriveBackupService
//
// Automatic backup to Google Drive — the free-tier alternative to iCloud
// Backup, which requires a paid Apple Developer Program membership that not
// every user has. Uses OAuth 2.0 + PKCE with the narrow "drive.file" scope
// (the app can only see files it created itself, never the rest of the
// user's Drive), reusing the same client-ID pattern as Gmail sync.
//
// All settings/state live in UserDefaults + Keychain — no SwiftData model
// changes, so this never triggers the app's wipe-and-recreate schema
// migration.
enum DriveBackupError: LocalizedError {
    case notConfigured
    case authCancelled
    case authFailed(String)
    case network(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Drive backup isn't configured yet. Add a Google OAuth client ID first."
        case .authCancelled:
            return "Sign-in was cancelled."
        case .authFailed(let message):
            return "Sign-in failed: \(message)"
        case .network(let message):
            return "Network error: \(message)"
        case .notConnected:
            return "Not connected to Google Drive."
        }
    }
}

@Observable
@MainActor
final class GoogleDriveBackupService: NSObject {
    static let shared = GoogleDriveBackupService()

    private let backupFileName = "FinTrack_Backup.fintrack"
    private let tokenKeychainKey = "ft_drive_oauth_token"
    private let connectedEmailKey = "drive_backup_connected_email"
    private let fileIdKey = "drive_backup_file_id"
    private let lastBackupKey = "drive_backup_last_date"
    private let enabledKey = "drive_backup_enabled"
    private let wifiOnlyKey = "drive_backup_wifi_only"

    var isBackingUp = false
    var isRestoring = false
    var isConnecting = false
    var lastError: String?

    private var authSession: ASWebAuthenticationSession?

    var connectedEmail: String? {
        get { UserDefaults.standard.string(forKey: connectedEmailKey) }
        set { UserDefaults.standard.set(newValue, forKey: connectedEmailKey) }
    }

    var isConnected: Bool { connectedEmail != nil }

    var backupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var wifiOnly: Bool {
        get { UserDefaults.standard.bool(forKey: wifiOnlyKey) }
        set { UserDefaults.standard.set(newValue, forKey: wifiOnlyKey) }
    }

    var lastBackupDate: Date? {
        get { UserDefaults.standard.object(forKey: lastBackupKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastBackupKey) }
    }

    private var storedFileId: String? {
        get { UserDefaults.standard.string(forKey: fileIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: fileIdKey) }
    }

    private override init() { super.init() }

    // MARK: - Configuration

    static func storedClientId() -> String? {
        if let saved = UserDefaults.standard.string(forKey: "google_drive_oauth_client_id")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty {
            return saved
        }
        // Falls back to the Gmail client ID — it's the same kind of Google
        // iOS OAuth client and can request the extra Drive scope without
        // re-registering, as long as the Drive API is enabled on that
        // Google Cloud project.
        return EmailSyncService.storedClientId(for: .gmail)
    }

    static func saveClientId(_ clientId: String) {
        UserDefaults.standard.set(
            clientId.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "google_drive_oauth_client_id")
    }

    var isConfigured: Bool { Self.storedClientId() != nil }

    private struct Config {
        let clientId: String
        let redirectURI: String
        let callbackScheme: String
    }

    private func config() -> Config? {
        guard let clientId = Self.storedClientId() else { return nil }
        let reversed = clientId.split(separator: ".").reversed().joined(separator: ".")
        return Config(clientId: clientId, redirectURI: "\(reversed):/oauth2redirect", callbackScheme: reversed)
    }

    // MARK: - Connect / Disconnect

    func connect() async throws {
        guard let cfg = config() else { throw DriveBackupError.notConfigured }
        isConnecting = true
        defer { isConnecting = false }

        let verifier = Self.randomVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: cfg.clientId),
            URLQueryItem(name: "redirect_uri", value: cfg.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email https://www.googleapis.com/auth/drive.file"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        let code = try await authorizationCode(authURL: components.url!, callbackScheme: cfg.callbackScheme)
        let token = try await exchangeToken(config: cfg, body: [
            "client_id": cfg.clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": cfg.redirectURI,
        ])
        try KeychainStore.save(token, key: tokenKeychainKey)

        connectedEmail = try await fetchEmail(accessToken: token.accessToken)
        // A previous account's file id shouldn't leak into a freshly
        // connected (possibly different) Google account.
        storedFileId = nil
    }

    func disconnect() {
        KeychainStore.delete(key: tokenKeychainKey)
        connectedEmail = nil
        storedFileId = nil
        lastBackupDate = nil
    }

    private func authorizationCode(authURL: URL, callbackScheme: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                if let error {
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    continuation.resume(throwing: cancelled ? DriveBackupError.authCancelled : DriveBackupError.authFailed(error.localizedDescription))
                    return
                }
                guard let url,
                      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = items.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: DriveBackupError.authFailed("No authorization code returned"))
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }
    }

    // MARK: - Backup / Restore

    @discardableResult
    func performBackup(context: ModelContext) async -> Bool {
        guard isConnected else { await set(error: DriveBackupError.notConnected.localizedDescription); return false }
        if wifiOnly {
            let network = NetworkMonitor.shared
            guard network.isConnected && network.connectionType == .wifi else {
                await set(error: "Backup skipped — Wi-Fi only mode is enabled and you are not on Wi-Fi.")
                return false
            }
        }

        isBackingUp = true
        lastError = nil
        defer { isBackingUp = false }

        do {
            let exportURL = try DataTransferService.shared.exportBackup(context: context)
            let data = try Data(contentsOf: exportURL)
            try? FileManager.default.removeItem(at: exportURL)

            let token = try await validAccessToken()
            let fileId = try await uploadOrUpdate(fileId: storedFileId, data: data, token: token)
            storedFileId = fileId
            lastBackupDate = Date()
            return true
        } catch {
            await set(error: error.localizedDescription)
            return false
        }
    }

    func restoreFromDrive(context: ModelContext, mode: DataTransferService.ImportMode = .merge) async -> String {
        guard isConnected else { return DriveBackupError.notConnected.localizedDescription }
        isRestoring = true
        lastError = nil
        defer { isRestoring = false }

        do {
            let token = try await validAccessToken()
            guard let fileId = try await locateBackupFile(token: token) ?? storedFileId else {
                return "No backup found in Google Drive."
            }
            storedFileId = fileId
            let data = try await downloadFile(fileId: fileId, token: token)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupFileName)
            try data.write(to: tempURL, options: .atomic)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let summary = try DataTransferService.shared.importBackup(from: tempURL, context: context, mode: mode)
            return summary.total > 0 ? "Restored \(summary.description) successfully." : "Backup imported — nothing new to add."
        } catch {
            let msg = "Restore failed: \(error.localizedDescription)"
            await set(error: msg)
            return msg
        }
    }

    /// Triggers a backup if auto-backup is due (24-hour interval) and enabled.
    /// Mirrors iCloudBackupService's scheduling so both can be wired into the
    /// same scene-phase change handler.
    func scheduleAutomaticBackupIfNeeded(context: ModelContext) {
        guard backupEnabled, isConnected else { return }
        let last = lastBackupDate ?? .distantPast
        guard Date().timeIntervalSince(last) >= 24 * 3600 else { return }
        Task { await performBackup(context: context) }
    }

    // MARK: - Drive REST

    private func locateBackupFile(token: String) async throws -> String? {
        let query = "name='\(backupFileName)' and trashed=false"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://www.googleapis.com/drive/v3/files?q=\(query)&fields=files(id,modifiedTime)&spaces=drive")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DriveBackupError.network("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) listing Drive files")
        }
        struct FileList: Decodable {
            struct FileRef: Decodable { let id: String; let modifiedTime: String? }
            let files: [FileRef]?
        }
        let list = try JSONDecoder().decode(FileList.self, from: data)
        // Most recently modified first, in case an older client left duplicates.
        return list.files?.sorted { ($0.modifiedTime ?? "") > ($1.modifiedTime ?? "") }.first?.id
    }

    private func downloadFile(fileId: String, token: String) async throws -> Data {
        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?alt=media")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DriveBackupError.network("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) downloading backup")
        }
        return data
    }

    /// Creates the backup file on first upload, otherwise overwrites the
    /// same Drive file in place — never accumulates duplicate backups.
    private func uploadOrUpdate(fileId: String?, data: Data, token: String) async throws -> String {
        let boundary = "FinTrackBackup-\(UUID().uuidString)"
        var metadata: [String: Any] = ["name": backupFileName]
        if fileId == nil { metadata["mimeType"] = "application/octet-stream" }
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataJSON)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--".data(using: .utf8)!)

        let urlString = fileId == nil
            ? "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"
            : "https://www.googleapis.com/upload/drive/v3/files/\(fileId!)?uploadType=multipart"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = fileId == nil ? "POST" : "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = String(data: respData, encoding: .utf8) ?? "HTTP error"
            throw DriveBackupError.network(String(message.prefix(200)))
        }
        struct FileResponse: Decodable { let id: String }
        return try JSONDecoder().decode(FileResponse.self, from: respData).id
    }

    private func fetchEmail(accessToken: String) async throws -> String {
        let url = URL(string: "https://www.googleapis.com/oauth2/v3/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            return "Google Drive account"
        }
        struct UserInfo: Decodable { let email: String? }
        return (try? JSONDecoder().decode(UserInfo.self, from: data))?.email ?? "Google Drive account"
    }

    // MARK: - Token plumbing

    private func validAccessToken() async throws -> String {
        guard var token: EmailSyncService.OAuthToken = KeychainStore.load(key: tokenKeychainKey) else {
            throw DriveBackupError.authFailed("No stored credentials — reconnect Google Drive")
        }
        if token.expiresAt > Date().addingTimeInterval(60) { return token.accessToken }
        guard let refresh = token.refreshToken, let cfg = config() else {
            throw DriveBackupError.authFailed("Session expired — reconnect Google Drive")
        }
        let refreshed = try await exchangeToken(config: cfg, body: [
            "client_id": cfg.clientId,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ])
        token.accessToken = refreshed.accessToken
        token.expiresAt = refreshed.expiresAt
        if let newRefresh = refreshed.refreshToken { token.refreshToken = newRefresh }
        try KeychainStore.save(token, key: tokenKeychainKey)
        return token.accessToken
    }

    private func exchangeToken(config: Config, body: [String: String]) async throws -> EmailSyncService.OAuthToken {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw DriveBackupError.authFailed(String(message.prefix(200)))
        }
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return EmailSyncService.OAuthToken(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: Date().addingTimeInterval(decoded.expires_in ?? 3600)
        )
    }

    @MainActor func clearError() { lastError = nil }

    private func set(error msg: String) async {
        await MainActor.run { lastError = msg }
    }

    // MARK: - PKCE helpers

    private static func randomVerifier() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }

    private static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleDriveBackupService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first {
                return window
            }
            if let scene = scenes.first {
                return UIWindow(windowScene: scene)
            }
            // OAuth is only ever launched from on-screen UI, so a window
            // scene always exists by the time this is called.
            preconditionFailure("OAuth presentation requested with no active window scene")
        }
    }
}
