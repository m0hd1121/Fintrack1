import Foundation
import CryptoKit

/// Hashing and verification for the app PIN (`AppSettings.pinHash`).
///
/// Stored format: `v2$<salt hex>$<hash hex>`, where the hash is
/// HMAC-SHA256 iterated over a random per-PIN salt. Hashes written before this
/// format (a bare SHA-256 hex digest of the PIN) still verify, and are replaced
/// with the salted form the next time the PIN is set.
nonisolated enum PINService {
    private static let iterations = 20_000

    static func makeHash(for pin: String) -> String {
        var salt = [UInt8](repeating: 0, count: 16)
        for i in salt.indices { salt[i] = UInt8.random(in: 0...255) }
        let digest = derive(pin: pin, salt: Data(salt))
        return "v2$\(hex(Data(salt)))$\(hex(digest))"
    }

    static func verify(pin: String, against stored: String?) -> Bool {
        guard let stored, !stored.isEmpty else { return false }
        let parts = stored.split(separator: "$").map(String.init)
        if parts.count == 3, parts[0] == "v2", let salt = data(fromHex: parts[1]) {
            return constantTimeEquals(hex(derive(pin: pin, salt: salt)), parts[2])
        }
        // Legacy: unsalted SHA-256 hex.
        let legacy = SHA256.hash(data: Data(pin.utf8)).map { String(format: "%02x", $0) }.joined()
        return constantTimeEquals(legacy, stored)
    }

    private static func derive(pin: String, salt: Data) -> Data {
        let key = SymmetricKey(data: Data(pin.utf8))
        var block = Data(HMAC<SHA256>.authenticationCode(for: salt, using: key))
        var result = block
        for _ in 1..<iterations {
            block = Data(HMAC<SHA256>.authenticationCode(for: block, using: key))
            for i in result.indices { result[i] ^= block[i] }
        }
        return result
    }

    private static func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func data(fromHex hex: String) -> Data? {
        guard hex.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }

    private static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
    }
}
