import SwiftUI

struct HeroPriceCard: View {
    let product: ProductDetail
    let snapshot: PriceHistorySnapshot
    let onAddPrice: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let latest = snapshot.latest {
                VStack(spacing: 6) {
                    Text("Last paid")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    PriceBadge(
                        amount: latest.amount,
                        currencyCode: latest.currencyCode,
                        emphasis: .hero
                    )

                    HStack(spacing: 6) {
                        Text(latest.purchasedAt, format: .dateTime.month(.abbreviated).day().year())
                        if let store = latest.storeName {
                            Text("·")
                            Text(store)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if snapshot.previous != nil || snapshot.difference != nil {
                    Divider()
                    comparisonRow
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tag")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No price saved yet")
                        .font(.headline)
                    Text("Add the price you paid so you can recall it next time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            }

            Button(action: onAddPrice) {
                Label("Add New Price", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private var comparisonRow: some View {
        HStack(alignment: .top, spacing: 12) {
            if let previous = snapshot.previous {
                stat(
                    label: "Previous",
                    value: CurrencyFormatter.string(from: previous.amount, currencyCode: previous.currencyCode),
                    tint: .secondary
                )
            }
            if let difference = snapshot.difference, let latest = snapshot.latest {
                Divider().frame(height: 32)
                stat(
                    label: "Change",
                    value: CurrencyFormatter.string(
                        from: difference,
                        currencyCode: latest.currencyCode,
                        alwaysShowSign: true
                    ),
                    tint: difference.sign == .minus ? .green : .orange
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProductMetaCard: View {
    let product: ProductDetail

    var body: some View {
        VStack(spacing: 0) {
            row(label: "Barcode", value: product.barcodeValue)
            Divider().padding(.leading, 16)
            row(label: "Type", value: product.barcodeType.rawValue)
            if let brand = product.brand {
                Divider().padding(.leading, 16)
                row(label: "Brand", value: brand)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct HistorySection: View {
    let entries: [PriceEntryRecord]
    let onEdit: (PriceEntryRecord) -> Void
    let onDelete: (PriceEntryRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price History")
                .font(.title3.weight(.semibold))
                .padding(.leading, 4)

            if entries.isEmpty {
                EmptyStateView(
                    systemImage: "clock",
                    title: "No history yet",
                    message: "Saved prices will appear here."
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HistoryRow(entry: entry)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    onEdit(entry)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                        if index < entries.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }
}
