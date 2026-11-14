import Foundation
import UserNotifications

/// Results arrive as a notification: a title and one short paragraph.
/// Shown as a banner even while the app is open.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
  static let shared = Notifier()

  func setUp() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func post(_ result: CheckResult) {
    let content = UNMutableNotificationContent()
    content.title = result.title + " · " + result.action
    content.body = [result.why, result.verdict == .scam || result.verdict == .suspicious ? result.nextStep : ""]
      .filter { !$0.isEmpty }.joined(separator: " ")
    content.sound = (result.verdict == .scam || result.verdict == .suspicious) ? .defaultCritical : nil
    content.interruptionLevel = (result.verdict == .scam) ? .timeSensitive : .active
    // Same id replaces the previous result instead of stacking.
    let request = UNNotificationRequest(identifier: "second-look-result", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }
}
