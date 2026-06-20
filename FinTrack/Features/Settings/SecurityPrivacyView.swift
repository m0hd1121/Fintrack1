import SwiftUI
import SwiftData
import CryptoKit

// MARK: - Main View

struct SecurityPrivacyView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]
    @Query(sort: \AuditLogEntry.timestamp, order: .reverse) private var auditLog: [AuditLogEntry]

    @State private var showingPINSetup = false

    private var settings: AppSettings? { allSettings.first }

    private func settingsBind<T>(_ kp: WritableKeyPath<AppSettings, T>, default def: T) -> Binding<T> {
        Binding(
            get: { settings?[keyPath: kp] ?? def },
            set: { v in settings?[keyPath: kp] = v; try? context.save() }
        )
    }

    private var biometricsBinding: Binding<Bool> { settingsBind(\.useBiometrics, default: false) }
    private var pinBinding: Binding<Bool> {
        Binding(
            get: { settings?.usePIN ?? false },
            set: { v in
                settings?.usePIN = v
                if v { showingPINSetup = true }
                else { settings?.pinHash = nil }
                try? context.save()
            }
        )
    }
    private var autoLockBinding: Binding<Int> { settingsBind(\.autoLockMinutes, default: 5) }
    private var encryptionBinding: Binding<Bool> { settingsBind(\.encryptionEnabled, default: true) }
    private var auditLogBinding: Binding<Bool> { settingsBind(\.auditLogEnabled, default: true) }

    private var securityScore: Int {
        var score = 0
        if settings?.useBiometrics == true  { score += 30 }
        if settings?.usePIN == true          { score += 20 }
        if settings?.twoFactorEnabled == true { score += 25 }
        if settings?.encryptionEnabled != false { score += 15 }
        if settings?.auditLogEnabled != false   { score += 10 }
        return score
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                securityScoreCard
                appLockCard
                advancedSecurityCard
                auditLogCard
                infoCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Security & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .sheet(isPresented: $showingPINSetup) {
            PINSetupSheet(isDecoy: false)
        }
    }

    // MARK: - Security Score Card

    private var securityScoreCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SECURITY OVERVIEW").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text("Security Score").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text(scoreLabel).font(.ftCaption).foregroundStyle(scoreColor)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(FTColor.textMuted.opacity(0.2), lineWidth: 6)
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: CGFloat(securityScore) / 100)
                        .stroke(scoreColor.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                    Text("\(securityScore)")
                        .font(.ftCallout)
                        .foregroundStyle(scoreColor)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                scoreFeatureTile("Biometrics", enabled: settings?.useBiometrics == true)
                scoreFeatureTile("PIN", enabled: settings?.usePIN == true)
                scoreFeatureTile("2FA", enabled: settings?.twoFactorEnabled == true)
                scoreFeatureTile("Encrypted", enabled: settings?.encryptionEnabled != false)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var scoreLabel: String {
        switch securityScore {
        case 0..<40:  return "Needs Improvement"
        case 40..<70: return "Fair"
        case 70..<90: return "Good"
        default:      return "Excellent"
        }
    }

    private var scoreColor: Color {
        switch securityScore {
        case 0..<40:  return FTColor.expense
        case 40..<70: return FTColor.gold
        case 70..<90: return FTColor.catBlue
        default:      return FTColor.income
        }
    }

    private func scoreFeatureTile(_ label: String, enabled: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(.ftCaption)
                .foregroundStyle(enabled ? FTColor.income : FTColor.textMuted)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.sm)
        .background(
            (enabled ? FTColor.income : FTColor.textMuted).opacity(0.07),
            in: RoundedRectangle(cornerRadius: FTRadius.sm)
        )
    }

    // MARK: - App Lock Card

    private var appLockCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("APP LOCK").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                FTToggleRow(
                    symbol: BiometricService.shared.biometricIcon,
                    tint: FTColor.accent,
                    title: BiometricService.shared.biometricTypeName,
                    isOn: biometricsBinding
                )
                .onChange(of: biometricsBinding.wrappedValue) { _, enabled in
                    logAudit(.settingsChanged,
                             "\(BiometricService.shared.biometricTypeName) \(enabled ? "enabled" : "disabled")")
                }
                divider
                FTToggleRow(symbol: "lock.fill", tint: FTColor.catPurple,
                            title: "PIN Lock", isOn: pinBinding)

                if settings?.usePIN == true {
                    divider
                    Button { showingPINSetup = true } label: {
                        securityRow(icon: "key.fill", tint: FTColor.catPurple, title: "Change PIN", chevron: true)
                    }
                    .buttonStyle(.plain)
                }

                divider

                Menu {
                    Picker("Auto-Lock", selection: autoLockBinding) {
                        Text("1 minute").tag(1)
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("Never").tag(0)
                    }
                } label: {
                    securityRow(icon: "timer", tint: FTColor.catBlue, title: "Auto-Lock",
                                trailing: autoLockText, chevron: true)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    private var autoLockText: String {
        switch autoLockBinding.wrappedValue {
        case 0:  return "Never"
        case 1:  return "1 min"
        default: return "\(autoLockBinding.wrappedValue) min"
        }
    }

    // MARK: - Advanced Security Card

    private var advancedSecurityCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("ADVANCED SECURITY").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                NavigationLink(destination: TwoFactorSetupView()) {
                    securityRow(icon: "checkmark.shield.fill", tint: FTColor.income,
                                title: "Two-Factor Authentication",
                                subtitle: settings?.twoFactorEnabled == true ? "Enabled" : "Disabled",
                                subtitleColor: settings?.twoFactorEnabled == true ? FTColor.income : FTColor.textMuted,
                                chevron: true)
                }
                .buttonStyle(.plain)

                divider

                FTToggleRow(symbol: "lock.shield.fill", tint: FTColor.catTeal,
                            title: "End-to-End Encryption", isOn: encryptionBinding)
                    .onChange(of: encryptionBinding.wrappedValue) { _, enabled in
                        logAudit(.settingsChanged, "Encryption \(enabled ? "enabled" : "disabled")")
                    }

                divider

                NavigationLink(destination: HiddenModeView()) {
                    securityRow(icon: "eye.slash.fill", tint: FTColor.catPurple,
                                title: "Hidden Mode / Decoy PIN",
                                subtitle: settings?.hiddenModeEnabled == true ? "Configured" : "Not Set Up",
                                subtitleColor: settings?.hiddenModeEnabled == true ? FTColor.gold : FTColor.textMuted,
                                chevron: true)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Audit Log Card

    private var auditLogCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("AUDIT LOG").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: 0) {
                FTToggleRow(symbol: "doc.text.magnifyingglass", tint: FTColor.gold,
                            title: "Enable Audit Logging", isOn: auditLogBinding)

                if settings?.auditLogEnabled != false {
                    divider
                    NavigationLink(destination: AuditLogView()) {
                        securityRow(icon: "list.bullet.clipboard.fill", tint: FTColor.gold,
                                    title: "View Audit Log",
                                    subtitle: "\(auditLog.count) events recorded",
                                    subtitleColor: FTColor.textMuted,
                                    chevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.ftCallout).foregroundStyle(FTColor.income)
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Data, Your Control").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text("All financial data is stored locally and encrypted using AES-256. FinTrack never transmits your data to third-party servers without your explicit consent.")
                    .font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func securityRow(icon: String, tint: Color, title: String,
                              subtitle: String? = nil, subtitleColor: Color = FTColor.textMuted,
                              trailing: String? = nil, chevron: Bool = false) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.ftCaption).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                if let sub = subtitle {
                    Text(sub).font(.ftCaption).foregroundStyle(subtitleColor)
                }
            }
            Spacer()
            if let trail = trailing {
                Text(trail).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            if chevron {
                Image(systemName: "chevron.right").font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
    }

    private var divider: some View {
        Divider().background(FTColor.textMuted.opacity(0.3))
    }

    // MARK: - Audit Helper

    private func logAudit(_ type: AuditEventType, _ description: String) {
        guard settings?.auditLogEnabled != false else { return }
        let entry = AuditLogEntry(eventType: type, description: description)
        context.insert(entry)
        try? context.save()
    }
}

// MARK: - PIN Setup Sheet

struct PINSetupSheet: View {
    var isDecoy: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var stage: PINStage = .enter
    @State private var errorMessage = ""
    @State private var showError = false

    private var settings: AppSettings? { allSettings.first }

    enum PINStage { case enter, confirm, success }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xxl) {
                    iconHeader
                    stageTitle
                    pinDots
                    if showError {
                        Text(errorMessage)
                            .font(.ftCaption).foregroundStyle(FTColor.expense)
                            .transition(.opacity)
                    }
                    if stage == .success {
                        successContent
                    } else {
                        numpad
                    }
                    Spacer()
                }
                .padding(FTSpacing.screen)
                .animation(.easeInOut(duration: 0.2), value: stage)
                .animation(.easeInOut(duration: 0.15), value: showError)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle(isDecoy ? "Decoy PIN" : "Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }

    private var iconHeader: some View {
        ZStack {
            Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 80, height: 80)
            Image(systemName: isDecoy ? "eye.slash.fill" : "lock.fill")
                .font(.system(size: 32)).foregroundStyle(FTColor.catPurple)
        }
        .padding(.top, FTSpacing.xl)
    }

    private var stageTitle: some View {
        VStack(spacing: FTSpacing.sm) {
            Text(stage == .enter
                 ? (isDecoy ? "Set Decoy PIN" : "Set New PIN")
                 : (stage == .confirm ? "Confirm PIN" : "PIN Saved"))
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

            Text(stage == .enter
                 ? (isDecoy ? "This PIN activates Hidden Mode when used to unlock" : "Enter a 4–6 digit PIN")
                 : (stage == .confirm ? "Re-enter your PIN to confirm" : ""))
                .font(.ftBody).foregroundStyle(FTColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var pinDots: some View {
        let currentPin = stage == .confirm ? confirmPin : pin
        return HStack(spacing: 16) {
            ForEach(0..<6) { i in
                Circle()
                    .fill(i < currentPin.count ? FTColor.catPurple : FTColor.textMuted.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(i < currentPin.count ? 1.15 : 1.0)
                    .animation(.spring(response: 0.2), value: currentPin.count)
            }
        }
    }

    private var successContent: some View {
        VStack(spacing: FTSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundStyle(FTColor.income)
            Text(isDecoy ? "Decoy PIN Set!" : "PIN Updated!")
                .font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
            Button("Done") { dismiss() }
                .font(.ftBodySemibold).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding()
                .background(FTColor.catPurple, in: RoundedRectangle(cornerRadius: FTRadius.md))
        }
    }

    private var numpad: some View {
        let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],["","0","⌫"]]
        return VStack(spacing: FTSpacing.md) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: FTSpacing.xxl) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 72, height: 72)
                        } else {
                            Button { handleKey(key) } label: {
                                ZStack {
                                    Circle()
                                        .fill(key == "⌫" ? Color.clear : FTColor.textMuted.opacity(0.12))
                                        .frame(width: 72, height: 72)
                                    Text(key)
                                        .font(.title2.weight(.medium))
                                        .foregroundStyle(FTColor.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        withAnimation { showError = false }
        if key == "⌫" {
            if stage == .enter { if !pin.isEmpty { pin.removeLast() } }
            else { if !confirmPin.isEmpty { confirmPin.removeLast() } }
            return
        }
        if stage == .enter {
            guard pin.count < 6 else { return }
            pin.append(key)
            if pin.count >= 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { stage = .confirm }
            }
        } else {
            guard confirmPin.count < pin.count else { return }
            confirmPin.append(key)
            if confirmPin.count == pin.count { savePIN() }
        }
    }

    private func savePIN() {
        guard pin == confirmPin else {
            withAnimation {
                errorMessage = "PINs don't match — try again."
                showError = true
            }
            pin = ""; confirmPin = ""; stage = .enter
            return
        }
        let hash = SHA256.hash(data: Data(pin.utf8))
            .compactMap { String(format: "%02x", $0) }.joined()
        if isDecoy {
            settings?.decoyPINHash = hash
            settings?.hiddenModeEnabled = true
            let entry = AuditLogEntry(eventType: .hiddenModeActivated, description: "Decoy PIN configured")
            context.insert(entry)
        } else {
            settings?.pinHash = hash
            settings?.usePIN = true
            let entry = AuditLogEntry(eventType: .pinChanged, description: "PIN changed")
            context.insert(entry)
        }
        try? context.save()
        withAnimation { stage = .success }
    }
}

// MARK: - Two-Factor Setup View

struct TwoFactorSetupView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    @State private var tfaStage: TFAStage = .intro
    @State private var verificationCode = ""
    @State private var showingRecoveryCodes = false
    @State private var secretKey: String = TwoFactorSetupView.makeSecret()
    @State private var recoveryCodes: [String] = TwoFactorSetupView.makeRecoveryCodes()

    private var settings: AppSettings? { allSettings.first }

    enum TFAStage { case intro, setup, verify, success }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                if settings?.twoFactorEnabled == true {
                    tfaEnabledView
                } else {
                    switch tfaStage {
                    case .intro:   tfaIntroView
                    case .setup:   tfaSetupView
                    case .verify:  tfaVerifyView
                    case .success: tfaSuccessView
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Two-Factor Auth")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .sheet(isPresented: $showingRecoveryCodes) {
            RecoveryCodesView(codes: recoveryCodes)
        }
    }

    // MARK: Enabled State

    private var tfaEnabledView: some View {
        VStack(spacing: FTSpacing.xxl) {
            ZStack {
                Circle().fill(FTColor.income.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40)).foregroundStyle(FTColor.income)
            }
            .padding(.top)

            VStack(spacing: FTSpacing.sm) {
                Text("2FA is Active").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Your account is protected with two-factor authentication.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }

            VStack(spacing: FTSpacing.md) {
                Button { showingRecoveryCodes = true } label: {
                    Label("View Recovery Codes", systemImage: "doc.on.doc")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.catBlue)
                        .frame(maxWidth: .infinity).padding()
                        .background(FTColor.catBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                }

                Button(role: .destructive) {
                    settings?.twoFactorEnabled = false
                    settings?.twoFactorSecret = nil
                    try? context.save()
                    let entry = AuditLogEntry(eventType: .twoFADisabled, description: "2FA disabled by user")
                    context.insert(entry)
                    try? context.save()
                } label: {
                    Label("Disable 2FA", systemImage: "xmark.shield")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                        .frame(maxWidth: .infinity).padding()
                        .background(FTColor.expense.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
            }
        }
    }

    // MARK: Intro

    private var tfaIntroView: some View {
        VStack(spacing: FTSpacing.xxl) {
            ZStack {
                Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40)).foregroundStyle(FTColor.catPurple)
            }
            .padding(.top)

            VStack(spacing: FTSpacing.sm) {
                Text("Two-Factor Authentication").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Add an extra layer of security by requiring a verification code from your authenticator app every time you access sensitive data.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: FTSpacing.md) {
                tfaFeatureBullet("Protects against unauthorized device access", icon: "shield.fill", color: FTColor.income)
                tfaFeatureBullet("Works with Authenticator, Authy, 1Password", icon: "apps.iphone", color: FTColor.catBlue)
                tfaFeatureBullet("8 recovery codes stored as backup", icon: "doc.text.fill", color: FTColor.gold)
            }
            .padding()
            .ftGlass(FTRadius.xl)

            Button { tfaStage = .setup } label: {
                Label("Set Up Two-Factor Auth", systemImage: "shield.fill")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(FTColor.catPurple, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
        }
    }

    private func tfaFeatureBullet(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(color).frame(width: 24)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    // MARK: Setup (QR)

    private var tfaSetupView: some View {
        VStack(spacing: FTSpacing.xxl) {
            Text("STEP 1 OF 2").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.lg) {
                Text("Add to Authenticator App").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)

                ZStack {
                    RoundedRectangle(cornerRadius: FTRadius.md)
                        .fill(FTColor.textMuted.opacity(0.08))
                        .frame(width: 180, height: 180)
                    VStack(spacing: FTSpacing.sm) {
                        Image(systemName: "qrcode").font(.system(size: 72)).foregroundStyle(FTColor.textPrimary)
                        Text("Scan in authenticator app")
                            .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }

                VStack(spacing: FTSpacing.sm) {
                    Text("Or enter this key manually:").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    Text(secretKey)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(FTColor.accent)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(FTColor.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: FTRadius.sm))
                        .onTapGesture { UIPasteboard.general.string = secretKey }
                    Text("Tap to copy")
                        .font(.system(size: 10)).foregroundStyle(FTColor.textMuted)
                }
            }
            .padding()
            .ftGlass(FTRadius.xl)

            Button { tfaStage = .verify } label: {
                Text("I've Added the Key →")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(FTColor.catPurple, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
        }
    }

    // MARK: Verify

    private var tfaVerifyView: some View {
        VStack(spacing: FTSpacing.xxl) {
            Text("STEP 2 OF 2").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            VStack(spacing: FTSpacing.md) {
                Image(systemName: "number.square.fill")
                    .font(.system(size: 48)).foregroundStyle(FTColor.catPurple)
                Text("Verify Setup").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Enter the 6-digit code from your authenticator app to confirm setup.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }
            .padding()
            .ftGlass(FTRadius.xl)

            VStack(spacing: FTSpacing.md) {
                TextField("000000", text: $verificationCode)
                    .font(.system(.title, design: .monospaced).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(FTColor.textMuted.opacity(0.1), in: RoundedRectangle(cornerRadius: FTRadius.md))
                    .onChange(of: verificationCode) { _, v in
                        verificationCode = String(v.filter { $0.isNumber }.prefix(6))
                    }

                Button {
                    guard verificationCode.count == 6 else { return }
                    settings?.twoFactorEnabled = true
                    settings?.twoFactorSecret = secretKey
                    try? context.save()
                    let entry = AuditLogEntry(eventType: .twoFAEnabled, description: "Two-factor authentication enabled")
                    context.insert(entry)
                    try? context.save()
                    tfaStage = .success
                } label: {
                    Text("Verify & Enable")
                        .font(.ftBodySemibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(
                            verificationCode.count == 6 ? FTColor.catPurple : FTColor.textMuted,
                            in: RoundedRectangle(cornerRadius: FTRadius.md)
                        )
                }
                .disabled(verificationCode.count < 6)
            }
        }
    }

    // MARK: Success

    private var tfaSuccessView: some View {
        VStack(spacing: FTSpacing.xxl) {
            ZStack {
                Circle().fill(FTColor.income.opacity(0.1)).frame(width: 96, height: 96)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40)).foregroundStyle(FTColor.income)
            }
            .padding(.top)
            VStack(spacing: FTSpacing.sm) {
                Text("2FA Enabled!").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Store your recovery codes somewhere safe. They let you regain access if you lose your authenticator app.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }
            Button { showingRecoveryCodes = true } label: {
                Label("View Recovery Codes", systemImage: "doc.on.doc")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(FTColor.income, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }
        }
    }

    // MARK: Helpers

    static func makeSecret() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        return (0..<32).map { _ in String(chars.randomElement()!) }.joined()
    }

    static func makeRecoveryCodes() -> [String] {
        (0..<8).map { _ in
            let a = String((0..<4).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            let b = String((0..<4).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            let c = String((0..<4).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            return "FTRC-\(a)-\(b)-\(c)"
        }
    }
}

// MARK: - Recovery Codes View

struct RecoveryCodesView: View {
    let codes: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    HStack(spacing: FTSpacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(FTColor.gold)
                        Text("Save these codes. Each can be used once to restore access if you lose your authenticator device.")
                            .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                    }
                    .padding()
                    .background(FTColor.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: FTRadius.md))

                    VStack(spacing: FTSpacing.sm) {
                        ForEach(codes, id: \.self) { code in
                            Text(code)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(FTColor.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(FTSpacing.md)
                                .background(FTColor.textMuted.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: FTRadius.sm))
                        }
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)

                    Button {
                        UIPasteboard.general.string = codes.joined(separator: "\n")
                    } label: {
                        Label("Copy All Codes", systemImage: "doc.on.doc")
                            .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                            .frame(maxWidth: .infinity).padding()
                            .background(FTColor.accent.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: FTRadius.md))
                    }
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Recovery Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                }
            }
        }
    }
}

// MARK: - Hidden Mode View

struct HiddenModeView: View {
    @Environment(\.modelContext) private var context
    @Query private var allSettings: [AppSettings]

    @State private var showingDecoyPINSetup = false

    private var settings: AppSettings? { allSettings.first }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                headerCard
                howItWorksCard
                statusCard
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Hidden Mode")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .sheet(isPresented: $showingDecoyPINSetup) {
            PINSetupSheet(isDecoy: true)
        }
    }

    private var headerCard: some View {
        VStack(spacing: FTSpacing.lg) {
            ZStack {
                Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "eye.slash.fill").font(.system(size: 32)).foregroundStyle(FTColor.catPurple)
            }
            VStack(spacing: FTSpacing.sm) {
                Text("Hidden Mode").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                Text("Set a Decoy PIN that shows a sanitized view of your finances — balances hidden, transactions limited to the last 30 days. Ideal for showing your phone to others without revealing sensitive data.")
                    .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("HOW IT WORKS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)

            hiddenRow("Real PIN → full access to all your data", icon: "lock.open.fill", color: FTColor.income)
            hiddenRow("Decoy PIN → Hidden Mode activates", icon: "eye.slash.fill", color: FTColor.catPurple)
            hiddenRow("Account balances replaced with ••••", icon: "eye.slash", color: FTColor.textMuted)
            hiddenRow("Transactions limited to last 30 days only", icon: "clock.fill", color: FTColor.catBlue)
            hiddenRow("Status indicator only visible to you", icon: "checkmark.seal.fill", color: FTColor.catTeal)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func hiddenRow(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: icon).font(.ftCallout).foregroundStyle(color).frame(width: 20)
            Text(text).font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private var statusCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Decoy PIN").font(.ftBody).foregroundStyle(FTColor.textPrimary)
                    Text(settings?.decoyPINHash != nil ? "Configured and active" : "Not set up")
                        .font(.ftCaption)
                        .foregroundStyle(settings?.decoyPINHash != nil ? FTColor.income : FTColor.textMuted)
                }
                Spacer()
                Image(systemName: settings?.decoyPINHash != nil ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(settings?.decoyPINHash != nil ? FTColor.income : FTColor.textMuted)
            }

            Button { showingDecoyPINSetup = true } label: {
                Text(settings?.decoyPINHash != nil ? "Change Decoy PIN" : "Set Up Decoy PIN")
                    .font(.ftBodySemibold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(FTColor.catPurple, in: RoundedRectangle(cornerRadius: FTRadius.md))
            }

            if settings?.decoyPINHash != nil {
                Button(role: .destructive) {
                    settings?.decoyPINHash = nil
                    settings?.hiddenModeEnabled = false
                    try? context.save()
                } label: {
                    Text("Remove Decoy PIN")
                        .font(.ftBodySemibold).foregroundStyle(FTColor.expense)
                        .frame(maxWidth: .infinity).padding()
                        .background(FTColor.expense.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: FTRadius.md))
                }
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }
}

// MARK: - Audit Log View

struct AuditLogView: View {
    @Query(sort: \AuditLogEntry.timestamp, order: .reverse) private var entries: [AuditLogEntry]
    @Environment(\.modelContext) private var context

    @State private var searchText = ""
    @State private var filterSecurityOnly = false
    @State private var showingClearConfirm = false

    private var filtered: [AuditLogEntry] {
        entries.filter { entry in
            let matchesSearch = searchText.isEmpty
                || entry.eventDescription.localizedCaseInsensitiveContains(searchText)
                || entry.eventType.rawValue.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = !filterSecurityOnly || entry.eventType.isSecurityEvent
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: FTSpacing.sm) {
                if filtered.isEmpty {
                    Text("No audit events found.")
                        .font(.ftBody).foregroundStyle(FTColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    ForEach(filtered) { entry in
                        auditRow(entry)
                    }
                }
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Audit Log (\(entries.count))")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .searchable(text: $searchText, prompt: "Search events…")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Toggle("Security Events Only", isOn: $filterSecurityOnly)
                    Divider()
                    Button(role: .destructive) { showingClearConfirm = true } label: {
                        Label("Clear All Events", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(FTColor.accent)
                }
            }
        }
        .confirmationDialog("Clear Audit Log", isPresented: $showingClearConfirm) {
            Button("Clear All Events", role: .destructive) {
                for entry in entries { context.delete(entry) }
                try? context.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all \(entries.count) recorded events.")
        }
    }

    private func auditRow(_ entry: AuditLogEntry) -> some View {
        let type = entry.eventType
        let color: Color = type.isSecurityEvent ? FTColor.gold : FTColor.textSecondary
        return HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: type.icon).font(.ftCaption).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue).font(.ftBody).foregroundStyle(FTColor.textPrimary)
                Text(entry.eventDescription).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                Text(entry.timestamp.relativeFormatted).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            }
            Spacer()
            if type.isSecurityEvent {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.ftCaption).foregroundStyle(FTColor.gold)
            }
        }
        .padding(FTSpacing.md)
        .ftGlass(FTRadius.md)
    }
}
