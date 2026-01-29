import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import os

// MARK: - LabeledScreenshot

/// A screenshot paired with the name of the app it belongs to.
public struct LabeledScreenshot {
    let appName: String
    let imageData: Data
}

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

    /// Captures the main display and returns PNG data (without saving to disk).
    public func captureMainDisplayData() async throws -> Data {
        let cgImage = try await captureEntireMainDisplay()
        guard let data = pngData(from: cgImage) else {
            throw ScreenshotError.cannotCreateImageDestination
        }
        return data
    }

    /// Captures individual window screenshots for the given app names.
    ///
    /// For each app name, finds its first on-screen window and captures it.
    /// If no per-app windows are found, falls back to a full display capture.
    ///
    /// - Parameter appNames: The display names of applications to capture (e.g. "Safari", "Xcode").
    /// - Returns: An array of labeled screenshots, one per captured window.
    public func captureWindows(forApps appNames: [String]) async throws -> [LabeledScreenshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        var results: [LabeledScreenshot] = []

        for appName in appNames {
            // Find the first on-screen window belonging to this app (case-insensitive match)
            guard let window = content.windows.first(where: {
                $0.owningApplication?.applicationName.lowercased() == appName.lowercased()
                    && $0.isOnScreen
                    && $0.frame.width > 0
                    && $0.frame.height > 0
            }) else {
                print("⚠️ No visible window found for \(appName)")
                continue
            }

            do {
                let cgImage = try await captureWindow(window)
                if let data = pngData(from: cgImage) {
                    results.append(LabeledScreenshot(appName: appName, imageData: data))
                    print("📸 Captured window for \(appName) (\(data.count) bytes)")
                }
            } catch {
                print("⚠️ Failed to capture window for \(appName): \(error.localizedDescription)")
            }
        }

        // Fallback: if no per-app windows were captured, capture the full display
        if results.isEmpty {
            print("📸 No per-app windows captured, falling back to full display")
            do {
                let data = try await captureMainDisplayData()
                results.append(LabeledScreenshot(appName: "Full Display", imageData: data))
            } catch {
                print("⚠️ Full display fallback also failed: \(error.localizedDescription)")
            }
        }

        return results
    }

    // MARK: - Private Methods

    /// Captures a single window as a CGImage using ScreenCaptureKit.
    private func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        let oneShotOutput = OneShotOutput()
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(oneShotOutput, type: .screen, sampleHandlerQueue: outputQueue)

        streamLock.withLock { stream in
            stream = newStream
        }

        try await newStream.startCapture()
        defer { stopCapture() }

        let sampleBuffer = try await oneShotOutput.nextSampleBuffer(timeoutSeconds: 2.0)

        guard let cgImage = sampleBuffer.makeCGImage() else {
            throw ScreenshotError.couldNotConvertSampleBufferToImage
        }
        return cgImage
    }

    /// Converts a CGImage to PNG data in memory (without writing to disk).
    private func pngData(from image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }

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
