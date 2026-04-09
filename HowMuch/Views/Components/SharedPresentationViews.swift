import SwiftUI

struct PriceBadge: View {
    let amount: Decimal
    let currencyCode: String
    var emphasis: Emphasis = .regular

    enum Emphasis {
        case regular
        case hero
    }

    var body: some View {
        Text(CurrencyFormatter.string(from: amount, currencyCode: currencyCode))
            .font(
                emphasis == .hero
                    ? .system(size: 52, weight: .bold, design: .rounded)
                    : .system(size: 16, weight: .semibold, design: .rounded)
            )
            .monospacedDigit()
            .foregroundStyle(.primary)
    }
}

struct HistoryRow: View {
    let entry: PriceEntryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(CurrencyFormatter.string(from: entry.amount, currencyCode: entry.currencyCode))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(entry.purchasedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let store = entry.storeName {
                    Label(store, systemImage: "bag")
                }
                if let quantityText = entry.quantityText {
                    if entry.storeName != nil {
                        Text("·")
                    }
                    Text(quantityText)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let place = entry.placeName {
                Label(place, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if let notes = entry.notes, notes.isEmpty == false {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct RecentStoresSection: View {
    let stores: [String]
    let onSelect: (String) -> Void

    @ViewBuilder
    var body: some View {
        if stores.isEmpty == false {
            Section("Recent Stores") {
                ForEach(stores, id: \.self) { store in
                    Button(store) {
                        onSelect(store)
                    }
                }
            }
        }
    }
}
