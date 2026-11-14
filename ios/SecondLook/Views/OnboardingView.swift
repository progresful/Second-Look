import SwiftUI

struct OnboardingView: View {
  let onContinue: () -> Void

  var body: some View {
    ZStack {
    AuroraBackground(mood: .calm)
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text("second look").font(.system(size: 46, design: .serif))
        Text("A second pair of eyes before you pay.")
          .font(.title3)

        Point(icon: "hand.raised", title: "Only when you ask",
              text: "The camera or microphone turns on only when you start a check, and turns off right after.")
        Point(icon: "photo.badge.arrow.down", title: "How photos are checked",
              text: "The photo you check is sent to our Second Look server and to Google Gemini, which reads it. We don't store it. Personal numbers are removed from text before checking.")
        Point(icon: "phone", title: "Call mode",
              text: "Turn speech into text on your glasses or phone. Audio is never uploaded. Only the text is checked, then discarded.")
        Point(icon: "exclamationmark.bubble", title: "A second opinion, not a guarantee",
              text: "Second Look never says something is safe. If it isn't sure, it says so. It doesn't give financial advice.")

        HStack {
          Spacer()
          PillButton(title: "I understand", action: onContinue)
        }
      }
      .padding(28)
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
    }
  }
}

private struct Point: View {
  let icon: String
  let title: String
  let text: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon).font(.title3).frame(width: 30)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.headline)
        Text(text).font(.callout).opacity(0.9)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
