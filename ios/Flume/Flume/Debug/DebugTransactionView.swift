#if DEBUG
import SwiftUI
import Supabase

struct DebugTransactionView: View {
    private let client = SupabaseService.shared

    @State private var name = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var selectedCategory = CategoryPreset.groceries
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var showingResult = false

    enum CategoryPreset: String, CaseIterable, Identifiable {
        case groceries = "Groceries"
        case restaurant = "Restaurant"
        case coffee = "Coffee"
        case income = "Income"
        case rent = "Rent"
        case utilities = "Utilities"
        case shopping = "Shopping"
        case gas = "Gas"
        case subscription = "Subscription"

        var id: String { rawValue }

        var category: PersonalFinanceCategory {
            switch self {
            case .groceries:    return PersonalFinanceCategory(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES")
            case .restaurant:   return PersonalFinanceCategory(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT")
            case .coffee:       return PersonalFinanceCategory(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_COFFEE")
            case .income:       return PersonalFinanceCategory(primary: "INCOME", detailed: "INCOME_WAGES")
            case .rent:         return PersonalFinanceCategory(primary: "RENT_AND_UTILITIES", detailed: "RENT_AND_UTILITIES_RENT")
            case .utilities:    return PersonalFinanceCategory(primary: "RENT_AND_UTILITIES", detailed: "RENT_AND_UTILITIES_ELECTRICITY")
            case .shopping:     return PersonalFinanceCategory(primary: "GENERAL_MERCHANDISE", detailed: "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES")
            case .gas:          return PersonalFinanceCategory(primary: "TRANSPORTATION", detailed: "TRANSPORTATION_GAS")
            case .subscription: return PersonalFinanceCategory(primary: "GENERAL_SERVICES", detailed: "GENERAL_SERVICES_SUBSCRIPTIONS")
            }
        }
    }

    var body: some View {
        Form {
            Section("Custom Transaction") {
                TextField("Name", text: $name)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(CategoryPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                Button("Submit") {
                    Task { await submitSingle() }
                }
                .disabled(name.isEmpty || amount.isEmpty || isSubmitting)
            }

            Section("Quick Presets") {
                Button("Add Paycheck (-$2,800)") {
                    Task { await runPreset(paycheck()) }
                }
                Button("Add Week of Groceries (~$180)") {
                    Task { await runPreset(weekOfGroceries()) }
                }
                Button("Add Dining Week (~$120)") {
                    Task { await runPreset(diningWeek()) }
                }
                Button("Add Monthly Fixed (~$1,820)") {
                    Task { await runPreset(monthlyFixed()) }
                }
                Button("Blow the Budget (~$950)") {
                    Task { await runPreset(blowTheBudget()) }
                }
            }
            .disabled(isSubmitting)

            Section {
                Button("Delete All Debug Transactions", role: .destructive) {
                    Task { await deleteAll() }
                }
                .disabled(isSubmitting)
            }
        }
        .navigationTitle("Test Transactions")
        .alert("Result", isPresented: $showingResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    // MARK: - Actions

    private func submitSingle() async {
        guard let amountDecimal = Decimal(string: amount) else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let isIncome = selectedCategory == .income
        let finalAmount = isIncome ? -abs(amountDecimal) : abs(amountDecimal)

        let input = BudgetAPIService.DebugTransactionInput(
            name: name,
            amount: finalAmount,
            date: formatter.string(from: date),
            personal_finance_category: selectedCategory.category
        )
        await runPreset([input])
    }

    private func runPreset(_ inputs: [BudgetAPIService.DebugTransactionInput]) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let token = try await client.auth.session.accessToken
            let created = try await BudgetAPIService.shared.createDebugTransactions(inputs, accessToken: token)
            resultMessage = "Created \(created.count) transaction(s)"
            showingResult = true
        } catch {
            resultMessage = "Error: \(error.localizedDescription)"
            showingResult = true
        }
    }

    private func deleteAll() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let token = try await client.auth.session.accessToken
            try await BudgetAPIService.shared.deleteDebugTransactions(accessToken: token)
            resultMessage = "Deleted all debug transactions"
            showingResult = true
        } catch {
            resultMessage = "Error: \(error.localizedDescription)"
            showingResult = true
        }
    }

    // MARK: - Presets

    private func paycheck() -> [BudgetAPIService.DebugTransactionInput] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return [
            BudgetAPIService.DebugTransactionInput(
                name: "ACME CORP PAYROLL", amount: -2800,
                date: formatter.string(from: Date()),
                personal_finance_category: PersonalFinanceCategory(primary: "INCOME", detailed: "INCOME_WAGES")
            )
        ]
    }

    private func weekOfGroceries() -> [BudgetAPIService.DebugTransactionInput] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let names = ["TRADER JOES #123", "WHOLE FOODS MKT", "COSTCO #441"]
        let amounts: [Decimal] = [72.45, 58.30, 47.80]
        let daysAgo = [6, 3, 1]
        return zip(zip(names, amounts), daysAgo).map { pair, days in
            BudgetAPIService.DebugTransactionInput(
                name: pair.0, amount: pair.1,
                date: formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!),
                personal_finance_category: PersonalFinanceCategory(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_GROCERIES")
            )
        }
    }

    private func diningWeek() -> [BudgetAPIService.DebugTransactionInput] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let items: [(String, Decimal, Int)] = [
            ("CHIPOTLE #4521", 14.85, 6),
            ("STARBUCKS #8832", 6.25, 5),
            ("THAI GARDEN REST", 38.50, 3),
            ("DOMINOS PIZZA", 28.99, 2),
            ("STARBUCKS #8832", 5.75, 1),
        ]
        return items.map { name, amount, days in
            BudgetAPIService.DebugTransactionInput(
                name: name, amount: amount,
                date: formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!),
                personal_finance_category: PersonalFinanceCategory(primary: "FOOD_AND_DRINK", detailed: "FOOD_AND_DRINK_RESTAURANT")
            )
        }
    }

    private func monthlyFixed() -> [BudgetAPIService.DebugTransactionInput] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let items: [(String, Decimal, Int, String, String)] = [
            ("RIVERSIDE APARTMENTS", 1450.00, 25, "RENT_AND_UTILITIES", "RENT_AND_UTILITIES_RENT"),
            ("CITY ELECTRIC CO", 98.00, 20, "RENT_AND_UTILITIES", "RENT_AND_UTILITIES_ELECTRICITY"),
            ("COMCAST INTERNET", 80.00, 18, "RENT_AND_UTILITIES", "RENT_AND_UTILITIES_INTERNET"),
            ("T-MOBILE WIRELESS", 45.00, 15, "RENT_AND_UTILITIES", "RENT_AND_UTILITIES_TELEPHONE"),
            ("STATE FARM INS", 120.00, 12, "LOAN_PAYMENTS", "LOAN_PAYMENTS_INSURANCE_PAYMENT"),
            ("SPOTIFY PREMIUM", 10.99, 10, "GENERAL_SERVICES", "GENERAL_SERVICES_SUBSCRIPTIONS"),
            ("NETFLIX", 15.49, 8, "GENERAL_SERVICES", "GENERAL_SERVICES_SUBSCRIPTIONS"),
        ]
        return items.map { name, amount, days, primary, detailed in
            BudgetAPIService.DebugTransactionInput(
                name: name, amount: amount,
                date: formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!),
                personal_finance_category: PersonalFinanceCategory(primary: primary, detailed: detailed)
            )
        }
    }

    private func blowTheBudget() -> [BudgetAPIService.DebugTransactionInput] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let items: [(String, Decimal, Int, String, String)] = [
            ("NOBU RESTAURANT", 142.00, 7, "FOOD_AND_DRINK", "FOOD_AND_DRINK_RESTAURANT"),
            ("DOORDASH", 48.30, 6, "FOOD_AND_DRINK", "FOOD_AND_DRINK_RESTAURANT"),
            ("UBER EATS", 35.75, 5, "FOOD_AND_DRINK", "FOOD_AND_DRINK_RESTAURANT"),
            ("SUSHI HOUSE", 78.50, 4, "FOOD_AND_DRINK", "FOOD_AND_DRINK_RESTAURANT"),
            ("AMAZON.COM", 189.99, 5, "GENERAL_MERCHANDISE", "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"),
            ("BEST BUY #7741", 149.99, 3, "GENERAL_MERCHANDISE", "GENERAL_MERCHANDISE_ELECTRONICS"),
            ("ZARA #0221", 87.50, 2, "GENERAL_MERCHANDISE", "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES"),
            ("STUBHUB TICKETS", 120.00, 1, "ENTERTAINMENT", "ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS"),
            ("AMC THEATRES", 32.00, 1, "ENTERTAINMENT", "ENTERTAINMENT_TV_AND_MOVIES"),
        ]
        return items.map { name, amount, days, primary, detailed in
            BudgetAPIService.DebugTransactionInput(
                name: name, amount: amount,
                date: formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!),
                personal_finance_category: PersonalFinanceCategory(primary: primary, detailed: detailed)
            )
        }
    }
}
#endif
