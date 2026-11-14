import MWDATCore
import SwiftUI

@main
struct SecondLookApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var glasses: GlassesManager
  @State private var coordinator: CheckCoordinator

  init() {
    // A server override left over from a temporary demo tunnel goes stale when the tunnel
    // stops; drop it so the app uses its built-in server (secondlook.pgf.lv).
    if let o = UserDefaults.standard.string(forKey: "apiBaseURL"), o.contains("trycloudflare.com") {
      UserDefaults.standard.removeObject(forKey: "apiBaseURL")
    }
    var configured = false
    do {
      try Wearables.configure()
      configured = true
    } catch {
      NSLog("[SecondLook] Wearables SDK configure failed: \(error)")
    }
    #if DEBUG
    if configured { MockGlasses.enableIfRequested() }
    #endif
    if UserDefaults.standard.bool(forKey: "consentGiven"), !ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--demo-") }) { Notifier.shared.setUp() }
    let glasses = GlassesManager(sdkConfigured: configured)
    _glasses = State(wrappedValue: glasses)
    _coordinator = State(wrappedValue: CheckCoordinator(glasses: glasses))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(glasses)
        .environment(coordinator)
        .task {
          Speaker.shared.prepareWarmVoice()
          #if DEBUG
          if UserDefaults.standard.bool(forKey: "debugMirror") { coordinator.setDebugMirror(true) }
          #endif
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { glasses.refreshConnection() }
        }
        // Meta AI app calls back here to finish registration and permission flows.
        .onOpenURL { url in
          #if DEBUG
          // Demo aid: secondlook://server?url=https://<name>.trycloudflare.com points the app
          // at a new tunnel without a rebuild. Only Cloudflare quick-tunnel addresses are accepted.
          if url.host == "server",
             let target = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
               .first(where: { $0.name == "url" })?.value,
             let t = URL(string: target), t.scheme == "https",
             t.host?.hasSuffix(".trycloudflare.com") == true {
            UserDefaults.standard.set(target, forKey: "apiBaseURL")
            NSLog("[SecondLook] server set to \(target)")
            return
          }
          #endif
          glasses.handle(url: url)
        }
    }
  }
}
