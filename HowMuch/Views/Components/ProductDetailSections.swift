import SwiftUI

struct HeroPriceCard: View {
    let product: ProductDetail
    let snapshot: PriceHistorySnapshot
    let onAddPrice: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            if let latest = snapshot.latest {
                VStack(spacing: 8) {
                    Text("LAST PAID")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)

                    PriceBadge(
                        amount: latest.amount,
                        currencyCode: latest.currencyCode,
                        emphasis: .hero
                    )
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                    PriceTrendChip(latest: latest, previous: snapshot.previous)

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                        Text(latest.purchasedAt, format: .dateTime.month(.abbreviated).day().year())
                        if let store = latest.storeName {
                            Text("·")
                            Image(systemName: "bag.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(store)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                    if let place = latest.placeName {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(place)
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                }

                if let previous = snapshot.previous {
                    Divider()
                    HStack {
                        Text("Previous")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.string(from: previous.amount, currencyCode: previous.currencyCode))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(previous.purchasedAt, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "tag")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                    Text("No price saved yet")
                        .font(.headline)
                    Text("Add the price you paid so you can recall it next time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)
            }

            Button {
                Haptics.medium()
                onAddPrice()
            } label: {
                Label("Add New Price", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.28), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(PressableScaleButtonStyle())
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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

struct CheapestPlacesCard: View {
    let snapshot: CheapestPlacesSnapshot
    var title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                if snapshot.places.isEmpty == false {
                    Text("Top \(snapshot.places.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if snapshot.places.isEmpty {
                Text("Add a store or tagged location to compare places later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.places.enumerated()), id: \.element.id) { index, place in
                        CheapestPlaceRow(rank: index + 1, summary: place)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                        if index < snapshot.places.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )

                if snapshot.usesEnteredQuantities {
                    Text("Prices are compared as entered. Pack sizes may differ.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct CheapestPlaceRow: View {
    let rank: Int
    let summary: CheapestPlaceSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: summary.sourceKind.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(summary.label)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(summary.purchasedAt, format: .dateTime.month(.abbreviated).day().year())
                    if let quantityText = summary.quantityText {
                        Text("·")
                        Text(quantityText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.string(from: summary.amount, currencyCode: summary.currencyCode))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
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
