import Foundation
import Observation
import UIKit

/// What the user wants to be protected from.
enum Protection: String, CaseIterable, Identifiable {
  case letters, messages, websites, shops, qr, calls
  var id: String { rawValue }

  var title: String {
    switch self {
    case .letters: return "letters & bills"
    case .messages: return "messages"
    case .websites: return "websites"
    case .shops: return "webshops"
    case .qr: return "qr codes"
    case .calls: return "phone calls"
    }
  }

  var usesCamera: Bool { self != .calls }
}

/// Runs checks and owns the app state.
/// On request: one photo per check. Always on: a quiet photo check every 15 s
/// (and call listening if chosen); it only speaks up when something looks wrong.
/// Every result is delivered the same way: a notification with one short paragraph,
/// spoken through the glasses, and a card on Ray-Ban Display. Nothing is stored.
@Observable
@MainActor
final class CheckCoordinator {
  enum Phase: Equatable { case idle, capturing, checking, done }

  private(set) var phase: Phase = .idle
  private(set) var result: CheckResult?
  private(set) var isListening = false
  private(set) var alwaysOnRunning = false
  var errorMessage: String?

  var protections: Set<Protection> {
    didSet {
      UserDefaults.standard.set(protections.map(\.rawValue), forKey: "protections")
      if alwaysOn { syncAlwaysOn() }
    }
  }

  var alwaysOn: Bool {
    didSet {
      UserDefaults.standard.set(alwaysOn, forKey: "alwaysOn")
      syncAlwaysOn()
    }
  }

  @ObservationIgnored let glasses: GlassesManager
  @ObservationIgnored private let api: APIClient
  @ObservationIgnored private let speaker = Speaker.shared
  @ObservationIgnored private let phoneListener = PhoneListener()
  /// Which microphone call listening uses right now.
  var micName: String { usingPhoneMic ? (phoneListener.micName.isEmpty ? "the phone" : phoneListener.micName) : "the glasses" }
  @ObservationIgnored private var usingPhoneMic = false
  @ObservationIgnored private var transcript = ""
  @ObservationIgnored private var lastCallCheck = Date.distantPast
  @ObservationIgnored private var callCheckInFlight = false
  @ObservationIgnored private var alwaysOnTask: Task<Void, Never>?
  @ObservationIgnored private var lastAlert: (verdict: CheckResult.Verdict, labels: Set<String>, at: Date)?
  @ObservationIgnored private var speakTurn = Int.random(in: 0..<12)
  @ObservationIgnored private var clearTask: Task<Void, Never>?

  static let alwaysOnInterval: Duration = .seconds(15)

  init(glasses: GlassesManager, api: APIClient = .shared) {
    self.glasses = glasses
    self.api = api
    let saved = UserDefaults.standard.stringArray(forKey: "protections")
    self.protections = Set((saved ?? ["letters", "messages", "websites", "shops", "calls"]).compactMap(Protection.init))
    self.alwaysOn = UserDefaults.standard.bool(forKey: "alwaysOn")

    glasses.onCapturePress = { [weak self] in Task { await self?.checkWithGlasses() } }
    glasses.onTranscript = { [weak self] text, isFinal in self?.heard(text, isFinal: isFinal) }
    phoneListener.onTranscript = { [weak self] text, isFinal in self?.heard(text, isFinal: isFinal) }
    if alwaysOn { syncAlwaysOn() }
  }

  var isBusy: Bool { phase == .capturing || phase == .checking }

  func toggle(_ p: Protection) {
    if protections.contains(p) { protections.remove(p) } else { protections.insert(p) }
  }

  // MARK: On request

  func checkWithGlasses() async {
    guard !isBusy else { return }
    phase = .capturing
    speaker.say("Checking.")
    await glasses.showCheckingOnDisplay("Checking…")
    do {
      let image = try await glasses.capturePhoto()
      phase = .checking
      deliver(await check(image: image), quiet: false)
    } catch {
      deliver(.notSure(glasses.isConnected
                       ? "I couldn't take the photo. Try again or use the phone camera."
                       : "Your glasses aren't connected. Use the phone camera instead.", engine: "Glasses"),
              quiet: false)
    }
  }

  func checkPhoneImage(_ image: UIImage) async {
    guard !isBusy else { return }
    phase = .checking
    deliver(await check(image: image), quiet: false)
  }

  /// Gemini via our server first; if that fails, on-device OCR + server text check, then offline rules.
  private func check(image: UIImage, live: Bool = false, phoneText: String = "") async -> CheckResult {
    // Live scan: if the server was just unreachable, don't wait on it again for 30 s.
    let skipServer = live && Date() < serverDownUntil
    if !skipServer {
      do { return try await api.analyzeImage(image, live: live, phoneText: phoneText) } catch {
        if live, APIClient.isUnreachable(error) { serverDownUntil = Date().addingTimeInterval(30) }
        NSLog("[SecondLook] image check failed: \(error)")
      }
    }
    let text = await OfflineChecker.recognizeText(in: image)
    if !text.isEmpty, !(live && Date() < serverDownUntil),
       let r = try? await api.analyzeText(Redactor.redact(text)) { return r }
    return OfflineChecker.check(text: text)
  }
  @ObservationIgnored private var serverDownUntil = Date.distantPast
  /// True while live scan runs on the basic on-device check because the server can't be reached.
  var liveOffline: Bool { liveStatus != .off && Date() < serverDownUntil }

  // MARK: Live scan (phone camera video)

  /// What live scan is doing right now, shown on the camera screen.
  enum LiveStatus: Equatable { case off, starting, watching, reading, checking }
  private(set) var liveStatus: LiveStatus = .off
  /// Boxes over the video: the whole message being checked (yellow), and
  /// where the scam signs are (red, with a label). Normalized 0-1, origin top-left.
  struct LiveBox: Identifiable, Equatable {
    enum Kind { case region, warning }
    let id: Int
    let rect: CGRect
    let kind: Kind
    let label: String?
  }
  private(set) var liveBoxes: [LiveBox] = []
  /// Pixel size of the frames the boxes refer to (to map them onto the preview).
  private(set) var liveFrameSize: CGSize = .zero
  let liveCamera = LiveCamera()
  @ObservationIgnored private var liveFromAlwaysOn = false
  /// Live scan is reading the glasses' camera (true) or the phone camera (false).
  private(set) var usingGlassesVideo = false
  @ObservationIgnored private var liveTask: Task<Void, Never>?
  @ObservationIgnored private var lastLiveText = ""
  @ObservationIgnored private var lastLiveCheck = Date.distantPast
  @ObservationIgnored private var liveCheckInFlight = false
  /// Scam signs from the last live result, followed on screen while they stay in view.
  @ObservationIgnored private var liveLines: [OfflineChecker.Line] = []
  @ObservationIgnored private var liveWarnings: [(label: String, evidence: String)] = []

  /// Boxes follow the text about twice a second (on-device, free).
  static let liveBoxInterval: Duration = .milliseconds(500)
  /// A frame is considered for a full check at most every 2 s.
  static let liveInterval: TimeInterval = 2

  /// Read the latest frame on-device and box the text. Every 2 s, only when it shows
  /// something worth checking (payment, link, codes, scam wording) and differs from
  /// what was last checked, send it for the full check (Gemini fast model).
  func startLiveScan() async {
    guard liveStatus == .off else { return }
    liveStatus = .starting
    usingGlassesVideo = false
    if glasses.isConnected {
      do { try await glasses.startLiveVideo(); usingGlassesVideo = true } catch {
        NSLog("[SecondLook] glasses video failed, using phone camera: %@", error.localizedDescription)
      }
    }
    if !usingGlassesVideo {
      do { try await liveCamera.start() } catch {
        liveStatus = .off
        errorMessage = error.localizedDescription
        return
      }
    }
    lastLiveText = ""
    liveWarnings = []
    liveStatus = .watching
    liveTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: Self.liveBoxInterval)
        guard let self, !Task.isCancelled else { return }
        await self.liveTick()
      }
    }
  }

  func stopLiveScan() {
    liveTask?.cancel()
    liveTask = nil
    if usingGlassesVideo { glasses.stopLiveVideo() } else { liveCamera.stop() }
    usingGlassesVideo = false
    liveStatus = .off
    liveBoxes = []
    liveWarnings = []
  }

  private func liveTick() async {
    guard let frame = usingGlassesVideo ? glasses.videoSnapshot() : liveCamera.snapshot() else { return }
    let lines = await OfflineChecker.recognizeLines(in: frame.downscaled(maxSide: 1280), fast: true)
    guard liveStatus != .off else { return }
    liveFrameSize = frame.size
    liveLines = lines
    liveBoxes = boxes(for: lines)

    let text = lines.map(\.text).joined(separator: "\n")
    guard !liveCheckInFlight, Date().timeIntervalSince(lastLiveCheck) >= Self.liveInterval,
          OfflineChecker.worthChecking(text), !Self.similar(text, lastLiveText) else { return }
    lastLiveText = text
    lastLiveCheck = Date()
    liveCheckInFlight = true
    liveStatus = .checking
    let checkedLines = lines
    Task {
      let r = await check(image: frame, live: true, phoneText: Redactor.redact(text))
      liveCheckInFlight = false
      guard liveStatus != .off else { return }
      liveStatus = .watching
      let warning = r.verdict == .scam || r.verdict == .suspicious
      var found: [(label: String, evidence: String)] = []
      if warning {
        found = r.signals.filter { $0.weight > 0 && !$0.evidence.isEmpty }.map { ($0.label, $0.evidence) }
        // Gemini saw the whole frame and says where each sign is: take the lines it points at,
        // so they stay boxed while the phone moves.
        for b in r.boxes ?? [] where b.box_2d.count == 4 {
          let rect = CGRect(x: b.box_2d[1] / 1000, y: b.box_2d[0] / 1000,
                            width: (b.box_2d[3] - b.box_2d[1]) / 1000, height: (b.box_2d[2] - b.box_2d[0]) / 1000)
          for line in checkedLines {
            let overlap = line.rect.intersection(rect)
            if !overlap.isNull, overlap.width * overlap.height >= 0.4 * line.rect.width * line.rect.height {
              found.append((b.label, line.text))
            }
          }
        }
      }
      liveWarnings = found
      liveBoxes = boxes(for: liveLines)
      deliver(r, quiet: true)
    }
  }

  /// Yellow: one frame around the whole message (the text block around anything worth
  /// checking), since the full frame is what gets checked. Red: each line holding a scam sign.
  private func boxes(for lines: [OfflineChecker.Line]) -> [LiveBox] {
    var out: [LiveBox] = []
    if let region = Self.messageRegion(lines) {
      out.append(LiveBox(id: -1, rect: region, kind: .region, label: nil))
    }
    var labelled = Set<String>()
    for (i, line) in lines.enumerated() {
      guard let w = liveWarnings.first(where: { Self.matches(line.text, $0.evidence) }) else { continue }
      let first = labelled.insert(w.label).inserted
      out.append(LiveBox(id: i, rect: line.rect, kind: .warning, label: first ? w.label : nil))
    }
    return out
  }

  /// Grow from the lines worth checking to the neighbouring lines of the same block
  /// (close below/above and overlapping sideways), so the box covers the whole message.
  private static func messageRegion(_ lines: [OfflineChecker.Line]) -> CGRect? {
    let seeds = lines.filter { OfflineChecker.hasTrigger($0.text) }
    guard var region = seeds.first?.rect else { return nil }
    for s in seeds.dropFirst() { region = region.union(s.rect) }
    var used = Set(seeds.map(\.rect.debugDescription))
    var grew = true
    while grew {
      grew = false
      for line in lines where !used.contains(line.rect.debugDescription) {
        let gap = max(line.rect.height, 0.01) * 1.8
        let near = region.insetBy(dx: -0.02, dy: -gap)
        let sideways = min(line.rect.maxX, region.maxX) - max(line.rect.minX, region.minX) > 0
        if near.intersects(line.rect), sideways {
          region = region.union(line.rect)
          used.insert(line.rect.debugDescription)
          grew = true
        }
      }
    }
    return region.insetBy(dx: -0.015, dy: -0.01)
  }

  /// Does an on-screen line contain the evidence text (or the other way round)?
  private static func matches(_ line: String, _ evidence: String) -> Bool {
    let l = line.lowercased(), e = evidence.lowercased()
    guard l.count >= 3, e.count >= 3 else { return false }
    if l.contains(e) || e.contains(l) { return true }
    let wl = Set(l.split { !$0.isLetter && !$0.isNumber }.filter { $0.count >= 3 })
    let we = Set(e.split { !$0.isLetter && !$0.isNumber }.filter { $0.count >= 3 })
    guard !wl.isEmpty, !we.isEmpty else { return false }
    return Double(wl.intersection(we).count) / Double(min(wl.count, we.count)) >= 0.6
  }

  /// Same thing still in view? (word overlap), so we don't re-check every 2 s.
  private static func similar(_ a: String, _ b: String) -> Bool {
    let wa = Set(a.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    let wb = Set(b.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    guard !wa.isEmpty, !wb.isEmpty else { return false }
    return Double(wa.intersection(wb).count) / Double(wa.union(wb).count) > 0.6
  }

  // MARK: Debug mirror (test builds only, opt-in in Settings)

  #if DEBUG
  @ObservationIgnored private var mirrorTask: Task<Void, Never>?
  func setDebugMirror(_ on: Bool) {
    mirrorTask?.cancel(); mirrorTask = nil
    guard on else { return }
    mirrorTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let frame: UIImage? = self.usingGlassesVideo ? self.glasses.videoSnapshot()
          : (self.liveStatus != .off ? self.liveCamera.snapshot() : self.glasses.lastGlassesPhoto)
        let g = self.glasses
        let status: [String: String] = [
          "source": self.usingGlassesVideo ? "glasses video" : (self.liveStatus != .off ? "phone camera" : (g.lastGlassesPhoto != nil ? "last glasses photo" : "none")),
          "glasses": g.headerText,
          "session": String(describing: g.sessionState),
          "registration": String(describing: g.registrationState),
          "device": g.deviceDiagnostics.isEmpty ? "none" : g.deviceDiagnostics,
          "bluetooth audio": g.bluetoothAudioName ?? "none",
          "last error": g.lastError ?? "none",
          "listening": self.isListening ? "yes, via \(self.micName)" : "no",
          "live scan": String(describing: self.liveStatus),
          "always on": self.alwaysOn ? "on" : "off",
          "last verdict": self.result.map { "\($0.verdict.rawValue): \($0.why)" } ?? "none",
        ]
        await self.api.postDebug(image: frame, status: status)
        try? await Task.sleep(for: .milliseconds(900))
      }
    }
  }
  #endif

  // MARK: Always on

  private func syncAlwaysOn() {
    alwaysOnTask?.cancel()
    alwaysOnTask = nil
    if liveFromAlwaysOn { stopLiveScan(); liveFromAlwaysOn = false }
    guard alwaysOn else {
      alwaysOnRunning = false
      if isListening { stopListening() }
      return
    }
    alwaysOnRunning = true
    if protections.contains(.calls), !isListening { Task { await startListening(announce: false) } }
    if !protections.contains(.calls), isListening { stopListening() }

    let watchesCamera = protections.contains { $0.usesCamera }
    guard watchesCamera else { return }
    // Always on with glasses: run the live-scan engine on the glasses' video in the
    // background (on-device reading twice a second, a check only when it matters, voice
    // only on warnings). Without a glasses session it waits and retries.
    alwaysOnTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        if self.glasses.isConnected, self.liveStatus == .off {
          await self.startLiveScan()
          self.liveFromAlwaysOn = self.usingGlassesVideo
          if !self.usingGlassesVideo { self.stopLiveScan() }
        }
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }

  // MARK: Calls

  func toggleListening() async {
    if isListening { stopListening() } else { await startListening(announce: true) }
  }

  private func startListening(announce: Bool) async {
    transcript = ""
    if glasses.isConnected, glasses.startListening() {
      usingPhoneMic = false
    } else {
      do {
        try await phoneListener.start()
        usingPhoneMic = true
      } catch {
        errorMessage = error.localizedDescription
        return
      }
    }
    isListening = true
    if announce { speaker.say("Listening to this call. I'll warn you if it sounds like a scam.") }
  }

  func stopListening() {
    if usingPhoneMic { phoneListener.stop() } else { glasses.stopListening() }
    isListening = false
    transcript = ""
    callCaption = ""
  }

  private static func lastWords(_ text: String, maxChars: Int) -> String {
    guard text.count > maxChars else { return text }
    let tail = text.suffix(maxChars)
    return "…" + (tail.firstIndex(of: " ").map { String(tail[tail.index(after: $0)...]) } ?? String(tail))
  }

  #if DEBUG
  /// Recording aid (`--demo-call`): plays a scripted call, word by word, through the real
  /// call check. No microphone, so the simulator can show call mode.
  func demoCall(_ lines: [String]) async {
    transcript = ""
    usingPhoneMic = true
    isListening = true
    speaker.say("Listening to this call. I'll warn you if it sounds like a scam.")
    try? await Task.sleep(for: .seconds(4))
    var text = ""
    for line in lines {
      for word in line.split(separator: " ") {
        guard isListening else { return }
        text += (text.isEmpty ? "" : " ") + word
        heard(text, isFinal: false)
        try? await Task.sleep(for: .milliseconds(230))
      }
      heard(text, isFinal: true)
      try? await Task.sleep(for: .milliseconds(900))
    }
  }
  #endif

  private static let urgentWords = ["code", "safe account", "anydesk", "teamviewer", "gift card", "bitcoin",
                                    "password", "pin", "transfer", "don't tell", "tunnusluku", "turvatili"]

  /// The last words heard on the call, shown on screen while listening (never stored).
  private(set) var callCaption = ""

  private func heard(_ text: String, isFinal: Bool) {
    guard isListening else { return }
    if usingPhoneMic { transcript = text } else if isFinal { transcript += (transcript.isEmpty ? "" : " ") + text }
    let current = usingPhoneMic ? transcript : transcript + " " + text
    callCaption = Self.lastWords(current, maxChars: 120)
    let lower = current.lowercased()
    let urgent = Self.urgentWords.contains { lower.contains($0) }
    let since = Date().timeIntervalSince(lastCallCheck)
    guard !callCheckInFlight, (urgent && since > 3) || (isFinal && since > 10) else { return }
    callCheckInFlight = true
    lastCallCheck = Date()
    let snapshot = Redactor.redact(String(current.suffix(2000)))
    Task {
      defer { self.callCheckInFlight = false }
      let r = (try? await api.analyzeText(snapshot)) ?? OfflineChecker.check(text: snapshot)
      guard self.isListening else { return }
      self.deliver(r, quiet: true)
    }
  }

  // MARK: Delivery: notification + one paragraph + voice + Display card

  /// quiet = background checks (always on, calls): only warnings are announced.
  private func deliver(_ r: CheckResult, quiet: Bool) {
    let warning = r.verdict == .scam || r.verdict == .suspicious
    if quiet && !warning {
      if phase != .done { phase = .idle }
      return
    }
    // Background checks: only speak again if there's something new to say. Same verdict
    // and no new kind of sign within 90 s -> update the screen quietly, no voice or alert.
    let labels = Set(r.warnings.map(\.label))
    if quiet, let last = lastAlert, last.verdict == r.verdict,
       labels.isSubset(of: last.labels), Date().timeIntervalSince(last.at) < 90 {
      result = r
      return
    }
    let carried = (quiet && lastAlert?.verdict == r.verdict) ? (lastAlert?.labels ?? []) : []
    lastAlert = (r.verdict, labels.union(carried), Date())

    result = r
    phase = .done
    Notifier.shared.post(r)
    speak(r)
    if warning { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    Task { await glasses.showOnDisplay(r) }

    clearTask?.cancel()
    clearTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(45))
      guard !Task.isCancelled else { return }
      self?.dismissResult()
    }
  }

  func dismissResult() {
    result = nil
    if !isBusy { phase = .idle }
  }

  func repeatAnswer() {
    if let r = result { speak(r) }
  }

  private func speak(_ r: CheckResult) {
    speakTurn += 1
    speaker.say(r.voiceLine(turn: speakTurn))
  }
}
