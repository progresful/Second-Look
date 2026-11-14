import AVFoundation
import SwiftUI
import UIKit

/// Phone camera video feed for live scan. Keeps only the latest frame in memory;
/// nothing is recorded or stored.
final class LiveCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
  let session = AVCaptureSession()
  private let queue = DispatchQueue(label: "secondlook.livecamera")
  private let lock = NSLock()
  private var latest: CVPixelBuffer?
  private let context = CIContext()

  enum CameraError: LocalizedError {
    case denied, unavailable
    var errorDescription: String? {
      switch self {
      case .denied: return "Second Look needs the camera. Allow it in Settings."
      case .unavailable: return "The camera isn't available."
      }
    }
  }

  func start() async throws {
    var granted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    if !granted { granted = await AVCaptureDevice.requestAccess(for: .video) }
    guard granted else { throw CameraError.denied }
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
      queue.async { [self] in
        if session.inputs.isEmpty {
          guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            cont.resume(throwing: CameraError.unavailable); return
          }
          session.beginConfiguration()
          session.sessionPreset = .hd1920x1080
          session.addInput(input)
          let output = AVCaptureVideoDataOutput()
          output.alwaysDiscardsLateVideoFrames = true
          output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
          output.setSampleBufferDelegate(self, queue: queue)
          if session.canAddOutput(output) { session.addOutput(output) }
          if let conn = output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
            conn.videoRotationAngle = 90 // portrait
          }
          session.commitConfiguration()
        }
        session.startRunning()
        cont.resume()
      }
    }
  }

  func stop() {
    queue.async { [self] in
      session.stopRunning()
      lock.lock(); latest = nil; lock.unlock()
    }
  }

  /// The most recent frame, or nil before the first one arrives.
  func snapshot() -> UIImage? {
    lock.lock(); let buffer = latest; lock.unlock()
    guard let buffer else { return nil }
    let ci = CIImage(cvPixelBuffer: buffer)
    guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
    return UIImage(cgImage: cg)
  }

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    lock.lock(); latest = buffer; lock.unlock()
  }
}

/// Full-screen camera preview.
struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
  }

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.previewLayer.session = session
    view.previewLayer.videoGravity = .resizeAspectFill
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {}
}
