import SwiftUI

struct PriceEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let existingEntry: PriceEntryRecord?
    let recentStores: [String]
    let locationService: (any LocationServicing)?
    let onSave: (PriceEntryDraft) -> Bool

    @State private var priceText: String
    @State private var currencyCode: String
    @State private var storeName: String
    @State private var quantityText: String
    @State private var notes: String
    @State private var purchasedAt: Date
    @State private var errorMessage: String?
    @State private var capturedLocation: CapturedLocation?
    @State private var isCapturingLocation = false

    init(
        title: String,
        existingEntry: PriceEntryRecord? = nil,
        recentStores: [String],
        locationService: (any LocationServicing)? = nil,
        onSave: @escaping (PriceEntryDraft) -> Bool
    ) {
        self.title = title
        self.existingEntry = existingEntry
        self.recentStores = recentStores
        self.locationService = locationService
        self.onSave = onSave
        _priceText = State(initialValue: existingEntry.map { "\($0.amount)" } ?? "")
        _currencyCode = State(initialValue: existingEntry?.currencyCode ?? "ZAR")
        _storeName = State(initialValue: existingEntry?.storeName ?? "")
        _quantityText = State(initialValue: existingEntry?.quantityText ?? "")
        _notes = State(initialValue: existingEntry?.notes ?? "")
        _purchasedAt = State(initialValue: existingEntry?.purchasedAt ?? .now)
        if let existingEntry, let lat = existingEntry.latitude, let lon = existingEntry.longitude {
            _capturedLocation = State(initialValue: CapturedLocation(
                latitude: lat,
                longitude: lon,
                placeName: existingEntry.placeName
            ))
        }
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

                Section("Location") {
                    LocationPill(
                        capturedLocation: capturedLocation,
                        isCapturing: isCapturingLocation,
                        onTagAgain: { Task { await captureLocation(force: true) } },
                        onClear: { capturedLocation = nil }
                    )
                }

                RecentStoresSection(stores: recentStores) { store in
                    storeName = store
                }
            }
            .task {
                await captureLocation(force: false)
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
                purchasedAt: purchasedAt,
                latitude: capturedLocation?.latitude,
                longitude: capturedLocation?.longitude,
                placeName: capturedLocation?.placeName
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

    private func captureLocation(force: Bool) async {
        guard let locationService else { return }
        if force == false, capturedLocation != nil { return }
        if force { capturedLocation = nil }
        guard isCapturingLocation == false else { return }
        isCapturingLocation = true
        capturedLocation = await locationService.captureCurrent()
        isCapturingLocation = false
    }
}

// MARK: - LocationPill (reusable)

struct LocationPill: View {
    let capturedLocation: CapturedLocation?
    let isCapturing: Bool
    let onTagAgain: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: capturedLocation == nil ? "location.slash" : "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(capturedLocation == nil ? .secondary : Color.accentColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill((capturedLocation == nil ? Color.secondary : Color.accentColor).opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                if isCapturing {
                    Text("Finding location…")
                        .font(.subheadline.weight(.medium))
                    Text("This only happens when you save")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let captured = capturedLocation {
                    Text(captured.placeName ?? "Tagged")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(String(format: "%.4f, %.4f", captured.latitude, captured.longitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text("No location tagged")
                        .font(.subheadline.weight(.medium))
                    Text("Enable Location to remember where you bought it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if isCapturing {
                ProgressView()
                    .controlSize(.small)
            } else if capturedLocation != nil {
                Menu {
                    Button {
                        onTagAgain()
                    } label: {
                        Label("Re-tag here", systemImage: "location.fill.viewfinder")
                    }
                    Button(role: .destructive) {
                        onClear()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                }
            } else {
                Button {
                    onTagAgain()
                } label: {
                    Text("Tag")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.14))
                        )
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
