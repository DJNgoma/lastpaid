import SwiftUI

struct ProductCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ProductCaptureViewModel
    let onSaved: (ProductDetail) -> Void

    init(viewModel: ProductCaptureViewModel, onSaved: @escaping (ProductDetail) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Barcode", text: $viewModel.barcodeValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Barcode Type", selection: $viewModel.barcodeType) {
                        ForEach(BarcodeType.userSelectableCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Product Name", text: $viewModel.customName)
                    TextField("Brand", text: $viewModel.brand)
                }

                Section("Price") {
                    TextField("Price Paid", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    TextField("Currency Code", text: $viewModel.currencyCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    DatePicker("Purchase Date", selection: $viewModel.purchasedAt, displayedComponents: .date)
                    TextField("Store", text: $viewModel.storeName)
                    TextField("Quantity / Pack Size", text: $viewModel.quantityText)
                    TextField("Notes", text: $viewModel.notes, axis: .vertical)
                }

                RecentStoresSection(stores: viewModel.recentStores) { store in
                    viewModel.storeName = store
                }
            }
            .navigationTitle("Save Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSave()
                    }
                    .disabled(viewModel.canSave == false || viewModel.isSaving)
                }
            }
        }
        .task {
            viewModel.loadRecentStores()
        }
        .alert("Unable to Save", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { }
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

    private func handleSave() {
        if let detail = viewModel.save() {
            onSaved(detail)
            dismiss()
        }
    }
}
