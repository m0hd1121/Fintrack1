import SwiftUI
import LocalAuthentication

// #10 – Fixed Face ID / Touch ID authentication
struct LockScreenView: View {
    @Environment(AppState.self) private var appState
    @State private var isAuthenticating = false
    @State private var failed = false
    @State private var errorMessage = ""

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
                    // Biometric button
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

                    if failed {
                        VStack(spacing: 8) {
                            Label(errorMessage.isEmpty ? "Authentication failed." : errorMessage,
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.ftCaption).foregroundColor(.white.opacity(0.9))
                            Button("Try Again") { authenticate() }
                                .font(.ftCaption).foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            // Small delay lets the UI render before showing the prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { authenticate() }
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
                    if laError.code == .userCancel || laError.code == .biometryLockout {
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
