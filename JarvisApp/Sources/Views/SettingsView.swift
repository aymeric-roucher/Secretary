import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("JARVIS")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.secondaryText)
                    .tracking(1.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 52)
                    .padding(.bottom, 16)

                SidebarButton(title: "Home", icon: "house", tab: .home, selection: $appState.selectedTab)
                SidebarButton(title: "Logs", icon: "doc.text", tab: .logs, selection: $appState.selectedTab)
                SidebarButton(title: "Dictionary", icon: "book", tab: .dictionary, selection: $appState.selectedTab)
                SidebarButton(title: "Style", icon: "textformat", tab: .style, selection: $appState.selectedTab)

                Spacer()

                Divider().overlay(Theme.borderColor)

                SidebarButton(title: "Settings", icon: "gearshape", tab: .settings, selection: $appState.selectedTab)
            }
            .frame(width: 180)
            .background(Theme.sidebarBackground)

            Rectangle().fill(Theme.borderColor).frame(width: 1)

            // Content Area
            VStack {
                switch appState.selectedTab {
                case .home: HomeView()
                case .logs: LogsView()
                case .dictionary: DictionaryView()
                case .style: StyleView()
                case .settings: GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let tab: SettingsTab
    @Binding var selection: SettingsTab

    var body: some View {
        Button(action: { selection = tab }) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14)).frame(width: 18)
                Text(title).font(Theme.bodyFont)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selection == tab ? Theme.textColor.opacity(0.08) : Color.clear)
        .foregroundColor(Theme.textColor)
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
                                    .overlay(Color(white: 0.75))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(timeFormatter.string(from: userMessage.timestamp))
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 40, alignment: .leading)

                Image(systemName: "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 16)

                Text(userMessage.content)
                    .font(.custom("Georgia", size: 15))
                    .foregroundColor(Theme.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let tool = toolMessage {
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                        .frame(width: 40)

                    Text("\u{21B3}")
                        .font(.custom("Georgia", size: 15))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 16)

                    Image(systemName: Theme.toolIcon(for: tool.toolPayload?.name))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 16)

                    Text(tool.content)
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.secondaryText)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct DictionaryView: View {
    @StateObject private var store = DictionaryStore()
    @State private var isEditorVisible = false
    @State private var editingEntry: DictionaryEntry?
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isCorrection: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                entryList
                addButton
                if isEditorVisible { entryForm }
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

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entries")
                .font(.custom("Georgia", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black)
            if store.entries.isEmpty {
                Text("Nothing added yet.")
                    .font(.custom("Georgia", size: 13))
                    .foregroundColor(.gray)
                    .italic()
            } else {
                ForEach(store.entries) { entry in
                    Button {
                        openEditor(for: entry)
                    } label: {
                        HStack(spacing: 12) {
                            if entry.kind == .correction {
                                Text(entry.input)
                                    .font(.custom("Georgia", size: 14))
                                    .foregroundColor(.black)
                                Text("→")
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
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.97))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            openEditor(for: nil)
        } label: {
            Label("Add element", systemImage: "plus.circle.fill")
                .font(.custom("Georgia", size: 14))
        }
        .buttonStyle(.borderedProminent)
    }

    private var entryForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(editingEntry == nil ? "Add entry" : "Edit entry")
                    .font(.custom("Georgia", size: 15))
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") { isEditorVisible = false }
                    .buttonStyle(.borderless)
            }

            Toggle(isOn: $isCorrection) {
                Text("Make it a correction")
                    .font(.custom("Georgia", size: 14))
                    .foregroundColor(.black)
            }
            .toggleStyle(.switch)

            if isCorrection {
                HStack(spacing: 8) {
                    ThemedTextArea(placeholder: "From (e.g. teh)", text: $inputText, height: 60)
                    Text("→")
                        .font(.custom("Georgia", size: 14))
                        .foregroundColor(.gray)
                        .frame(width: 24)
                    ThemedTextArea(placeholder: "To (e.g. the)", text: $outputText, height: 60)
                }
            } else {
                ThemedTextArea(placeholder: "Word to keep (e.g. Eylul)", text: $inputText, height: 60)
            }

            HStack {
                Spacer()
                Button("Save") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .disabled(saveDisabled)
            }
        }
        .padding(14)
        .background(Color(white: 0.98))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func openEditor(for entry: DictionaryEntry?) {
        editingEntry = entry
        if let entry = entry {
            inputText = entry.input
            outputText = entry.output ?? ""
            isCorrection = entry.kind == .correction
        } else {
            inputText = ""
            outputText = ""
            isCorrection = false
        }
        isEditorVisible = true
    }

    private var saveDisabled: Bool {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCorrection {
            return trimmedInput.isEmpty || trimmedOutput.isEmpty
        }
        return trimmedInput.isEmpty
    }

    private func saveEntry() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let entry = editingEntry {
            let updated = DictionaryEntry(id: entry.id,
                                          kind: isCorrection ? .correction : .word,
                                          input: trimmedInput,
                                          output: isCorrection ? trimmedOutput : nil)
            store.update(updated)
        } else {
            if isCorrection {
                store.addCorrection(from: trimmedInput, to: trimmedOutput)
            } else {
                store.addWord(trimmedInput)
            }
        }

        isEditorVisible = false
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

            ThemedTextArea(placeholder: "", text: .constant("Hi [Name],\n\nThanks for reaching out..."), height: 220)
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

    @State private var openaiStatus: ValidationStatus = .none
    @State private var hfStatus: ValidationStatus = .none
    @State private var micStatus: ValidationStatus = .none
    @State private var accessStatus: ValidationStatus = .none

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").font(Theme.titleFont).foregroundColor(Theme.textColor)

                ApiKeysSection(
                    openaiKey: $openaiApiKey,
                    hfKey: $hfApiKey,
                    openaiStatus: $openaiStatus,
                    hfStatus: $hfStatus,
                    onApiKeysValidate: { Task { await validateKeys() } }
                )

                Divider().overlay(Theme.borderColor)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Shortcut").font(Theme.headingFont).foregroundColor(Theme.textColor)
                    ShortcutRecorder().frame(height: 50)
                }

                Divider().overlay(Theme.borderColor)

                PermissionsSection(
                    micStatus: $micStatus,
                    accessStatus: $accessStatus,
                    requestMic: requestMic,
                    checkAccess: checkAccessibility
                )

                Divider().overlay(Theme.borderColor)

                VStack(alignment: .leading, spacing: 8) {
                    Text("About").font(Theme.headingFont).foregroundColor(Theme.textColor)
                    Text("Jarvis v1.0").font(Theme.bodyFont).foregroundColor(Theme.secondaryText).italic()
                }
            }
            .padding(24)
        }
        .background(Theme.background)
        .onAppear {
            loadAPIKeys(openaiKey: &openaiApiKey, hfKey: &hfApiKey)
            checkPermissions()
        }
    }

    private func validateKeys() async {
        openaiStatus = .checking
        hfStatus = .checking
        async let openResult = ApiValidator.validateOpenAI(openaiKey: openaiApiKey)
        async let hfResult = ApiValidator.validateHF(hfKey: hfApiKey)
        let (open, hf) = await (openResult, hfResult)
        openaiStatus = open == .valid ? .valid : .invalid
        hfStatus = hf == .valid ? .valid : .invalid
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: micStatus = .valid
        case .denied, .restricted: micStatus = .invalid
        case .notDetermined: micStatus = .none
        @unknown default: micStatus = .none
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        accessStatus = AXIsProcessTrustedWithOptions(options as CFDictionary) ? .valid : .none
    }

    private func requestMic() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                micStatus = granted ? .valid : .invalid
            }
        }
    }

    private func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessStatus = AXIsProcessTrustedWithOptions(options as CFDictionary) ? .valid : .none
    }
}
