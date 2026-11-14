import MWDATDisplay

/// Cards for the Ray-Ban Display (600x600 additive display): short, large, high contrast.
enum DisplayCards {
  static func checking(_ message: String) -> FlexBox {
    FlexBox(direction: .column, spacing: 12) {
      Text("Second Look", style: .meta, color: .secondary)
      Text(message, style: .heading)
    }
    .padding(24)
  }

  static func result(_ r: CheckResult) -> FlexBox {
    let headline: String
    switch r.verdict {
    case .scam: headline = "⚠ LIKELY SCAM"
    case .suspicious: headline = "⚠ BE CAREFUL"
    case .looks_ok: headline = "✓ No scam signs"
    case .not_sure: headline = "? Not sure"
    }
    let reasons = Array(r.warnings.prefix(3)).map { "• " + $0.label }
    return FlexBox(direction: .column, spacing: 10) {
      Text(headline, style: .heading)
      for line in reasons {
        Text(line, style: .body)
      }
      Text(r.nextStep, style: .meta, color: .secondary)
    }
    .padding(24)
  }
}
