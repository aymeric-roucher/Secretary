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
            .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
        .buttonStyle(ThemeButtonStyle())
        .background(selection == tab ? Theme.textColor.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .foregroundColor(Theme.textColor)
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

    private var totalWordCount: Int {
        appState.messages
            .filter { $0.role == .user }
            .reduce(0) { $0 + $1.content.split(separator: " ").count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Home")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textColor)
                Spacer()
                if totalWordCount > 0 {
                    Text("\(totalWordCount) words")
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.inputBackground)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            if groupedMessages.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No messages")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.secondaryText)
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
                                    .overlay(Theme.dividerColor)
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
        .background(Theme.background)
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
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let tool = toolMessage {
                HStack(alignment: .top, spacing: 8) {
                    Text("")
                        .frame(width: 40)

                    Text("\u{21B3}")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.secondaryText)
                        .frame(width: 16)

                    Image(systemName: Theme.iconForTool(name: tool.toolPayload?.name, arguments: tool.toolPayload?.arguments))
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Dictionary")
                .font(Theme.titleFont)
                .foregroundColor(Theme.textColor)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Text("Add custom words or map abbreviations/misspellings to their corrected form.")
                .font(Theme.bodyFont)
                .foregroundColor(Theme.secondaryText)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    entryList
                    addButton
                    if isEditorVisible { entryForm }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.background)
    }

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entries")
                .font(Theme.headingFont)
                .foregroundColor(Theme.textColor)
            if store.entries.isEmpty {
                Text("Nothing added yet.")
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.secondaryText)
                    .italic()
            } else {
                ForEach(store.entries) { entry in
                    Button {
                        openEditor(for: entry)
                    } label: {
                        HStack(spacing: 12) {
                            if entry.kind == .correction {
                                Text(entry.input)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textColor)
                                Text("→")
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.secondaryText)
                                Text(entry.output ?? "")
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textColor)
                            } else {
                                Text(entry.input)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textColor)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .foregroundColor(Theme.secondaryText)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    }
                    .buttonStyle(ThemeButtonStyle())
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            openEditor(for: nil)
        } label: {
            Label("Add element", systemImage: "plus.circle.fill")
        }
        .buttonStyle(ThemeButtonStyle())
    }

    private var entryForm: some View {
        ThemedBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(editingEntry == nil ? "Add entry" : "Edit entry")
                        .font(Theme.headingFont)
                        .foregroundColor(Theme.textColor)
                    Spacer()
                    Button("Cancel") { isEditorVisible = false }
                        .buttonStyle(ThemeButtonStyle())
                }

                Toggle(isOn: $isCorrection) {
                    Text("Make it a correction")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textColor)
                }
                .toggleStyle(.switch)

                if isCorrection {
                    HStack(spacing: 8) {
                        ThemedTextArea(placeholder: "From (e.g. teh)", text: $inputText, height: 60)
                        Text("→")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.secondaryText)
                            .frame(width: 24)
                        ThemedTextArea(placeholder: "To (e.g. the)", text: $outputText, height: 60)
                    }
                } else {
                    ThemedTextArea(placeholder: "Word to keep (e.g. Eylul)", text: $inputText, height: 60)
                }

                HStack {
                    Spacer()
                    Button("Save") { saveEntry() }
                        .buttonStyle(ThemePrimaryButtonStyle())
                        .disabled(saveDisabled)
                }
            }
        }
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
                .font(Theme.titleFont)
                .foregroundColor(Theme.textColor)
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

            Text("Provide examples of your writing style.")
                .font(Theme.bodyFont)
                .foregroundColor(Theme.secondaryText)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            ThemedTextArea(placeholder: "", text: .constant("Hi [Name],\n\nThanks for reaching out..."), height: 220)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
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
