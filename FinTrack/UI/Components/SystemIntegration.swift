import SwiftUI
import AppIntents

// iOS 27 system integrations, kept in one file so that any signature change in
// the iOS 27 SDK is a one-place fix.
//
// `appEntityIdentifier(_:)` / `EntityIdentifier(for:identifier:)` are taken
// from Apple's WWDC26 session "Build intelligent Siri experiences with App
// Schemas" (view annotations). They tell Siri and Apple Intelligence which
// app entity a view shows, so a request like "split this transaction" can
// refer to what's on screen. Requires a device and language with Apple
// Intelligence; it does nothing elsewhere.
//
// The `#if compiler` guard keeps the project building with Xcode 26 (Swift
// 6.2), where these symbols don't exist; `#available` alone can't hide a
// symbol the SDK doesn't declare.

extension View {
    /// Marks a row as showing the given transaction (iOS 27+).
    @ViewBuilder
    func annotatesTransaction(_ id: UUID) -> some View {
        #if compiler(>=6.3)
        if #available(iOS 27.0, *) {
            self.appEntityIdentifier(EntityIdentifier(for: TransactionEntity.self, identifier: id))
        } else {
            self
        }
        #else
        self
        #endif
    }
}
