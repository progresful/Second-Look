import AVFoundation
import Foundation
import Speech

/// Call-mode fallback when the glasses have no on-device speech: Apple speech recognition
/// on the phone, forced on-device where supported. Audio is never uploaded or stored.
@MainActor
final class PhoneListener {
  enum ListenError: LocalizedError {
    case notAuthorized, unavailable
    var errorDescription: String? {
      switch self {
      case .notAuthorized: return "Speech recognition or microphone permission is off."
      case .unavailable: return "Speech recognition isn't available right now."
      }
    }
  }

  var onTranscript: ((String, Bool) -> Void)?
  private let engine = AVAudioEngine()
  /// Which microphone feeds recognition, e.g. "Ray-Ban Display mic" or "iPhone mic".
  private(set) var micName = ""
  private(set) var usesGlassesMic = false
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

  func start() async throws {
    let speechOK = await withCheckedContinuation { c in
      SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
    }
    let micOK = await AVAudioApplication.requestRecordPermission()
    guard speechOK, micOK else { throw ListenError.notAuthorized }
    guard let recognizer, recognizer.isAvailable else { throw ListenError.unavailable }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
    self.request = request

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement,
                            options: [.allowBluetoothHFP, .defaultToSpeaker, .duckOthers])
    try session.setActive(true)
    // Prefer the glasses' microphone (Bluetooth) over the iPhone's own mic.
    let btTypes: [AVAudioSession.Port] = [.bluetoothHFP, .bluetoothLE]
    if let bt = session.availableInputs?.first(where: { btTypes.contains($0.portType) }) {
      try? session.setPreferredInput(bt)
    }
    let port = session.currentRoute.inputs.first
    usesGlassesMic = port.map { btTypes.contains($0.portType) } ?? false
    micName = port.map { usesGlassesMic ? "\($0.portName) mic" : "iPhone mic" } ?? "no mic"
    NSLog("[SecondLook] call listening mic: %@ (%@)", port?.portName ?? "-", port?.portType.rawValue ?? "-")

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    // No usable mic (e.g. Simulator without input): fail gracefully instead of crashing.
    guard format.sampleRate > 0, format.channelCount > 0 else { throw ListenError.unavailable }
    input.removeTap(onBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    engine.prepare()
    try engine.start()

    task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
      guard let result else { return }
      let text = result.bestTranscription.formattedString
      let isFinal = result.isFinal
      Task { @MainActor in self?.onTranscript?(text, isFinal) }
    }
  }

  func stop() {
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.cancel()
    request = nil
    task = nil
  }
}
