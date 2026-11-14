import Foundation

#if DEBUG
/// Test builds only: keeps the latest "[SecondLook]" log lines in memory so the debug mirror
/// can show them in the web viewer. It taps stderr (where NSLog writes) and passes everything
/// through unchanged, so Xcode / devicectl consoles still see the log.
final class DebugLog: @unchecked Sendable {
  static let shared = DebugLog()
  private let lock = NSLock()
  private var lines: [String] = []
  private var pipe: Pipe?
  private let clock: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f }()

  func start() {
    lock.lock(); defer { lock.unlock() }
    guard pipe == nil else { return }
    let p = Pipe()
    let original = dup(STDERR_FILENO)
    setvbuf(stderr, nil, _IONBF, 0)
    dup2(p.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    let passthrough = FileHandle(fileDescriptor: original, closeOnDealloc: false)
    p.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      passthrough.write(data)
      guard let self, let text = String(data: data, encoding: .utf8) else { return }
      for raw in text.split(separator: "\n") {
        guard let r = raw.range(of: "[SecondLook] ") else { continue }
        self.append(String(raw[r.upperBound...]))
      }
    }
    pipe = p
  }

  private func append(_ message: String) {
    let line = clock.string(from: Date()) + "  " + message
    lock.lock(); defer { lock.unlock() }
    lines.append(line)
    if lines.count > 200 { lines.removeFirst(lines.count - 200) }
  }

  func recent(_ n: Int = 200) -> [String] {
    lock.lock(); defer { lock.unlock() }
    return Array(lines.suffix(n))
  }
}
#endif
