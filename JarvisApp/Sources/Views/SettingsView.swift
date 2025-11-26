import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("geminiApiKey") var geminiApiKey: String = ""
    @AppStorage("hfApiKey") var hfApiKey: String = ""
    @State private var logContent: String = "Loading logs..."
    
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
                
                SidebarButton(title: "Home", icon: "house", tab: .home, selection: $appState.selectedTab)
                SidebarButton(title: "Dictionary", icon: "book", tab: .dictionary, selection: $appState.selectedTab)
                SidebarButton(title: "Style", icon: "text.quote", tab: .style, selection: $appState.selectedTab)
                
                Spacer()
                
                Text("SETTINGS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                
                SidebarButton(title: "Settings", icon: "gear", tab: .settings, selection: $appState.selectedTab)
                    .padding(.bottom, 20)
            }
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content Area
            VStack {
                switch appState.selectedTab {
                case .home:
                    HomeView(logContent: $logContent, loadLogs: loadLogs, clearLogs: clearLogs)
                case .dictionary:
                    DictionaryView()
                case .style:
                    StyleView()
                case .settings:
                    GeneralSettingsView(geminiApiKey: $geminiApiKey, hfApiKey: $hfApiKey)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 800, height: 500)
        .onAppear { loadLogs() }
    }
    
    func loadLogs() {
        let logFile = URL(fileURLWithPath: "/Users/aymeric/Documents/Code/Jarvis/Jarvis_Log.txt")
        if let content = try? String(contentsOf: logFile) {
            logContent = content
        } else {
            logContent = "No logs found."
        }
    }
    
    func clearLogs() {
        let logFile = URL(fileURLWithPath: "/Users/aymeric/Documents/Code/Jarvis/Jarvis_Log.txt")
        try? "".write(to: logFile, atomically: true, encoding: .utf8)
        loadLogs()
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
    @Binding var logContent: String
    var loadLogs: () -> Void
    var clearLogs: () -> Void
    
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Activity")
                .font(.title2)
                .padding(.top)
                .padding(.horizontal)
            
            Text("Logs at: /Users/aymeric/Documents/Code/Jarvis/Jarvis_Log.txt")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .textSelection(.enabled)
            
            ScrollView {
                Text(logContent)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            HStack {
                Spacer()
                Button("Clear Logs", action: clearLogs)
            }
            .padding()
        }
        .onReceive(timer) { _ in
            loadLogs()
        }
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
    @Binding var geminiApiKey: String
    @Binding var hfApiKey: String
    
    @State private var micStatus: Bool = false
    @State private var accessStatus: Bool = false
    
    var body: some View {
        Form {
            Section("API Keys") {
                SecureField("Gemini API Key", text: $geminiApiKey)
                SecureField("Hugging Face Token", text: $hfApiKey)
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
                Text("Created with Gemini 1.5 Flash")
            }
        }
        .padding()
        .formStyle(.grouped)
        .onAppear {
            checkMic()
            checkAccess()
        }
    }
    
    func checkMic() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micStatus = true
        default: micStatus = false
        }
    }
    
    func checkAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        accessStatus = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
