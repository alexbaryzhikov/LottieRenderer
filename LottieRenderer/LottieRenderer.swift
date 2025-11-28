import AVFoundation
import AppKit
import ArgumentParser
import Darwin
import Lottie

@main
struct LottieRendererCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lottie2mp4",
        abstract: "Renders Lottie animation to MP4 video file."
    )

    @Argument(help: "Path to the input Lottie JSON file.")
    var inputPath: String

    @Argument(help: "Path to the output MP4 file. Defaults to input filename with .mp4 extension.")
    var outputPath: String?

    @Option(help: "Scale factor for the output video.")
    var scale: Float = 1.0

    @Option(help: "Target bitrate in bits per second (e.g. 5000000 for 5Mbps).")
    var bitrate: Int?

    var defaultOutputPath: String {
        URL(fileURLWithPath: inputPath).deletingPathExtension().appendingPathExtension("mp4").path
    }

    func run() throws {
        Task { @MainActor in
            let renderer = LottieRenderer(
                inputPath: inputPath,
                outputPath: outputPath ?? defaultOutputPath,
                scale: scale,
                bitrate: bitrate
            )

            do {
                try await renderer.render()
                Darwin.exit(0)
            } catch {
                print("Error: \(error.localizedDescription)")
                Darwin.exit(1)
            }
        }

        RunLoop.main.run()
    }
}

@MainActor
final class LottieRenderer {
    let inputPath: String
    let outputPath: String
    let scale: Float
    let bitrate: Int?

    init(inputPath: String, outputPath: String, scale: Float, bitrate: Int?) {
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.scale = scale
        self.bitrate = bitrate
    }

    func render() async throws {
        guard let animation = LottieAnimation.filepath(inputPath) else {
            throw NSError(domain: "LottieRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load Lottie file at \(inputPath)"])
        }

        let size = CGSize(
            width: animation.size.width * CGFloat(scale),
            height: animation.size.height * CGFloat(scale)
        )

        let configuration = LottieConfiguration(renderingEngine: .mainThread)
        let animationView = LottieAnimationView(animation: animation, configuration: configuration)
        animationView.frame = CGRect(origin: .zero, size: size)
        animationView.contentMode = .scaleAspectFit

        let outputURL = URL(fileURLWithPath: outputPath)
        try? FileManager.default.removeItem(at: outputURL)

        let (assetWriter, writerInput, adaptor) = try setupAssetWriter(outputURL: outputURL, size: size)

        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let fps = Int32(animation.framerate)
        let totalFrames = Int(animation.endFrame)

        print("Rendering \(totalFrames) frames at \(fps) FPS...", terminator: "")
        fflush(stdout)

        for i in 0..<totalFrames {
            animationView.currentFrame = CGFloat(i)
            animationView.layoutSubtreeIfNeeded()

            if let buffer = snapshotToPixelBuffer(view: animationView, size: size) {
                let frameTime = CMTimeMake(value: Int64(i), timescale: fps)

                while !writerInput.isReadyForMoreMediaData {
                    try await Task.sleep(for: .milliseconds(100))
                }

                adaptor.append(buffer, withPresentationTime: frameTime)
            }

            if i % 10 == 0 {
                print(".", terminator: "")
                fflush(stdout)
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { continuation in
            assetWriter.finishWriting { continuation.resume() }
        }

        print("Done!")
        print("Video saved to \(outputPath)")
    }

    private func setupAssetWriter(outputURL: URL, size: CGSize) throws -> (AVAssetWriter, AVAssetWriterInput, AVAssetWriterInputPixelBufferAdaptor) {
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw NSError(domain: "LottieRenderer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create AVAssetWriter"])
        }

        var compressionProperties: [String: Any] = [
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]

        if let bitrate {
            compressionProperties[AVVideoAverageBitRateKey] = bitrate
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: compressionProperties,
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)

        if assetWriter.canAdd(writerInput) {
            assetWriter.add(writerInput)
        } else {
            throw NSError(domain: "LottieRenderer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not add input to AssetWriter"])
        }

        return (assetWriter, writerInput, adaptor)
    }

    private func snapshotToPixelBuffer(view: LottieAnimationView, size: CGSize) -> CVPixelBuffer? {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
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
        else { return nil }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        view.layer?.render(in: context)

        guard let cgImage = context.makeImage() else { return nil }

        return createPixelBuffer(from: cgImage, size: size, colorSpace: colorSpace)
    }

    private func createPixelBuffer(from image: CGImage, size: CGSize, colorSpace: CGColorSpace) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
        else { return nil }

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(origin: .zero, size: size))

        return buffer
    }
}
