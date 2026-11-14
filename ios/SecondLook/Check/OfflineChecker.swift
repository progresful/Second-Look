import Foundation
import UIKit
import Vision

/// Fallback when the server or network is unavailable: on-device OCR (Apple Vision)
/// plus a small subset of the server rules. Never says "safe": with no strong signs
/// the answer is "not sure, don't pay yet".
enum OfflineChecker {
  private struct Rule {
    let id: String
    let label: String
    let weight: Double
    let explanation: String
    let pattern: String
  }

  private static let rules: [Rule] = [
    Rule(id: "credential_request", label: "Asks for codes or passwords", weight: 0.9,
         explanation: "Real companies and banks never ask for codes, passwords or card details by message.",
         pattern: #"\b(pin|password|banking codes?|bank credentials|card details|read me the code|tunnusluku|pankkitunnu\w*|vahvistuskoodi\w*)\b"#),
    Rule(id: "unusual_payment", label: "Unusual payment method", weight: 0.8,
         explanation: "Gift cards, crypto or a 'safe account' are classic scam payments.",
         pattern: #"\b(gift ?cards?|bitcoin|crypto|usdt|safe account|turvatili\w*|lahjakort\w*|only (by )?bank transfer)\b"#),
    Rule(id: "remote_access", label: "Asks to control your device", weight: 0.9,
         explanation: "Never install AnyDesk or TeamViewer because someone asks.",
         pattern: #"\b(anydesk|teamviewer|remote access)\b"#),
    Rule(id: "relative_impersonation", label: "Pretends to be a relative", weight: 0.8,
         explanation: "Call your relative on their old number.",
         pattern: #"\b(hi mum|hi mom|new number|moi äiti|uusi numero)\b"#),
    Rule(id: "false_urgency", label: "False urgency", weight: 0.5,
         explanation: "Pressure to act fast stops you from checking.",
         pattern: #"\b(urgent|immediately|within 24 hours|today only|heti|välittömästi)\b"#),
    Rule(id: "account_threat", label: "Threatens your account", weight: 0.7,
         explanation: "Threats that your account is limited or will be closed are a classic way to rush you.",
         pattern: #"\b(account (is|has been|will be) (limited|suspended|locked|closed|disabled|terminated)|permanently (disabled|closed|locked)|closure of your account|tilisi (on )?(suljettu|lukittu|jäädytetty))\b"#),
    Rule(id: "confirm_details", label: "Asks you to confirm your details", weight: 0.6,
         explanation: "Real companies don't ask you to confirm account details through a link.",
         pattern: #"\b(confirm (all of )?your (account|information|details|identity)|verify your (account|identity|information)|re-?verify|update your (payment|billing|account) (details|information)|vahvista tietosi)\b"#),
    Rule(id: "deadline", label: "Short deadline", weight: 0.4,
         explanation: "A tight deadline is meant to stop you from checking.",
         pattern: #"\b(\d{1,2} hours|24h|48h|tunnin sisällä)\b"#),
    Rule(id: "small_fee", label: "Small fee to release something", weight: 0.6,
         explanation: "A small fee via a link is a common parcel scam.",
         pattern: #"\b(customs fee|delivery fee|tullimaksu|toimitusmaksu)\b"#),
    Rule(id: "risky_link", label: "Unusual website address", weight: 0.5,
         explanation: "Scam sites often use cheap endings like .top or .xyz.",
         pattern: #"[a-z0-9-]+\.(top|xyz|icu|click|shop|site|online)\b"#),
  ]

  /// A line of text found on-device, with its place in the image
  /// (normalized 0-1, origin top-left).
  struct Line: Equatable {
    let text: String
    let rect: CGRect
  }

  /// Read text in the image on-device (Finnish + English).
  static func recognizeText(in image: UIImage, fast: Bool = false) async -> String {
    await recognizeLines(in: image, fast: fast).map(\.text).joined(separator: "\n")
  }

  static func recognizeLines(in image: UIImage, fast: Bool = false) async -> [Line] {
    guard let cg = image.cgImage else { return [] }
    return await withCheckedContinuation { cont in
      let request = VNRecognizeTextRequest { req, _ in
        let lines = (req.results as? [VNRecognizedTextObservation])?.compactMap { obs -> Line? in
          guard let s = obs.topCandidates(1).first?.string else { return nil }
          let b = obs.boundingBox // Vision: origin bottom-left
          return Line(text: s, rect: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
        } ?? []
        cont.resume(returning: lines)
      }
      request.recognitionLevel = fast ? .fast : .accurate
      request.recognitionLanguages = ["fi-FI", "en-US"]
      request.usesLanguageCorrection = !fast
      do {
        try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
      } catch {
        cont.resume(returning: [])
      }
    }
  }

  /// How many text-like regions are in the image (cheap; works even when the text is too
  /// small to read). Used to decide when a full-resolution glasses photo is worth taking.
  static func textRegionCount(in image: UIImage) async -> Int {
    guard let cg = image.cgImage else { return 0 }
    return await withCheckedContinuation { cont in
      let req = VNDetectTextRectanglesRequest { r, _ in cont.resume(returning: r.results?.count ?? 0) }
      req.reportCharacterBoxes = false
      do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req]) } catch { cont.resume(returning: 0) }
    }
  }

  /// Cheap on-device gate for live scan: is there enough text, and does it involve
  /// money, a link, codes or scam wording? Only then is the frame sent for a full check.
  static func worthChecking(_ text: String) -> Bool {
    guard text.filter({ $0.isLetter }).count >= 20 else { return false }
    return hasTrigger(text)
  }

  /// Does this piece of text involve money, a link, codes or scam wording?
  static func hasTrigger(_ text: String) -> Bool {
    let t = text.lowercased()
    if rules.contains(where: { t.range(of: $0.pattern, options: [.regularExpression, .caseInsensitive]) != nil }) {
      return true
    }
    let triggers = #"(€|\$|£|\beur\b|\d+[.,]\d{2}\b|%|\b(pay|payment|checkout|cart|order|buy|price|sale|discount|invoice|bill|iban|account|card|login|log in|verify|confirm|code|parcel|package|delivery|refund|prize|winner|bank|maksa|maksu|lasku|tilaa|ostoskori|tarjous|alennus|tili|kortti|vahvista|paketti|pankki)\b|https?://|www\.|\b[a-z0-9-]+\.(com|fi|net|org|shop|store|top|xyz|online|site)\b)"#
    return t.range(of: triggers, options: .regularExpression) != nil
  }

  static func check(text: String) -> CheckResult {
    let clean = Redactor.redact(text)
    guard clean.trimmingCharacters(in: .whitespacesAndNewlines).count >= 12 else {
      return .notSure("I can't read it. Hold it closer and steady.", engine: "Offline")
    }
    var signals: [CheckResult.Signal] = []
    for rule in rules {
      if let range = clean.range(of: rule.pattern, options: [.regularExpression, .caseInsensitive]) {
        signals.append(.init(id: rule.id, label: rule.label, weight: rule.weight,
                             explanation: rule.explanation, evidence: String(clean[range]), source: "offline"))
      }
    }
    let score = signals.reduce(0) { $0 + $1.weight }
    let top = signals.max { $0.weight < $1.weight }
    let suffix = " I'm offline, so this is a basic check."
    var result: CheckResult
    if score >= 1.2 {
      result = CheckResult(verdict: .scam, confidence: 0.6,
                           spoken: "Likely scam. Don't pay or reply. " + (top?.explanation ?? "") + suffix,
                           reason: top?.explanation ?? "", signals: signals)
    } else if score >= 0.5 {
      result = CheckResult(verdict: .suspicious, confidence: 0.4,
                           spoken: "Be careful. " + (top?.explanation ?? "") + suffix,
                           reason: top?.explanation ?? "", signals: signals)
    } else {
      result = .notSure("I can't check fully right now. Don't pay yet. Call the official number.", engine: "Offline")
      result = CheckResult(verdict: .not_sure, confidence: 0, spoken: result.spoken, reason: "", signals: signals)
    }
    result.engine = "Offline (on-device)"
    return result
  }
}

/// Removes personal data before any text leaves the phone. Mirrors api/app/redact.py.
enum Redactor {
  private static let rules: [(String, String)] = [
    ("[IBAN]", #"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,4})?\b"#),
    ("[CARD]", #"\b(?:\d[ -]?){13,19}\b"#),
    ("[HETU]", #"\b\d{6}[-+AaBCDEFYXWVU]\d{3}[0-9A-Ya-y]\b"#),
    ("[EMAIL]", #"\b[\w.+-]+@[\w-]+\.[\w.-]+\b"#),
    ("[PHONE]", #"(?<!\w)(?:\+358|0)[\s-]?\d{1,3}(?:[\s-]?\d{2,4}){2,3}(?!\w)"#),
  ]

  static func redact(_ text: String) -> String {
    rules.reduce(text) { acc, rule in
      acc.replacingOccurrences(of: rule.1, with: rule.0, options: .regularExpression)
    }
  }
}
