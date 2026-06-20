import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: – Result

struct DetectedDocument {
    let image: UIImage
    let wasReceiptDetected: Bool
}

// MARK: – Detector

/// Step 1 + 2: Locates the receipt quad, applies perspective correction,
/// then runs a preprocessing chain to maximise OCR accuracy.
final class ReceiptDocumentDetector {

    private let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .workingColorSpace: CGColorSpaceCreateDeviceGray()
    ])

    // MARK: – Public entry point

    func detect(in image: UIImage) async -> DetectedDocument {
        guard let ciImage = normalised(image) else {
            return DetectedDocument(image: image, wasReceiptDetected: false)
        }

        if let corrected = detectAndCorrect(ciImage) {
            return DetectedDocument(image: corrected, wasReceiptDetected: true)
        }

        // Fallback — preprocess the whole image without any warp
        let fallback = preprocess(ciImage) ?? image
        return DetectedDocument(image: fallback, wasReceiptDetected: false)
    }

    // MARK: – Step 1: Rectangle detection

    private func detectAndCorrect(_ ciImage: CIImage) -> UIImage? {
        let request = VNDetectRectanglesRequest()
        // Receipts are portrait strips — allow narrow aspect ratios
        request.minimumAspectRatio = 0.10
        request.maximumAspectRatio = 0.95
        // Must occupy at least 15 % of the frame so we don't grab tiny paper scraps
        request.minimumSize = 0.15
        request.maximumObservations = 8
        // Allow up to 35 ° tilt — handles phones held at an angle
        request.quadratureTolerance = 35
        request.minimumConfidence = 0.35

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])

        // Score = confidence × normalised area. Prefer larger, more-certain rectangles.
        guard let best = request.results?
            .sorted(by: { rectScore($0) > rectScore($1) })
            .first else { return nil }

        // Reject if the detected quad is suspiciously square (likely a credit card / phone)
        let ar = aspectRatio(of: best)
        if ar > 0.85 { return nil }

        let warped = perspectiveWarp(ciImage, using: best)
        return preprocess(warped)
    }

    private func rectScore(_ obs: VNRectangleObservation) -> Float {
        let area = Float(obs.boundingBox.width * obs.boundingBox.height)
        return obs.confidence * area
    }

    private func aspectRatio(of obs: VNRectangleObservation) -> CGFloat {
        // Use the bounding box as a proxy — Vision normalises it
        let bb = obs.boundingBox
        let w = bb.width, h = bb.height
        guard h > 0 else { return 1 }
        return min(w, h) / max(w, h)
    }

    // MARK: – Step 2a: Perspective correction

    private func perspectiveWarp(_ image: CIImage, using obs: VNRectangleObservation) -> CIImage {
        let size = image.extent.size

        // Vision uses normalised bottom-left origin; CIImage same convention.
        func v(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * size.width, y: p.y * size.height)
        }

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return image }
        filter.setValue(image,                    forKey: kCIInputImageKey)
        filter.setValue(v(obs.topLeft),           forKey: "inputTopLeft")
        filter.setValue(v(obs.topRight),          forKey: "inputTopRight")
        filter.setValue(v(obs.bottomLeft),        forKey: "inputBottomLeft")
        filter.setValue(v(obs.bottomRight),       forKey: "inputBottomRight")

        return filter.outputImage ?? image
    }

    // MARK: – Step 2b: Image preprocessing pipeline

    /// Grayscale → contrast normalise → adaptive-style enhance → sharpen → denoise.
    func preprocess(_ ciImage: CIImage) -> UIImage? {
        var img = ciImage

        // 1. Grayscale — removes colour bias that confuses OCR
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(img,  forKey: kCIInputImageKey)
            f.setValue(0.0,  forKey: kCIInputSaturationKey)
            f.setValue(1.15, forKey: kCIInputContrastKey)
            f.setValue(0.02, forKey: kCIInputBrightnessKey)
            img = f.outputImage ?? img
        }

        // 2. Histogram equalisation — lifts faded thermal receipts
        if let f = CIFilter(name: "CIToneCurve") {
            f.setValue(img, forKey: kCIInputImageKey)
            // Gentle S-curve: boosts mid-tone contrast while keeping highlights/shadows
            f.setValue(CIVector(x: 0.00, y: 0.00), forKey: "inputPoint0")
            f.setValue(CIVector(x: 0.25, y: 0.20), forKey: "inputPoint1")
            f.setValue(CIVector(x: 0.50, y: 0.52), forKey: "inputPoint2")
            f.setValue(CIVector(x: 0.75, y: 0.80), forKey: "inputPoint3")
            f.setValue(CIVector(x: 1.00, y: 1.00), forKey: "inputPoint4")
            img = f.outputImage ?? img
        }

        // 3. Unsharp mask — crisp character edges
        if let f = CIFilter(name: "CIUnsharpMask") {
            f.setValue(img,  forKey: kCIInputImageKey)
            f.setValue(2.0,  forKey: kCIInputRadiusKey)
            f.setValue(0.55, forKey: kCIInputIntensityKey)
            img = f.outputImage ?? img
        }

        // 4. Noise reduction — reduces grain from low-light shots
        if let f = CIFilter(name: "CINoiseReduction") {
            f.setValue(img,  forKey: kCIInputImageKey)
            f.setValue(0.02, forKey: "inputNoiseLevel")
            f.setValue(0.50, forKey: "inputSharpness")
            img = f.outputImage ?? img
        }

        // 5. Luminance sharpen pass — tightens text strokes for OCR
        if let f = CIFilter(name: "CISharpenLuminance") {
            f.setValue(img,  forKey: kCIInputImageKey)
            f.setValue(0.55, forKey: kCIInputSharpnessKey)
            f.setValue(0.0,  forKey: "inputRadius")
            img = f.outputImage ?? img
        }

        guard let cgImage = ciContext.createCGImage(img, from: img.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: – Orientation helpers

    /// Returns a CIImage already rotated to portrait/up orientation,
    /// respecting the UIImage's EXIF orientation tag.
    private func normalised(_ image: UIImage) -> CIImage? {
        guard let ci = CIImage(image: image) else { return nil }
        return ci.oriented(exifOrientation(from: image))
    }

    private func exifOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
