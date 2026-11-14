import SwiftUI

/// The answer to a check, as one clear alert: what it is, what to do, why, and what was noticed.
/// Used on the home screen and (compact) in live scan.
struct AlertCard: View {
  let result: CheckResult
  var compact = false
  var onRepeat: () -> Void = {}
  var onDone: () -> Void = {}

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 10 : 16) {
      HStack(spacing: 10) {
        Image(systemName: result.symbol)
          .font(.system(size: compact ? 15 : 17, weight: .bold))
          .foregroundStyle(result.tint)
          .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
          .background(.white, in: Circle())
        Text(result.word.uppercased())
          .font(.system(size: compact ? 13 : 14, weight: .heavy))
          .tracking(1.6)
        Spacer()
      }
      .accessibilityElement(children: .combine)

      Text(result.action)
        .font(.system(size: compact ? 26 : 34, weight: .regular, design: .serif))
        .fixedSize(horizontal: false, vertical: true)

      if !result.why.isEmpty {
        Text(result.why)
          .font(.system(size: compact ? 16 : 18))
          .lineSpacing(2)
          .opacity(0.95)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !result.warnings.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          if !compact {
            Text("WHAT I NOTICED").font(.system(size: 12, weight: .semibold)).tracking(1.4).opacity(0.75)
          }
          FlowChips(labels: Array(result.warnings.prefix(compact ? 2 : 3).map(\.label)))
        }
      }

      if !compact {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "phone.fill").font(.system(size: 14)).padding(.top, 2)
          Text(result.nextStep.replacingOccurrences(of: "Don't pay. ", with: "")).font(.system(size: 16, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
      }

      HStack(spacing: 10) {
        Button(action: onRepeat) {
          Label("Hear again", systemImage: "speaker.wave.2.fill")
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(.white.opacity(0.2), in: Capsule())
        }
        Spacer()
        Button(action: onDone) {
          Text("Done")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(.white, in: Capsule())
        }
      }
      .padding(.top, compact ? 0 : 4)
    }
    .foregroundStyle(.white)
    .padding(compact ? 18 : 22)
    .background(
      RoundedRectangle(cornerRadius: 28)
        .fill(result.tint.opacity(compact ? 0.92 : 0.55))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(.white.opacity(0.25), lineWidth: 1))
    )
    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
  }
}

/// Small rounded labels that wrap onto new lines.
struct FlowChips: View {
  let labels: [String]
  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 8) { chips }
      VStack(alignment: .leading, spacing: 8) { chips }
    }
  }
  @ViewBuilder private var chips: some View {
    ForEach(labels, id: \.self) { l in
      Text(l)
        .font(.system(size: 14, weight: .semibold))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.white.opacity(0.22), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
    }
  }
}

extension CheckResult {
  /// Short instruction shown and spoken first.
  var action: String {
    switch verdict {
    case .scam: return "Don't pay or reply."
    case .suspicious: return "Check before you pay."
    case .looks_ok: return "No scam signs found."
    case .not_sure: return "Not sure yet. Don't pay."
    }
  }

  /// One sentence on why.
  var why: String {
    switch verdict {
    case .scam, .suspicious: return reason.isEmpty ? (warnings.first?.explanation ?? "") : reason
    case .looks_ok: return "If something still feels off, check with the official number."
    case .not_sure: return spoken
    }
  }

  var tint: Color {
    switch verdict {
    case .scam: return Color(red: 0.86, green: 0.15, blue: 0.15)
    case .suspicious: return Color(red: 0.92, green: 0.47, blue: 0.08)
    case .looks_ok: return Color(red: 0.13, green: 0.6, blue: 0.35)
    case .not_sure: return Color(red: 0.35, green: 0.38, blue: 0.45)
    }
  }

  var symbol: String {
    switch verdict {
    case .scam: return "exclamationmark.triangle.fill"
    case .suspicious: return "exclamationmark"
    case .looks_ok: return "checkmark"
    case .not_sure: return "questionmark"
    }
  }
}
