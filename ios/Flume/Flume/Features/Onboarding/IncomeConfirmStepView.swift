import SwiftUI

struct IncomeConfirmStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var includedStreamNames: Set<String> = []
    @State private var manualStreams: [ManualStream] = []
    @State private var showManualEntry = false
    @State private var isSaving = false

    struct ManualStream: Identifiable {
        let id = UUID()
        var name: String
        var amount: String
        var frequency: String = "monthly"
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Income")
                .font(.title.bold())

            if viewModel.isLoading {
                Spacer()
                ProgressView("Detecting income patterns...")
                Spacer()
            } else if viewModel.detectedStreams.isEmpty && manualStreams.isEmpty {
                noIncomeDetectedView
            } else {
                detectedStreamsView
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .task {
            guard let token = authService.accessToken else { return }
            await viewModel.detectIncome(accessToken: token)
            includedStreamNames = Set(viewModel.detectedStreams.map { $0.name })
            if viewModel.detectedStreams.isEmpty {
                showManualEntry = true
            }
        }
    }

    @ViewBuilder
    private var noIncomeDetectedView: some View {
        Spacer()

        Text("We couldn't automatically detect recurring income. You can add your income manually.")
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

        manualEntryButton

        Spacer()

        confirmButton
    }

    @ViewBuilder
    private var detectedStreamsView: some View {
        if viewModel.expandedSearch {
            Text("We looked beyond your budget period to find income patterns.")
                .font(.caption)
                .foregroundStyle(.blue)
        } else if viewModel.dateRangeDays < 30 {
            Text("Based on \(viewModel.dateRangeDays) days of data — suggestions may be less accurate.")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.detectedStreams) { stream in
                    streamCard(stream: stream)
                }

                ForEach($manualStreams) { $manual in
                    manualStreamCard(stream: $manual)
                }

                manualEntryButton
            }
        }

        confirmButton
    }

    @ViewBuilder
    private func streamCard(stream: DetectedIncomeStream) -> some View {
        let isIncluded = includedStreamNames.contains(stream.name)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(isOn: Binding(
                    get: { isIncluded },
                    set: { newValue in
                        if newValue {
                            includedStreamNames.insert(stream.name)
                        } else {
                            includedStreamNames.remove(stream.name)
                        }
                    }
                )) {
                    Text(stream.name)
                        .font(.headline)
                }

                if stream.confidence == "high" {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            HStack {
                Text("$\(stream.totalAmount as NSDecimalNumber, formatter: Self.currencyFormatter)")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(Self.frequencyLabel(stream.frequency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }

            DisclosureGroup("Transactions (\(stream.occurrences))") {
                VStack(spacing: 4) {
                    ForEach(stream.transactions) { txn in
                        HStack {
                            Text(txn.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(txn.amount, format: .currency(code: "USD"))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding(.top, 4)
            }
            .font(.subheadline)
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isIncluded ? 1.0 : 0.5)
    }

    @ViewBuilder
    private func manualStreamCard(stream: Binding<ManualStream>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Income source name", text: stream.name)
                .font(.headline)

            HStack {
                Text("$")
                TextField("Amount", text: stream.amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Remove", role: .destructive) {
                    manualStreams.removeAll { $0.id == stream.wrappedValue.id }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var manualEntryButton: some View {
        Button {
            manualStreams.append(ManualStream(name: "", amount: ""))
        } label: {
            Label("Add Income Source", systemImage: "plus.circle")
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        Button {
            Task { await confirmAll() }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Confirm Income")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isSaving || (includedStreamNames.isEmpty && manualStreams.isEmpty))
    }

    private func confirmAll() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        var totalIncome: Decimal = 0

        // Confirm included detected streams
        for stream in viewModel.detectedStreams where includedStreamNames.contains(stream.name) {
            _ = await viewModel.confirmIncomeStream(
                name: stream.name,
                estimatedAmount: stream.estimatedAmount,
                frequency: stream.frequency,
                nextExpectedDate: stream.nextExpectedDate,
                accessToken: token
            )
            totalIncome += stream.totalAmount
        }

        // Confirm manual streams
        for manual in manualStreams {
            guard let amount = Decimal(string: manual.amount), amount > 0 else { continue }
            _ = await viewModel.confirmIncomeStream(
                name: manual.name,
                estimatedAmount: amount,
                frequency: manual.frequency,
                nextExpectedDate: nil,
                accessToken: token
            )
            totalIncome += amount
        }

        viewModel.confirmedIncomeTotal = totalIncome
        await viewModel.advanceStep(accessToken: token)
    }

    // MARK: - Helpers

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static func frequencyLabel(_ frequency: String) -> String {
        switch frequency {
        case "weekly": return "Weekly"
        case "biweekly": return "Bi-weekly"
        case "semimonthly": return "Semi-monthly"
        case "monthly": return "Monthly"
        default: return frequency
        }
    }
}
