import SwiftUI
import SwiftData

// MARK: - RentalView

struct RentalView: View {

    // MARK: Environment
    @Environment(\.modelContext) private var context

    // MARK: Data
    @Query(sort: \RentalProperty.createdAt, order: .reverse)
    private var allProperties: [RentalProperty]

    // MARK: State
    @State private var selectedProperty: RentalProperty? = nil
    @State private var showAddProperty: Bool = false

    // MARK: Computed

    private var activeProperties: [RentalProperty] {
        allProperties.filter { $0.isActive }
    }

    private var totalMonthlyRent: Double {
        activeProperties.reduce(0) { $0 + $1.currentMonthlyRent }
    }

    private var averageCollectionRate: Double {
        guard !activeProperties.isEmpty else { return 0 }
        let total = activeProperties.reduce(0.0) { $0 + $1.collectionRate }
        return total / Double(activeProperties.count)
    }

    private var occupiedCount: Int {
        activeProperties.filter { $0.isOccupied }.count
    }

    private var totalOverdueCount: Int {
        activeProperties.reduce(0) { $0 + $1.overduePayments.count }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.lg) {
                portfolioSummaryCard
                propertiesSection
                if allProperties.isEmpty {
                    emptyState
                }
                Color.clear.frame(height: 20)
            }
            .padding(.horizontal, FTSpacing.screen)
            .padding(.top, FTSpacing.lg)
        }
        .sheet(item: $selectedProperty) { property in
            PropertyDetailSheet(property: property)
        }
        .sheet(isPresented: $showAddProperty) {
            AddRentalPropertyView()
        }
    }

    // MARK: - Portfolio Summary Card

    private var portfolioSummaryCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.lg) {
            Text("RENTAL PORTFOLIO")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            // Primary metric
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Monthly Rent")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                Text(totalMonthlyRent.formatted(as: "AED"))
                    .font(.ftAmount)
                    .foregroundStyle(FTColor.income)
            }

            // Secondary metrics row
            HStack(spacing: 0) {
                summaryMetric(
                    title: "Collection Rate",
                    value: (averageCollectionRate * 100).asPercentage(),
                    icon: "percent",
                    color: averageCollectionRate >= 0.9 ? FTColor.income : FTColor.gold
                )
                metricDivider
                summaryMetric(
                    title: "Occupied",
                    value: "\(occupiedCount)/\(activeProperties.count)",
                    icon: "person.fill",
                    color: FTColor.textPrimary
                )
                metricDivider
                summaryMetric(
                    title: "Overdue",
                    value: "\(totalOverdueCount)",
                    icon: "exclamationmark.circle.fill",
                    color: totalOverdueCount > 0 ? FTColor.expense : FTColor.textMuted
                )
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private func summaryMetric(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: FTSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(color)
            Text(title)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.1))
            .frame(width: 0.5, height: 50)
    }

    // MARK: - Properties Section

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            HStack {
                Text("PROPERTIES")
                    .font(.ftLabel)
                    .tracking(1.6)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()
                Button {
                    showAddProperty = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(FTColor.accent)
                }
            }
            .padding(.leading, FTSpacing.xs)

            if activeProperties.isEmpty && !allProperties.isEmpty {
                Text("All properties are inactive.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(FTSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                ForEach(activeProperties) { property in
                    PropertyCard(property: property)
                        .onTapGesture { selectedProperty = property }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: FTSpacing.lg) {
            FTIconTile(symbol: "building.fill", tint: FTColor.accent, size: 56)
            VStack(spacing: FTSpacing.xs) {
                Text("No Rental Properties")
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("Add your first property to start tracking rent income and tenancy details.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .multilineTextAlignment(.center)
            }
            Button("Add Property") { showAddProperty = true }
                .buttonStyle(.ftPrimary)
                .frame(maxWidth: 220)
        }
        .padding(FTSpacing.xxl)
        .frame(maxWidth: .infinity)
        .ftGlass(FTRadius.lg)
    }
}

// MARK: - PropertyCard

private struct PropertyCard: View {
    let property: RentalProperty

    var body: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            // Header
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: property.propertyType.icon,
                    tint: Color.fromString(property.colorName),
                    size: 42
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(property.propertyName)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                    if let address = property.address {
                        Text(address)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(property.propertyType.rawValue)
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
                Spacer()
                occupancyBadge
            }

            // Rent amount
            HStack {
                Text(property.currentMonthlyRent.formatted(as: property.currency))
                    .font(.ftHeadline)
                    .foregroundStyle(FTColor.textPrimary)
                Text("/mo")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()

                // Overdue badge
                if !property.overduePayments.isEmpty {
                    HStack(spacing: FTSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(property.overduePayments.count) overdue")
                            .font(.ftCaption)
                    }
                    .foregroundStyle(FTColor.expense)
                    .padding(.horizontal, FTSpacing.sm)
                    .padding(.vertical, 4)
                    .background(FTColor.expense.opacity(0.12), in: .capsule)
                }
            }

            // Collection rate progress
            if property.totalExpected > 0 {
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    HStack {
                        Text("Collection Rate")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Spacer()
                        Text((property.collectionRate * 100).asPercentage())
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    FTProgressBar(
                        value: property.collectionRate,
                        color: property.collectionRate >= 0.9 ? FTColor.income : FTColor.gold
                    )
                }
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlassInteractive(FTRadius.md)
    }

    private var occupancyBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(property.isOccupied ? FTColor.income : FTColor.textMuted)
                .frame(width: 7, height: 7)
            Text(property.isOccupied ? "Occupied" : "Vacant")
                .font(.ftCaption)
                .foregroundStyle(property.isOccupied ? FTColor.income : FTColor.textMuted)
        }
        .padding(.horizontal, FTSpacing.sm)
        .padding(.vertical, 4)
        .background(
            (property.isOccupied ? FTColor.income : FTColor.textMuted).opacity(0.12),
            in: .capsule
        )
    }
}

// MARK: - PropertyDetailSheet

struct PropertyDetailSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let property: RentalProperty

    @State private var showAddTenancy: Bool = false
    @State private var showRecordPayment: Bool = false
    @State private var showEndTenancyAlert: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                FTBackdrop()
                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        propertyHeaderCard
                        occupancyCard
                        analyticsCard
                        paymentHistorySection
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }
            }
            .navigationTitle(property.propertyName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showRecordPayment = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .tint(FTColor.accent)
                }
            }
            .sheet(isPresented: $showAddTenancy) {
                AddTenancySheet(property: property)
            }
            .sheet(isPresented: $showRecordPayment) {
                RecordRentPaymentSheet(property: property)
            }
            .alert("End Tenancy", isPresented: $showEndTenancyAlert) {
                Button("End Tenancy", role: .destructive) { endTenancy() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the property as vacant and close the current lease period.")
            }
        }
    }

    // MARK: Property Header Card

    private var propertyHeaderCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack(spacing: FTSpacing.md) {
                FTIconTile(
                    symbol: property.propertyType.icon,
                    tint: Color.fromString(property.colorName),
                    size: 48
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(property.propertyType.rawValue)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    if let address = property.address {
                        Text(address)
                            .font(.ftBody)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                }
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(property.currentMonthlyRent.formatted(as: property.currency))
                    .font(.ftTitle)
                    .foregroundStyle(FTColor.income)
                Text("/month")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
            }

            if let notes = property.notes {
                Text(notes)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textSecondary)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    // MARK: Occupancy Card

    private var occupancyCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("OCCUPANCY")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)

            if property.isOccupied, let period = property.currentOccupancyPeriod {
                // Tenant info
                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    HStack {
                        FTIconTile(symbol: "person.fill", tint: FTColor.accent, size: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(period.tenantName)
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                            Text("Lease: \(period.leaseStartDate.formatted) – \(period.leaseEndDate.formatted)")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textSecondary)
                        }
                        Spacer()
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Monthly Rent")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                            Text(period.monthlyRent.formatted(as: property.currency))
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Deposit")
                                .font(.ftCaption)
                                .foregroundStyle(FTColor.textMuted)
                            Text(period.depositAmount.formatted(as: property.currency))
                                .font(.ftBodySemibold)
                                .foregroundStyle(FTColor.textPrimary)
                        }
                    }
                }

                Button("End Tenancy") {
                    showEndTenancyAlert = true
                }
                .font(.ftCallout)
                .foregroundStyle(FTColor.expense)
                .padding(.horizontal, FTSpacing.lg)
                .padding(.vertical, FTSpacing.sm)
                .background(FTColor.expense.opacity(0.1), in: .capsule)
                .buttonStyle(.plain)

            } else {
                // Vacant state
                HStack(spacing: FTSpacing.md) {
                    FTIconTile(symbol: "house", tint: FTColor.textMuted, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Currently Vacant")
                            .font(.ftBodySemibold)
                            .foregroundStyle(FTColor.textPrimary)
                        Text("No active lease")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                    Spacer()
                }

                Button("Add Tenancy") {
                    showAddTenancy = true
                }
                .buttonStyle(.ftPrimary)
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    // MARK: Analytics Card

    private var analyticsCard: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            HStack {
                Text("ANALYTICS")
                    .font(.ftLabel)
                    .tracking(1.6)
                    .foregroundStyle(FTColor.textMuted)
                Spacer()
                Button("Record Payment") {
                    showRecordPayment = true
                }
                .font(.ftCallout)
                .foregroundStyle(FTColor.accent)
                .buttonStyle(.plain)
            }

            HStack {
                statBlock(title: "Collected", value: property.totalCollected.asCompact(currency: property.currency), color: FTColor.income)
                Spacer()
                statBlock(title: "Expected", value: property.totalExpected.asCompact(currency: property.currency), color: FTColor.textPrimary)
                Spacer()
                statBlock(title: "Overdue", value: "\(property.overduePayments.count)", color: property.overduePayments.isEmpty ? FTColor.textMuted : FTColor.expense)
            }

            if property.totalExpected > 0 {
                VStack(alignment: .leading, spacing: FTSpacing.xs) {
                    HStack {
                        Text("Collection Rate")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                        Spacer()
                        Text((property.collectionRate * 100).asPercentage())
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textSecondary)
                    }
                    FTProgressBar(
                        value: property.collectionRate,
                        color: property.collectionRate >= 0.9 ? FTColor.income : FTColor.gold
                    )
                }
            }
        }
        .padding(FTSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ftGlass(FTRadius.lg)
    }

    private func statBlock(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.ftBodySemibold)
                .foregroundStyle(color)
            Text(title)
                .font(.ftCaption)
                .foregroundStyle(FTColor.textMuted)
        }
    }

    // MARK: Payment History Section

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: FTSpacing.sm) {
            Text("PAYMENT HISTORY")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)
                .padding(.leading, FTSpacing.xs)

            let sorted = property.paymentHistory.sorted { $0.expectedDate > $1.expectedDate }

            if sorted.isEmpty {
                Text("No payment records yet.")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                    .padding(FTSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sorted.prefix(20).enumerated()), id: \.element.id) { index, record in
                        paymentRecordRow(record: record)
                        if index < min(sorted.count, 20) - 1 {
                            Rectangle()
                                .fill(FTColor.textPrimary.opacity(0.06))
                                .frame(height: 0.5)
                                .padding(.leading, FTSpacing.lg)
                        }
                    }
                }
                .ftGlass(FTRadius.md)
            }
        }
    }

    private func paymentRecordRow(record: RentPaymentRecord) -> some View {
        HStack(spacing: FTSpacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.expectedDate.formatted)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                HStack(spacing: FTSpacing.xs) {
                    if record.isLate {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Late")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(FTColor.gold)
                    }
                    if let receivedDate = record.receivedDate {
                        Text("Received \(receivedDate.formatted)")
                            .font(.ftCaption)
                            .foregroundStyle(FTColor.textMuted)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if let received = record.receivedAmount {
                    Text(received.formatted(as: property.currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(record.isPaid ? FTColor.income : FTColor.textPrimary)
                } else {
                    Text(record.expectedAmount.formatted(as: property.currency))
                        .font(.ftBodySemibold)
                        .foregroundStyle(record.isLate ? FTColor.expense : FTColor.textSecondary)
                }
                paymentStatusChip(record: record)
            }
        }
        .padding(FTSpacing.lg)
    }

    private func paymentStatusChip(record: RentPaymentRecord) -> some View {
        let (label, color): (String, Color) = {
            if record.isPaid { return ("Paid", FTColor.income) }
            if record.isLate { return ("Overdue", FTColor.expense) }
            return ("Pending", FTColor.gold)
        }()

        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: .capsule)
    }

    // MARK: Actions

    private func endTenancy() {
        var mutableProperty = property
        IncomeService.shared.endOccupancy(property: &mutableProperty)
        property.isOccupied = false
        if let lastIdx = property.occupancyPeriods.indices.last {
            property.occupancyPeriods[lastIdx].leaseEndDate = Date()
        }
        property.updatedAt = Date()
        try? context.save()
    }
}

// MARK: - AddTenancySheet

struct AddTenancySheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let property: RentalProperty

    @State private var tenantName: String = ""
    @State private var leaseStart: Date = Date()
    @State private var leaseEnd: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var monthlyRentText: String = ""
    @State private var depositText: String = ""
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        tenancyFormSection
                        notesSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle("Add Tenancy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear {
                if monthlyRentText.isEmpty {
                    monthlyRentText = String(format: "%.2f", property.monthlyRentExpected)
                }
            }
        }
    }

    private var tenancyFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("TENANCY DETAILS")

            VStack(spacing: 0) {
                formRow {
                    fieldLabel("Tenant Name")
                    Spacer()
                    TextField("Full name", text: $tenantName)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                }
                rowDivider
                formRow {
                    fieldLabel("Lease Start")
                    Spacer()
                    DatePicker("", selection: $leaseStart, displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                rowDivider
                formRow {
                    fieldLabel("Lease End")
                    Spacer()
                    DatePicker("", selection: $leaseEnd, in: leaseStart..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                rowDivider
                formRow {
                    fieldLabel("Monthly Rent")
                    Spacer()
                    TextField("0.00", text: $monthlyRentText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                rowDivider
                formRow {
                    fieldLabel("Deposit Amount")
                    Spacer()
                    TextField("0.00", text: $depositText)
                        .keyboardType(.decimalPad)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("NOTES")
            VStack {
                TextEditor(text: $notes)
                    .font(.ftBody)
                    .foregroundStyle(FTColor.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .padding(FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text(validationMessage)
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button("Start Tenancy") { save() }
                .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func save() {
        let trimmedName = tenantName.trimmingCharacters(in: .whitespaces)
        let monthlyRent = Double(monthlyRentText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let deposit = Double(depositText.replacingOccurrences(of: ",", with: ".")) ?? 0

        guard !trimmedName.isEmpty else {
            validationMessage = "Tenant name is required"
            withAnimation { showValidationError = true }
            return
        }
        guard monthlyRent > 0 else {
            validationMessage = "Please enter a valid monthly rent"
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let period = OccupancyPeriod(
            tenantName: trimmedName,
            leaseStartDate: leaseStart,
            leaseEndDate: leaseEnd,
            monthlyRent: monthlyRent,
            depositAmount: deposit,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )

        var mutableProperty = property
        IncomeService.shared.addOccupancyPeriod(property: &mutableProperty, period: period)

        // Apply changes to the SwiftData @Model object directly
        property.isOccupied = true
        property.occupancyPeriods.append(period)
        property.updatedAt = Date()

        try? context.save()
        dismiss()
    }

    // MARK: Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.ftLabel)
            .tracking(1.6)
            .foregroundStyle(FTColor.textMuted)
            .padding(.leading, FTSpacing.xs)
            .padding(.bottom, FTSpacing.xs)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.ftBody)
            .foregroundStyle(FTColor.textSecondary)
            .fixedSize()
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(FTColor.textPrimary.opacity(0.06))
            .frame(height: 0.5)
    }

    private func formRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: FTSpacing.md) { content() }
            .padding(.vertical, FTSpacing.md)
    }
}

// MARK: - RecordRentPaymentSheet

struct RecordRentPaymentSheet: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let property: RentalProperty

    @State private var amountText: String = ""
    @State private var paymentDate: Date = Date()
    @State private var notes: String = ""
    @State private var showValidationError: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                FTBackdrop()

                ScrollView {
                    VStack(spacing: FTSpacing.lg) {
                        propertySummaryCard
                        paymentFormSection
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, FTSpacing.screen)
                    .padding(.top, FTSpacing.lg)
                }

                saveButtonArea
            }
            .navigationTitle("Record Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            .onAppear {
                amountText = String(format: "%.2f", property.currentMonthlyRent)
            }
        }
    }

    private var propertySummaryCard: some View {
        HStack(spacing: FTSpacing.md) {
            FTIconTile(
                symbol: property.propertyType.icon,
                tint: Color.fromString(property.colorName),
                size: 42
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(property.propertyName)
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
                if let tenant = property.currentOccupancyPeriod?.tenantName {
                    Text(tenant)
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Expected")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.textMuted)
                Text(property.currentMonthlyRent.formatted(as: property.currency))
                    .font(.ftBodySemibold)
                    .foregroundStyle(FTColor.textPrimary)
            }
        }
        .padding(FTSpacing.lg)
        .ftGlass(FTRadius.lg)
    }

    private var paymentFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PAYMENT DETAILS")
                .font(.ftLabel)
                .tracking(1.6)
                .foregroundStyle(FTColor.textMuted)
                .padding(.leading, FTSpacing.xs)
                .padding(.bottom, FTSpacing.xs)

            VStack(spacing: 0) {
                HStack(spacing: FTSpacing.md) {
                    Text("Amount")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.ftBodySemibold)
                        .foregroundStyle(FTColor.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                }
                .padding(.vertical, FTSpacing.md)

                Rectangle()
                    .fill(FTColor.textPrimary.opacity(0.06))
                    .frame(height: 0.5)

                HStack(spacing: FTSpacing.md) {
                    Text("Date")
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textSecondary)
                        .fixedSize()
                    Spacer()
                    DatePicker("", selection: $paymentDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .tint(FTColor.accent)
                }
                .padding(.vertical, FTSpacing.sm)

                Rectangle()
                    .fill(FTColor.textPrimary.opacity(0.06))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: FTSpacing.sm) {
                    Text("Notes (optional)")
                        .font(.ftCaption)
                        .foregroundStyle(FTColor.textMuted)
                    TextEditor(text: $notes)
                        .font(.ftBody)
                        .foregroundStyle(FTColor.textPrimary)
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
                .padding(.vertical, FTSpacing.md)
            }
            .padding(.horizontal, FTSpacing.lg)
            .ftGlass(FTRadius.md)
        }
    }

    private var saveButtonArea: some View {
        VStack(spacing: FTSpacing.sm) {
            if showValidationError {
                Text("Please enter a valid payment amount")
                    .font(.ftCaption)
                    .foregroundStyle(FTColor.expense)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Button("Record Payment") { save() }
                .buttonStyle(.ftPrimary)
        }
        .padding(.horizontal, FTSpacing.screen)
        .padding(.bottom, FTSpacing.xl)
        .padding(.top, FTSpacing.md)
        .background {
            LinearGradient(
                colors: [FTColor.bgBase.opacity(0), FTColor.bgBase],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func save() {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard amount > 0 else {
            withAnimation { showValidationError = true }
            return
        }
        showValidationError = false

        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        IncomeService.shared.recordRentPayment(
            property: property,
            amount: amount,
            date: paymentDate,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )

        // Create income transaction
        let tx = Transaction(
            title: "Rent — \(property.propertyName)",
            amount: amount,
            currency: property.currency,
            type: .income,
            category: .rental,
            date: paymentDate,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            incomeSource: property.propertyName
        )
        context.insert(tx)

        try? context.save()
        dismiss()
    }
}
