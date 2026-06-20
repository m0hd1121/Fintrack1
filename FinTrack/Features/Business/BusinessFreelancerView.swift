import SwiftUI
import SwiftData

struct BusinessFreelancerView: View {
    @Environment(AppState.self) private var appState
    @Query private var clients: [ClientProfile]
    @Query private var invoices: [BusinessInvoice]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var projects: [BusinessProject]
    @Query private var transactions: [Transaction]

    private var outstandingTotal: Double {
        invoices.filter { $0.status.isOpen || $0.status == .overdue }
                .reduce(0) { $0 + $1.balanceDue }
    }

    private var overdueCount: Int {
        invoices.filter { $0.isOverdue }.count
    }

    private var activeClients: Int {
        clients.filter { $0.status == .active }.count
    }

    private var monthMileageKm: Double {
        let now = Date()
        return mileageTrips
            .filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.distanceKm }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                summaryStrip
                modulesGrid
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Business & Freelancer")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        VStack(spacing: FTSpacing.xl) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTSTANDING BALANCE").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(outstandingTotal.formatted(as: appState.baseCurrency))
                        .font(.ftAmount)
                        .foregroundStyle(outstandingTotal > 0 ? FTColor.gold : FTColor.income)
                    Text("Across \(invoices.filter { $0.status.isOpen }.count) open invoices")
                        .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.catBlue.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "briefcase.fill")
                        .font(.ftTitle).foregroundStyle(FTColor.catBlue)
                }
            }

            HStack(spacing: FTSpacing.sm) {
                summaryTile("Clients", value: "\(activeClients)", icon: "person.fill", color: FTColor.accent)
                summaryTile("Invoices", value: "\(invoices.count)", icon: "doc.text.fill", color: FTColor.catBlue)
                summaryTile("Overdue", value: "\(overdueCount)", icon: "exclamationmark.triangle.fill", color: overdueCount > 0 ? FTColor.expense : FTColor.textMuted)
                summaryTile("km / Mo", value: String(format: "%.0f", monthMileageKm), icon: "car.fill", color: FTColor.catTeal)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func summaryTile(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.ftCaption).foregroundStyle(color)
            Text(value).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Modules Grid

    private var modulesGrid: some View {
        VStack(spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                moduleCard(title: "Clients", icon: "person.2.fill", color: FTColor.accent,
                           subtitle: "\(activeClients) active",
                           destination: AnyView(ClientManagementView()))
                moduleCard(title: "Invoices", icon: "doc.text.fill", color: FTColor.catBlue,
                           subtitle: "\(invoices.count) total",
                           destination: AnyView(InvoiceListView()))
            }
            HStack(spacing: FTSpacing.md) {
                moduleCard(title: "Expenses", icon: "creditcard.fill", color: FTColor.expense,
                           subtitle: "Tag & filter",
                           destination: AnyView(BusinessExpenseView()))
                moduleCard(title: "Mileage", icon: "car.fill", color: FTColor.catTeal,
                           subtitle: String(format: "%.0f km total", mileageTrips.reduce(0) { $0 + $1.distanceKm }),
                           destination: AnyView(MileageTrackerView()))
            }
            HStack(spacing: FTSpacing.md) {
                moduleCard(title: "Projects", icon: "folder.fill", color: FTColor.catPurple,
                           subtitle: "\(projects.filter { $0.status == .active }.count) active",
                           destination: AnyView(ProjectProfitabilityView()))
                moduleCard(title: "New Invoice", icon: "plus.circle.fill", color: FTColor.gold,
                           subtitle: "Create invoice",
                           destination: AnyView(InvoiceCreatorView(invoice: nil)))
            }
        }
    }

    private func moduleCard(title: String, icon: String, color: Color, subtitle: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: FTSpacing.md) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: FTRadius.sm)
                            .fill(color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon).font(.ftHeadline).foregroundStyle(color)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                    Text(subtitle).font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .ftGlass(FTRadius.lg)
        }
        .buttonStyle(.plain)
    }
}
