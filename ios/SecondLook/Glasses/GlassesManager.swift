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
    background.append(Task { [weak self] in
      for await state in wearables.registrationStateStream() {
        self?.registrationState = state
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
      do { _ = try await wearables.handleUrl(url) } catch { lastError = error.localizedDescription }
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
    devices.compactMap { wearables.deviceForIdentifier($0) }
      .contains { $0.linkState == .connected && $0.compatibility() == .compatible }
  }

  private var deviceDiagnostics: String {
    devices.compactMap { wearables.deviceForIdentifier($0) }
      .map { "\(String(describing: $0.linkState)), \(String(describing: $0.compatibility()))" }
      .joined(separator: "; ")
  }

  private func openSession() {
    guard session == nil else { return }
    do {
      let session = try wearables.createSession(deviceSelector: AutoDeviceSelector(wearables: wearables))
      self.session = session
      session.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.sessionChanged(state) }
      }.store(in: sessionTokens)
      session.errorPublisher.listen { [weak self] error in
        Task { @MainActor in self?.lastError = error.localizedDescription }
      }.store(in: sessionTokens)
      sessionState = .starting
      try session.start()
    } catch {
      lastError = "Couldn't connect: \(error.localizedDescription)"
      teardown()
    }
  }

  func disconnect() {
    stopListening()
    session?.stop()
  }

  private func sessionChanged(_ state: DeviceSessionState) {
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

  func capturePhoto(timeout: Duration = .seconds(8)) async throws -> UIImage {
    guard let session, sessionState == .started else { throw GlassesError.notConnected }
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
    return image
  }

  private func startStream(on session: DeviceSession) throws {
    guard camera == nil else { return }
    // High resolution: we need to read small text on letters and screens.
    let config = StreamConfiguration(videoCodec: .hvc1, resolution: .high, frameRate: 15)
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
