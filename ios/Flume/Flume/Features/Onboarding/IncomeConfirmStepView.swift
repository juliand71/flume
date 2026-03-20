import SwiftUI

struct IncomeConfirmStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    @State private var editableStreams: [EditableStream] = []
    @State private var isSaving = false
    @State private var showManualEntry = false

    struct EditableStream: Identifiable {
        let id = UUID()
        var name: String
        var amount: String
        var frequency: String
        var nextExpectedDate: String?
        var confidence: String
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Your Income")
                .font(.title.bold())

            if viewModel.isLoading {
                Spacer()
                ProgressView("Detecting income patterns...")
                Spacer()
            } else if editableStreams.isEmpty {
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
            editableStreams = viewModel.detectedStreams.map { stream in
                EditableStream(
                    name: stream.name,
                    amount: "\(stream.estimatedAmount)",
                    frequency: stream.frequency,
                    nextExpectedDate: stream.nextExpectedDate,
                    confidence: stream.confidence
                )
            }
            if editableStreams.isEmpty {
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

        manualEntryForm

        Spacer()

        confirmButton
    }

    @ViewBuilder
    private var detectedStreamsView: some View {
        if viewModel.dateRangeDays < 30 {
            Text("Based on \(viewModel.dateRangeDays) days of data — suggestions may be less accurate.")
                .font(.caption)
                .foregroundStyle(.orange)
        }

        ScrollView {
            VStack(spacing: 16) {
                ForEach($editableStreams) { $stream in
                    streamCard(stream: $stream)
                }

                if showManualEntry {
                    manualEntryForm
                } else {
                    Button("Add Another") {
                        showManualEntry = true
                    }
                }
            }
        }

        confirmButton
    }

    @ViewBuilder
    private func streamCard(stream: Binding<EditableStream>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Name", text: stream.name)
                    .font(.headline)

                if stream.wrappedValue.confidence == "high" {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            HStack {
                Text("$")
                TextField("Amount", text: stream.amount)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }

            Picker("Frequency", selection: stream.frequency) {
                Text("Weekly").tag("weekly")
                Text("Biweekly").tag("biweekly")
                Text("Semimonthly").tag("semimonthly")
                Text("Monthly").tag("monthly")
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Remove", role: .destructive) {
                    editableStreams.removeAll { $0.id == stream.wrappedValue.id }
                }
                .font(.caption)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var manualEntryForm: some View {
        Button {
            editableStreams.append(EditableStream(
                name: "",
                amount: "",
                frequency: "monthly",
                nextExpectedDate: nil,
                confidence: "manual"
            ))
            showManualEntry = false
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
        .disabled(editableStreams.isEmpty || isSaving || editableStreams.contains { $0.name.isEmpty || $0.amount.isEmpty })
    }

    private func confirmAll() async {
        guard let token = authService.accessToken else { return }
        isSaving = true
        defer { isSaving = false }

        for stream in editableStreams {
            guard let amount = Decimal(string: stream.amount), amount > 0 else { continue }
            _ = await viewModel.confirmIncomeStream(
                name: stream.name,
                estimatedAmount: amount,
                frequency: stream.frequency,
                nextExpectedDate: stream.nextExpectedDate,
                accessToken: token
            )
        }

        await viewModel.advanceStep(accessToken: token)
    }
}
