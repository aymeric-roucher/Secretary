import SwiftUI
import AVFoundation
import ApplicationServices

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @AppStorage("openaiApiKey") var openaiApiKey: String = ""
    @AppStorage("hfApiKey") var hfApiKey: String = ""
    
    @State private var openaiStatus: ValidationStatus = .none
    @State private var hfStatus: ValidationStatus = .none
    @State private var micStatus: ValidationStatus = .none
    @State private var accessStatus: ValidationStatus = .none
    @State private var lastCheckedOpenAIKey: String = ""
    @State private var lastCheckedHFKey: String = ""
    
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("Welcome to Jarvis")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Your AI Secretary for macOS")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Shortcut")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                ShortcutRecorder()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 12) {
                ApiKeysSection(openaiKey: $openaiApiKey,
                               hfKey: $hfApiKey,
                               openaiStatus: $openaiStatus,
                               hfStatus: $hfStatus,
                               onApiKeysValidate: { Task { await validateKeys() } })
            }
            .padding(14)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionsSection(micStatus: $micStatus,
                                   accessStatus: $accessStatus,
                                   requestMic: requestMic,
                                   checkAccess: checkAccessibility)
            }
            .padding(14)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 3)
            
            HStack {
                Spacer()
                Button("Finish") {
                    NotificationCenter.default.post(name: NSNotification.Name("ReloadHotkey"), object: nil)
                    Task { await validateAllAndFinish() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 740)
        .background(Color(nsColor: .underPageBackgroundColor))
        .onAppear {
            loadAPIKeys(openaiKey: &openaiApiKey, hfKey: &hfApiKey)
            checkPermissions()
        }
    }
    
    func validateKeys() async {
        openaiStatus = .checking
        hfStatus = .checking
        async let openResult = ApiValidator.validateOpenAI(openaiKey: openaiApiKey)
        async let hfResult = ApiValidator.validateHF(hfKey: hfApiKey)
        let (open, hf) = await (openResult, hfResult)
        openaiStatus = open == .valid ? .valid : .invalid
        hfStatus = hf == .valid ? .valid : .invalid
        lastCheckedOpenAIKey = openaiApiKey
        lastCheckedHFKey = hfApiKey
    }
    
    func validateAllAndFinish() async {
        let keysChanged = openaiApiKey != lastCheckedOpenAIKey || hfApiKey != lastCheckedHFKey
        if keysChanged {
            await validateKeys()
        }
        if openaiStatus == .valid && hfStatus == .valid && micStatus == .valid && accessStatus == .valid {
            isCompleted = true
        }
    }
    
    func checkPermissions() {
        // Mic
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micStatus = .valid
        case .denied, .restricted: micStatus = .invalid
        case .notDetermined: micStatus = .none
        @unknown default: micStatus = .none
        }
        
        // Accessibility
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        accessStatus = trusted ? .valid : .none
    }
    
    func requestMic() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micStatus = granted ? .valid : .invalid
            }
        }
    }
    
func checkAccessibility() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    accessStatus = trusted ? .valid : .none
    if !trusted {
            // It will prompt. User has to go to settings.
            // We can re-check after a delay or user click.
        }
    }
}

// Shared helper to load API keys from local .env locations into the provided bindings if they are empty.
func loadAPIKeys(openaiKey: inout String, hfKey: inout String) {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let possiblePaths = [
        URL(fileURLWithPath: ".env"), // Current dir
        home.appendingPathComponent(".env"),
        home.appendingPathComponent("Documents/Code/Jarvis/.env")
    ]
    
    for url in possiblePaths {
        if let content = try? String(contentsOf: url) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: "=")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let val = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
                    
                    if key == "OPENAI_API_KEY" && openaiKey.isEmpty { openaiKey = val }
                    if key == "HF_TOKEN" && hfKey.isEmpty { hfKey = val }
                }
            }
        }
    }
}
