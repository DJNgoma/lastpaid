import SwiftUI

struct HomeScreen: View {
    @Bindable var viewModel: CatalogListViewModel
    let onScan: () -> Void
    let onManualEntry: () -> Void
    let onOpenProduct: (UUID) -> Void
    let onBrowseAll: () -> Void

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                primaryActions
                    .padding(.top, 8)

                if viewModel.products.isEmpty && isSearching == false {
                    EmptyHomeState()
                        .padding(.top, 24)
                } else if viewModel.products.isEmpty && isSearching {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No Matches",
                        message: "Try a different name or barcode."
                    )
                    .padding(.top, 24)
                } else {
                    recentSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
            Button(action: onScan) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 26, weight: .semibold))
                    Text("Scan Barcode")
                        .font(.system(size: 19, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)

            Button(action: onManualEntry) {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Enter Barcode Manually")
                        .font(.system(size: 16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(Color.accentColor)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isSearching ? "Results" : "Recent")
                    .font(.title3.weight(.semibold))
                Spacer()
                if isSearching == false, viewModel.products.count > 5 {
                    Button("See All", action: onBrowseAll)
                        .font(.subheadline.weight(.medium))
                }
            }

            VStack(spacing: 0) {
                let items = isSearching ? viewModel.products : Array(viewModel.products.prefix(5))
                ForEach(Array(items.enumerated()), id: \.element.id) { index, product in
                    Button {
                        onOpenProduct(product.id)
                    } label: {
                        RecentProductRow(summary: product)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
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

private struct RecentProductRow: View {
    let summary: ProductSummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let store = summary.latestEntry?.storeName {
                        Text(store).lineLimit(1)
                    } else {
                        Text(summary.barcodeValue).lineLimit(1)
                    }
                    if let date = summary.latestEntry?.purchasedAt {
                        Text("·")
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let latest = summary.latestEntry {
                PriceBadge(amount: latest.amount, currencyCode: latest.currencyCode)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

struct ProductListView: View {
    @Bindable var viewModel: CatalogListViewModel
    let onOpenProduct: (UUID) -> Void

    var body: some View {
        List {
            ForEach(viewModel.products) { product in
                Button {
                    onOpenProduct(product.id)
                } label: {
                    RecentProductRow(summary: product)
                }
                .buttonStyle(.plain)
            }
            .onDelete(perform: viewModel.deleteProducts)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("All Items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $viewModel.sortOption) {
                        ForEach(ProductSortOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search products, barcodes, or stores")
    }
}

struct HomeManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var barcode: String
    @Binding var barcodeType: BarcodeType
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Barcode") {
                    TextField("Barcode number", text: $barcode)
                        .keyboardType(barcodeType.isNumericRetailCode ? .numberPad : .asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Type", selection: $barcodeType) {
                        ForEach(BarcodeType.userSelectableCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Enter Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { onSubmit() }
                        .disabled(barcode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct EmptyHomeState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.8))
            Text("No items yet")
                .font(.title3.weight(.semibold))
            Text("Scan a product barcode to remember what you paid.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
