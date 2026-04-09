import SwiftUI

private enum CatalogRoute: Hashable {
    case product(UUID)
}

struct CatalogRootView: View {
    let container: AppContainer

    @State private var viewModel: CatalogListViewModel
    @State private var path: [CatalogRoute] = []
    @State private var isScannerPresented = false
    @State private var scannerViewModel: ScannerViewModel?
    @State private var pendingScannerResolution: ScanResolution?
    @State private var pendingDraft: ProductDraft?

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeCatalogListViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.products.isEmpty, viewModel.isLoading == false {
                    ContentUnavailableView(
                        "Scan Your First Item",
                        systemImage: "barcode.viewfinder",
                        description: Text("Use the camera to scan a product barcode, then save the price you paid.")
                    )
                } else {
                    List {
                        ForEach(viewModel.products) { product in
                            Button {
                                path.append(.product(product.id))
                            } label: {
                                ProductRowView(summary: product)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: viewModel.deleteProducts)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("How Much?")
            .searchable(text: $viewModel.searchText, prompt: "Search name, barcode, or store")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        scannerViewModel = container.makeScannerViewModel()
                        isScannerPresented = true
                    } label: {
                        Label("Scan", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .task {
                viewModel.load()
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.load()
            }
            .onChange(of: viewModel.sortOption) { _, _ in
                viewModel.load()
            }
            .navigationDestination(for: CatalogRoute.self) { route in
                switch route {
                case .product(let productID):
                    ProductDetailView(
                        viewModel: container.makeProductDetailViewModel(productID: productID),
                        onChanged: {
                            viewModel.load()
                        },
                        onDeleted: {
                            viewModel.load()
                            path.removeAll()
                        }
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
                    ProgressView()
                        .presentationDetents([.medium])
                }
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
        .alert("Catalog Error", isPresented: errorAlertBinding) {
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

    private func handleScannerDismiss() {
        let resolution = pendingScannerResolution
        pendingScannerResolution = nil
        scannerViewModel = nil
        viewModel.load()

        guard let resolution else {
            return
        }

        switch resolution {
        case .existing(let product):
            path.append(.product(product.id))
        case .newDraft(let draft):
            pendingDraft = draft
        }
    }
}

private struct ProductRowView: View {
    let summary: ProductSummary

    private var history: PriceHistorySnapshot {
        PriceHistoryCalculator.snapshot(
            for: [summary.latestEntry, summary.previousEntry].compactMap { $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.displayName)
                        .font(.headline)
                    Text(summary.barcodeValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let latest = summary.latestEntry {
                    Text(CurrencyFormatter.string(from: latest.amount, currencyCode: latest.currencyCode))
                        .font(.headline)
                }
            }

            if let latest = history.latest {
                Text("Last price: \(CurrencyFormatter.string(from: latest.amount, currencyCode: latest.currencyCode))")
                    .font(.subheadline)
            }

            if let previous = history.previous {
                Text("Previous: \(CurrencyFormatter.string(from: previous.amount, currencyCode: previous.currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let difference = history.difference, let latest = history.latest {
                Text("Difference: \(CurrencyFormatter.string(from: difference, currencyCode: latest.currencyCode, alwaysShowSign: true))")
                    .font(.subheadline)
                    .foregroundStyle(difference.sign == .minus ? .green : .orange)
            }
        }
        .padding(.vertical, 4)
    }
}
