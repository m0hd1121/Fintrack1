import SwiftUI
import SwiftData

struct OpenBankingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]

    @State private var connectedBanks: [ConnectedBank] = []
    @State private var selectedBank: BankInfo? = nil
    @State private var showingConsent = false
    @State private var isConnecting = false
    @State private var showingSuccess = false
    @State private var successBankName = ""

    struct ConnectedBank: Identifiable {
        let id = UUID()
        var bankName: String
        var maskedAccount: String
        var lastSynced: Date
        var transactionCount: Int
        var status: SyncStatus
    }

    enum SyncStatus: String {
        case connected = "Connected"
        case syncing   = "Syncing"
        case error     = "Error"

        var icon: String {
            switch self { case .connected: return "checkmark.circle.fill"; case .syncing: return "arrow.clockwise"; case .error: return "exclamationmark.circle.fill" }
        }
        var color: Color {
            switch self { case .connected: return FTColor.income; case .syncing: return FTColor.catBlue; case .error: return FTColor.expense }
        }
    }

    struct BankInfo: Identifiable {
        let id = UUID()
        var name: String
        var icon: String
        var colorHex: String
        var isUAE: Bool = true
    }

    private let availableBanks: [BankInfo] = [
        BankInfo(name: "Emirates NBD",             icon: "building.2.fill",    colorHex: "#c8a200"),
        BankInfo(name: "FAB",                      icon: "building.fill",      colorHex: "#00adef"),
        BankInfo(name: "ADCB",                     icon: "creditcard.fill",    colorHex: "#c1272d"),
        BankInfo(name: "Dubai Islamic Bank",        icon: "building.2.fill",    colorHex: "#006938"),
        BankInfo(name: "Mashreq",                  icon: "building.fill",      colorHex: "#e30613"),
        BankInfo(name: "RAK Bank",                 icon: "building.fill",      colorHex: "#003472"),
        BankInfo(name: "HSBC UAE",                 icon: "building.2.fill",    colorHex: "#db0011"),
        BankInfo(name: "Standard Chartered UAE",   icon: "building.fill",      colorHex: "#006bb6"),
        BankInfo(name: "Abu Dhabi Islamic Bank",   icon: "building.2.fill",    colorHex: "#007a53"),
        BankInfo(name: "Commercial Bank of Dubai", icon: "creditcard.fill",    colorHex: "#004b87"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                headerCard
                if !connectedBanks.isEmpty { connectedSection }
                availableBanksSection
                privacyNote
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Open Banking")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .sheet(item: $selectedBank) { bank in
            consentSheet(bank: bank)
        }
        .alert("Connected!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("\(successBankName) is now connected. Your transactions will sync automatically.")
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: FTSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPEN BANKING UAE").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text("Secure Direct Connection").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                    Text("CBUAE-compliant · Consent-based · OAuth 2.0").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 52, height: 52)
                    Image(systemName: "lock.shield.fill").font(.ftTitle).foregroundStyle(FTColor.catPurple)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                featureBadge("Bank-Grade Security", icon: "lock.fill")
                featureBadge("Read-Only Access", icon: "eye.fill")
                featureBadge("Auto Sync", icon: "arrow.clockwise")
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func featureBadge(_ label: String, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(FTColor.catPurple)
            .padding(.horizontal, FTSpacing.sm)
            .padding(.vertical, 4)
            .background(FTColor.catPurple.opacity(0.1), in: Capsule())
    }

    // MARK: - Connected Section

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("CONNECTED BANKS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            ForEach(connectedBanks) { bank in
                HStack(spacing: FTSpacing.md) {
                    ZStack {
                        Circle().fill(FTColor.catPurple.opacity(0.1)).frame(width: 44, height: 44)
                        Image(systemName: "building.2.fill").font(.ftCallout).foregroundStyle(FTColor.catPurple)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(bank.bankName).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                        Text(bank.maskedAccount).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        Text("Last synced \(bank.lastSynced.relativeFormatted)").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Label(bank.status.rawValue, systemImage: bank.status.icon)
                            .font(.ftCaption).foregroundStyle(bank.status.color)
                        Text("\(bank.transactionCount) txns").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                    }
                }
                .padding()
                .ftGlass(FTRadius.md)
            }
        }
    }

    // MARK: - Available Banks

    private var availableBanksSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("CONNECT A BANK").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FTSpacing.md) {
                ForEach(availableBanks) { bank in
                    let isConnected = connectedBanks.contains { $0.bankName == bank.name }
                    Button {
                        if !isConnected { selectedBank = bank }
                    } label: {
                        HStack(spacing: FTSpacing.sm) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color(hex: bank.colorHex).opacity(0.15)).frame(width: 36, height: 36)
                                Image(systemName: bank.icon).font(.system(size: 14)).foregroundStyle(Color(hex: bank.colorHex))
                            }
                            Text(bank.name).font(.ftCaption).foregroundStyle(FTColor.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                            Spacer()
                            if isConnected {
                                Image(systemName: "checkmark.circle.fill").font(.ftCaption).foregroundStyle(FTColor.income)
                            }
                        }
                        .padding(FTSpacing.sm)
                        .ftGlass(FTRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnected)
                    .opacity(isConnected ? 0.6 : 1)
                }
            }
        }
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: "shield.fill").font(.ftCallout).foregroundStyle(FTColor.income)
            Text("FinTrack never stores your banking credentials. All connections use OAuth 2.0 with read-only access tokens. You can disconnect any bank at any time.")
                .font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .padding()
        .ftGlass(FTRadius.md)
    }

    // MARK: - Consent Sheet

    private func consentSheet(bank: BankInfo) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    VStack(spacing: FTSpacing.lg) {
                        ZStack {
                            Circle().fill(Color(hex: bank.colorHex).opacity(0.15)).frame(width: 80, height: 80)
                            Image(systemName: bank.icon).font(.system(size: 32)).foregroundStyle(Color(hex: bank.colorHex))
                        }
                        Text("Connect to \(bank.name)").font(.ftHeadline).foregroundStyle(FTColor.textPrimary)
                        Text("You will be redirected to \(bank.name)'s secure portal to authorize FinTrack's read-only access to your account data.")
                            .font(.ftBody).foregroundStyle(FTColor.textSecondary).multilineTextAlignment(.center)
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)

                    VStack(alignment: .leading, spacing: FTSpacing.md) {
                        Text("WHAT WE ACCESS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                        permissionRow("Transaction history (last 90 days)", icon: "list.bullet", allowed: true)
                        permissionRow("Account balance", icon: "dollarsign.circle.fill", allowed: true)
                        permissionRow("Personal payments or transfers", icon: "banknote", allowed: false)
                        permissionRow("Account credentials", icon: "lock.fill", allowed: false)
                    }
                    .padding()
                    .ftGlass(FTRadius.xl)

                    if isConnecting {
                        ProgressView("Connecting to \(bank.name)…").padding()
                    } else {
                        Button {
                            simulateConnect(bank: bank)
                        } label: {
                            Text("Authorize \(bank.name)")
                                .font(.ftBodySemibold).foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(FTColor.catPurple, in: RoundedRectangle(cornerRadius: FTRadius.md))
                        }
                    }
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Authorization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selectedBank = nil }.foregroundStyle(FTColor.textSecondary)
                }
            }
        }
    }

    private func permissionRow(_ label: String, icon: String, allowed: Bool) -> some View {
        HStack(spacing: FTSpacing.md) {
            Image(systemName: allowed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(allowed ? FTColor.income : FTColor.expense)
            Image(systemName: icon).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
            Text(label).font(.ftBody).foregroundStyle(FTColor.textPrimary)
        }
    }

    private func simulateConnect(bank: BankInfo) {
        isConnecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            connectedBanks.append(ConnectedBank(
                bankName: bank.name,
                maskedAccount: "****" + String(format: "%04d", Int.random(in: 1000...9999)),
                lastSynced: Date(),
                transactionCount: Int.random(in: 12...45),
                status: .connected
            ))
            successBankName = bank.name
            selectedBank = nil
            showingSuccess = true
        }
    }
}
