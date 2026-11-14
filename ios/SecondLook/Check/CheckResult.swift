import Foundation

/// Mirrors the backend response from /analyze and /analyze-image.
struct CheckResult: Codable, Equatable {
  enum Verdict: String, Codable {
    case scam, suspicious, looks_ok, not_sure
  }

  struct Signal: Codable, Equatable, Hashable {
    let id: String
    let label: String
    let weight: Double
    let explanation: String
    let evidence: String
    let source: String
  }

  struct Box: Codable, Equatable {
    let id: String
    let label: String
    let evidence: String
    /// [ymin, xmin, ymax, xmax] on a 0-1000 scale (Gemini convention).
    let box_2d: [Double]
  }

  let verdict: Verdict
  let confidence: Double
  let spoken: String
  let reason: String
  let signals: [Signal]
  var boxes: [Box]? = nil
  var latency_ms: Int? = nil
  var llm_used: Bool? = nil

  /// Which engine produced this answer, for honest UI ("Gemini", "Server rules", "Offline").
  var engine: String = "Server"

  enum CodingKeys: String, CodingKey {
    case verdict, confidence, spoken, reason, signals, boxes, latency_ms, llm_used
  }

  /// Warning signs only (brand mentions and "official domain" are not warnings).
  var warnings: [Signal] {
    signals.filter { $0.weight >= 0.3 }.sorted { $0.weight > $1.weight }
  }

  var title: String {
    switch verdict {
    case .scam: return "Likely scam"
    case .suspicious: return "Be careful"
    case .looks_ok: return "No scam signs found"
    case .not_sure: return "Not sure"
    }
  }

  var nextStep: String {
    switch verdict {
    case .scam, .suspicious: return "Don't pay. Call the official number, for example the one on your card."
    case .looks_ok: return "Still unsure? Call the official number."
    case .not_sure: return "Don't pay yet. Call the official number."
    }
  }

  /// One short paragraph for the notification and the home screen.
  var summary: String {
    let response = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !response.isEmpty { return response }
    switch verdict {
    case .scam, .suspicious:
      let why = warnings.first?.explanation ?? reason
      return (why.isEmpty ? "" : why + " ") + "Don't pay. Check with the official number first."
    case .looks_ok:
      return "No scam signs found. If you're unsure, check with the official number."
    case .not_sure:
      return spoken
    }
  }

  /// Lowercase state word for the home screen.
  var word: String {
    switch verdict {
    case .scam: return "likely scam"
    case .suspicious: return "be careful"
    case .looks_ok: return "looks okay"
    case .not_sure: return "not sure"
    }
  }

  static func notSure(_ spoken: String, engine: String) -> CheckResult {
    var r = CheckResult(verdict: .not_sure, confidence: 0, spoken: spoken, reason: "", signals: [])
    r.engine = engine
    return r
  }
}

/// Preserve the analysis answer and specific failure/offline guidance.
/// Stock wording is only a fallback for results without a spoken answer.
extension CheckResult {
  func voiceLine(turn: Int) -> String {
    let response = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
    if !response.isEmpty { return response }
    func pick(_ options: [String]) -> String { options[turn % options.count] }
    func sentence(_ s: String) -> String {
      let t = s.trimmingCharacters(in: .whitespaces)
      guard let last = t.last else { return "" }
      return ".!?".contains(last) ? t : t + "."
    }
    let signs = warnings
    let why = sentence(signs.first?.explanation ?? reason)

    switch verdict {
    case .scam:
      return [pick(["Hold on.", "Wait a moment.", "Careful.", "Stop there."]),
              pick(["This looks like a scam.", "I think this is a scam.", "This has scam written all over it."]),
              why + (signs.count > 1 ? Self.alsoLine(signs[1].label) : ""),
              pick(["Don't pay or click anything.", "Please don't pay this.", "Don't reply, and don't click the link."]),
              pick(["If you're worried, call them on a number you already trust.",
                    "Check with the real company first, using their official number.", ""])]
        .filter { !$0.isEmpty }.joined(separator: " ")
    case .suspicious:
      return [pick(["Hmm, something's off here.", "I'm not comfortable with this one.", "Take a second look at this."]),
              why,
              pick(["Check it before you pay.", "Better confirm it with the sender another way.", "I'd hold off for now."])]
        .filter { !$0.isEmpty }.joined(separator: " ")
    case .looks_ok:
      return pick(["I don't see any scam signs here.", "Looks fine to me.", "Nothing suspicious that I can see."])
    case .not_sure:
      return pick(["I can't read that well enough.", "I'm not sure about this one."]) + " "
        + pick(["Try holding it a bit closer.", "Don't pay yet, and check with the official number."])
    }
  }

  /// "Asks for codes or passwords" -> " It also asks for codes or passwords."
  private static func alsoLine(_ label: String) -> String {
    let l = label.prefix(1).lowercased() + label.dropFirst()
    let verbs = ["asks", "uses", "pretends", "has", "is", "wants", "claims", "creates", "offers", "says"]
    let first = l.split(separator: " ").first.map(String.init) ?? ""
    return verbs.contains(first) ? " It also \(l)." : " I also noticed: \(l)."
  }
}
