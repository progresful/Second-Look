import AVFoundation
import Foundation
import MWDATCamera
import MWDATCore
import MWDATDisplay
import MWDATInputs
import MWDATSpeech
import Observation
import UIKit

/// Everything that touches the Meta glasses through the Device Access Toolkit (DAT):
/// registration, one device session, camera photo capture, the Display card,
/// the capture button, and on-device speech for call mode.
@Observable
@MainActor
final class GlassesManager {
  enum GlassesError: LocalizedError {
    case notConnected, permissionDenied, cameraUnavailable, captureFailed, timeout

    var errorDescription: String? {
      switch self {
      case .notConnected: return "Glasses aren't connected."
      case .permissionDenied: return "Camera permission for the glasses was denied."
      case .cameraUnavailable: return "The glasses camera isn't available right now."
      case .captureFailed: return "Couldn't take the photo."
      case .timeout: return "The glasses didn't answer in time."
      }
    }
  }

  // Observable state for the UI.
  private(set) var registrationState: RegistrationState
  private(set) var devices: [DeviceIdentifier] = []
  private(set) var sessionState: DeviceSessionState = .idle
  private(set) var streamState: StreamState = .stopped
  private(set) var hasDisplay = false
  private(set) var hasSpeech = false
  private(set) var isListening = false
  var lastError: String?

  /// Called when the wearer short-presses the capture button.
  @ObservationIgnored var onCapturePress: (() -> Void)?
  /// Called with on-device transcripts (call mode). Bool = isFinal.
  @ObservationIgnored var onTranscript: ((String, Bool) -> Void)?

  /// nil when the SDK failed to configure: the app then runs in phone-only mode.
  @ObservationIgnored private let wearables: WearablesInterface!
  let sdkAvailable: Bool
  @ObservationIgnored private var session: DeviceSession?
  @ObservationIgnored private var camera: MWDATCamera.Camera?
  @ObservationIgnored private var display: Display?
  @ObservationIgnored private var displayReady = false
  @ObservationIgnored private var inputs: Inputs?
  @ObservationIgnored private var speech: Speech?
  @ObservationIgnored private let sessionTokens = ListenerTokenBag()
  @ObservationIgnored private let streamTokens = ListenerTokenBag()
  @ObservationIgnored private let capabilityTokens = ListenerTokenBag()
  @ObservationIgnored private var photoContinuation: CheckedContinuation<Data, Error>?
  @ObservationIgnored private var background: [Task<Void, Never>] = []

  var isRegistered: Bool { registrationState == .registered }
  var isConnected: Bool { sessionState == .started }

  /// Name of glasses (or any Bluetooth headset) connected for audio, even when the
  /// Meta session (camera, display, capture button) isn't running.
  private(set) var bluetoothAudioName: String?
  /// Meta's toolkit says the glasses-side app must be updated in Meta AI first.
  var needsGlassesAppUpdate: Bool { (lastError ?? "").localizedCaseInsensitiveContains("update") }

  /// Opens Meta AI on the screen that updates Second Look's companion app on the glasses.
  func openGlassesAppUpdate() {
    guard let wearables else { return }
    Task { do { try await wearables.openDATGlassesAppUpdate() } catch { lastError = "Couldn't open Meta AI: \(error)" } }
  }

  /// Opens Meta AI's firmware update screen for the glasses.
  func openFirmwareUpdate() {
    guard let wearables else { return }
    Task { do { try await wearables.openFirmwareUpdate() } catch { lastError = "Couldn't open Meta AI: \(error)" } }
  }

  func refreshAudioRoute() {
    let r = AVAudioSession.sharedInstance().currentRoute
    let bt: [AVAudioSession.Port] = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
    bluetoothAudioName = (r.outputs + r.inputs).first { bt.contains($0.portType) }?.portName
  }

  /// One line for the header.
  var headerText: String {
    if isConnected { return "glasses connected" }
    if let name = bluetoothAudioName {
      return needsGlassesAppUpdate ? "\(name.lowercased()) · audio only, update in Meta AI" : "\(name.lowercased()) · audio only"
    }
    return "glasses not connected"
  }

  var statusText: String {
    if !sdkAvailable { return "Glasses unavailable (phone mode)" }
    if !isRegistered { return "Glasses not set up" }
    if devices.isEmpty { return "No glasses nearby" }
    switch sessionState {
    case .started: return hasDisplay ? "Connected · Ray-Ban Display" : "Connected · audio glasses"
    case .starting: return "Connecting…"
    case .paused: return "Paused (glasses off your face?)"
    case .stopping: return "Disconnecting…"
    case .idle, .stopped: return "Glasses ready to connect"
    @unknown default: return "Unknown"
    }
  }

  init(sdkConfigured: Bool) {
    guard sdkConfigured else {
      self.wearables = nil
      self.sdkAvailable = false
      self.registrationState = .unavailable
      self.lastError = "Glasses toolkit couldn't start. Phone camera still works."
      return
    }
    let wearables = Wearables.shared
    self.wearables = wearables
    self.sdkAvailable = true
    self.registrationState = wearables.registrationState
    self.devices = wearables.devices
    refreshAudioRoute()
    NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
      Task { @MainActor in self?.refreshAudioRoute() }
    }
    background.append(Task { [weak self] in
      for await state in wearables.registrationStateStream() {
        guard let self else { return }
        self.registrationState = state
        // Discovery can arrive before registration finishes in the Meta AI app.
        if state == .registered, !self.devices.isEmpty { self.connect() }
      }
    })
    background.append(Task { [weak self] in
      for await devices in wearables.devicesStream() {
        guard let self else { return }
        self.devices = devices
        // Auto-connect when glasses appear; reconnect after a drop.
        if !devices.isEmpty, self.isRegistered, self.session == nil { self.connect() }
      }
    })
  }

  // MARK: Registration (opens the Meta AI app, which calls back via secondlook://)

  func refreshConnection() {
    guard sdkAvailable else { return }
    registrationState = wearables.registrationState
    devices = wearables.devices
    if isRegistered, !devices.isEmpty { connect() }
  }

  func register() {
    guard sdkAvailable else { return }
    Task {
      do { try await wearables.startRegistration() } catch { lastError = "Setup failed: \(error.localizedDescription)" }
    }
  }

  func unregister() {
    guard sdkAvailable else { return }
    disconnect()
    Task {
      do { try await wearables.startUnregistration() } catch { lastError = error.localizedDescription }
    }
  }

  func handle(url: URL) {
    guard sdkAvailable else { return }
    guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
          items.contains(where: { $0.name == "metaWearablesAction" }) else { return }
    Task {
      do {
        _ = try await wearables.handleUrl(url)
        refreshConnection()
      } catch { lastError = error.localizedDescription }
    }
  }

  // MARK: Session

  private var isConnecting = false

  /// Opens a session once a pair is linked and compatible (DAT refuses "not eligible" devices).
  func connect() {
    guard sdkAvailable, session == nil, isRegistered, !isConnecting else { return }
    isConnecting = true
    Task {
      defer { isConnecting = false }
      let clock = ContinuousClock()
      let deadline = clock.now.advanced(by: .seconds(6))
      while !hasReadyDevice {
        if clock.now >= deadline {
          lastError = "Glasses found but not ready: \(deviceDiagnostics). Put them on and unfold them."
          return
        }
        try? await Task.sleep(for: .milliseconds(150))
      }
      lastError = nil
      openSession()
    }
  }

  private var hasReadyDevice: Bool {
    readyDeviceIdentifier != nil
  }

  private var readyDeviceIdentifier: DeviceIdentifier? {
    devices.first { identifier in
      guard let device = wearables.deviceForIdentifier(identifier) else { return false }
      return device.linkState == .connected && device.compatibility() == .compatible
    }
  }

  var deviceDiagnostics: String {
    devices.compactMap { wearables.deviceForIdentifier($0) }
      .map { "\(String(describing: $0.linkState)), \(String(describing: $0.compatibility()))" }
      .joined(separator: "; ")
  }

  private func openSession() {
    guard session == nil else { return }
    guard let identifier = readyDeviceIdentifier else {
      lastError = "Glasses are not ready: \(deviceDiagnostics)"
      return
    }
    do {
      // AutoDeviceSelector discovers asynchronously; a freshly created selector can
      // still be empty even though wearables.devices already contains the glasses.
      let selector = SpecificDeviceSelector(device: identifier)
      let session = try wearables.createSession(deviceSelector: selector)
      self.session = session
      session.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.sessionChanged(state) }
      }.store(in: sessionTokens)
      session.errorPublisher.listen { [weak self] error in
        NSLog("[SecondLook] glasses session error: %@ (%@)", error.localizedDescription, String(describing: error))
        Task { @MainActor in self?.lastError = error.localizedDescription }
      }.store(in: sessionTokens)
      NSLog("[SecondLook] opening session on %@; device: %@", String(describing: identifier), deviceDiagnostics)
      sessionState = .starting
      try session.start()
    } catch {
      lastError = "Couldn't connect: \(error.localizedDescription). Device: \(deviceDiagnostics)"
      NSLog("[SecondLook] session failed: %@", lastError ?? "Unknown")
      teardown()
    }
  }

  func disconnect() {
    stopListening()
    session?.stop()
  }

  private func sessionChanged(_ state: DeviceSessionState) {
    NSLog("[SecondLook] glasses session: %@; device: %@", String(describing: state), deviceDiagnostics)
    sessionState = state
    switch state {
    case .started:
      attachInputs()
      attachDisplayIfSupported()
    case .stopped:
      teardown()
    default:
      break
    }
  }

  private func teardown() {
    if let c = photoContinuation { photoContinuation = nil; c.resume(throwing: GlassesError.notConnected) }
    streamTokens.clear()
    capabilityTokens.clear()
    sessionTokens.clear()
    camera = nil
    display = nil
    displayReady = false
    inputs = nil
    speech = nil
    hasDisplay = false
    hasSpeech = false
    isListening = false
    streamState = .stopped
    session = nil
    sessionState = .stopped
  }

  // MARK: Capture button

  private func attachInputs() {
    guard inputs == nil, let session else { return }
    do {
      let config = InputsConfiguration(sources: [.captureButton], consumeBack: false)
      guard let inputs = try session.addInputs(configuration: config) else { return }
      self.inputs = inputs
      background.append(Task { [weak self] in
        for await event in inputs.events {
          if case let .capture(pressType, source, _) = event, pressType == .shortPress, source == .captureButton {
            self?.onCapturePress?()
          }
        }
      })
    } catch {
      // Inputs are a convenience; the in-app button and voice still work.
    }
  }

  // MARK: Camera: one photo per check, stream stopped right after (privacy + battery)

  // MARK: Live video: the glasses' camera stream feeds live scan (frames stay in memory only)

  private(set) var liveVideoOn = false
  /// Last single photo from the glasses (for the debug mirror).
  @ObservationIgnored private(set) var lastGlassesPhoto: UIImage?
  /// Latest frame for the on-screen preview (updated a few times a second).
  private(set) var previewFrame: UIImage?
  @ObservationIgnored private var lastPreviewAt = Date.distantPast
  /// Thread-safe holder: frames arrive on a background thread.
  final class FrameBox: @unchecked Sendable {
    private let lock = NSLock(); private var image: UIImage?
    func set(_ i: UIImage?) { lock.lock(); image = i; lock.unlock() }
    func get() -> UIImage? { lock.lock(); defer { lock.unlock() }; return image }
  }
  nonisolated let frameBox = FrameBox()
  final class FrameCounter: @unchecked Sendable {
    private let lock = NSLock(); private var n = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; n += 1; return n }
  }

  func startLiveVideo() async throws {
    guard let session, sessionState == .started else { throw GlassesError.notConnected }
    if try await wearables.checkPermissionStatus(.camera) != .granted {
      guard try await wearables.requestPermission(.camera) == .granted else { throw GlassesError.permissionDenied }
    }
    try startStream(on: session)
    let box = frameBox
    let counter = FrameCounter()
    camera?.stream.videoFramePublisher.listen { [weak self] frame in
      let n = counter.next()
      guard let image = frame.makeUIImage() else {
        if n <= 3 || n % 150 == 0 { NSLog("[SecondLook] glasses frame %d: could not convert to image", n) }
        return
      }
      if n <= 2 || n % 300 == 0 { NSLog("[SecondLook] glasses frame %d: %.0fx%.0f", n, image.size.width, image.size.height) }
      box.set(image)
      Task { @MainActor in
        guard let self, self.liveVideoOn, Date().timeIntervalSince(self.lastPreviewAt) > 0.12 else { return }
        self.lastPreviewAt = Date(); self.previewFrame = image
      }
    }.store(in: streamTokens)
    try await waitForStreaming(timeout: .seconds(6))
    liveVideoOn = true
    NSLog("[SecondLook] glasses live video on")
  }

  func stopLiveVideo() {
    guard liveVideoOn || camera != nil else { return }
    liveVideoOn = false
    frameBox.set(nil)
    previewFrame = nil
    stopStream()
  }

  /// The newest glasses frame, or nil before the first one arrives.
  nonisolated func videoSnapshot() -> UIImage? { frameBox.get() }

  func capturePhoto(timeout: Duration = .seconds(8)) async throws -> UIImage {
    guard let session, sessionState == .started else { throw GlassesError.notConnected }
    // While live video runs, the newest frame is the photo (don't stop the stream).
    if liveVideoOn, let frame = videoSnapshot() { return frame }
    if try await wearables.checkPermissionStatus(.camera) != .granted {
      guard try await wearables.requestPermission(.camera) == .granted else { throw GlassesError.permissionDenied }
    }
    try startStream(on: session)
    defer { stopStream() }
    try await waitForStreaming(timeout: .seconds(5))

    let data: Data = try await withCheckedThrowingContinuation { cont in
      photoContinuation = cont
      guard camera?.stream.capturePhoto(format: .jpeg) == true else {
        photoContinuation = nil
        cont.resume(throwing: GlassesError.captureFailed)
        return
      }
      Task { [weak self] in
        try? await Task.sleep(for: timeout)
        guard let self, let pending = self.photoContinuation else { return }
        self.photoContinuation = nil
        pending.resume(throwing: GlassesError.timeout)
      }
    }
    guard let image = UIImage(data: data) else { throw GlassesError.captureFailed }
    lastGlassesPhoto = image
    return image
  }

  private func startStream(on session: DeviceSession) throws {
    guard camera == nil else { return }
    // High resolution: we need to read small text on letters and screens.
    // Raw (uncompressed) frames: VideoFrame.makeUIImage() can't convert hvc1 (HEVC) frames,
    // and live scan needs images. Medium resolution keeps raw frames within the link budget.
    let config = StreamConfiguration(videoCodec: .raw, resolution: .medium, frameRate: 15)
    guard let cam = try session.addCamera(config: config) else { throw GlassesError.cameraUnavailable }
    camera = cam
    cam.stream.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.streamState = state }
    }.store(in: streamTokens)
    cam.stream.photoDataPublisher.listen { [weak self] photo in
      Task { @MainActor in
        guard let self, let c = self.photoContinuation else { return }
        self.photoContinuation = nil
        c.resume(returning: photo.data)
      }
    }.store(in: streamTokens)
    cam.stream.errorPublisher.listen { [weak self] error in
      Task { @MainActor in
        guard let self else { return }
        self.lastError = error.localizedDescription
        if let c = self.photoContinuation { self.photoContinuation = nil; c.resume(throwing: error) }
      }
    }.store(in: streamTokens)
    streamState = .starting
    cam.stream.start()
  }

  private func waitForStreaming(timeout: Duration) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while streamState != .streaming {
      // DAT known issue: device-state sessions are unreliable with a camera stream,
      // so we detect drops from the stream itself and time out instead of hanging.
      if clock.now >= deadline || session == nil { throw GlassesError.timeout }
      try await Task.sleep(for: .milliseconds(100))
    }
  }

  private func stopStream() {
    camera?.stream.stop()
    streamTokens.clear()
    camera = nil
    streamState = .stopped
  }

  // MARK: Display card (Ray-Ban Display only)

  private func attachDisplayIfSupported() {
    guard display == nil, let session else { return }
    let supports = devices.compactMap { wearables.deviceForIdentifier($0) }.contains { $0.supportsDisplay() }
    guard supports else { hasDisplay = false; return }
    do {
      let display = try session.addDisplay()
      self.display = display
      display.statePublisher.listen { [weak self] state in
        Task { @MainActor in
          guard let self else { return }
          self.displayReady = (state == .started)
          self.hasDisplay = self.displayReady
        }
      }.store(in: capabilityTokens)
      display.start()
    } catch {
      hasDisplay = false
    }
  }

  func showOnDisplay(_ result: CheckResult) async {
    guard let display, displayReady else { return }
    do { try await display.send(DisplayCards.result(result)) } catch { lastError = "Display: \(error.localizedDescription)" }
  }

  func showCheckingOnDisplay(_ message: String) async {
    guard let display, displayReady else { return }
    try? await display.send(DisplayCards.checking(message))
  }

  // MARK: Speech (call mode). Recognition runs on the glasses; only text reaches the phone.

  /// Returns false if these glasses have no on-device speech (caller falls back to the phone).
  @discardableResult
  func startListening() -> Bool {
    guard let session, sessionState == .started else { return false }
    if speech == nil {
      do {
        guard let s = try session.addSpeech() else { hasSpeech = false; return false }
        speech = s
        hasSpeech = true
        s.transcriptionPublisher.listen { [weak self] result in
          let text = result.text
          let isFinal = result.isFinal
          Task { @MainActor in
            guard let self, self.isListening else { return }
            self.onTranscript?(text, isFinal)
          }
        }.store(in: capabilityTokens)
      } catch {
        hasSpeech = false
        return false
      }
    }
    speech?.start()
    isListening = true
    return true
  }

  func stopListening() {
    guard isListening else { return }
    isListening = false
    speech?.stop()
  }
}
