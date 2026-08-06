import SwiftUI
import UIKit
import AVFoundation

/// Barcode scanner. The design's dark frame is kept; behind it is a real camera preview
/// when one is available (device + permission), otherwise the screen degrades to manual entry.
struct ScanScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var nav: Nav
    @StateObject private var scanner = BarcodeScanner()
    @State private var status: String?
    @State private var linePhase: CGFloat = -70

    private var statusText: String {
        if let status { return status }
        return scanner.isAvailable ? "Ищем код…" : "Камера недоступна — введите продукт вручную"
    }

    var body: some View {
        ZStack {
            Theme.scanBackdrop.ignoresSafeArea()

            if scanner.isRunning {
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()
                    .opacity(0.55)
            }

            VStack(spacing: 0) {
                HStack {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 19))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("Штрих-код")
                        .golos(600, 14)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                Spacer()

                VStack(spacing: 26) {
                    scanFrame

                    VStack(spacing: 6) {
                        Text(statusText)
                            .golos(600, 16)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text("Наведите камеру на упаковку")
                            .golos(400, 13)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    close()
                } label: {
                    Text("Ввести вручную")
                        .golos(500, 14.5)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 42)
            }
        }
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.code) { _, code in
            guard let code else { return }
            handle(code: code)
        }
    }

    private var scanFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 2)

            // Decorative barcode, as in the design.
            HStack(alignment: .center, spacing: 3) {
                ForEach(Array(Self.bars.enumerated()), id: \.offset) { _, width in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: width, height: 66)
                }
            }
            .opacity(0.55)

            Rectangle()
                .fill(Theme.scanLine)
                .frame(height: 2)
                .shadow(color: Theme.scanLine, radius: 7)
                .offset(y: linePhase)
        }
        .frame(width: 270, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                linePhase = 70
            }
        }
    }

    private static let bars: [CGFloat] = [3, 1, 2, 1, 4, 1, 2, 3, 1, 1, 2, 4, 1, 3, 1, 2, 1, 4, 2, 1]

    private func close() {
        scanner.stop()
        nav.screen = .add
    }

    private func handle(code: String) {
        guard let food = store.food(withBarcode: code) else {
            status = "Код \(code) не найден — введите продукт вручную"
            scanner.clearCode()
            return
        }
        status = "Найдено: \(food.name)"
        scanner.stop()
        let shownCode = String(code.prefix(7))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            nav.openProduct(food, source: "Штрих-код \(shownCode)", returnTo: .add)
        }
    }
}

// MARK: - Capture session

/// Thin AVFoundation wrapper. All published state is updated on the main queue.
final class BarcodeScanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published private(set) var code: String?
    @Published private(set) var isRunning = false
    /// False on the simulator, on a device without a camera, or when access was denied.
    @Published private(set) var isAvailable = true

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "kbzhu.scanner")
    private var isConfigured = false

    func start() {
        guard !isRunning else { return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted, self.configureIfNeeded() else {
                    self.isAvailable = false
                    return
                }
                self.isAvailable = true
                self.isRunning = true
                self.sessionQueue.async { [session = self.session] in
                    if !session.isRunning { session.startRunning() }
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        sessionQueue.async { [session = self.session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Lets the same barcode be reported again after an unknown code.
    func clearCode() {
        code = nil
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return false }

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .itf14]
        session.commitConfiguration()

        isConfigured = true
        return true
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue,
              value != code else { return }
        code = value
    }
}

/// Thin wrapper around `AVCaptureVideoPreviewLayer`.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
