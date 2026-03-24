import SwiftUI

struct BudgetPeriodStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(AuthService.self) private var authService

    private let periodTypes = ["monthly", "semimonthly", "biweekly", "weekly"]
    private let periodLabels = [
        "monthly": "Monthly",
        "semimonthly": "Semi-monthly",
        "biweekly": "Bi-weekly",
        "weekly": "Weekly",
    ]
    private let periodDescriptions = [
        "monthly": "1st of each month",
        "semimonthly": "Twice a month",
        "biweekly": "Every two weeks",
        "weekly": "Every week",
    ]

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 24) {
            Text("Budget Period")
                .font(.title.bold())

            Text("How often do you want to budget? Most people use monthly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(periodTypes, id: \.self) { type in
                        periodOption(type: type)
                    }

                    if let start = viewModel.periodStartDate, let end = viewModel.periodEndDate {
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            Text("Your first period:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(formatted(start)) – \(formatted(end))")
                                .font(.subheadline.bold())
                        }
                    }
                }
            }

            Button {
                Task {
                    guard let token = authService.accessToken else { return }
                    await viewModel.advanceStep(accessToken: token)
                }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: 400)
        .onAppear {
            viewModel.computePeriodDates()
        }
    }

    @ViewBuilder
    private func periodOption(type: String) -> some View {
        let isSelected = viewModel.selectedPeriodType == type

        VStack(alignment: .leading, spacing: 8) {
            Button {
                viewModel.selectedPeriodType = type
                if type == "monthly" || type == "semimonthly" {
                    viewModel.computePeriodDates()
                } else if type == "biweekly" && viewModel.biweeklyAnchorDate != nil {
                    viewModel.computePeriodDates()
                } else if type == "weekly" {
                    viewModel.computePeriodDates()
                }
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(periodLabels[type] ?? type)
                            .font(.headline)
                        Text(periodDescriptions[type] ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected {
                customConfig(for: type)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.quaternarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func customConfig(for type: String) -> some View {
        switch type {
        case "semimonthly":
            Picker("Which half?", selection: Binding(
                get: { viewModel.semimonthlyHalf },
                set: { newValue in
                    viewModel.semimonthlyHalf = newValue
                    viewModel.computePeriodDates()
                }
            )) {
                Text("1st – 15th").tag(1)
                Text("16th – End of month").tag(2)
            }
            .pickerStyle(.segmented)

        case "biweekly":
            DatePicker(
                "Next payday",
                selection: Binding(
                    get: { viewModel.biweeklyAnchorDate ?? Date() },
                    set: { newValue in
                        viewModel.biweeklyAnchorDate = newValue
                        viewModel.computePeriodDates()
                    }
                ),
                in: Date()...Calendar.current.date(byAdding: .day, value: 14, to: Date())!,
                displayedComponents: .date
            )

        case "weekly":
            HStack {
                Text("Start day")
                    .font(.subheadline)
                Spacer()
                Picker("Start day", selection: Binding(
                    get: { viewModel.weeklyStartDay },
                    set: { newValue in
                        viewModel.weeklyStartDay = newValue
                        viewModel.computePeriodDates()
                    }
                )) {
                    ForEach(1...7, id: \.self) { day in
                        Text(dayNames[day - 1]).tag(day)
                    }
                }
            }

        default:
            EmptyView()
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
