#if DEBUG
import Foundation
import MWDATCore
import MWDATMockDevice

/// Simulated glasses (MockDeviceKit) for building and demoing without hardware.
/// The mock camera "captures" the bundled demo photo (the fake Ray-Ban webshop).
@MainActor
enum MockGlasses {
  static var isOn: Bool {
    get { UserDefaults.standard.bool(forKey: "useMockGlasses") }
    set { UserDefaults.standard.set(newValue, forKey: "useMockGlasses") }
  }

  static var useDisplayModel: Bool {
    get { UserDefaults.standard.object(forKey: "mockDisplayModel") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "mockDisplayModel") }
  }

  /// Called at launch. Takes effect on next launch after toggling in Settings.
  static func enableIfRequested() {
    let forced = ProcessInfo.processInfo.arguments.contains("--mock-glasses")
    guard isOn || forced else { return }
    let kit = MockDeviceKit.shared
    kit.enable(config: MockDeviceKitConfig(initiallyRegistered: true, initialPermissionsGranted: true))
    // Forget pairs left over from earlier launches (they come back disconnected).
    for old in kit.pairedDevices { kit.unpairDevice(old) }
    let model: GlassesModel = useDisplayModel ? .metaRayBanDisplay : .rayBanMeta
    let photo = Bundle.main.url(forResource: "demo-webshop", withExtension: "jpg")
    // Pairing is slow SDK work; keep it off the main thread (as Meta's BirdSpotter sample does).
    Task.detached(priority: .userInitiated) {
      do {
        let glasses = try kit.pairGlasses(model: model)
        glasses.powerOn()
        glasses.unfold()
        glasses.don()
        if let photo {
          glasses.services.camera.setCameraFeed(fileURL: photo)
          glasses.services.camera.setCapturedImage(fileURL: photo)
        }
      } catch {
        NSLog("[SecondLook] Mock glasses failed: \(error)")
      }
    }
  }
}
#endif
