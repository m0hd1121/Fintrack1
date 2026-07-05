import Foundation
import Network
import os

// MARK: - SMTPClient
// Minimal SMTP client over implicit TLS (port 465) built on Network.framework
// — the sending counterpart to IMAPClient. Just enough protocol to
// authenticate and send one MIME message with an attachment: EHLO, AUTH
// LOGIN, MAIL FROM/RCPT TO/DATA, QUIT. Credentials go straight to the mail
// server over TLS and are never logged or sent anywhere else.
//
// Scope note: implicit TLS only, matching IMAPClient's own scope in this
// codebase. This covers Gmail, Yahoo, and most third-party SMTPS configs on
// port 465. Providers that require a STARTTLS upgrade on port 587 instead
// (some enterprise mail servers) aren't supported here.

enum SMTPError: LocalizedError {
    case connectionFailed(String)
    case connectionClosed
    case commandFailed(String)
    case authFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return "Could not reach mail server: \(message)"
        case .connectionClosed: return "The mail server closed the connection."
        case .commandFailed(let line): return "Mail server error: \(line)"
        case .authFailed(let reason): return "Sign-in failed: \(reason)"
        case .timeout: return "The mail server took too long to respond."
        }
    }
}

final class SMTPClient: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.fintrack.smtp")
    private static let commandTimeout: Double = 30

    init(host: String, port: UInt16 = 465) {
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 15
        let params = NWParameters(tls: NWProtocolTLS.Options(), tcp: tcp)
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 465,
            using: params
        )
    }

    // MARK: - Lifecycle

    func connect() async throws {
        try await withTimeout {
            try await self.waitForReady()
            _ = try await self.readResponse()   // server greeting "220 ..."
        }
    }

    private func waitForReady() async throws {
        let resumed = OSAllocatedUnfairLock(initialState: false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                let isFinal: Bool
                switch state {
                case .ready, .failed, .cancelled: isFinal = true
                default: isFinal = false
                }
                guard isFinal else { return }
                let shouldResume = resumed.withLock { done -> Bool in
                    if done { return false }
                    done = true
                    return true
                }
                guard shouldResume else { return }
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: SMTPError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: SMTPError.connectionClosed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func close() {
        connection.cancel()
    }

    // MARK: - Commands

    func ehlo(domain: String = "fintrack.local") async throws {
        _ = try await command("EHLO \(domain)")
    }

    func authLogin(user: String, password: String) async throws {
        do {
            _ = try await command("AUTH LOGIN")
            _ = try await command(Data(user.utf8).base64EncodedString())
            _ = try await command(Data(password.utf8).base64EncodedString())
        } catch SMTPError.commandFailed(let line) {
            throw SMTPError.authFailed(line)
        }
    }

    /// Sends a single MIME message with one binary attachment to `to` (the
    /// same address the user signed in with, i.e. emailing yourself a copy).
    func sendMessage(from: String, to: String, subject: String, textBody: String,
                     attachment: Data, attachmentFilename: String) async throws {
        _ = try await command("MAIL FROM:<\(from)>")
        _ = try await command("RCPT TO:<\(to)>")
        _ = try await command("DATA")

        let boundary = "FinTrackBackup-\(UUID().uuidString)"
        let dateString = Self.rfc822Date(Date())
        let base64Body = attachment.base64EncodedString()
        let wrapped = Self.wrapBase64(base64Body)

        var message = ""
        message += "Date: \(dateString)\r\n"
        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "MIME-Version: 1.0\r\n"
        message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
        message += "\r\n"
        message += "--\(boundary)\r\n"
        message += "Content-Type: text/plain; charset=UTF-8\r\n\r\n"
        message += textBody + "\r\n"
        message += "--\(boundary)\r\n"
        message += "Content-Type: application/octet-stream; name=\"\(attachmentFilename)\"\r\n"
        message += "Content-Transfer-Encoding: base64\r\n"
        message += "Content-Disposition: attachment; filename=\"\(attachmentFilename)\"\r\n\r\n"
        message += wrapped + "\r\n"
        message += "--\(boundary)--\r\n"

        // Dot-stuff: any line beginning with "." must be escaped as ".." per
        // RFC 5321, since a lone "." on its own line ends the DATA command.
        let stuffed = message
            .components(separatedBy: "\r\n")
            .map { $0.hasPrefix(".") ? "." + $0 : $0 }
            .joined(separator: "\r\n")

        try await sendRaw(stuffed + "\r\n.\r\n")
        _ = try await readResponse()
    }

    func quit() async throws {
        _ = try? await command("QUIT")
        close()
    }

    // MARK: - Protocol plumbing

    @discardableResult
    private func command(_ text: String) async throws -> String {
        try await sendRaw(text + "\r\n")
        return try await readResponse()
    }

    /// SMTP multi-line responses look like "250-first\r\n250-second\r\n250 last\r\n"
    /// (dash on every line but the last). Waits for a final line whose 4th
    /// character is a space, then checks the 3-digit code.
    private func readResponse() async throws -> String {
        try await withTimeout {
            var transcript = Data()
            while true {
                let chunk = try await self.receiveChunk()
                transcript.append(chunk)
                let text = Self.latin1(transcript)
                let lines = text.components(separatedBy: "\r\n").filter { !$0.isEmpty }
                guard let last = lines.last, last.count >= 4 else { continue }
                let codeEndIndex = last.index(last.startIndex, offsetBy: 3)
                guard last[codeEndIndex] == " " else { continue }   // still a "250-" continuation line
                let code = String(last.prefix(3))
                if code.hasPrefix("2") || code.hasPrefix("3") { return text }
                throw SMTPError.commandFailed(text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func sendRaw(_ text: String) async throws {
        let data = Data(text.utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: SMTPError.connectionFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func receiveChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: SMTPError.connectionFailed(error.localizedDescription))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: SMTPError.connectionClosed)
                } else {
                    continuation.resume(returning: Data())
                }
            }
        }
    }

    private func withTimeout<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.commandTimeout))
                self.connection.cancel()
                throw SMTPError.timeout
            }
            guard let result = try await group.next() else { throw SMTPError.timeout }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Helpers

    private static func latin1(_ data: Data) -> String {
        String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func rfc822Date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// MIME requires base64 attachment bodies wrapped at 76 characters per line.
    private static func wrapBase64(_ base64: String) -> String {
        var lines: [String] = []
        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: 76, limitedBy: base64.endIndex) ?? base64.endIndex
            lines.append(String(base64[index..<end]))
            index = end
        }
        return lines.joined(separator: "\r\n")
    }
}
