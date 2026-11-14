import SwiftUI

/// Soft, slowly drifting colour blobs (like a calm aura). The palette follows the app state,
/// so the whole screen turns red for a scam, green when it looks okay, violet while listening.
struct AuroraBackground: View {
  enum Mood: Equatable { case calm, checking, listening, scam, careful, okay, unsure }

  var mood: Mood
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var palette: (base: Color, blobs: [Color]) {
    switch mood {
    case .calm:      return (Color(hex: 0xF6EEE6), [Color(hex: 0x1F3BE0), Color(hex: 0x2CC3FF), Color(hex: 0x7C8CFF)])
    case .checking:  return (Color(hex: 0xEFEAF8), [Color(hex: 0x4B2CE0), Color(hex: 0x2CC3FF), Color(hex: 0xB06CFF)])
    case .listening: return (Color(hex: 0xF1E9F7), [Color(hex: 0x6A2CE0), Color(hex: 0xD06CFF), Color(hex: 0x3A6BFF)])
    case .scam:      return (Color(hex: 0xFBECE6), [Color(hex: 0xE5231B), Color(hex: 0xFF7A3D), Color(hex: 0xFF3D7F)])
    case .careful:   return (Color(hex: 0xFBF1E2), [Color(hex: 0xF08A00), Color(hex: 0xFFC233), Color(hex: 0xFF6A3D)])
    case .okay:      return (Color(hex: 0xEAF6EF), [Color(hex: 0x0FA86A), Color(hex: 0x37D6B0), Color(hex: 0x2CC3FF)])
    case .unsure:    return (Color(hex: 0xEEEFF2), [Color(hex: 0x5B6475), Color(hex: 0x9AA6BC), Color(hex: 0x6C7FA8)])
    }
  }

  /// Faster drift while something is happening.
  private var speed: Double {
    switch mood {
    case .checking: return 0.9
    case .listening: return 0.6
    case .scam: return 0.5
    default: return 0.22
    }
  }

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      let t = timeline.date.timeIntervalSinceReferenceDate * speed
      GeometryReader { geo in
        let w = geo.size.width, h = geo.size.height
        ZStack {
          palette.base
          blob(palette.blobs[0], size: w * 2.1,
               x: w * 0.45 + cos(t * 0.9) * w * 0.18, y: h * 0.55 + sin(t * 0.7) * h * 0.12)
          blob(palette.blobs[1], size: w * 1.6,
               x: w * 0.35 + sin(t * 0.6 + 1) * w * 0.25, y: h * 0.55 + cos(t * 0.8 + 2) * h * 0.18)
          blob(palette.blobs[2], size: w * 1.3,
               x: w * 0.7 + cos(t * 0.5 + 3) * w * 0.25, y: h * 0.3 + sin(t * 0.9 + 1) * h * 0.15)
          // Soft shade for text contrast (WCAG-friendly white text over light corners).
          LinearGradient(colors: [.black.opacity(0.10), .clear, .black.opacity(0.22)],
                         startPoint: .top, endPoint: .bottom)
        }
      }
    }
    .animation(.easeInOut(duration: 1.4), value: mood)
    .ignoresSafeArea()
  }

  private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
    Circle()
      .fill(RadialGradient(colors: [color, color.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
      .frame(width: size, height: size)
      .position(x: x, y: y)
      .blur(radius: 30)
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }
}
