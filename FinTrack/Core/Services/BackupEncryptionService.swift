import Foundation
import CryptoKit
import Security

// MARK: - BackupEncryptionService
//
// Mandatory, always-on encryption for the .fintrack backup file, applied
// uniformly by manual Export/Import, iCloud Backup, Google Drive Backup, and
// email backup. Every backup FinTrack writes is ciphertext — the plain JSON
// (full transaction history, balances, account numbers, card last-4 digits) is
// never persisted anywhere in readable form.
//
// The key is a random 256-bit value generated once on this device and stored
// only in this device's Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
// via KeychainStore). It is never derived from anything the user types, never
// transmitted, and never synced. Consequences by design:
//   • No other app can open a FinTrack backup — the key lives in FinTrack's
//     own Keychain scope, and the file is useless without it.
//   • A backup can only be restored by the same FinTrack install that created
//     it. Moving the file to another device / app, or reinstalling, cannot
//     read it. This is the price of "readable by nothing but this app."
//
// There is intentionally no user setting for any of this — encryption cannot be
// turned off, and the key cannot be viewed or changed.
enum BackupEncryptionError: LocalizedError {
    case cannotOpen

    var errorDescription: String? {
        switch self {
        case .cannotOpen:
            return "Couldn't open this backup. FinTrack backups are encrypted and can only be restored by the FinTrack app on the device that created them."
        }
    }
}

// Pure computation (Keychain + crypto), no UI — explicitly opted out of this
// project's default MainActor isolation so the Task.detached blocks below
// (which keep the PBKDF2 pass off the main thread) can access these members
// without needing to hop back onto the main actor.
nonisolated enum BackupEncryptionService {
    // 5-byte header identifying an encrypted FinTrack backup, so imports can
    // tell an encrypted file from a plain legacy export without guessing.
    private static let magic = Data("FTBK1".utf8)
    private static let saltSize = 16
    private static let pbkdf2Iterations: UInt32 = 100_000

    private static let keyKeychainKey = "ft_backup_encryption_key"
    private static let keyLock = NSLock()

    /// The device-local random key every backup is encrypted with. Generated
    /// lazily on first use and stored only in this device's Keychain. The lock
    /// serializes first-run provisioning so two backups triggered at once (e.g.
    /// iCloud + email auto-backup on launch) can't each mint a different key
    /// and race on save.
    private static var encryptionKey: String {
        keyLock.lock()
        defer { keyLock.unlock() }
        if let existing: String = KeychainStore.load(key: keyKeychainKey) {
            return existing
        }
        let fresh = randomKeyString()
        try? KeychainStore.save(fresh, key: keyKeychainKey)
        return fresh
    }

    private static func randomKeyString() -> String {
        var bytes = Data(count: 32)
        let status = bytes.withUnsafeMutableBytes { ptr -> Int32 in
            guard let base = ptr.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, 32, base)
        }
        // SecRandomCopyBytes effectively never fails on-device; fall back to
        // CryptoKit's generator so we never hand back low-entropy key material.
        if status != errSecSuccess {
            return SymmetricKey(size: .bits256).withUnsafeBytes { Data($0).base64EncodedString() }
        }
        return bytes.base64EncodedString()
    }

    static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: magic)
    }

    /// Encrypts the data. Backup encryption is mandatory and always on — there
    /// is no "disabled" path. (Name kept for its existing call sites.)
    static func encryptIfEnabled(_ data: Data) async throws -> Data {
        try await encrypt(data, key: encryptionKey)
    }

    /// Decrypts an encrypted backup with this device's key. Plain (legacy,
    /// pre-encryption) files are still passed through so old exports remain
    /// importable.
    static func decryptIfNeeded(_ data: Data) async throws -> Data {
        guard isEncrypted(data) else { return data }
        return try await decrypt(data, key: encryptionKey)
    }

    /// The 100k-iteration PBKDF2 pass is CPU-bound; run it off the caller's
    /// actor (typically @MainActor) so backup/restore never hitches the UI.
    static func encrypt(_ data: Data, key passphrase: String) async throws -> Data {
        try await Task.detached(priority: .utility) {
            var salt = Data(count: saltSize)
            let status = salt.withUnsafeMutableBytes { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return errSecParam }
                return SecRandomCopyBytes(kSecRandomDefault, saltSize, base)
            }
            guard status == errSecSuccess else { throw BackupEncryptionError.cannotOpen }

            let key = deriveKey(passphrase: passphrase, salt: salt)
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { throw BackupEncryptionError.cannotOpen }
            return magic + salt + combined
        }.value
    }

    static func decrypt(_ data: Data, key passphrase: String) async throws -> Data {
        try await Task.detached(priority: .utility) {
            guard data.count > magic.count + saltSize, data.starts(with: magic) else {
                throw BackupEncryptionError.cannotOpen
            }
            let salt = data.subdata(in: magic.count..<(magic.count + saltSize))
            let combined = data.subdata(in: (magic.count + saltSize)..<data.count)
            let key = deriveKey(passphrase: passphrase, salt: salt)
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: combined)
                return try AES.GCM.open(sealedBox, using: key)
            } catch {
                throw BackupEncryptionError.cannotOpen
            }
        }.value
    }

    // MARK: - PBKDF2-HMAC-SHA256 key derivation
    //
    // CryptoKit has no built-in password-based KDF, so this implements
    // PBKDF2 (RFC 2898) directly on top of CryptoKit's HMAC<SHA256> — no
    // CommonCrypto bridging needed.
    private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(passphrase.utf8))
        var derived = Data()
        var blockIndex: UInt32 = 1
        while derived.count < 32 {
            var block = salt
            block.append(contentsOf: withUnsafeBytes(of: blockIndex.bigEndian) { Array($0) })

            var u = Data(HMAC<SHA256>.authenticationCode(for: block, using: passwordKey))
            var result = u
            if pbkdf2Iterations > 1 {
                for _ in 1..<pbkdf2Iterations {
                    u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                    for i in 0..<result.count { result[i] ^= u[i] }
                }
            }
            derived.append(result)
            blockIndex += 1
        }
        return SymmetricKey(data: derived.prefix(32))
    }
}
