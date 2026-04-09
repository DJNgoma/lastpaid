import SwiftUI

struct ProductMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let product: ProductDetail
    let onSave: (ProductUpdateDraft) -> Bool

    @State private var barcodeValue: String
    @State private var barcodeType: BarcodeType
    @State private var customName: String
    @State private var brand: String
    @State private var errorMessage: String?

    init(product: ProductDetail, onSave: @escaping (ProductUpdateDraft) -> Bool) {
        self.product = product
        self.onSave = onSave
        _barcodeValue = State(initialValue: product.barcodeValue)
        _barcodeType = State(initialValue: product.barcodeType)
        _customName = State(initialValue: product.customName)
        _brand = State(initialValue: product.brand ?? "")
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
            }
            .navigationTitle("Edit Product")
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
        let draft = ProductUpdateDraft(
            productID: product.id,
            barcodeValue: barcodeValue,
            barcodeType: barcodeType,
            customName: customName,
            brand: brand
        )

        if onSave(draft) {
            dismiss()
        } else {
            errorMessage = "The product could not be saved. Check the barcode and try again."
        }
    }
}
