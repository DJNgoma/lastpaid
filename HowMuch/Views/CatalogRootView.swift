import SwiftUI

private enum CatalogRoute: Hashable {
    case product(UUID)
    case browseAll
    case settings
}

private enum CatalogSheet: Identifiable {
    case scanner
    case manualEntry
    case capture(ProductDraft)
    case quickAdd(ProductDetail, KnownProductQuickAddOrigin)

    var id: String {
        switch self {
        case .scanner:
            "scanner"
        case .manualEntry:
            "manual-entry"
        case .capture(let draft):
            "capture-\(draft.id.uuidString)"
        case .quickAdd(let product, let origin):
            "quick-add-\(product.id.uuidString)-\(origin.rawValue)"
        }
    }
}

private enum SheetFollowUp {
    case reopenScanner
    case navigateToProduct(UUID)
}

@MainActor
struct CatalogRootView: View {
    @State private var viewModel: CatalogListViewModel
    private let makeScannerViewModel: () -> ScannerViewModel
    private let makeProductCaptureViewModel: (ProductDraft) -> ProductCaptureViewModel
    private let makeProductDetailViewModel: (UUID) -> ProductDetailViewModel
    private let makeKnownProductQuickAddViewModel: (ProductDetail) -> KnownProductQuickAddViewModel

    @State private var path: [CatalogRoute] = []
    @State private var presentedSheet: CatalogSheet?
    @State private var scannerViewModel: ScannerViewModel?
    @State private var pendingScannerResolution: ScanResolution?
    @State private var pendingSheetFollowUp: SheetFollowUp?
    @State private var manualBarcode = ""
    @State private var manualBarcodeType: BarcodeType = BarcodeType.userSelectableCases.first ?? .ean13

    init(
        viewModel: CatalogListViewModel,
        makeScannerViewModel: @escaping () -> ScannerViewModel,
        makeProductCaptureViewModel: @escaping (ProductDraft) -> ProductCaptureViewModel,
        makeProductDetailViewModel: @escaping (UUID) -> ProductDetailViewModel,
        makeKnownProductQuickAddViewModel: @escaping (ProductDetail) -> KnownProductQuickAddViewModel
    ) {
        _viewModel = State(initialValue: viewModel)
        self.makeScannerViewModel = makeScannerViewModel
        self.makeProductCaptureViewModel = makeProductCaptureViewModel
        self.makeProductDetailViewModel = makeProductDetailViewModel
        self.makeKnownProductQuickAddViewModel = makeKnownProductQuickAddViewModel
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
            .navigationTitle("Last Paid")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel("Settings")
                }
            }
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
                case .settings:
                    SettingsView()
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
                case .quickAdd(let product, let origin):
                    KnownProductQuickAddView(
                        viewModel: makeKnownProductQuickAddViewModel(product)
                    ) { _ in
                        viewModel.scheduleLoad(immediate: true)
                        switch CatalogScanFlow.saveFollowUp(for: origin) {
                        case .none:
                            pendingSheetFollowUp = nil
                        case .reopenScanner:
                            pendingSheetFollowUp = .reopenScanner
                        }
                        presentedSheet = nil
                    } onViewHistory: { productID in
                        pendingSheetFollowUp = .navigateToProduct(productID)
                        presentedSheet = nil
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
        let followUp = pendingSheetFollowUp
        pendingSheetFollowUp = nil

        if scannerViewModel != nil {
            scannerViewModel = nil
            viewModel.scheduleLoad(immediate: true)
        }

        if let resolution {
            handle(resolution, knownProductOrigin: .scanner)
            return
        }

        guard let followUp else {
            return
        }

        perform(followUp: followUp)
    }

    private func handleManualEntrySubmit() {
        guard let resolution = viewModel.resolveManualBarcode(manualBarcode, type: manualBarcodeType) else {
            return
        }

        manualBarcode = ""
        presentedSheet = nil
        viewModel.scheduleLoad(immediate: true)
        handle(resolution, knownProductOrigin: .manualEntry)
    }

    private func handle(_ resolution: ScanResolution, knownProductOrigin: KnownProductQuickAddOrigin) {
        switch CatalogScanFlow.destination(for: resolution, knownProductOrigin: knownProductOrigin) {
        case .capture(let draft):
            presentedSheet = .capture(draft)
        case .quickAdd(let product, let origin):
            presentedSheet = .quickAdd(product, origin)
        }
    }

    private func perform(followUp: SheetFollowUp) {
        switch followUp {
        case .reopenScanner:
            presentScanner()
        case .navigateToProduct(let productID):
            path.append(.product(productID))
        }
    }
}
