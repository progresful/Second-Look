import SwiftUI

/// Live scan: phone camera video. Looks at a frame every 2 s and only checks
/// when it sees something worth checking. Warnings appear here, are spoken and notified.
struct LiveScanView: View {
  @Environment(CheckCoordinator.self) private var coordinator
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      CameraPreview(session: coordinator.liveCamera.session).ignoresSafeArea()
      LiveBoxesOverlay(boxes: coordinator.liveBoxes, frameSize: coordinator.liveFrameSize)
        .ignoresSafeArea()
        .allowsHitTesting(false)

      VStack(spacing: 0) {
        HStack {
          statusChip
          Spacer()
          Button {
            coordinator.stopLiveScan()
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 44, height: 44)
              .background(.ultraThinMaterial, in: Circle())
          }
          .accessibilityLabel("Stop live scan")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)

        Spacer()

        if let r = coordinator.result {
          AlertCard(result: r, compact: true, onRepeat: { coordinator.repeatAnswer() },
                    onDone: { coordinator.dismissResult() })
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
          Text("Point at a letter, message or webshop. I'll speak up if I see scam signs.")
            .font(.system(size: 15, weight: .medium))
            .multilineTextAlignment(.center)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
      }
      .foregroundStyle(.white)
    }
    .animation(.easeOut(duration: 0.25), value: coordinator.result)
    .task { await coordinator.startLiveScan() }
    .onDisappear { coordinator.stopLiveScan() }
  }

  private var statusChip: some View {
    let (text, color): (String, Color) = switch coordinator.liveStatus {
    case .off, .starting: ("starting", .gray)
    case .watching: coordinator.liveOffline ? ("watching · offline", .orange) : ("watching", .green)
    case .reading: ("reading", .green)
    case .checking: coordinator.liveOffline ? ("checking · offline", .orange) : ("checking", .yellow)
    }
    return HStack(spacing: 8) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(text).font(.system(size: 14, weight: .semibold))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(.ultraThinMaterial, in: Capsule())
    .accessibilityLabel("Live scan: \(text)")
  }

  private func resultCard(_ r: CheckResult) -> some View {
    let tint: Color = switch r.verdict {
    case .scam: .red
    case .suspicious: .orange
    case .looks_ok: .green
    case .not_sure: .gray
    }
    return VStack(alignment: .leading, spacing: 8) {
      Text(r.word).font(.system(size: 26, weight: .bold))
      Text(r.summary).font(.system(size: 16))
      HStack {
        Spacer()
        Button("Keep scanning") { coordinator.dismissResult() }
          .font(.system(size: 15, weight: .semibold))
      }
    }
    .padding(18)
    .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
  }
}

/// Draws live-scan boxes over the preview. The preview fills the screen
/// (aspect fill), so boxes are scaled and cropped the same way.
struct LiveBoxesOverlay: View {
  let boxes: [CheckCoordinator.LiveBox]
  let frameSize: CGSize

  var body: some View {
    GeometryReader { geo in
      let view = geo.size
      if frameSize.width > 0, frameSize.height > 0 {
        let scale = max(view.width / frameSize.width, view.height / frameSize.height)
        let shown = CGSize(width: frameSize.width * scale, height: frameSize.height * scale)
        let dx = (view.width - shown.width) / 2, dy = (view.height - shown.height) / 2
        ForEach(boxes) { box in
          let r = CGRect(x: dx + box.rect.minX * shown.width - 4, y: dy + box.rect.minY * shown.height - 3,
                         width: box.rect.width * shown.width + 8, height: box.rect.height * shown.height + 6)
          let color: Color = box.kind == .warning ? .red : .yellow
          RoundedRectangle(cornerRadius: box.kind == .warning ? 6 : 12)
            .stroke(color, style: StrokeStyle(lineWidth: box.kind == .warning ? 3 : 2.5,
                                              dash: box.kind == .warning ? [] : [10, 6]))
            .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(box.kind == .warning ? 0.18 : 0.04)))
            .frame(width: r.width, height: r.height)
            .overlay(alignment: .topLeading) {
              if let label = box.label {
                Text(label)
                  .font(.system(size: 12, weight: .bold))
                  .foregroundStyle(.white)
                  .padding(.horizontal, 6).padding(.vertical, 3)
                  .background(Color.red, in: RoundedRectangle(cornerRadius: 5))
                  .fixedSize()
                  .offset(y: -22)
              }
            }
            .position(x: r.midX, y: r.midY)
            .accessibilityHidden(true)
        }
        .animation(.easeOut(duration: 0.2), value: boxes)
      }
    }
  }
}
