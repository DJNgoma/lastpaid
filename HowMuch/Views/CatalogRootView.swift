import SwiftUI

private enum CatalogRoute: Hashable {
    case product(UUID)
    case browseAll
}

private enum CatalogSheet: Identifiable {
    case scanner
    case manualEntry
    case capture(ProductDraft)

    var id: String {
        switch self {
        case .scanner:
            "scanner"
        case .manualEntry:
            "manual-entry"
        case .capture(let draft):
            "capture-\(draft.id.uuidString)"
        }
    }
}

@MainActor
struct CatalogRootView: View {
    @State private var viewModel: CatalogListViewModel
    private let makeScannerViewModel: () -> ScannerViewModel
    private let makeProductCaptureViewModel: (ProductDraft) -> ProductCaptureViewModel
    private let makeProductDetailViewModel: (UUID) -> ProductDetailViewModel

    @State private var path: [CatalogRoute] = []
    @State private var presentedSheet: CatalogSheet?
    @State private var scannerViewModel: ScannerViewModel?
    @State private var pendingScannerResolution: ScanResolution?
    @State private var manualBarcode = ""
    @State private var manualBarcodeType: BarcodeType = BarcodeType.userSelectableCases.first ?? .ean13

    init(
        viewModel: CatalogListViewModel,
        makeScannerViewModel: @escaping () -> ScannerViewModel,
        makeProductCaptureViewModel: @escaping (ProductDraft) -> ProductCaptureViewModel,
        makeProductDetailViewModel: @escaping (UUID) -> ProductDetailViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeScannerViewModel = makeScannerViewModel
        self.makeProductCaptureViewModel = makeProductCaptureViewModel
        self.makeProductDetailViewModel = makeProductDetailViewModel
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(
                viewModel: viewModel,
                onScan: presentScanner,
                onManualEntry: { presentedSheet = .manualEntry },
                onOpenProduct: { path.append(.product($0)) },
                onBrowseAll: { path.append(.browseAll) }
            )
            .navigationTitle("How Much?")
            .searchable(text: $viewModel.searchText, prompt: "Search products, barcodes, or stores")
            .task { viewModel.loadIfNeeded() }
            .onChange(of: viewModel.searchText) { _, _ in viewModel.scheduleLoad() }
            .onChange(of: viewModel.sortOption) { _, _ in viewModel.scheduleLoad(immediate: true) }
            .navigationDestination(for: CatalogRoute.self) { route in
                switch route {
                case .product(let id):
                    ProductDetailView(
                        viewModel: makeProductDetailViewModel(id),
                        onChanged: { viewModel.scheduleLoad(immediate: true) },
                        onDeleted: {
                            viewModel.scheduleLoad(immediate: true)
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
            .sheet(item: $presentedSheet, onDismiss: handleSheetDismiss) { sheet in
                switch sheet {
                case .scanner:
                    if let scannerViewModel {
                        ScannerView(viewModel: scannerViewModel) { resolution in
                            pendingScannerResolution = resolution
                            presentedSheet = nil
                        }
                    } else {
                        ProgressView().presentationDetents([.medium])
                    }
                case .manualEntry:
                    HomeManualEntrySheet(
                        barcode: $manualBarcode,
                        barcodeType: $manualBarcodeType,
                        onSubmit: handleManualEntrySubmit
                    )
                case .capture(let draft):
                    ProductCaptureView(
                        viewModel: makeProductCaptureViewModel(draft)
                    ) { detail in
                        presentedSheet = nil
                        viewModel.scheduleLoad(immediate: true)
                        path.append(.product(detail.id))
                    }
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
        scannerViewModel = makeScannerViewModel()
        presentedSheet = .scanner
    }

    private func handleSheetDismiss() {
        let resolution = pendingScannerResolution
        pendingScannerResolution = nil

        if scannerViewModel != nil {
            scannerViewModel = nil
            viewModel.scheduleLoad(immediate: true)
        }

        guard let resolution else {
            return
        }

        handle(resolution)
    }

    private func handleManualEntrySubmit() {
        guard let resolution = viewModel.resolveManualBarcode(manualBarcode, type: manualBarcodeType) else {
            return
        }

        manualBarcode = ""
        presentedSheet = nil
        viewModel.scheduleLoad(immediate: true)
        handle(resolution)
    }

    private func handle(_ resolution: ScanResolution) {
        switch resolution {
        case .existing(let product):
            path.append(.product(product.id))
        case .newDraft(let draft):
            presentedSheet = .capture(draft)
        }
    }
}
