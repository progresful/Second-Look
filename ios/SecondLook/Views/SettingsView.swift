import SwiftUI
import UIKit

struct SettingsView: View {
  @Environment(GlassesManager.self) private var glasses
  @Environment(\.dismiss) private var dismiss
  @AppStorage("apiBaseURL") private var apiBaseURL = ""
  @AppStorage("speechRate") private var speechRate: Double = 0.52
  @AppStorage("consentGiven") private var consentGiven = true
  #if DEBUG
  @State private var mockOn = MockGlasses.isOn
  @State private var mockDisplay = MockGlasses.useDisplayModel
  #endif

  var body: some View {
    NavigationStack {
      Form {
        Section("Glasses") {
          LabeledContent("Status", value: glasses.statusText)
          if glasses.isRegistered {
            Button("Disconnect glasses from Second Look", role: .destructive) { glasses.unregister() }
          } else {
            Button("Set up glasses") { glasses.register() }
          }
        }

        Section("Voice") {
          VStack(alignment: .leading) {
            Text("Speaking speed")
            Slider(value: $speechRate, in: 0.35...0.6)
              .onChange(of: speechRate) { _, v in Speaker.shared.rate = Float(v) }
          }
          Button("Test voice") { Speaker.shared.say("Likely scam. Real banks never ask for your codes.") }
        }

        Section {
          TextField("Default: \(APIClient.shared.baseURL.absoluteString)", text: $apiBaseURL)
            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        } header: { Text("Server") } footer: {
          Text("Restart the app after changing. On a real iPhone use your Mac's network address or the Hostinger URL.")
        }

        #if DEBUG
        Section {
          Toggle("Use mock glasses", isOn: $mockOn).onChange(of: mockOn) { _, v in MockGlasses.isOn = v }
          Toggle("Mock is Ray-Ban Display", isOn: $mockDisplay).onChange(of: mockDisplay) { _, v in MockGlasses.useDisplayModel = v }
        } header: { Text("Developer") } footer: {
          Text("Mock glasses use the bundled webshop photo as the camera. Restart the app to apply.")
        }
        #endif

        Section("Privacy") {
          Text("Photos are sent to our server and Google Gemini to be read, and are not stored by us. Call audio never leaves your devices. Meta's toolkit analytics are turned off.")
            .font(.callout)
          Button("Show the introduction again") { consentGiven = false; dismiss() }
        }
      }
      .navigationTitle("Settings")
      .toolbar { Button("Done") { dismiss() } }
    }
  }
}

/// Phone camera fallback (when glasses aren't connected).
struct CameraPicker: UIViewControllerRepresentable {
  let onImage: (UIImage) -> Void
  @Environment(\.dismiss) private var dismiss

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: CameraPicker
    init(_ parent: CameraPicker) { self.parent = parent }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
  }
}
