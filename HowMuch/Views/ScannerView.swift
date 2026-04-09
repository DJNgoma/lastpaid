import SwiftUI
import UIKit

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: ScannerViewModel
    let onResolved: (ScanResolution) -> Void

    init(viewModel: ScannerViewModel, onResolved: @escaping (ScanResolution) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onResolved = onResolved
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                scannerContent

                Button {
                    viewModel.beginManualEntry()
                } label: {
                    Label("Enter Barcode Manually", systemImage: "keyboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if viewModel.permissionStatus == .denied {
                    Button("Open Settings") {
                        openSettings()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Scan Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.requestAccessIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }

            Task {
                await viewModel.handleAppDidBecomeActive()
            }
        }
        .onChange(of: viewModel.resolution) { _, newValue in
            guard let newValue else {
                return
            }
            onResolved(newValue)
            viewModel.consumeResolution()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .sheet(isPresented: $viewModel.isManualEntryPresented) {
            ManualBarcodeEntryView(
                barcodeValue: $viewModel.manualBarcodeValue,
                barcodeType: $viewModel.manualBarcodeType,
                onCancel: {
                    viewModel.endManualEntry()
                },
                onSubmit: {
                    viewModel.submitManualBarcode()
                },
                onSubmitSuccess: {
                    viewModel.endManualEntry()
                }
            )
        }
        .alert("Scanner Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch viewModel.permissionStatus {
        case .authorized:
            VStack(alignment: .leading, spacing: 12) {
                CameraPreviewView(session: viewModel.captureSession)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignment: .center) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.white.opacity(0.85), lineWidth: 2)
                            .frame(width: 240, height: 160)
                    }

                Text("Point the barcode inside the frame. Scanning pauses after the first valid read.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("If the code is hard to read, move closer or improve the lighting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .notDetermined:
            ContentUnavailableView(
                "Camera Access Needed",
                systemImage: "camera",
                description: Text("Allow camera access to scan product barcodes. Manual entry is always available.")
            )
        case .denied:
            ContentUnavailableView(
                "Camera Access Denied",
                systemImage: "camera.fill.badge.ellipsis",
                description: Text("Use manual barcode entry or enable camera access in Settings.")
            )
        case .restricted:
            ContentUnavailableView(
                "Camera Access Restricted",
                systemImage: "lock.slash",
                description: Text("This device cannot grant camera access right now. Use manual barcode entry instead.")
            )
        case .unsupported:
            ContentUnavailableView(
                "Camera Unavailable",
                systemImage: "barcode.slash",
                description: Text("Barcode scanning is not available on this device or in the simulator.")
            )
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

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

private struct ManualBarcodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var barcodeValue: String
    @Binding var barcodeType: BarcodeType
    let onCancel: () -> Void
    let onSubmit: () -> Bool
    let onSubmitSuccess: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Barcode") {
                    TextField("Barcode Value", text: $barcodeValue)
                        .keyboardType(barcodeType.isNumericRetailCode ? .numberPad : .asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Barcode Type", selection: $barcodeType) {
                        ForEach(BarcodeType.userSelectableCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
            }
            .navigationTitle("Manual Barcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Barcode") {
                        if onSubmit() {
                            onSubmitSuccess()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
