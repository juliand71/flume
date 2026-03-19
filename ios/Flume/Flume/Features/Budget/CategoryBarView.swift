import SwiftUI

struct CategoryBarView: View {
    let title: String
    let actual: Decimal
    let target: Decimal
    let tint: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(truncating: actual / target as NSDecimalNumber), 1.5)
    }

    private var isOverBudget: Bool {
        actual > target && target > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(actual as NSDecimalNumber, formatter: currencyFormatter) / \(target as NSDecimalNumber, formatter: currencyFormatter)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tint.opacity(0.15))

                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOverBudget ? .red : tint)
                        .frame(width: max(0, geometry.size.width * min(progress, 1.0)))
                }
            }
            .frame(height: 12)
        }
        .padding(.vertical, 4)
    }
}

private let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    f.maximumFractionDigits = 0
    return f
}()
