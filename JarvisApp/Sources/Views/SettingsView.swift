import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 10) {
                Text("JARVIS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 20)
                
                SidebarButton(title: "Chatbot", icon: "bubble.left.and.bubble.right", tab: .home, selection: $appState.selectedTab)
                SidebarButton(title: "Logs", icon: "doc.plaintext", tab: .logs, selection: $appState.selectedTab)
                SidebarButton(title: "Dictionary", icon: "book", tab: .dictionary, selection: $appState.selectedTab)
                SidebarButton(title: "Style", icon: "text.quote", tab: .style, selection: $appState.selectedTab)
                
                Spacer()
                
                Text("SETTINGS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                
                SidebarButton(title: "Settings", icon: "gearshape.2", tab: .settings, selection: $appState.selectedTab)
                    .padding(.bottom, 20)
            }
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content Area
            VStack {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .logs:
                    LogsView()
                case .dictionary:
                    DictionaryView()
                case .style:
                    StyleView()
                case .settings:
                    GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let tab: SettingsTab
    @Binding var selection: SettingsTab
    
    var body: some View {
        Button(action: { selection = tab }) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selection == tab ? Color.blue.opacity(0.1) : Color.clear)
        .foregroundColor(selection == tab ? .blue : .primary)
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}

// Subviews for cleaner code

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chatbot")
                .font(.title2)
                .padding(.top)
                .padding(.horizontal)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.messages) { msg in
                            ChatMessageRow(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .onChange(of: appState.messages.count) { _, _ in
                    if let last = appState.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
    }
}

struct ChatMessageRow: View {
    var message: ChatMessage

    var body: some View {
        ToolMessageView(role: message.role, content: message.content, toolName: message.toolPayload?.name)
    }
}

struct DictionaryView: View {
    var body: some View {
        VStack {
            Text("Dictionary")
                .font(.title2)
                .padding()
            Text("Define custom abbreviations here.")
                .foregroundColor(.secondary)
            List {
                Text("Coming soon...")
            }
        }
    }
}

struct StyleView: View {
    var body: some View {
        VStack {
            Text("Writing Style")
                .font(.title2)
                .padding()
            Text("Provide examples of your writing style.")
                .foregroundColor(.secondary)
            TextEditor(text: .constant("Hi [Name],\n\nThanks for reaching out..."))
                .border(Color.gray.opacity(0.2))
                .padding()
        }
    }
}

import AVFoundation
import ApplicationServices

struct GeneralSettingsView: View {
    @AppStorage("openaiApiKey") var openaiApiKey: String = ""
    @AppStorage("hfApiKey") var hfApiKey: String = ""
    
    @State private var micStatus: Bool = false
    @State private var accessStatus: Bool = false
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("OpenAI API Key", text: $openaiApiKey)
                SecureField("Hugging Face Token", text: $hfApiKey)
                Button("Check APIs") {
                    Task { await validateKeys() }
                }
                .buttonStyle(.bordered)
            }
            
            Section("Shortcut") {
                ShortcutRecorder()
                    .frame(height: 60)
            }
            
            Section("Permissions") {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Microphone")
                    Spacer()
                    Image(systemName: micStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(micStatus ? .green : .red)
                    Button("Check") { checkMic() }
                }
                
                HStack {
                    Image(systemName: "keyboard.fill")
                    Text("Accessibility")
                    Spacer()
                    Image(systemName: accessStatus ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(accessStatus ? .green : .red)
                    Button("Check") { checkAccess() }
                }
            }
            
            Section("About") {
                Text("Jarvis v1.0")
            }
        }
        .padding()
        .formStyle(.grouped)
        .onAppear {
            loadAPIKeys(openaiKey: &openaiApiKey, hfKey: &hfApiKey)
            checkMic()
            checkAccess()
        }
    }
    
    func checkMic() {
        NSApp.activate(ignoringOtherApps: true)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            micStatus = true
            NSApp.activate(ignoringOtherApps: true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    micStatus = granted
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        case .denied, .restricted:
            micStatus = false
            // Optionally open settings:
            // if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            //    NSWorkspace.shared.open(url)
            // }
        @unknown default:
            micStatus = false
        }
    }
    
    func checkAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        accessStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    private func validateKeys() async {
        async let openResult = ApiValidator.validateOpenAI(openaiKey: openaiApiKey)
        async let hfResult = ApiValidator.validateHF(hfKey: hfApiKey)
        let (open, hf) = await (openResult, hfResult)
        log("API validation - OpenAI: \(open), HF: \(hf)")
    }
}
