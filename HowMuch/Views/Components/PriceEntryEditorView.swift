import SwiftUI

struct PriceEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let existingEntry: PriceEntryRecord?
    let recentStores: [String]
    let onSave: (PriceEntryDraft) -> Bool

    @State private var priceText: String
    @State private var currencyCode: String
    @State private var storeName: String
    @State private var quantityText: String
    @State private var notes: String
    @State private var purchasedAt: Date
    @State private var errorMessage: String?

    init(
        title: String,
        existingEntry: PriceEntryRecord? = nil,
        recentStores: [String],
        onSave: @escaping (PriceEntryDraft) -> Bool
    ) {
        self.title = title
        self.existingEntry = existingEntry
        self.recentStores = recentStores
        self.onSave = onSave
        _priceText = State(initialValue: existingEntry.map { "\($0.amount)" } ?? "")
        _currencyCode = State(initialValue: existingEntry?.currencyCode ?? "ZAR")
        _storeName = State(initialValue: existingEntry?.storeName ?? "")
        _quantityText = State(initialValue: existingEntry?.quantityText ?? "")
        _notes = State(initialValue: existingEntry?.notes ?? "")
        _purchasedAt = State(initialValue: existingEntry?.purchasedAt ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Price") {
                    TextField("Price Paid", text: $priceText)
                        .keyboardType(.decimalPad)
                    TextField("Currency Code", text: $currencyCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    DatePicker("Purchase Date", selection: $purchasedAt, displayedComponents: .date)
                }

                Section("Details") {
                    TextField("Store", text: $storeName)
                    TextField("Quantity / Pack Size", text: $quantityText)
                    TextField("Notes", text: $notes, axis: .vertical)
                }

                RecentStoresSection(stores: recentStores) { store in
                    storeName = store
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
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
                    .disabled(canSave == false)
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

    private var canSave: Bool {
        priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func save() {
        do {
            let amount = try DecimalParser.parseCurrencyInput(priceText)
            let draft = PriceEntryDraft(
                amount: amount,
                currencyCode: currencyCode,
                storeName: storeName,
                quantityText: quantityText,
                notes: notes,
                purchasedAt: purchasedAt
            )

            if onSave(draft) {
                dismiss()
            } else {
                errorMessage = "The price entry could not be saved."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
