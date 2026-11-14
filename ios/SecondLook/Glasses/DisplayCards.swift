import MWDATDisplay

/// Cards for the Ray-Ban Display (600x600 additive display): short, large, high contrast.
enum DisplayCards {
  static func checking(_ message: String) -> FlexBox {
    FlexBox(direction: .row, spacing: 14, crossAlignment: .center) {
      Icon(name: .eye)
      Text(message, style: .heading)
    }
    .padding(28)
    .background(.card)
  }

  /// Glance-able alert: icon + verdict, what to do, one short reason, up to two signs.
  static func result(_ r: CheckResult) -> FlexBox {
    let icon: IconName
    switch r.verdict {
    case .scam, .suspicious: icon = .exclamationTriangle
    case .looks_ok: icon = .checkmarkCircle
    case .not_sure: icon = .iCircle
    }
    let signs = r.warnings.prefix(2).map(\.label).joined(separator: " · ")
    return FlexBox(direction: .column, spacing: 14) {
      FlexBox(direction: .row, spacing: 12, crossAlignment: .center) {
        Icon(name: icon)
        Text(r.word.uppercased(), style: .heading)
      }
      Text(r.action, style: .heading)
      if !r.why.isEmpty {
        Text(short(r.why, max: 90), style: .body)
      }
      if !signs.isEmpty {
        Text(signs, style: .meta, color: .secondary)
      }
    }
    .padding(28)
    .background(.card)
  }

  /// Cut at a word boundary so it fits the small display.
  static func short(_ s: String, max: Int) -> String {
    guard s.count > max else { return s }
    let cut = s.prefix(max)
    return (cut.lastIndex(of: " ").map { String(cut[..<$0]) } ?? String(cut)) + "…"
  }
}
