import Foundation
import Network
import os

// MARK: - IMAPClient
// Minimal IMAP4rev1 client over TLS (port 993) built on Network.framework —
// just enough protocol for the email import engine: LOGIN, SELECT, UID SEARCH,
// UID FETCH, LOGOUT. Credentials go straight to the mail server over TLS and
// are never logged or sent anywhere else.

enum IMAPError: LocalizedError {
    case connectionFailed(String)
    case connectionClosed
    case commandFailed(String)
    case loginFailed(String)
    case timeout
    case responseTooLarge

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message): return "Could not reach mail server: \(message)"
        case .connectionClosed: return "The mail server closed the connection."
        case .commandFailed(let line): return "Mail server error: \(line)"
        case .loginFailed(let reason): return "Sign-in failed: \(reason)"
        case .timeout: return "The mail server took too long to respond."
        case .responseTooLarge: return "Mail server response too large."
        }
    }
}

final class IMAPClient: @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.fintrack.imap")
    private var tagCounter = 0
    private static let commandTimeout: Double = 30

    init(host: String, port: UInt16 = 993) {
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 15
        let params = NWParameters(tls: NWProtocolTLS.Options(), tcp: tcp)
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 993,
            using: params
        )
    }

    // MARK: - Lifecycle

    func connect() async throws {
        try await withTimeout {
            try await self.waitForReady()
            _ = try await self.receiveChunk()   // server greeting "* OK ..."
        }
    }

    private func waitForReady() async throws {
        // The state handler can fire multiple times; the lock guarantees the
        // continuation resumes exactly once, without actor-isolation issues
        // inside the Sendable network callback.
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
                    continuation.resume(throwing: IMAPError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: IMAPError.connectionClosed)
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

    func login(user: String, password: String) async throws {
        do {
            _ = try await command("LOGIN \(Self.quote(user)) \(Self.quote(password))")
        } catch IMAPError.commandFailed(let line) {
            // Strip the leading "A2 NO " tag/status so the server's actual
            // reason surfaces verbatim — e.g. Gmail's own
            // "Application-specific password required" text, which is far
            // more useful than a generic guess.
            let reason = line.replacingOccurrences(
                of: "^[A-Za-z0-9]+\\s+(NO|BAD)\\s*", with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            throw IMAPError.loginFailed(reason.isEmpty ? "invalid credentials" : reason)
        }
    }

    func selectInbox() async throws {
        _ = try await command("SELECT INBOX")
    }

    /// e.g. uidSearch("SINCE 04-Jun-2026 HEADER FROM \"emiratesnbd.com\"")
    func uidSearch(_ query: String) async throws -> [Int] {
        let transcript = try await command("UID SEARCH \(query)")
        let text = Self.latin1(transcript)
        var uids: [Int] = []
        for line in text.components(separatedBy: "\r\n") where line.uppercased().hasPrefix("* SEARCH") {
            uids += line.dropFirst("* SEARCH".count)
                .components(separatedBy: " ")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        return uids
    }

    /// Fetches one full message (headers + body) and returns readable text.
    func fetchMessage(uid: Int) async throws -> (headers: String, body: String) {
        let transcript = try await command("UID FETCH \(uid) (BODY.PEEK[])")
        guard let raw = Self.extractFirstLiteral(from: transcript) else {
            throw IMAPError.commandFailed("No message data for UID \(uid)")
        }
        let message = Self.latin1(raw)
        if let separator = message.range(of: "\r\n\r\n") {
            let headers = String(message[..<separator.lowerBound])
            let body = String(message[separator.upperBound...])
            return (headers, MIMEDecoder.readableBody(headers: headers, rawBody: body))
        }
        return (message, "")
    }

    func logout() async throws {
        _ = try? await command("LOGOUT")
        close()
    }

    // MARK: - Protocol plumbing

    private func command(_ text: String) async throws -> Data {
        tagCounter += 1
        let tag = "A\(tagCounter)"
        try await sendRaw("\(tag) \(text)\r\n")

        var transcript = Data()
        while true {
            let chunk = try await withTimeout { try await self.receiveChunk() }
            transcript.append(chunk)
            guard transcript.count < 5_000_000 else { throw IMAPError.responseTooLarge }

            // Completion: a line starting with "<tag> OK/NO/BAD"
            let text = Self.latin1(transcript)
            for line in text.components(separatedBy: "\r\n").reversed() {
                if line.hasPrefix("\(tag) OK") { return transcript }
                if line.hasPrefix("\(tag) NO") || line.hasPrefix("\(tag) BAD") {
                    throw IMAPError.commandFailed(line)
                }
            }
        }
    }

    private func sendRaw(_ text: String) async throws {
        let data = Data(text.utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: IMAPError.connectionFailed(error.localizedDescription))
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
                    continuation.resume(throwing: IMAPError.connectionFailed(error.localizedDescription))
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(throwing: IMAPError.connectionClosed)
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
                // Cancel the socket so any pending receive/send continuation
                // fires with an error — otherwise the group would wait forever.
                self.connection.cancel()
                throw IMAPError.timeout
            }
            guard let result = try await group.next() else { throw IMAPError.timeout }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Helpers

    /// Latin-1 decodes 1 byte → 1 char, so string indices stay byte-accurate
    /// even on partial UTF-8 sequences — ideal for protocol parsing.
    private static func latin1(_ data: Data) -> String {
        String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func quote(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Extracts the first IMAP literal: `{<n>}\r\n` followed by exactly n bytes.
    static func extractFirstLiteral(from data: Data) -> Data? {
        let text = latin1(data)
        guard let braceRange = text.range(of: "\\{[0-9]+\\}\r\n", options: .regularExpression),
              let size = Int(text[braceRange].dropFirst().prefix(while: { $0.isNumber })) else {
            return nil
        }
        let startOffset = text.distance(from: text.startIndex, to: braceRange.upperBound)
        guard startOffset + size <= data.count else { return nil }
        return data.subdata(in: startOffset..<(startOffset + size))
    }
}

// MARK: - MIMEDecoder
// Best-effort decoding of bank notification emails: multipart splitting,
// quoted-printable and base64 transfer encodings, RFC 2047 subjects.

enum MIMEDecoder {

    /// Returns the most readable body text: prefers text/plain, falls back to
    /// text/html (the parser strips tags later), decodes transfer encodings.
    static func readableBody(headers: String, rawBody: String) -> String {
        if let boundary = boundary(in: headers) ?? boundary(in: String(rawBody.prefix(2000))) {
            let parts = rawBody.components(separatedBy: "--" + boundary)
            var htmlFallback: String?
            for part in parts {
                guard let separator = part.range(of: "\r\n\r\n") ?? part.range(of: "\n\n") else { continue }
                let partHeaders = String(part[..<separator.lowerBound]).lowercased()
                let partBody = String(part[separator.upperBound...])
                let decoded = decodeTransferEncoding(partBody, headers: partHeaders)
                if partHeaders.contains("text/plain") { return decoded }
                if partHeaders.contains("text/html"), htmlFallback == nil { htmlFallback = decoded }
            }
            if let htmlFallback { return htmlFallback }
        }
        return decodeTransferEncoding(rawBody, headers: headers.lowercased())
    }

    private static func boundary(in text: String) -> String? {
        guard let range = text.range(of: "boundary=\"?([^\";\r\n]+)\"?",
                                     options: [.regularExpression, .caseInsensitive]) else { return nil }
        var value = String(text[range]).dropFirst("boundary=".count)
        if value.hasPrefix("\"") { value = value.dropFirst() }
        if value.hasSuffix("\"") { value = value.dropLast() }
        return String(value)
    }

    private static func decodeTransferEncoding(_ body: String, headers: String) -> String {
        if headers.contains("base64") {
            let compact = body.components(separatedBy: .whitespacesAndNewlines).joined()
            if let data = Data(base64Encoded: compact),
               let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                return text
            }
        }
        if headers.contains("quoted-printable") {
            return decodeQuotedPrintable(body)
        }
        return body
    }

    static func decodeQuotedPrintable(_ text: String) -> String {
        let result = text
            .replacingOccurrences(of: "=\r\n", with: "")
            .replacingOccurrences(of: "=\n", with: "")
        var output = ""
        output.reserveCapacity(result.count)
        var bytes: [UInt8] = []
        var index = result.startIndex
        func flushBytes() {
            guard !bytes.isEmpty else { return }
            output += String(decoding: bytes, as: UTF8.self)
            bytes.removeAll()
        }
        while index < result.endIndex {
            let char = result[index]
            if char == "=",
               let second = result.index(index, offsetBy: 2, limitedBy: result.endIndex),
               let byte = UInt8(result[result.index(after: index)..<second], radix: 16) {
                bytes.append(byte)
                index = second
            } else {
                flushBytes()
                output.append(char)
                index = result.index(after: index)
            }
        }
        flushBytes()
        return output
    }

    /// Decodes RFC 2047 encoded words: =?UTF-8?B?...?= and =?UTF-8?Q?...?=
    static func decodeEncodedWords(_ text: String) -> String {
        var output = text
        while let range = output.range(of: "=\\?[^?]+\\?[BbQq]\\?[^?]*\\?=", options: .regularExpression) {
            let token = String(output[range])
            let pieces = token.components(separatedBy: "?")
            guard pieces.count >= 5 else { break }
            let encoding = pieces[2].uppercased()
            let payload = pieces[3]
            var decoded = token
            if encoding == "B", let data = Data(base64Encoded: payload),
               let text = String(data: data, encoding: .utf8) {
                decoded = text
            } else if encoding == "Q" {
                decoded = decodeQuotedPrintable(payload.replacingOccurrences(of: "_", with: " "))
            }
            output.replaceSubrange(range, with: decoded)
        }
        return output
    }

    /// Pulls a single header value ("From", "Subject", "Date") out of a raw
    /// header block, unfolding continuation lines.
    static func headerValue(_ name: String, in headers: String) -> String? {
        let unfolded = headers
            .replacingOccurrences(of: "\r\n ", with: " ")
            .replacingOccurrences(of: "\r\n\t", with: " ")
        for line in unfolded.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix(name.lowercased() + ":") {
                return decodeEncodedWords(
                    String(line.dropFirst(name.count + 1)).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
}
