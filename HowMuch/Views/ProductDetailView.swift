import SwiftUI

struct ProductDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ProductDetailViewModel
    @State private var isEditingProduct = false
    @State private var isAddingPrice = false
    @State private var editingEntry: PriceEntryRecord?
    @State private var deletingEntry: PriceEntryRecord?
    @State private var isConfirmingDeleteProduct = false

    let onChanged: () -> Void
    let onDeleted: () -> Void

    init(
        viewModel: ProductDetailViewModel,
        onChanged: @escaping () -> Void = {},
        onDeleted: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onChanged = onChanged
        self.onDeleted = onDeleted
    }

    var body: some View {
        Group {
            if let product = viewModel.product {
                ScrollView {
                    VStack(spacing: 20) {
                        HeroPriceCard(
                            product: product,
                            snapshot: viewModel.historySnapshot,
                            onAddPrice: { isAddingPrice = true }
                        )

                        ProductMetaCard(product: product)

                        HistorySection(
                            entries: product.entries,
                            onEdit: { editingEntry = $0 },
                            onDelete: { deletingEntry = $0 }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle(product.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                isEditingProduct = true
                            } label: {
                                Label("Edit Product", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                isConfirmingDeleteProduct = true
                            } label: {
                                Label("Delete Product", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                ContentUnavailableView(
                    "Product Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(viewModel.errorMessage ?? "The product could not be loaded.")
                )
            }
        }
        .task {
            viewModel.load()
        }
        .sheet(isPresented: $isEditingProduct) {
            if let product = viewModel.product {
                ProductMetadataEditorView(product: product) { draft in
                    let updated = viewModel.updateProduct(draft)
                    if updated {
                        onChanged()
                    }
                    return updated
                }
            }
        }
        .sheet(isPresented: $isAddingPrice) {
            PriceEntryEditorView(
                title: "Add Price",
                recentStores: viewModel.recentStores
            ) { draft in
                let updated = viewModel.addPriceEntry(draft)
                if updated {
                    onChanged()
                }
                return updated
            }
        }
        .sheet(item: $editingEntry) { entry in
            PriceEntryEditorView(
                title: "Edit Price",
                existingEntry: entry,
                recentStores: viewModel.recentStores
            ) { draft in
                let updated = viewModel.updatePriceEntry(
                    PriceEntryUpdateDraft(
                        entryID: entry.id,
                        productID: entry.productID,
                        amount: draft.amount,
                        currencyCode: draft.currencyCode,
                        storeName: draft.storeName,
                        quantityText: draft.quantityText,
                        notes: draft.notes,
                        purchasedAt: draft.purchasedAt
                    )
                )
                if updated {
                    onChanged()
                }
                return updated
            }
        }
        .confirmationDialog(
            "Delete this price entry?",
            isPresented: Binding(
                get: { deletingEntry != nil },
                set: { if $0 == false { deletingEntry = nil } }
            ),
            presenting: deletingEntry
        ) { entry in
            Button("Delete", role: .destructive) {
                if viewModel.deletePriceEntry(id: entry.id) {
                    onChanged()
                }
                deletingEntry = nil
            }
            Button("Cancel", role: .cancel) {
                deletingEntry = nil
            }
        } message: { _ in
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete this product and all price history?",
            isPresented: $isConfirmingDeleteProduct
        ) {
            Button("Delete Product", role: .destructive) {
                if viewModel.deleteProduct() {
                    onDeleted()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All saved entries for this barcode will be removed.")
        }
        .alert("Product Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    viewModel.clearError()
                }
            }
        )
    }
}

// MARK: - Hero Price Card

private struct HeroPriceCard: View {
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

// MARK: - Meta Card

private struct ProductMetaCard: View {
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

// MARK: - History Section

private struct HistorySection: View {
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
                VStack(spacing: 0) {
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
