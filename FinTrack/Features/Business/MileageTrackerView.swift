import SwiftUI
import SwiftData
import Charts

struct MileageTrackerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \MileageTrip.date, order: .reverse) private var trips: [MileageTrip]

    @State private var showingAdd = false
    @State private var periodFilter: Period = .thisMonth
    @State private var vehicleFilter: MileageVehicleType? = nil

    enum Period: String, CaseIterable {
        case thisMonth = "This Month"
        case last3     = "Last 3 Mo"
        case thisYear  = "This Year"
        case all       = "All"
    }

    private var filtered: [MileageTrip] {
        let now = Date()
        let cal = Calendar.current
        var result = trips
        switch periodFilter {
        case .thisMonth:
            result = result.filter { cal.isDate($0.date, equalTo: now, toGranularity: .month) }
        case .last3:
            if let start = cal.date(byAdding: .month, value: -3, to: now) {
                result = result.filter { $0.date >= start }
            }
        case .thisYear:
            result = result.filter { cal.isDate($0.date, equalTo: now, toGranularity: .year) }
        case .all:
            break
        }
        if let v = vehicleFilter { result = result.filter { $0.vehicleType == v } }
        return result
    }

    private var totalKm: Double  { filtered.reduce(0) { $0 + $1.distanceKm } }
    private var totalAmt: Double { filtered.reduce(0) { $0 + $1.reimbursementAmount } }
    private var unreimbursed: Double {
        filtered.filter { $0.isReimbursable && !$0.isReimbursed }
                .reduce(0) { $0 + $1.reimbursementAmount }
    }

    private var monthlyData: [(month: String, km: Double)] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).reversed().compactMap { offset -> (String, Double)? in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let monthKm = trips.filter { cal.isDate($0.date, equalTo: date, toGranularity: .month) }
                              .reduce(0) { $0 + $1.distanceKm }
            let fmt = DateFormatter(); fmt.dateFormat = "MMM"
            return (fmt.string(from: date), monthKm)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FTSpacing.xxl) {
                summaryCard
                filterRow
                trendChart
                tripList
            }
            .padding(FTSpacing.screen)
            .padding(.bottom, 40)
        }
        .navigationTitle("Mileage Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .background { FTBackdrop() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus").foregroundStyle(FTColor.accent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddMileageTripSheet()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: FTSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MILEAGE SUMMARY").font(.ftLabel).tracking(1.4).foregroundStyle(FTColor.textMuted)
                    Text(String(format: "%.1f km", totalKm)).font(.ftAmount).foregroundStyle(FTColor.catTeal)
                    Text("\(filtered.count) trips · \(periodFilter.rawValue)").font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(FTColor.catTeal.opacity(0.1)).frame(width: 52, height: 52)
                    Image(systemName: "car.fill").font(.ftTitle).foregroundStyle(FTColor.catTeal)
                }
            }
            HStack(spacing: FTSpacing.sm) {
                tile("Reimbursement", value: totalAmt, suffix: appState.baseCurrency, color: FTColor.income)
                tile("Pending", value: unreimbursed, suffix: appState.baseCurrency, color: unreimbursed > 0 ? FTColor.gold : FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private func tile(_ label: String, value: Double, suffix: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value.asCompact(currency: suffix)).font(.ftCallout).foregroundStyle(color)
            Text(label).font(.ftCaption).foregroundStyle(FTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FTSpacing.md)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: FTRadius.sm))
    }

    // MARK: - Filter Row

    private var filterRow: some View {
        VStack(spacing: FTSpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    ForEach(Period.allCases, id: \.self) { p in
                        FilterChip(title: p.rawValue, isSelected: periodFilter == p) { periodFilter = p }
                    }
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FTSpacing.sm) {
                    FilterChip(title: "All Vehicles", isSelected: vehicleFilter == nil) { vehicleFilter = nil }
                    ForEach(MileageVehicleType.allCases, id: \.self) { v in
                        FilterChip(title: v.rawValue, isSelected: vehicleFilter == v) {
                            vehicleFilter = vehicleFilter == v ? nil : v
                        }
                    }
                }
            }
        }
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("6-MONTH TREND").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Chart {
                ForEach(monthlyData, id: \.month) { item in
                    BarMark(x: .value("Month", item.month), y: .value("km", item.km))
                        .foregroundStyle(FTColor.catTeal.gradient)
                    LineMark(x: .value("Month", item.month), y: .value("km", item.km))
                        .foregroundStyle(FTColor.catTeal)
                        .symbol(Circle())
                }
            }
            .frame(height: 160)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    // MARK: - Trip List

    private var tripList: some View {
        VStack(alignment: .leading, spacing: FTSpacing.md) {
            Text("TRIPS (\(filtered.count))").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            if filtered.isEmpty {
                Text("No trips recorded. Tap + to log your first trip.")
                    .font(.ftBody).foregroundStyle(FTColor.textMuted)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .ftGlass(FTRadius.md)
            } else {
                VStack(spacing: FTSpacing.sm) {
                    ForEach(filtered) { trip in
                        tripRow(trip)
                    }
                }
            }
        }
    }

    private func tripRow(_ trip: MileageTrip) -> some View {
        HStack(spacing: FTSpacing.md) {
            ZStack {
                Circle().fill(FTColor.catTeal.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: trip.vehicleType.icon).font(.ftCaption).foregroundStyle(FTColor.catTeal)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(trip.fromLocation) → \(trip.toLocation)").font(.ftBodySemibold).foregroundStyle(FTColor.textPrimary)
                Text(trip.purpose.rawValue).font(.ftCaption).foregroundStyle(FTColor.textSecondary)
                if let client = trip.clientName { Text(client).font(.ftCaption).foregroundStyle(FTColor.textMuted) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f km", trip.distanceKm)).font(.ftCallout).foregroundStyle(FTColor.catTeal)
                Text(trip.reimbursementAmount.formatted(as: trip.currency))
                    .font(.ftCaption).foregroundStyle(FTColor.income)
                if trip.isReimbursed {
                    Text("Reimbursed").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                }
                Text(trip.date.formatted).font(.ftCaption).foregroundStyle(FTColor.textMuted)
            }
        }
        .padding()
        .ftGlass(FTRadius.md)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(trip)
                try? context.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                trip.isReimbursed.toggle()
                try? context.save()
            } label: {
                Label(trip.isReimbursed ? "Unreimburse" : "Mark Reimbursed",
                      systemImage: trip.isReimbursed ? "xmark.circle" : "checkmark.circle")
            }
            .tint(FTColor.income)
        }
    }
}

// MARK: - Add Mileage Trip Sheet

struct AddMileageTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ClientProfile.name) private var clients: [ClientProfile]
    @Query(sort: \BusinessProject.name) private var projects: [BusinessProject]

    @State private var date = Date()
    @State private var from = ""
    @State private var to = ""
    @State private var distanceKm = ""
    @State private var ratePerKm = "0.29"
    @State private var vehicleType: MileageVehicleType = .car
    @State private var purpose: MileagePurpose = .clientVisit
    @State private var selectedClientName = ""
    @State private var selectedProjectName = ""
    @State private var notes = ""
    @State private var isReimbursable = true
    @State private var currency = "AED"

    private var computedAmount: Double {
        (Double(distanceKm) ?? 0) * (Double(ratePerKm) ?? 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FTSpacing.xl) {
                    amountPreview
                    routeSection
                    detailsSection
                    attributionSection
                }
                .padding(FTSpacing.screen)
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
            .background { FTBackdrop() }
            .navigationTitle("Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(FTColor.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.ftBodySemibold).foregroundStyle(FTColor.accent)
                        .disabled(from.isEmpty || to.isEmpty || (Double(distanceKm) ?? 0) <= 0)
                }
            }
        }
    }

    private var amountPreview: some View {
        VStack(spacing: 4) {
            Text("REIMBURSEMENT").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
            Text(computedAmount.formatted(as: currency)).font(.ftAmount).foregroundStyle(FTColor.income)
            Text(String(format: "%.1f km × %@ /km", Double(distanceKm) ?? 0, ratePerKm))
                .font(.ftCaption).foregroundStyle(FTColor.textSecondary)
        }
        .padding()
        .ftGlass(FTRadius.xl)
    }

    private var routeSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("ROUTE").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: FTSpacing.sm) {
                inputField("From", text: $from)
                inputField("To", text: $to)
                HStack(spacing: FTSpacing.md) {
                    inputField("Distance (km)", text: $distanceKm, keyboardType: .decimalPad)
                    inputField("Rate/km (\(currency))", text: $ratePerKm, keyboardType: .decimalPad)
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .font(.ftBody)
                    .padding(FTSpacing.md)
                    .ftGlass(FTRadius.sm)
            }
        }
    }

    private var detailsSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("DETAILS").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: FTSpacing.sm) {
                pickerRow("Vehicle", vehicleType.rawValue) {
                    Picker("Vehicle", selection: $vehicleType) {
                        ForEach(MileageVehicleType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                pickerRow("Purpose", purpose.rawValue) {
                    Picker("Purpose", selection: $purpose) {
                        ForEach(MileagePurpose.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                }
                FTToggleRow(symbol: "dollarsign.circle.fill", tint: FTColor.income, title: "Reimbursable",
                            isOn: $isReimbursable)
            }
            .padding()
            .ftGlass(FTRadius.xl)
        }
    }

    private var attributionSection: some View {
        VStack(spacing: FTSpacing.md) {
            Text("ATTRIBUTION").font(.ftLabel).tracking(1.6).foregroundStyle(FTColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: FTSpacing.sm) {
                if !clients.isEmpty {
                    Menu {
                        Button("None") { selectedClientName = "" }
                        Divider()
                        ForEach(clients) { c in
                            Button(c.name) { selectedClientName = c.name }
                        }
                    } label: {
                        HStack {
                            Text("Client").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(selectedClientName.isEmpty ? "None" : selectedClientName)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        .padding(FTSpacing.md)
                        .ftGlass(FTRadius.sm)
                    }
                }
                if !projects.isEmpty {
                    Menu {
                        Button("None") { selectedProjectName = "" }
                        Divider()
                        ForEach(projects.filter { $0.status == .active }) { p in
                            Button(p.name) { selectedProjectName = p.name }
                        }
                    } label: {
                        HStack {
                            Text("Project").font(.ftBody).foregroundStyle(FTColor.textSecondary)
                            Spacer()
                            Text(selectedProjectName.isEmpty ? "None" : selectedProjectName)
                                .font(.ftBody).foregroundStyle(FTColor.textPrimary)
                            Image(systemName: "chevron.up.chevron.down").font(.ftCaption).foregroundStyle(FTColor.textMuted)
                        }
                        .padding(FTSpacing.md)
                        .ftGlass(FTRadius.sm)
                    }
                }
                inputField("Notes (optional)", text: $notes)
            }
        }
    }

    private func inputField(_ label: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        TextField(label, text: text)
            .keyboardType(keyboardType)
            .font(.ftBody)
            .padding(FTSpacing.md)
            .ftGlass(FTRadius.sm)
    }

    private func pickerRow<C: View>(_ label: String, _ value: String, @ViewBuilder picker: () -> C) -> some View {
        HStack {
            Text(label).font(.ftBody).foregroundStyle(FTColor.textSecondary)
            Spacer()
            picker()
                .labelsHidden()
                .foregroundStyle(FTColor.textPrimary)
        }
    }

    private func save() {
        let km = Double(distanceKm) ?? 0
        let rate = Double(ratePerKm) ?? 0.29
        guard km > 0 else { return }
        let trip = MileageTrip(
            date: date,
            fromLocation: from,
            toLocation: to,
            distanceKm: km,
            ratePerKm: rate,
            vehicleType: vehicleType,
            purpose: purpose,
            clientName: selectedClientName.isEmpty ? nil : selectedClientName,
            projectName: selectedProjectName.isEmpty ? nil : selectedProjectName,
            notes: notes.isEmpty ? nil : notes,
            isReimbursable: isReimbursable,
            currency: currency
        )
        context.insert(trip)
        try? context.save()
        dismiss()
    }
}
