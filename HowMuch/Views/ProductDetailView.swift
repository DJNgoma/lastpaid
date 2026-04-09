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
                List {
                    Section("Product") {
                        LabeledContent("Name", value: product.displayName)
                        LabeledContent("Barcode", value: product.barcodeValue)
                        LabeledContent("Barcode Type", value: product.barcodeType.rawValue)

                        if let brand = product.brand {
                            LabeledContent("Brand", value: brand)
                        }
                    }

                    Section("Price Snapshot") {
                        if let latest = viewModel.historySnapshot.latest {
                            LabeledContent(
                                "Last Price",
                                value: CurrencyFormatter.string(from: latest.amount, currencyCode: latest.currencyCode)
                            )
                            .font(.headline)

                            if let previous = viewModel.historySnapshot.previous {
                                LabeledContent(
                                    "Previous",
                                    value: CurrencyFormatter.string(from: previous.amount, currencyCode: previous.currencyCode)
                                )
                            }

                            if let difference = viewModel.historySnapshot.difference {
                                LabeledContent(
                                    "Difference",
                                    value: CurrencyFormatter.string(
                                        from: difference,
                                        currencyCode: latest.currencyCode,
                                        alwaysShowSign: true
                                    )
                                )
                                .foregroundStyle(difference.sign == .minus ? .green : .orange)
                            }
                        } else {
                            Text("No price history yet.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("History") {
                        if product.entries.isEmpty {
                            Text("Add a price entry to start tracking changes over time.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(product.entries) { entry in
                                PriceHistoryRow(entry: entry)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button("Edit") {
                                            editingEntry = entry
                                        }
                                        .tint(.blue)

                                        Button("Delete", role: .destructive) {
                                            deletingEntry = entry
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(product.displayName)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Edit Product") {
                            isEditingProduct = true
                        }

                        Button("Add Price") {
                            isAddingPrice = true
                        }
                    }

                    ToolbarItem(placement: .bottomBar) {
                        Button("Delete Product", role: .destructive) {
                            isConfirmingDeleteProduct = true
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

private struct PriceHistoryRow: View {
    let entry: PriceEntryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(CurrencyFormatter.string(from: entry.amount, currencyCode: entry.currencyCode))
                    .font(.headline)
                Spacer()
                Text(entry.purchasedAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let storeName = entry.storeName {
                Label(storeName, systemImage: "storefront")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let quantityText = entry.quantityText {
                Text("Quantity: \(quantityText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let notes = entry.notes {
                Text(notes)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }
}
