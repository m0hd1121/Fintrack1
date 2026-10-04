import SwiftUI
import SwiftData
import LocalAuthentication

// #10 – Fixed Face ID / Touch ID authentication
struct LockScreenView: View {
    @Environment(AppState.self) private var appState
    @Query private var allSettings: [AppSettings]
    @State private var isAuthenticating = false
    @State private var failed = false
    @State private var errorMessage = ""
    @State private var enteredPIN = ""
    @State private var wrongAttempts = 0
    @State private var lockedUntil: Date? = nil

    private var settings: AppSettings? { allSettings.first }
    /// The app PIN is enforced here whenever one has been set. Biometrics stay
    /// available alongside it when that option is on.
    private var pinEnabled: Bool { settings?.usePIN == true && (settings?.pinHash?.isEmpty == false) }
    private var biometricsEnabled: Bool { settings?.useBiometrics != false || !pinEnabled }

    var body: some View {
        ZStack {
            FTColor.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.ftDisplay)
                        .imageScale(.large)
                        .foregroundColor(.white.opacity(0.9))

                    Text("FinTrack")
                        .font(.ftDisplay)
                        .foregroundColor(.white)

                    Text("Verify your identity to continue")
                        .font(.ftBody)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(spacing: 16) {
                    if pinEnabled { pinPad }

                    // Biometric button
                    if biometricsEnabled {
                    Button { authenticate() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: biometricIcon).font(.ftHeadline)
                            Text("Unlock with \(biometricName)").font(.ftBodySemibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .foregroundColor(FTColor.accentDeep)
                        .clipShape(RoundedRectangle(cornerRadius: FTRadius.md))
                        .padding(.horizontal, 32)
                    }
                    .disabled(isAuthenticating)
                    }

                    if failed {
                        VStack(spacing: 8) {
                            Label(errorMessage.isEmpty ? "Authentication failed." : errorMessage,
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.ftCaption).foregroundColor(.white.opacity(0.9))
                            if biometricsEnabled {
                                Button("Try Again") { authenticate() }
                                    .font(.ftCaption).foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            // Small delay lets the UI render before showing the prompt
            if biometricsEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { authenticate() }
            }
        }
    }

    // MARK: - PIN entry

    private var pinPad: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack(spacing: FTSpacing.md) {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(i < enteredPIN.count ? Color.white : Color.white.opacity(0.25))
                        .frame(width: 12, height: 12)
                }
            }
            let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],["","0","⌫"]]
            VStack(spacing: FTSpacing.sm) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: FTSpacing.xl) {
                        ForEach(row, id: \.self) { key in
                            if key.isEmpty {
                                Color.clear.frame(width: 64, height: 64)
                            } else {
                                Button { handlePINKey(key) } label: {
                                    Text(key)
                                        .font(.ftTitle)
                                        .foregroundColor(.white)
                                        .frame(width: 64, height: 64)
                                        .background(Color.white.opacity(key == "⌫" ? 0 : 0.15), in: Circle())
                                }
                                .accessibilityLabel(key == "⌫" ? "Delete" : key)
                                .disabled(isPINLockedOut)
                            }
                        }
                    }
                }
            }
            Button("Unlock") { checkPIN() }
                .font(.ftBodySemibold)
                .foregroundColor(.white)
                .disabled(enteredPIN.count < 4 || isPINLockedOut)
        }
    }

    private var isPINLockedOut: Bool {
        if let until = lockedUntil, until > Date() { return true }
        return false
    }

    private func handlePINKey(_ key: String) {
        if key == "⌫" {
            if !enteredPIN.isEmpty { enteredPIN.removeLast() }
            return
        }
        guard enteredPIN.count < 6 else { return }
        enteredPIN.append(key)
        if enteredPIN.count == 6 { checkPIN() }
    }

    private func checkPIN() {
        guard !isPINLockedOut else { return }
        if PINService.verify(pin: enteredPIN, against: settings?.pinHash) {
            wrongAttempts = 0
            enteredPIN = ""
            appState.unlock()
        } else {
            wrongAttempts += 1
            enteredPIN = ""
            failed = true
            if wrongAttempts >= 5 {
                // Back off after repeated failures to slow down guessing.
                lockedUntil = Date().addingTimeInterval(30)
                errorMessage = "Too many attempts. Try again in 30 seconds."
            } else {
                errorMessage = "Incorrect PIN."
            }
        }
    }

    private var biometricName: String { BiometricService.shared.biometricTypeName }
    private var biometricIcon: String { BiometricService.shared.biometricIcon }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        failed = false

        Task {
            let context = LAContext()
            var error: NSError?

            // Prefer biometrics, fall back to device passcode (#10)
            let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
                ? .deviceOwnerAuthenticationWithBiometrics
                : .deviceOwnerAuthentication

            do {
                let success = try await context.evaluatePolicy(
                    policy,
                    localizedReason: "Unlock FinTrack to access your finances"
                )
                await MainActor.run {
                    isAuthenticating = false
                    if success {
                        appState.unlock()
                    } else {
                        failed = true
                        errorMessage = "Authentication failed. Try again."
                    }
                }
            } catch let laError as LAError {
                await MainActor.run {
                    isAuthenticating = false
                    failed = true
                    switch laError.code {
                    case .userCancel:       errorMessage = "Cancelled. Tap to try again."
                    case .biometryNotAvailable: errorMessage = "Biometrics unavailable. Use passcode."
                    case .biometryNotEnrolled:  errorMessage = "No biometrics enrolled. Use passcode."
                    default:               errorMessage = laError.localizedDescription
                    }
                    // For .userCancel or passcode fall-back, try deviceOwner policy
                    // With an app PIN set, cancelling falls back to the PIN pad instead.
                    if !pinEnabled && (laError.code == .userCancel || laError.code == .biometryLockout) {
                        retryWithPasscode()
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    failed = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func retryWithPasscode() {
        isAuthenticating = true
        Task {
            let context = LAContext()
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: "Unlock FinTrack"
                )
                await MainActor.run {
                    isAuthenticating = false
                    if success { appState.unlock() }
                    else { failed = true; errorMessage = "Authentication failed." }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    failed = true
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
