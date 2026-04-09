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
        ZStack {
            Color.black.ignoresSafeArea()

            scannerContent
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
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
            ZStack {
                CameraPreviewView(session: viewModel.captureSession)

                ScannerOverlay()
            }
        case .notDetermined, .denied, .restricted, .unsupported:
            permissionState
        }
    }

    @ViewBuilder
    private var permissionState: some View {
        let (title, message, symbol): (String, String, String) = {
            switch viewModel.permissionStatus {
            case .notDetermined:
                return ("Camera Access Needed",
                        "Allow camera access to scan product barcodes. Manual entry is always available.",
                        "camera")
            case .denied:
                return ("Camera Access Denied",
                        "Enable camera access in Settings, or enter the barcode manually below.",
                        "camera.fill.badge.ellipsis")
            case .restricted:
                return ("Camera Restricted",
                        "This device cannot grant camera access. Use manual barcode entry instead.",
                        "lock.slash")
            case .unsupported:
                return ("Camera Unavailable",
                        "Barcode scanning is not available on this device or simulator.",
                        "barcode.slash")
            case .authorized:
                return ("", "", "")
            }
        }()

        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.light()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(.ultraThinMaterial)
                    )
            }
            .buttonStyle(PressableScaleButtonStyle())

            Spacer()

            Text("Scan Barcode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(.ultraThinMaterial)
                )

            Spacer()

            // balance the X button
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            if viewModel.permissionStatus == .authorized {
                Text("Position the barcode inside the frame")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(.ultraThinMaterial)
                    )
            }

            Button {
                Haptics.medium()
                viewModel.beginManualEntry()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Enter Barcode Manually")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .buttonStyle(PressableScaleButtonStyle())

            if viewModel.permissionStatus == .denied {
                Button {
                    Haptics.light()
                    openSettings()
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(PressableScaleButtonStyle())
            }
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

// MARK: - Reticle overlay

private struct ScannerOverlay: View {
    @State private var pulse = false
    private let reticleSize = CGSize(width: 280, height: 180)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim mask everywhere except inside the reticle
                Color.black.opacity(0.45)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .frame(width: reticleSize.width, height: reticleSize.height)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                // Glowing reticle border
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(pulse ? 0.95 : 0.55), lineWidth: 2.5)
                    .frame(width: reticleSize.width, height: reticleSize.height)
                    .shadow(color: Color.white.opacity(pulse ? 0.45 : 0.0), radius: 12)
                    .scaleEffect(pulse ? 1.012 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: pulse
                    )

                // Corner accents
                ForEach(Corner.allCases, id: \.self) { corner in
                    CornerBracket(corner: corner)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 28, height: 28)
                        .position(corner.position(in: reticleSize))
                }
                .frame(width: reticleSize.width, height: reticleSize.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { pulse = true }
        }
    }
}

private enum Corner: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    func position(in size: CGSize) -> CGPoint {
        let inset: CGFloat = 14
        switch self {
        case .topLeading:     return CGPoint(x: inset, y: inset)
        case .topTrailing:    return CGPoint(x: size.width - inset, y: inset)
        case .bottomLeading:  return CGPoint(x: inset, y: size.height - inset)
        case .bottomTrailing: return CGPoint(x: size.width - inset, y: size.height - inset)
        }
    }
}

private struct CornerBracket: Shape {
    let corner: Corner

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len: CGFloat = rect.width
        switch corner {
        case .topLeading:
            p.move(to: CGPoint(x: 0, y: len))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: len, y: 0))
        case .topTrailing:
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: len, y: 0))
            p.addLine(to: CGPoint(x: len, y: len))
        case .bottomLeading:
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 0, y: len))
            p.addLine(to: CGPoint(x: len, y: len))
        case .bottomTrailing:
            p.move(to: CGPoint(x: len, y: 0))
            p.addLine(to: CGPoint(x: len, y: len))
            p.addLine(to: CGPoint(x: 0, y: len))
        }
        return p
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
