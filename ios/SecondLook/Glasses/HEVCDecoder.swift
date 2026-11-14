import CoreImage
import CoreMedia
import UIKit
import VideoToolbox

/// Decodes the glasses' compressed (HEVC) video frames on the phone, like Meta's CameraAccess
/// sample. Compressed video uses far less of the glasses' wireless link than raw frames, which
/// is what kept ending the stream. Every frame is decoded (HEVC frames depend on each other);
/// only the newest picture is kept, and it becomes a UIImage only when someone asks for it.
final class HEVCDecoder: @unchecked Sendable {
  private let lock = NSLock()
  private var session: VTDecompressionSession?
  private var format: CMFormatDescription?
  private var latest: CVPixelBuffer?
  private let ci = CIContext()

  func decode(_ sample: CMSampleBuffer) {
    guard CMSampleBufferGetDataBuffer(sample) != nil, let f = CMSampleBufferGetFormatDescription(sample) else { return }
    lock.lock(); defer { lock.unlock() }
    if session == nil || format == nil || !CMFormatDescriptionEqual(format!, otherFormatDescription: f) {
      if let s = session { VTDecompressionSessionInvalidate(s) }
      var s: VTDecompressionSession?
      let attrs = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as CFDictionary
      VTDecompressionSessionCreate(allocator: kCFAllocatorDefault, formatDescription: f, decoderSpecification: nil,
                                   imageBufferAttributes: attrs, outputCallback: nil, decompressionSessionOut: &s)
      session = s; format = f
    }
    guard let s = session else { return }
    var out: CVPixelBuffer?
    // Synchronous decode: the handler runs before this call returns.
    let status = VTDecompressionSessionDecodeFrame(s, sampleBuffer: sample, flags: [], infoFlagsOut: nil) { st, _, image, _, _ in
      if st == noErr, let image { out = image }
    }
    if status == noErr, let out { latest = out }
  }

  /// The newest decoded picture, or nil before the first one.
  func image() -> UIImage? {
    lock.lock(); let px = latest; lock.unlock()
    guard let px else { return nil }
    let img = CIImage(cvPixelBuffer: px)
    guard let cg = ci.createCGImage(img, from: img.extent) else { return nil }
    return UIImage(cgImage: cg)
  }

  func reset() {
    lock.lock(); defer { lock.unlock() }
    if let s = session { VTDecompressionSessionInvalidate(s) }
    session = nil; format = nil; latest = nil
  }
}
