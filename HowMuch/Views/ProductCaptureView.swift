import SwiftUI

struct ProductCaptureView: View {
    @Environment(\.dismiss) private var dismiss

    let initialDraft: ProductDraft
    let catalogService: any CatalogServicing
    let onSaved: (ProductDetail) -> Void

    @State private var barcodeValue: String
    @State private var barcodeType: BarcodeType
    @State private var customName: String
    @State private var brand: String
    @State private var priceText: String = ""
    @State private var currencyCode = "ZAR"
    @State private var storeName: String = ""
    @State private var quantityText: String = ""
    @State private var notes: String = ""
    @State private var purchasedAt: Date = .now
    @State private var recentStores: [String] = []
    @State private var errorMessage: String?

    init(
        initialDraft: ProductDraft,
        catalogService: any CatalogServicing,
        onSaved: @escaping (ProductDetail) -> Void
    ) {
        self.initialDraft = initialDraft
        self.catalogService = catalogService
        self.onSaved = onSaved
        _barcodeValue = State(initialValue: initialDraft.barcodeValue)
        _barcodeType = State(initialValue: initialDraft.barcodeType)
        _customName = State(initialValue: initialDraft.customName)
        _brand = State(initialValue: initialDraft.brand ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Barcode", text: $barcodeValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Barcode Type", selection: $barcodeType) {
                        ForEach(BarcodeType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    TextField("Product Name", text: $customName)
                    TextField("Brand", text: $brand)
                }

                Section("Price") {
                    TextField("Price Paid", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField("Currency Code", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    DatePicker("Purchase Date", selection: $purchasedAt, displayedComponents: .date)
                    TextField("Store", text: $storeName)
                    TextField("Quantity / Pack Size", text: $quantityText)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                if recentStores.isEmpty == false {
                    Section("Recent Stores") {
                        ForEach(recentStores, id: \.self) { store in
                            Button(store) {
                                storeName = store
                            }
                        }
                    }
                }
            }
            .navigationTitle("Save Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
        .task {
            recentStores = (try? catalogService.recentStores(limit: 6)) ?? []
        }
        .alert("Unable to Save", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    errorMessage = nil
                }
            }
        )
    }

    private func save() {
        do {
            let amount = try DecimalParser.parseCurrencyInput(priceText)
            let productDraft = ProductDraft(
                barcodeValue: barcodeValue,
                barcodeType: barcodeType,
                customName: customName,
                brand: brand
            )
            let entryDraft = PriceEntryDraft(
                amount: amount,
                currencyCode: currencyCode,
                storeName: storeName,
                quantityText: quantityText,
                notes: notes,
                purchasedAt: purchasedAt
            )

            let detail = try catalogService.saveNewProduct(productDraft, initialPriceEntry: entryDraft)
            onSaved(detail)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
