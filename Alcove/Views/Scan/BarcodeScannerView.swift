import SwiftUI
import Vision
import VisionKit

/// Live camera barcode scanner (VisionKit). Calls `onScan` once per barcode
/// as it comes into view; holding the same code in frame doesn't repeat it.
struct BarcodeScannerView: UIViewControllerRepresentable {
    var isActive: Bool
    var onScan: (String) -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .itf14, .qr]),
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onScan = onScan
        if isActive, !scanner.isScanning {
            // Starting before the view is on screen can fail; defer a tick.
            DispatchQueue.main.async { try? scanner.startScanning() }
        } else if !isActive, scanner.isScanning {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String) -> Void
        private var lastCode: String?
        private var lastScanAt = Date.distantPast

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                guard case .barcode(let barcode) = item, let code = barcode.payloadStringValue else { continue }
                handle(code)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            // Tapping a highlighted code scans it again (handy for counting multiples).
            guard case .barcode(let barcode) = item, let code = barcode.payloadStringValue else { return }
            lastCode = nil
            handle(code)
        }

        private func handle(_ code: String) {
            let now = Date()
            if code == lastCode, now.timeIntervalSince(lastScanAt) < 1.5 { return }
            lastCode = code
            lastScanAt = now
            onScan(code)
        }
    }
}
