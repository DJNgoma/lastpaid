import SwiftUI

private enum CatalogRoute: Hashable {
    case product(UUID)
    case browseAll
}

// MARK: - Root

struct CatalogRootView: View {
    let container: AppContainer

    @State private var viewModel: CatalogListViewModel
    @State private var path: [CatalogRoute] = []
    @State private var isScannerPresented = false
    @State private var isManualEntryPresented = false
    @State private var scannerViewModel: ScannerViewModel?
    @State private var pendingScannerResolution: ScanResolution?
    @State private var pendingDraft: ProductDraft?
    @State private var manualBarcode = ""
    @State private var manualBarcodeType: BarcodeType = .ean13

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeCatalogListViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                viewModel: viewModel,
                onScan: presentScanner,
                onManualEntry: { isManualEntryPresented = true },
                onOpenProduct: { path.append(.product($0)) },
                onBrowseAll: { path.append(.browseAll) }
            )
            .navigationTitle("How Much?")
            .searchable(text: $viewModel.searchText, prompt: "Search products or barcodes")
            .task { viewModel.load() }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.load() }
            .onChange(of: viewModel.sortOption) { _, _ in viewModel.load() }
            .navigationDestination(for: CatalogRoute.self) { route in
                switch route {
                case .product(let id):
                    ProductDetailView(
                        viewModel: container.makeProductDetailViewModel(productID: id),
                        onChanged: { viewModel.load() },
                        onDeleted: {
                            viewModel.load()
                            path.removeAll()
                        }
                    )
                case .browseAll:
                    ProductListView(
                        viewModel: viewModel,
                        onOpenProduct: { path.append(.product($0)) }
                    )
                }
            }
            .sheet(isPresented: $isScannerPresented, onDismiss: handleScannerDismiss) {
                if let scannerViewModel {
                    ScannerView(viewModel: scannerViewModel) { resolution in
                        pendingScannerResolution = resolution
                        isScannerPresented = false
                    }
                } else {
                    ProgressView().presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $isManualEntryPresented) {
                HomeManualEntrySheet(
                    barcode: $manualBarcode,
                    barcodeType: $manualBarcodeType,
                    onSubmit: handleManualEntrySubmit
                )
            }
            .sheet(item: $pendingDraft) { draft in
                ProductCaptureView(
                    initialDraft: draft,
                    catalogService: container.catalogService
                ) { detail in
                    pendingDraft = nil
                    viewModel.load()
                    path.append(.product(detail.id))
                }
            }
        }
        .alert("Something Went Wrong", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if $0 == false { viewModel.clearError() } }
        )
    }

    private func presentScanner() {
        scannerViewModel = container.makeScannerViewModel()
        isScannerPresented = true
    }

    private func handleScannerDismiss() {
        let resolution = pendingScannerResolution
        pendingScannerResolution = nil
        scannerViewModel = nil
        viewModel.load()

        guard let resolution else { return }
        handle(resolution)
    }

    private func handleManualEntrySubmit() {
        do {
            let normalized = try BarcodeNormalizer.validated(manualBarcode)
            let resolution = try container.catalogService.resolveScan(
                ScannedBarcode(payload: normalized, symbology: manualBarcodeType)
            )
            manualBarcode = ""
            isManualEntryPresented = false
            viewModel.load()
            handle(resolution)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func handle(_ resolution: ScanResolution) {
        switch resolution {
        case .existing(let product):
            path.append(.product(product.id))
        case .newDraft(let draft):
            pendingDraft = draft
        }
    }
}

// MARK: - Home Screen

private struct HomeScreen: View {
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
        .background(Color(.systemGroupedBackground))
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

// MARK: - Recent Row

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

// MARK: - Browse-all list

private struct ProductListView: View {
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
        .searchable(text: $viewModel.searchText, prompt: "Search products or barcodes")
    }
}

// MARK: - Manual Entry Sheet

private struct HomeManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var barcode: String
    @Binding var barcodeType: BarcodeType
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Barcode") {
                    TextField("Barcode number", text: $barcode)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Type", selection: $barcodeType) {
                        ForEach(BarcodeType.allCases) { type in
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

// MARK: - Reusable: PriceBadge

struct PriceBadge: View {
    let amount: Decimal
    let currencyCode: String
    var emphasis: Emphasis = .regular

    enum Emphasis { case regular, hero }

    var body: some View {
        Text(CurrencyFormatter.string(from: amount, currencyCode: currencyCode))
            .font(emphasis == .hero
                  ? .system(size: 52, weight: .bold, design: .rounded)
                  : .system(size: 16, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.primary)
    }
}

// MARK: - Reusable: HistoryRow

struct HistoryRow: View {
    let entry: PriceEntryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(CurrencyFormatter.string(from: entry.amount, currencyCode: entry.currencyCode))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text(entry.purchasedAt, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if let store = entry.storeName {
                    Label(store, systemImage: "bag")
                }
                if let qty = entry.quantityText {
                    if entry.storeName != nil { Text("·") }
                    Text(qty)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if let notes = entry.notes, notes.isEmpty == false {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reusable: EmptyStateView

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
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
