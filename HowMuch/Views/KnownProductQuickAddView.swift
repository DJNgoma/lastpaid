import SwiftUI

struct KnownProductQuickAddView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: KnownProductQuickAddViewModel

    let onSaved: (ProductDetail) -> Void
    let onViewHistory: (UUID) -> Void

    init(
        viewModel: KnownProductQuickAddViewModel,
        onSaved: @escaping (ProductDetail) -> Void,
        onViewHistory: @escaping (UUID) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
        self.onViewHistory = onViewHistory
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    QuickAddLatestPriceCard(
                        product: viewModel.product,
                        snapshot: viewModel.historySnapshot
                    )
                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section {
                    CheapestPlacesCard(
                        snapshot: viewModel.cheapestPlacesSnapshot,
                        title: "Cheapest Places"
                    )
                    .listRowInsets(.init(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }

                Section("New Price") {
                    TextField("Price Paid", text: $viewModel.priceText)
                        .keyboardType(.decimalPad)
                    DatePicker("Purchase Date", selection: $viewModel.purchasedAt, displayedComponents: .date)
                    TextField("Store", text: $viewModel.storeName)
                    TextField("Quantity / Pack Size", text: $viewModel.quantityText)
                }

                Section("Location") {
                    LocationPill(
                        capturedLocation: viewModel.capturedLocation,
                        isCapturing: viewModel.isCapturingLocation,
                        onTagAgain: { Task { await viewModel.captureLocationIfPossible(force: true) } },
                        onClear: { viewModel.clearLocation() }
                    )
                }

                RecentStoresSection(stores: viewModel.recentStores) { store in
                    viewModel.storeName = store
                }

                Section {
                    Button {
                        onViewHistory(viewModel.product.id)
                    } label: {
                        Label("View Full History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                }
            }
            .navigationTitle("Update Price")
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
            viewModel.loadSupportingData()
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
        guard let updated = viewModel.save() else {
            return
        }

        onSaved(updated)
    }
}

private struct QuickAddLatestPriceCard: View {
    let product: ProductDetail
    let snapshot: PriceHistorySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(product.displayName)
                .font(.title3.weight(.semibold))

            if let latest = snapshot.latest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LAST PAID")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)

                    PriceBadge(
                        amount: latest.amount,
                        currencyCode: latest.currencyCode,
                        emphasis: .hero
                    )
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

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

                    if let place = latest.placeName {
                        Label(place, systemImage: "location.fill")
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
                Text("No saved price yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
