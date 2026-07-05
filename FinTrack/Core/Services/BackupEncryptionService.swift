import Foundation
import CryptoKit
import Security

// MARK: - BackupEncryptionService
//
// Optional passphrase-based encryption for the .fintrack backup file, used
// uniformly by manual Export/Import, iCloud Backup, and Google Drive Backup.
// Without this, the backup file is plain JSON containing full transaction
// history, balances, account numbers, and card last-4 digits — readable by
// anyone who gets hold of the file.
//
// The passphrase is a shared secret only the user knows: it lives in this
// device's Keychain only, is never transmitted anywhere, and is NOT
// automatically available on other devices — you must set the same
// passphrase on every device that needs to restore an encrypted backup.
// Forgetting it means the backup cannot be recovered; that's the same
// tradeoff as any end-to-end-encrypted backup (WhatsApp, iTunes encrypted
// backups, etc.) — there is no "reset password" for data nobody but you can
// read.
enum BackupEncryptionError: LocalizedError {
    case passphraseRequired
    case wrongPassphraseOrCorruptFile

    var errorDescription: String? {
        switch self {
        case .passphraseRequired:
            return "This backup is encrypted. Set the same Backup Passphrase on this device (Settings → Data & Privacy → Backup Encryption), then try again."
        case .wrongPassphraseOrCorruptFile:
            return "Couldn't decrypt this backup — the Backup Passphrase on this device doesn't match the one used to create it, or the file is corrupted."
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

    private static let passphraseKeychainKey = "ft_backup_encryption_passphrase"

    static var storedPassphrase: String? {
        get { KeychainStore.load(key: passphraseKeychainKey) }
        set {
            if let newValue, !newValue.isEmpty {
                try? KeychainStore.save(newValue, key: passphraseKeychainKey)
            } else {
                KeychainStore.delete(key: passphraseKeychainKey)
            }
        }
    }

    static var isEnabled: Bool { storedPassphrase != nil }

    static func isEncrypted(_ data: Data) -> Bool {
        data.starts(with: magic)
    }

    /// Encrypts with the stored passphrase if one is set; otherwise returns
    /// the data unchanged (encryption is opt-in).
    static func encryptIfEnabled(_ data: Data) async throws -> Data {
        guard let passphrase = storedPassphrase else { return data }
        return try await encrypt(data, passphrase: passphrase)
    }

    /// Decrypts using the stored passphrase if the data looks encrypted;
    /// passes plain (legacy or never-encrypted) data through unchanged.
    static func decryptIfNeeded(_ data: Data) async throws -> Data {
        guard isEncrypted(data) else { return data }
        guard let passphrase = storedPassphrase else { throw BackupEncryptionError.passphraseRequired }
        return try await decrypt(data, passphrase: passphrase)
    }

    /// The 100k-iteration PBKDF2 pass is CPU-bound; run it off the caller's
    /// actor (typically @MainActor) so backup/restore never hitches the UI.
    static func encrypt(_ data: Data, passphrase: String) async throws -> Data {
        try await Task.detached(priority: .utility) {
            var salt = Data(count: saltSize)
            let status = salt.withUnsafeMutableBytes { ptr -> Int32 in
                guard let base = ptr.baseAddress else { return errSecParam }
                return SecRandomCopyBytes(kSecRandomDefault, saltSize, base)
            }
            guard status == errSecSuccess else { throw BackupEncryptionError.wrongPassphraseOrCorruptFile }

            let key = deriveKey(passphrase: passphrase, salt: salt)
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { throw BackupEncryptionError.wrongPassphraseOrCorruptFile }
            return magic + salt + combined
        }.value
    }

    static func decrypt(_ data: Data, passphrase: String) async throws -> Data {
        try await Task.detached(priority: .utility) {
            guard data.count > magic.count + saltSize, data.starts(with: magic) else {
                throw BackupEncryptionError.wrongPassphraseOrCorruptFile
            }
            let salt = data.subdata(in: magic.count..<(magic.count + saltSize))
            let combined = data.subdata(in: (magic.count + saltSize)..<data.count)
            let key = deriveKey(passphrase: passphrase, salt: salt)
            do {
                let sealedBox = try AES.GCM.SealedBox(combined: combined)
                return try AES.GCM.open(sealedBox, using: key)
            } catch {
                throw BackupEncryptionError.wrongPassphraseOrCorruptFile
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
