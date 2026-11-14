import PhotosUI
import SwiftUI

struct ContentView: View {
  @Environment(GlassesManager.self) private var glasses
  @Environment(CheckCoordinator.self) private var coordinator
  @AppStorage("consentGiven") private var consentGiven = false
  @State private var showPhotoPicker = false
  @State private var pickedItem: PhotosPickerItem?
  @State private var showCamera = false
  @State private var showSettings = false
  @State private var showLiveScan = false

  var body: some View {
    ZStack {
      AuroraBackground(mood: mood)
        .fullScreenCover(isPresented: $showLiveScan) { LiveScanView() }

      VStack(alignment: .leading, spacing: 0) {
        header
        Spacer(minLength: 24)
        if let r = coordinator.result {
          AlertCard(result: r, onRepeat: { coordinator.repeatAnswer() }, onDone: { coordinator.dismissResult() })
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
          state
          protectionList
            .padding(.top, 28)
          ModeToggle(alwaysOn: Binding(get: { coordinator.alwaysOn }, set: { coordinator.alwaysOn = $0 }))
            .padding(.top, 22)
        }
        Spacer(minLength: 16)
        bottomBar
      }
      .animation(.spring(response: 0.45, dampingFraction: 0.85), value: coordinator.result)
      .padding(.horizontal, 28)
      .padding(.top, 8)
      .padding(.bottom, 12)
      .foregroundStyle(.white)
    }
    .sheet(isPresented: $showSettings) { SettingsView() }
    .sheet(isPresented: $showCamera) {
      CameraPicker { image in Task { await coordinator.checkPhoneImage(image) } }.ignoresSafeArea()
    }
    .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .images)
    .onChange(of: pickedItem) { _, item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
          await coordinator.checkPhoneImage(image)
        }
        pickedItem = nil
      }
    }
    .fullScreenCover(isPresented: .constant(!consentGiven)) {
      OnboardingView {
        consentGiven = true
        Notifier.shared.setUp()
      }
    }
    #if DEBUG
    // Recording aid: `--demo-check` runs the same "Demo: webshop photo" action after launch.
    .task {
      guard ProcessInfo.processInfo.arguments.contains("--demo-check"),
            let url = Bundle.main.url(forResource: "demo-webshop", withExtension: "jpg"),
            let image = UIImage(contentsOfFile: url.path) else { return }
      try? await Task.sleep(for: .seconds(3))
      await coordinator.checkPhoneImage(image)
    }
    .task {
      guard ProcessInfo.processInfo.arguments.contains("--demo-call") else { return }
      try? await Task.sleep(for: .seconds(2))
      await coordinator.demoCall([
        "Hello, this is Anna from your bank's security team.",
        "We've noticed a suspicious payment from your account.",
        "To stop it, I need you to read me the code we just sent you.",
        "Then we'll move your money to a safe account. Don't tell anyone, it's confidential.",
      ])
    }
    #endif
    .alert("Something went wrong", isPresented: .constant(coordinator.errorMessage != nil)) {
      Button("OK") { coordinator.errorMessage = nil }
    } message: { Text(coordinator.errorMessage ?? "") }
  }

  // MARK: Mood + words

  private var mood: AuroraBackground.Mood {
    if let r = coordinator.result {
      switch r.verdict {
      case .scam: return .scam
      case .suspicious: return .careful
      case .looks_ok: return .okay
      case .not_sure: return .unsure
      }
    }
    if coordinator.isBusy { return .checking }
    if coordinator.isListening { return .listening }
    return .calm
  }

  private var stateWord: String {
    if let r = coordinator.result { return r.word }
    if coordinator.isBusy { return "checking" }
    if coordinator.isListening { return "listening" }
    return coordinator.alwaysOn ? "watching" : "ready"
  }

  private var stateText: String {
    if let r = coordinator.result { return r.summary }
    if coordinator.isBusy { return "Reading what you're looking at." }
    if coordinator.isListening && !coordinator.alwaysOn { return "Listening through \(coordinator.micName). I'll warn you about scam signs." }
    if coordinator.alwaysOn {
      return "I check what you look at every 15 seconds and only speak up if something looks wrong."
    }
    return glasses.isConnected
      ? "Look at it and tap check, or press the capture button on your glasses."
      : "Look at it and tap check. Your phone camera works too."
  }

  // MARK: Pieces

  private var header: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(glasses.isConnected ? Color.green : glasses.bluetoothAudioName != nil ? Color.orange : Color.white.opacity(0.5))
        .frame(width: 8, height: 8)
      Text(glasses.headerText).lineLimit(1)
        .font(.system(size: 15, weight: .medium))
        .opacity(0.85)
      Spacer()
      Text("second look")
        .font(.system(size: 15, weight: .semibold, design: .serif))
        .opacity(0.85)
    }
    .accessibilityElement(children: .combine)
  }

  private var state: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(stateWord)
        .font(.system(size: 46, weight: .regular, design: .serif))
        .contentTransition(.opacity)
        .animation(.easeInOut, value: stateWord)
      Text(stateText)
        .font(.system(size: 17, weight: .regular))
        .lineSpacing(3)
        .opacity(0.92)
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeInOut, value: stateText)
      if coordinator.isListening, coordinator.result == nil, !coordinator.callCaption.isEmpty {
        Text("“\(coordinator.callCaption)”")
          .font(.system(size: 17, weight: .medium, design: .serif))
          .italic()
          .opacity(0.8)
          .lineLimit(3)
          .padding(.top, 6)
          .accessibilityLabel("Heard on the call: \(coordinator.callCaption)")
      }
    }
    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
    .contentShape(Rectangle())
    .onTapGesture { if coordinator.result != nil { coordinator.dismissResult() } }
    .onLongPressGesture { coordinator.repeatAnswer() }
    .accessibilityElement(children: .combine)
    .accessibilityHint(coordinator.result != nil ? "Tap to dismiss. Long press to hear it again." : "")
  }

  private var protectionList: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("protect me from")
        .font(.system(size: 14, weight: .medium))
        .textCase(.uppercase)
        .tracking(1.2)
        .opacity(0.7)
        .padding(.bottom, 6)
      ForEach(Protection.allCases) { p in
        let on = coordinator.protections.contains(p)
        Button {
          withAnimation(.easeInOut(duration: 0.25)) { coordinator.toggle(p) }
        } label: {
          Text(p.title)
            .font(.system(size: 32, weight: .light))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .opacity(on ? 1 : 0.38)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p.title)
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
      }
    }
    .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
  }

  private var bottomBar: some View {
    HStack(spacing: 10) {
      moreMenu

      Spacer(minLength: 0)

      if !coordinator.alwaysOn && coordinator.protections.contains(.calls) {
        CircleButton(systemImage: coordinator.isListening ? "phone.down.fill" : "phone",
                     label: coordinator.isListening ? "Stop listening" : "Listen to a call") {
          Task { await coordinator.toggleListening() }
        }
      }

      if !coordinator.alwaysOn {
        PillButton(title: coordinator.isBusy ? "checking" : "check") {
          Task {
            if glasses.isConnected { await coordinator.checkWithGlasses() }
            else if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
            else { showPhotoPicker = true }
          }
        }
        .disabled(coordinator.isBusy)
      }
    }
  }

  private var moreMenu: some View {
    Menu {
      if !glasses.isConnected && glasses.sdkAvailable {
        Button { glasses.isRegistered ? glasses.connect() : glasses.register() } label: {
          Label(glasses.isRegistered ? "Connect glasses" : "Set up glasses", systemImage: "eyeglasses")
        }
      }
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        Button { showLiveScan = true } label: { Label("Live scan with camera", systemImage: "video") }
        Button { showCamera = true } label: { Label("Check with phone camera", systemImage: "camera") }
      }
      Button { showPhotoPicker = true } label: { Label("Check a screenshot", systemImage: "photo") }
      #if DEBUG
      Button {
        if let url = Bundle.main.url(forResource: "demo-webshop", withExtension: "jpg"),
           let image = UIImage(contentsOfFile: url.path) {
          Task { await coordinator.checkPhoneImage(image) }
        }
      } label: { Label("Demo: webshop photo", systemImage: "photo.badge.checkmark") }
      #endif
      Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
    } label: {
      Image(systemName: "ellipsis")
        .font(.system(size: 17, weight: .semibold))
        .frame(width: 46, height: 46)
        .background(.white.opacity(0.22), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
    }
    .accessibilityLabel("More")
  }
}

/// "on request · always on" capsule.
struct ModeToggle: View {
  @Binding var alwaysOn: Bool

  var body: some View {
    HStack(spacing: 0) {
      segment("on request", selected: !alwaysOn) { alwaysOn = false }
      segment("always on", selected: alwaysOn) { alwaysOn = true }
    }
    .padding(3)
    .background(.white.opacity(0.18), in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
    .accessibilityElement(children: .contain)
  }

  private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button {
      withAnimation(.spring(duration: 0.3)) { action() }
    } label: {
      Text(title)
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 16)
        .frame(height: 38)
        .foregroundStyle(selected ? Color.black : Color.white)
        .background(selected ? Color.white : Color.clear, in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// White pill like "start ›".
struct PillButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Text(title).font(.system(size: 17, weight: .medium)).lineLimit(1).fixedSize()
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .frame(width: 26, height: 26)
          .background(Color.black.opacity(0.08), in: Circle())
      }
      .foregroundStyle(.black)
      .padding(.leading, 18)
      .padding(.trailing, 8)
      .frame(height: 46)
      .background(.white, in: Capsule())
      .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
    .buttonStyle(.plain)
  }
}

struct CircleButton: View {
  let systemImage: String
  let label: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 46, height: 46)
        .background(.white.opacity(0.22), in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}
