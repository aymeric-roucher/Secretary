import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 8) {
                Text("JARVIS")
                    .font(.custom("Georgia", size: 11))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(1.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                SidebarButton(title: "Home", tab: .home, selection: $appState.selectedTab)
                SidebarButton(title: "Logs", tab: .logs, selection: $appState.selectedTab)
                SidebarButton(title: "Dictionary", tab: .dictionary, selection: $appState.selectedTab)
                SidebarButton(title: "Style", tab: .style, selection: $appState.selectedTab)

                Spacer()

                Text("SETTINGS")
                    .font(.custom("Georgia", size: 11))
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .tracking(1.5)
                    .padding(.horizontal, 16)

                SidebarButton(title: "Settings", tab: .settings, selection: $appState.selectedTab)
                    .padding(.bottom, 24)
            }
            .frame(width: 180)
            .background(Color(white: 0.97))

            Rectangle()
                .fill(Color(white: 0.85))
                .frame(width: 1)

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
            .background(Color.white)
        }
    }
}

struct SidebarButton: View {
    let title: String
    let tab: SettingsTab
    @Binding var selection: SettingsTab

    var body: some View {
        Button(action: { selection = tab }) {
            HStack {
                Text(title)
                    .font(.custom("Georgia", size: 14))
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selection == tab ? Color.black.opacity(0.05) : Color.clear)
        .foregroundColor(selection == tab ? .black : .gray)
        .padding(.horizontal, 8)
    }
}

// Subviews for cleaner code

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    private var groupedMessages: [(user: ChatMessage, tool: ChatMessage?)] {
        var groups: [(user: ChatMessage, tool: ChatMessage?)] = []
        var i = 0
        let messages = appState.messages
        while i < messages.count {
            let msg = messages[i]
            if msg.role == .user {
                var toolMsg: ChatMessage? = nil
                if i + 1 < messages.count && messages[i + 1].role == .tool {
                    toolMsg = messages[i + 1]
                    i += 1
                }
                groups.append((user: msg, tool: toolMsg))
            }
            i += 1
        }
        return groups
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Home")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            if groupedMessages.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No messages")
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(.gray)
                        .italic()
                    Spacer()
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(groupedMessages.enumerated()), id: \.element.user.id) { _, group in
                                Divider()
                                    .padding(.vertical, 16)
                                MessageGroupRow(
                                    userMessage: group.user,
                                    toolMessage: group.tool,
                                    timeFormatter: Self.timeFormatter
                                )
                                .id(group.user.id)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .onChange(of: appState.messages.count) { _, _ in
                        if let lastGroup = groupedMessages.last {
                            withAnimation { proxy.scrollTo(lastGroup.user.id, anchor: .bottom) }
                        }
                    }
                }
            }
        }
        .background(Color.white)
    }
}

struct MessageGroupRow: View {
    let userMessage: ChatMessage
    let toolMessage: ChatMessage?
    let timeFormatter: DateFormatter

    private static let toolIcons: [String: String] = [
        "type": "pencil.and.line",
        "deep_research": "magnifyingglass",
        "open_app": "desktopcomputer",
        "switch_to": "arrow.triangle.2.circlepath"
    ]

    private func toolIcon(for name: String?) -> String {
        Self.toolIcons[name ?? ""] ?? "hammer.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(timeFormatter.string(from: userMessage.timestamp))
                    .font(.custom("Georgia", size: 13))
                    .foregroundColor(.gray)
                    .frame(width: 40, alignment: .leading)

                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 16)

                Text(userMessage.content)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let tool = toolMessage {
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                        .frame(width: 40)

                    Image(systemName: toolIcon(for: tool.toolPayload?.name))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(width: 16)

                    HStack(alignment: .top, spacing: 6) {
                        Text("\u{21B3}")
                            .font(.custom("Georgia", size: 15))
                            .foregroundColor(.gray)

                        Text(tool.content)
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            }
        }
    }
}

struct DictionaryView: View {
    @StateObject private var store = DictionaryStore()
    @State private var newWord: String = ""
    @State private var newInput: String = ""
    @State private var newOutput: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                entryForm
                entryList
            }
            .padding(24)
        }
        .background(Color.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dictionary")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
            Text("Add custom words or map abbreviations/misspellings to their corrected form.")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(.gray)
        }
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("New Word")
                    .font(.custom("Georgia", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                HStack(spacing: 12) {
                    TextField("e.g. Eylul", text: $newWord)
                        .textFieldStyle(.plain)
                        .font(.custom("Georgia", size: 14))
                        .padding(10)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.85), lineWidth: 1))
                    Button("Add") {
                        store.addWord(newWord)
                        newWord = ""
                    }
                    .font(.custom("Georgia", size: 13))
                    .buttonStyle(.bordered)
                    .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("New Abbreviation / Correction")
                    .font(.custom("Georgia", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                HStack(spacing: 12) {
                    TextField("From (e.g. teh)", text: $newInput)
                        .textFieldStyle(.plain)
                        .font(.custom("Georgia", size: 14))
                        .padding(10)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.85), lineWidth: 1))
                    Text("\u{2192}")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(.gray)
                    TextField("To (e.g. the)", text: $newOutput)
                        .textFieldStyle(.plain)
                        .font(.custom("Georgia", size: 14))
                        .padding(10)
                        .background(Color(white: 0.97))
                        .overlay(Rectangle().stroke(Color(white: 0.85), lineWidth: 1))
                    Button("Add") {
                        store.addCorrection(from: newInput, to: newOutput)
                        newInput = ""
                        newOutput = ""
                    }
                    .font(.custom("Georgia", size: 13))
                    .buttonStyle(.bordered)
                    .disabled(newInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              newOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Entries")
                    .font(.custom("Georgia", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Spacer()
                if store.entries.isEmpty {
                    Text("No entries yet")
                        .font(.custom("Georgia", size: 13))
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            ForEach(store.entries) { entry in
                HStack(spacing: 12) {
                    if entry.kind == .correction {
                        Text(entry.input)
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(.black)
                        Text("\u{2192}")
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(.gray)
                        Text(entry.output ?? "")
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(.black)
                    } else {
                        Text(entry.input)
                            .font(.custom("Georgia", size: 14))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Button {
                        store.remove(entry)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.97))
                .overlay(Rectangle().stroke(Color(white: 0.9), lineWidth: 1))
            }
        }
    }
}

struct StyleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Writing Style")
                .font(.custom("Georgia", size: 28))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Text("Provide examples of your writing style.")
                .font(.custom("Georgia", size: 14))
                .foregroundColor(.gray)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            TextEditor(text: .constant("Hi [Name],\n\nThanks for reaching out..."))
                .font(.custom("Georgia", size: 14))
                .padding(16)
                .background(Color(white: 0.97))
                .overlay(Rectangle().stroke(Color(white: 0.85), lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
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
