import AVFoundation
import FluidAudio
import Foundation

/// Kokoro-82M running on this iPhone (Core ML / Neural Engine via FluidAudio), voice af_heart.
/// Model files download once on first launch and are cached; after that it works offline.
actor KokoroVoice {
  enum State: String, Sendable { case notLoaded, loading, ready, failed }
  static let voice = "af_heart"
  static let shared = KokoroVoice()

  private(set) var state: State = .notLoaded
  private var manager: KokoroAneManager?

  func prepare() async {
    guard state == .notLoaded || state == .failed else { return }
    state = .loading
    let m = KokoroAneManager(defaultVoice: Self.voice)
    do {
      try await m.initialize(preloadVoices: [Self.voice])
      manager = m
      _ = try? await m.synthesize(text: "Ready.", voice: Self.voice)  // warm up the first-call path
      state = .ready
      NSLog("[SecondLook] Kokoro voice ready")
    } catch {
      state = .failed
      NSLog("[SecondLook] Kokoro voice unavailable: \(error)")
    }
  }

  /// 24 kHz mono WAV, or nil if Kokoro isn't ready or fails.
  func wav(_ text: String, speed: Float) async -> Data? {
    guard state == .ready, let manager else { return nil }
    do { return try await manager.synthesize(text: text, voice: Self.voice, speed: speed) } catch {
      NSLog("[SecondLook] Kokoro synthesis failed: \(error)")
      return nil
    }
  }
}

/// Speaks answers in a warm voice (Kokoro on the phone), falling back to the system voice
/// until Kokoro is ready. When glasses are connected as a Bluetooth audio device, iOS routes
/// the audio to the glasses' open-ear speakers.
@MainActor
final class Speaker: NSObject, AVAudioPlayerDelegate {
  static let shared = Speaker()
  private let synth = AVSpeechSynthesizer()
  private var player: AVAudioPlayer?
  private var playTask: Task<Void, Never>?
  private var finished: CheckedContinuation<Void, Never>?

  /// System-voice rate (AVSpeech scale). Kokoro speed is derived from it.
  var rate: Float = UserDefaults.standard.object(forKey: "speechRate") as? Float ?? 0.52
  private var kokoroSpeed: Float { min(1.2, max(0.8, rate / 0.52)) }

  func prepareWarmVoice() {
    Task.detached(priority: .utility) { await KokoroVoice.shared.prepare() }
  }

  func say(_ text: String, interrupt: Bool = true) {
    configureSession()
    if interrupt { stop() }
    let sentences = Self.sentences(text)
    guard !sentences.isEmpty else { return }
    let speed = kokoroSpeed
    playTask = Task { [weak self] in
      guard let self else { return }
      guard await KokoroVoice.shared.state == .ready else {
        NSLog("[SecondLook] voice: iPhone (Kokoro not ready)")
        self.speakSystem(sentences.joined(separator: " "))
        return
      }
      NSLog("[SecondLook] voice: Kokoro af_heart, %d sentences", sentences.count)
      // Synthesize the next sentence while the current one plays.
      var next: Task<Data?, Never>? = Task.detached { await KokoroVoice.shared.wav(sentences[0], speed: speed) }
      for i in sentences.indices {
        guard let data = await next?.value else {
          if !Task.isCancelled { self.speakSystem(sentences[i...].joined(separator: " ")) }
          return
        }
        if i + 1 < sentences.count {
          let s = sentences[i + 1]
          next = Task.detached { await KokoroVoice.shared.wav(s, speed: speed) }
        } else {
          next = nil
        }
        if Task.isCancelled { return }
        NSLog("[SecondLook] Kokoro sentence %d: %d bytes", i + 1, data.count)
        await self.play(data)
      }
    }
  }

  func stop() {
    playTask?.cancel()
    playTask = nil
    player?.stop()
    player = nil
    finished?.resume()
    finished = nil
    if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
  }

  private func play(_ data: Data) async {
    guard let p = try? AVAudioPlayer(data: data) else { return }
    p.delegate = self
    player = p
    await withCheckedContinuation { cont in
      finished = cont
      if !p.play() { finished = nil; cont.resume() }
    }
  }

  nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    Task { @MainActor in
      self.finished?.resume()
      self.finished = nil
    }
  }

  // MARK: System voice fallback

  private lazy var systemVoice: AVSpeechSynthesisVoice? = {
    let english = AVSpeechSynthesisVoice.speechVoices().filter {
      $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice)
    }
    func score(_ v: AVSpeechSynthesisVoice) -> Int {
      (v.quality == .premium ? 300 : v.quality == .enhanced ? 200 : 100) + (v.language == "en-US" ? 5 : 0)
    }
    return english.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: "en-US")
  }()

  private func speakSystem(_ text: String) {
    for s in Self.sentences(text) {
      let u = AVSpeechUtterance(string: s)
      u.voice = systemVoice
      u.rate = rate
      u.pitchMultiplier = 1.03
      u.postUtteranceDelay = 0.18
      synth.speak(u)
    }
  }

  /// Sentences with their own punctuation, so each keeps its intonation.
  static func sentences(_ text: String) -> [String] {
    var out: [String] = [], buf = ""
    for ch in text {
      buf.append(ch)
      if ".!?".contains(ch) {
        let t = buf.trimmingCharacters(in: .whitespaces)
        if t.count > 1 { out.append(t) }
        buf = ""
      }
    }
    let rest = buf.trimmingCharacters(in: .whitespaces)
    if !rest.isEmpty { out.append(rest) }
    return out
  }

  private func configureSession() {
    let session = AVAudioSession.sharedInstance()
    // .playAndRecord keeps the Bluetooth route active while call mode uses the mic.
    try? session.setCategory(.playAndRecord, mode: .spokenAudio,
                             options: [.allowBluetoothA2DP, .allowBluetoothHFP, .duckOthers, .defaultToSpeaker])
    try? session.setActive(true)
  }
}
