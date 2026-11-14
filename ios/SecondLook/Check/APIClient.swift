import Foundation
import UIKit

/// Talks to the Second Look backend (FastAPI on Hostinger). Holds no API keys:
/// Gemini is called by the server, never from the phone.
struct APIClient {
  enum APIError: Error {
    case badStatus(Int, String)
    case encoding
  }

  /// Read on every request, so a new server address (Settings, or the debug
  /// secondlook://server link) works without restarting or rebuilding the app.
  var baseURL: URL {
    let raw = (Bundle.main.object(forInfoDictionaryKey: "SLApiBaseURL") as? String) ?? ""
    let override = UserDefaults.standard.string(forKey: "apiBaseURL") ?? ""
    let chosen = override.isEmpty ? raw : override
    return URL(string: chosen) ?? URL(string: "http://localhost:8765")!
  }

  static let shared = APIClient()

  /// True for failures that mean "the server can't be reached" (no network, tunnel down,
  /// proxy error page), as opposed to the server rejecting this one request.
  static func isUnreachable(_ error: Error) -> Bool {
    if error is URLError { return true }
    if case APIError.badStatus(let code, _) = error { return code == 0 || code >= 500 }
    return false
  }

  /// Photo check. The photo is downscaled, sent to our server, which forwards it to Gemini.
  /// Nothing is stored on the phone or by our server.
  /// live = a live-scan frame: the server uses its fast model (~3 s) instead of the stronger one (~9 s).
  func analyzeImage(_ image: UIImage, live: Bool = false) async throws -> CheckResult {
    let timeout: TimeInterval = live ? 8 : 15
    guard let jpeg = image.downscaled(maxSide: 1280).jpegData(compressionQuality: 0.7) else {
      throw APIError.encoding
    }
    let body: [String: Any] = ["image_base64": jpeg.base64EncodedString(), "mime_type": "image/jpeg", "live": live]
    var result = try await post("analyze-image", body: body, timeout: timeout)
    result.engine = "Gemini + server checks"
    return result
  }

  /// Text check, used for call transcripts and the offline-OCR fallback when online.
  func analyzeText(_ text: String, timeout: TimeInterval = 8) async throws -> CheckResult {
    var result = try await post("analyze", body: ["text": text], timeout: timeout)
    result.engine = (result.llm_used ?? false) ? "Server rules + AI" : "Server rules"
    return result
  }

  private func post(_ path: String, body: [String: Any], timeout: TimeInterval) async throws -> CheckResult {
    var req = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: timeout)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // Lets the server accept checks that arrive through the public tunnel (phone on 5G).
    if let token = Bundle.main.object(forInfoDictionaryKey: "SLAppToken") as? String, !token.isEmpty {
      req.setValue(token, forHTTPHeaderField: "X-App-Token")
    }
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: req)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard status == 200 else {
      throw APIError.badStatus(status, String(data: data, encoding: .utf8) ?? "")
    }
    return try JSONDecoder().decode(CheckResult.self, from: data)
  }
}

extension UIImage {
  func downscaled(maxSide: CGFloat) -> UIImage {
    let longest = max(size.width, size.height)
    guard longest > maxSide else { return self }
    let scale = maxSide / longest
    let target = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
