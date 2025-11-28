import AVFoundation
import AppKit
import Foundation
import Lottie

// 1. Setup Standard Input/Output
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Usage: lottie2video <input_json_path> <output_video_path>")
    exit(1)
}
let inputPath = arguments[1]
let outputPath = arguments[2]

// 2. Load the Lottie Animation
// We use 'filepath' to load from disk
guard let animation = LottieAnimation.filepath(inputPath) else {
    print("Error: Could not load Lottie file at \(inputPath)")
    exit(1)
}

// 3. Configure the View
// CRITICAL: We must use the .mainThread rendering engine.
// The default .coreAnimation engine renders on the GPU and cannot be easily snapshotted in this context.
let configuration = LottieConfiguration(renderingEngine: .mainThread)
let animationView = LottieAnimationView(animation: animation, configuration: configuration)

// Set the size (you might want to make this configurable)
let size = animation.size
animationView.frame = CGRect(origin: .zero, size: size)
animationView.contentMode = .scaleAspectFit

// 4. Setup Video Writer (AVAssetWriter)
let outputURL = URL(fileURLWithPath: outputPath)
// Remove existing file if necessary
try? FileManager.default.removeItem(at: outputURL)

guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
    print("Error: Could not create AVAssetWriter")
    exit(1)
}

let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: size.width,
    AVVideoHeightKey: size.height,
]

let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

assetWriter.add(writerInput)
assetWriter.startWriting()
assetWriter.startSession(atSourceTime: .zero)

// 5. Render Loop
let fps: Int32 = Int32(animation.framerate)
let totalFrames = Int(animation.endFrame)
print("Rendering \(totalFrames) frames at \(fps) FPS...")

for i in 0..<totalFrames {
    // A. Update Animation State
    animationView.currentFrame = CGFloat(i)

    // Force layout update to ensure frames are ready
    animationView.layoutSubtreeIfNeeded()

    // B. Render to Image
    // Create a context and render the layer into it
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)

    guard
        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
    else { continue }

    // Fill background (optional, video usually needs opaque background)
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(origin: .zero, size: size))

    // Render the Lottie Layer into context
    animationView.layer?.render(in: context)

    // C. Write to Video
    if let cgImage = context.makeImage() {
        // Convert generic time (i) to CMTime
        let frameTime = CMTimeMake(value: Int64(i), timescale: fps)

        // Wait for adaptor to be ready
        while !writerInput.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Helper to convert CGImage to PixelBuffer (Implementation required here normally)
        if let buffer = pixelBuffer(from: cgImage, size: size) {
            adaptor.append(buffer, withPresentationTime: frameTime)
        }
    }

    // Progress indicator
    if i % 10 == 0 { print("Rendered frame \(i)/\(totalFrames)") }
}

// 6. Finish
writerInput.markAsFinished()
assetWriter.finishWriting {
    print("Done! Video saved to \(outputPath)")
    exit(0)
}

// Keep the CLI running until the async finishWriting block calls exit()
RunLoop.main.run()

// --- Helper Function ---
func pixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let options: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
    ]
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options as CFDictionary, &pixelBuffer)

    guard let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    let pixelData = CVPixelBufferGetBaseAddress(buffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

    let context = CGContext(
        data: pixelData,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: rgbColorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    )

    context?.draw(image, in: CGRect(origin: .zero, size: size))
    CVPixelBufferUnlockBaseAddress(buffer, [])

    return buffer
}
