import SwiftUI

@MainActor
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
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            content
        }
        .navigationTitle(viewModel.product?.displayName ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
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

    @ViewBuilder
    private var content: some View {
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
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Product Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(viewModel.errorMessage ?? "The product could not be loaded.")
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.product != nil {
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
