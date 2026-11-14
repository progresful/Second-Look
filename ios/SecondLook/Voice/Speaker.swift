import AVFoundation
import Foundation

/// Speaks answers. When glasses are connected as a Bluetooth audio device,
/// iOS routes speech to the glasses' open-ear speakers.
@MainActor
final class Speaker: NSObject {
  static let shared = Speaker()
  private let synth = AVSpeechSynthesizer()

  /// AVSpeech default (0.5) sounds natural; the old 0.47 felt sluggish.
  var rate: Float = UserDefaults.standard.object(forKey: "speechRate") as? Float ?? 0.52

  /// The most natural English voice on this phone: Premium > Enhanced > default,
  /// preferring warm conversational voices. Better voices are a free download in
  /// Settings > Accessibility > Spoken Content > Voices > English.
  private lazy var voice: AVSpeechSynthesisVoice? = {
    let preferred = ["Zoe", "Ava", "Evan", "Nathan", "Joelle", "Noelle", "Samantha", "Allison", "Tom"]
    let english = AVSpeechSynthesisVoice.speechVoices().filter {
      $0.language.hasPrefix("en") && !$0.voiceTraits.contains(.isNoveltyVoice)
    }
    func score(_ v: AVSpeechSynthesisVoice) -> Int {
      let quality = switch v.quality {
      case .premium: 300
      case .enhanced: 200
      default: 100
      }
      let nameBonus = preferred.firstIndex { v.name.hasPrefix($0) }.map { 50 - $0 } ?? 0
      let localeBonus = v.language == "en-US" ? 5 : 0
      return quality + nameBonus + localeBonus
    }
    let best = english.max { score($0) < score($1) }
    if let best { NSLog("[SecondLook] voice: \(best.name) (\(best.quality.rawValue))") }
    return best ?? AVSpeechSynthesisVoice(language: "en-US")
  }()

  /// Speaks sentence by sentence with short pauses, which sounds far less robotic
  /// than one long utterance.
  func say(_ text: String, interrupt: Bool = true) {
    configureSession()
    if interrupt, synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    let sentences = text.split(whereSeparator: { ".!?".contains($0) })
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    var rest = Substring(text)
    for s in sentences {
      // Keep the sentence's own punctuation for intonation.
      guard let r = rest.range(of: s) else { continue }
      var end = r.upperBound
      while end < rest.endIndex, ".!?".contains(rest[end]) { end = rest.index(after: end) }
      let piece = String(rest[r.lowerBound..<end])
      rest = rest[end...]
      let u = AVSpeechUtterance(string: piece)
      u.voice = voice
      u.rate = rate
      u.pitchMultiplier = 1.03
      u.postUtteranceDelay = 0.18
      synth.speak(u)
    }
  }

  func stop() {
    synth.stopSpeaking(at: .immediate)
  }

  private func configureSession() {
    let session = AVAudioSession.sharedInstance()
    // .playAndRecord keeps the Bluetooth route active while call mode uses the mic.
    try? session.setCategory(.playAndRecord, mode: .spokenAudio,
                             options: [.allowBluetoothA2DP, .allowBluetoothHFP, .duckOthers, .defaultToSpeaker])
    try? session.setActive(true)
  }
}
