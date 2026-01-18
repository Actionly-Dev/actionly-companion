import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import os


/// ScreenshotHelper
///
/// Responsible for capturing a single screenshot of a macOS display
/// using ScreenCaptureKit (Apple’s modern, supported screen capture API).
///
/// Key design goals:
/// - Capture exactly ONE frame (not a continuous stream)
/// - Be async/await friendly
/// - Own and manage the ScreenCaptureKit stream lifecycle
/// - Fail cleanly if Screen Recording permission is denied
///
/// IMPORTANT:
/// Capturing the screen requires the user to grant
/// System Settings → Privacy & Security → Screen Recording
///
public final class ScreenshotHelper {

    // MARK: State
    
    /// We keep the current stream here so it stays alive during capture.
    private let streamLock = OSAllocatedUnfairLock<SCStream?>(initialState: nil)
    
    /// Queue used to receive image frames to keep work off the main thread.
    private let outputQueue = DispatchQueue(label: "ScreenshotHelper.ScreenCaptureKitOutputQueue")

    public init() {}

    /// Stop any capture if this object is deleted.
    deinit {
        stopCapture()
    }

    // MARK: - Public API
    
    /// Captures a screenshot of the main display and saves it as a PNG into the app’s Caches folder.
    ///
    /// - Returns: The file URL of the saved PNG in Caches (e.g., .../Library/Caches/<bundle-id>/Screenshots/<file>.png)
    ///
    /// Notes:
    /// - The Caches folder is for temporary files; macOS may delete these files later.
    /// - This call will fail if Screen Recording permission is not granted.
    public func captureAndSaveToCaches() async throws -> URL {

        // 1) Capture the screenshot as a CGImage
        let cgImage: CGImage = try await captureEntireMainDisplay()

        // 2) Get the app’s Caches directory
        guard let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw ScreenshotError.cachesDirectoryUnavailable
        }

        // 3) Create a subfolder for screenshots: Caches/Screenshots
        let screenshotsDir = cachesURL.appendingPathComponent("Screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)

        // 4) Build a unique filename (timestamp-based)
        let filename = "screenshot_\(Self.timestampString()).png"
        let fileURL = screenshotsDir.appendingPathComponent(filename, isDirectory: false)

        // 5) Save PNG to disk using your helper method
        try savePNG(cgImage, to: fileURL)

        return fileURL
    }

    // MARK: - Private Methods
    
    // Simple timestamp helper for filenames: yyyy-MM-dd_HH-mm-ss
    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    /// Captures the entire main display as a CGImage.
    /// Requires Screen Recording permission.
    private func captureEntireMainDisplay() async throws -> CGImage {
        try await captureEntireDisplay(displayID: CGMainDisplayID())
    }

    /// Takes a screenshot of the display identified by `displayID`.
    /// Steps:
    /// 1. Find the requested display
    /// 2. Start capturing that display
    /// 3. Wait for one image
    /// 4. Stop capturing
    /// Requires Screen Recording permission.
    private func captureEntireDisplay(displayID: CGDirectDisplayID) async throws -> CGImage {

        // Ask macOS what displays can be captured - This is where the permission check happens
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the display that matches the given ID.
        guard let scDisplay = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotError.noMatchingDisplay(displayID: displayID)
        }
        // Configure filter for the capture so only this display is included.
        let filter = SCContentFilter(display: scDisplay, excludingWindows: [])

        // Configure the capture.
        let config = SCStreamConfiguration()
        config.width = scDisplay.width
        config.height = scDisplay.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // We only need one image, but this value must be set.

        // Helper object that waits for one image.
        let oneShotOutput = OneShotOutput()

        // Create the capture stream.
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // Tell the stream where to send captured images.
        try newStream.addStreamOutput(oneShotOutput, type: .screen, sampleHandlerQueue: outputQueue)

        // Set the capture stream - Keeping a reference keeps the stream alive.
        streamLock.withLock { stream in
                    stream = newStream
                }
        // Start capturing.
        try await newStream.startCapture()
        
        // Always stop when leaving this function (success or error).
        defer { stopCapture() }

        // Wait for one frame (timeout protects against “no frames ever arrive” cases).
        let sampleBuffer = try await oneShotOutput.nextSampleBuffer(timeoutSeconds: 2.0)

        // Convert it to a CGImage.
        guard let cgImage = sampleBuffer.makeCGImage() else {
            throw ScreenshotError.couldNotConvertSampleBufferToImage
        }

        return cgImage
        
    }

    /// Convenience: capture as NSImage.
    private func captureEntireMainDisplayImage() async throws -> NSImage {
        let cg = try await captureEntireMainDisplay()
        return NSImage(cgImage: cg, size: .zero)
    }

    /// Saves a CGImage as a PNG file at the given file URL.
    ///
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: The destination file URL (e.g. on Desktop)
    ///
    /// - Returns:
    ///   The same URL, so the caller can easily chain or log it.
    ///
    /// This method throws if the file cannot be created or written.
    @discardableResult
    private func savePNG(_ image: CGImage, to url: URL) throws -> URL {
        
        // Create an image destination that knows how to write PNG files.
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenshotError.cannotCreateImageDestination
        }
        
        // Add the image to the destination.
        CGImageDestinationAddImage(destination, image, nil)

        // Finalize actually writes the file to disk.
        guard CGImageDestinationFinalize(destination) else {
            throw ScreenshotError.cannotFinalizeImageDestination
        }

        return url
    }

    /// Best-effort stop for any active stream.
    private func stopCapture() {
        // Take the stream out under lock, then stop it outside the lock.
        let activeStream: SCStream? = streamLock.withLock { stream in
            let s = stream
            stream = nil
            return s
        }

        // If there was no active stream, we are done.
        guard let activeStream else { return }

        // Stop the stream asynchronously - We ignore errors here because stopping is best-effort cleanup.
        Task {
            try? await activeStream.stopCapture()
        }
        
    }
}

// MARK: - Errors

/// Errors that can occur while capturing or saving a screenshot.
public extension ScreenshotHelper {
    enum ScreenshotError: Error {
        /// The requested display ID was not found.
        case noMatchingDisplay(displayID: CGDirectDisplayID)
        
        /// No image arrived within the expected time.
        case timedOutWaitingForFrame

        /// The captured data could not be turned into an image.
        case couldNotConvertSampleBufferToImage

        /// Failed to create a file destination for saving the image.
        case cannotCreateImageDestination

        /// Failed while writing the image file to disk.
        case cannotFinalizeImageDestination
        
        /// The system did not return a valid Caches directory.
        case cachesDirectoryUnavailable
    }
}

// MARK: - One-shot SCStreamOutput

/// This object waits for a single image from ScreenCaptureKit and then returns it.
private final class OneShotOutput: NSObject, SCStreamOutput {
    
    /// Lock used to protect access to the continuation.
    private let lock = NSLock()
    
    /// Stored continuation that will be resumed when a frame arrives (or times out).
    private var continuation: CheckedContinuation<CMSampleBuffer, Error>?

    /// Waits until one image is received or the timeout expires.
    func nextSampleBuffer(timeoutSeconds: Double) async throws -> CMSampleBuffer {

        try await withCheckedThrowingContinuation { cont in

            // Store the continuation so the stream callback can resume it.
            lock.lock()
            continuation = cont
            lock.unlock()

            // If no frame arrives within the timeout,
            // resume with an error.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds) { [weak self] in
                guard let self else { return }

                self.lock.lock()
                guard let cont = self.continuation else {
                    self.lock.unlock()
                    return
                }
                self.continuation = nil
                self.lock.unlock()

                cont.resume(
                    throwing: ScreenshotHelper.ScreenshotError.timedOutWaitingForFrame
                )
            }
        }
    }
    
    /// Called by ScreenCaptureKit when a frame is available.
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        
        // Ignore anything that is not a screen image.
        guard type == .screen else { return }

        lock.lock()
        guard let cont = continuation else {
            lock.unlock()
            return
        }
        continuation = nil
        lock.unlock()

        // Resume the awaiting task with the captured frame.
        cont.resume(returning: sampleBuffer)
    }
}

// MARK: - CMSampleBuffer -> CGImage

private extension CMSampleBuffer {
    
    /// Converts captured screen data into a CGImage.
    func makeCGImage() -> CGImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }

        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
