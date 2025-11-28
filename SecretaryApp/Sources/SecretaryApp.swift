import SwiftUI
import AppKit
import Carbon

@main
struct SecretaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("SecretaryShortcutModifier") var savedModifier: Int = ShortcutConfig.defaultModifier
    @AppStorage("SecretaryShortcutKey") var savedKey: Int = ShortcutConfig.defaultKey

    var body: some Scene {
        // Menu Bar Icon
        MenuBarExtra("Secretary", systemImage: "pencil.line") {
            Button("Open Secretary") {
                appState.selectedTab = .home
                appState.showSettings()
            }
            Button("Check for updates...") {
                log("User checked for updates - not implemented")
            }
            Button("Paste last transcript") {
                appState.pasteLastTranscript()
            }
            
            Divider()
            
            Menu("Shortcuts") {
                Button("Toggle Secretary (\(ShortcutConfig.display(modifier: savedModifier, key: savedKey)))") {
                    appState.toggleSpotlight()
                }
            }
            
            Menu("Microphone") {
                Button("Auto-detect (AirPods)") {}
                Button("AirPods") {}
                Button("✓ Built-in mic (recommended)") {}
            }
            
            Menu("Languages") {
                Button("English (US)") {}
                Button("French") {}
            }
            
            Divider()
            
            Button("Quit Secretary") {
                NSApplication.shared.terminate(nil)
            }
        }

        // Settings / Dashboard Window
        Window("Secretary Dashboard", id: "settings") {
            if hasCompletedOnboarding {
                SettingsView()
                    .environmentObject(appState)
            } else {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .handlesExternalEvents(matching: Set(arrayLiteral: "settings"))
    }
}

enum SettingsTab: String {
    case home, logs, dictionary, style, settings
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let toolPayload: ToolPayload?
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, toolPayload: ToolPayload? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.toolPayload = toolPayload
        self.timestamp = timestamp
    }
}

enum MessageRole {
    case user
    case assistant
    case system
    case tool
}

@MainActor
class AppState: ObservableObject {
    static var shared: AppState?
    
    @Published var isSpotlightVisible: Bool = false
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
    @Published var isCompleted: Bool = false
    @Published var shortRecordingWarning: Bool = false
    @Published var messages: [ChatMessage] = []
    @Published var selectedTab: SettingsTab = .home
    @Published var popupTranscript: String?
    @Published var popupToolMessage: ChatMessage?

    let audioRecorder = AudioRecorder()
    let toolManager = ToolManager()
    private let minimumRecordingDuration: TimeInterval = 0.4
    init() {
        AppState.shared = self
        // Listen for the toggle notification here, in the persistent state object
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleNotification), name: NSNotification.Name("ToggleSecretary"), object: nil)
    }

    @objc func handleToggleNotification() {
        log("AppState received ToggleSecretary")
        toggleSpotlight()
    }
    
    func toggleSpotlight() {
        if isSpotlightVisible {
            hideSpotlight()
        } else {
            showSpotlight()
        }
    }
    
    func showSpotlight() {
        AppDelegate.shared?.popupManager.show(appState: self)
        isSpotlightVisible = true
        if !isRecording {
            startRecording()
        }
    }
    
    func hideSpotlight() {
        AppDelegate.shared?.popupManager.hide()
        if isRecording {
            stopRecording()
        }
        isSpotlightVisible = false
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func pasteLastTranscript() {
        if let last = messages.last(where: { $0.role == .user }) {
            toolManager.execute(toolName: "type", args: .text(last.content))
        }
    }
    
    func startRecording() {
        log("Started recording")
        SoundPlayer.playStart()
        shortRecordingWarning = false
        isProcessing = false
        isCompleted = false
        popupTranscript = nil
        popupToolMessage = nil
        isRecording = true
        audioRecorder.startRecording()
    }
    
    func stopRecording() {
        log("Stopped recording")
        SoundPlayer.playStop()
        isRecording = false
        isProcessing = true

        guard let fileURL = audioRecorder.stopRecording() else {
            log("Error: No file URL returned from recorder")
            isProcessing = false
            return
        }

        if audioRecorder.lastRecordingDuration < minimumRecordingDuration {
            log("Recording too short: \(audioRecorder.lastRecordingDuration)s (threshold \(minimumRecordingDuration)s)")
            withAnimation {
                shortRecordingWarning = true
            }
            isProcessing = false
            return
        }

        Task {
            do {
                let openaiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""

                if openaiKey.isEmpty {
                    pushMessage(role: .system, content: "Please set OpenAI API Key in Settings.")
                    log("Missing OpenAI API Key")
                    await completeAndHidePopup()
                    return
                }

                let whisper = TranscriptionClient(apiKey: openaiKey)
                log("Sending audio to OpenAI Whisper...")

                let transcript = try await whisper.transcribe(fileURL: fileURL)

                // Show transcript in popup and save to history
                popupTranscript = transcript
                pushMessage(role: .user, content: transcript)
                log("Whisper transcription: \(transcript)")

                // Decide action using Cerebras
                let hfKey = UserDefaults.standard.string(forKey: "hfApiKey") ?? ""
                guard !hfKey.isEmpty else {
                    pushMessage(role: .system, content: "Please set Hugging Face Token in Settings.")
                    log("Missing Hugging Face token for Cerebras routing.")
                    await completeAndHidePopup()
                    return
                }

                let defaultBrowser = Self.currentDefaultBrowserName()
                let openAppsDescription = Self.currentOpenAppsDescription()
                let installedAppsDescription = Self.installedAppsDescription()
                let dictionaryEntries = DictionaryStore().entries
                let styleExamples = StyleStore().styleText

                let cerebras = ThinkingClient(apiKey: hfKey)
                if let toolCall = try await cerebras.processCommand(input: transcript, defaultBrowser: defaultBrowser, openAppsDescription: openAppsDescription, installedAppsDescription: installedAppsDescription, dictionaryEntries: dictionaryEntries, styleExamples: styleExamples) {
                    let toolDescription = formattedToolCall(toolCall)
                    log("Tool call: \(toolCall.tool_name), \(toolCall.tool_arguments)")

                    // Show tool message in popup and save to history
                    let toolMsg = createToolMessage(name: toolDescription.name, args: toolDescription.args)
                    popupToolMessage = toolMsg
                    messages.append(toolMsg)

                    // Execute the tool
                    self.toolManager.execute(toolName: toolCall.tool_name, args: toolCall.tool_arguments)

                    // Show completion then hide after delay
                    await completeAndHidePopup()
                } else {
                    pushMessage(role: .system, content: "Could not understand the command.")
                    log("Cerebras returned no tool call.")
                    await completeAndHidePopup()
                }
            } catch {
                pushMessage(role: .system, content: "Error: \(error.localizedDescription)")
                log("Error processing: \(error)")
                await completeAndHidePopup()
            }
        }
    }

    @MainActor
    private func completeAndHidePopup(delay: UInt64 = 1_500_000_000) async {
        isProcessing = false
        isCompleted = true
        try? await Task.sleep(nanoseconds: delay)
        hideSpotlight()
    }
    
    func showSettings() {
        if let url = URL(string: "secretary://settings") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @MainActor
    private func pushMessage(role: MessageRole, content: String) {
        let msg = ChatMessage(role: role, content: content)
        messages.append(msg)
    }

    @MainActor
    private func createToolMessage(name: String, args: String) -> ChatMessage {
        let rendered = args.isEmpty ? name : args
        return ChatMessage(role: .tool, content: rendered, toolPayload: ToolPayload(name: name, arguments: args))
    }
    
    private static func currentDefaultBrowserName() -> String {
        if let url = URL(string: "http://apple.com"),
           let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) {
            return FileManager.default.displayName(atPath: appURL.path)
        }
        return "Safari"
    }
    
    private static func currentOpenAppsDescription() -> String {
        let names = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .sorted()
        return names.isEmpty ? "None detected" : names.joined(separator: ", ")
    }

    private static func installedAppsDescription() -> String {
        let applicationsURL = URL(fileURLWithPath: "/Applications")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: applicationsURL, includingPropertiesForKeys: nil) else {
            return "Unknown"
        }
        let appNames = contents
            .filter { $0.pathExtension == "app" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return appNames.isEmpty ? "Unknown" : appNames.joined(separator: ", ")
    }

    private func formattedToolCall(_ toolCall: ToolCallResponse) -> (name: String, args: String) {
        switch toolCall.tool_arguments {
        case .text(let text):
            return (toolCall.tool_name, text)
        case .none:
            return (toolCall.tool_name, "")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    var hotKeyRef: EventHotKeyRef?
    var pollingTimer: Timer? // Unused now, kept for potential future hold-to-talk
    var lastKeyCode: UInt32 = 0
    var lastModifiers: UInt32 = 0
    let popupManager = MenuPopupManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        log("Application finished launching")
        CrashLogger.install()
        registerHotKey()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadHotkey), name: NSNotification.Name("ReloadHotkey"), object: nil)
        
        // Auto-open onboarding if needed
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            log("Onboarding not completed. Attempting to open settings window.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                if let url = URL(string: "secretary://settings") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    @objc private func handleAppWillTerminate() {
        log("NSApplication.willTerminateNotification received")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        log("applicationWillTerminate called")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    @objc func reloadHotkey() {
        log("Reloading hotkey...")
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            // Stop polling if active
            pollingTimer?.invalidate()
            pollingTimer = nil
        }
        registerHotKey()
    }
    
    func registerHotKey() {
        // Unregister any existing hotkey first
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x11223344), id: 1)
        var newHotKeyRef: EventHotKeyRef?
        
        // Load from defaults or fall back to Control + Space
        let defaults = UserDefaults.standard
        let hasStoredMod = defaults.object(forKey: "SecretaryShortcutModifier") != nil
        let hasStoredKey = defaults.object(forKey: "SecretaryShortcutKey") != nil
        let storedMod = defaults.integer(forKey: "SecretaryShortcutModifier")
        let storedKey = defaults.integer(forKey: "SecretaryShortcutKey")
        let usesLegacyDefault = (storedMod == Int(shiftKey) && storedKey == 49) || (storedMod == Int(shiftKey) && storedKey == Int(kVK_ANSI_2))
        let shouldResetToDefault = !hasStoredMod || !hasStoredKey || usesLegacyDefault
        let effectiveModifiers = shouldResetToDefault ? ShortcutConfig.defaultModifier : storedMod
        let effectiveKey = shouldResetToDefault ? ShortcutConfig.defaultKey : storedKey
        if shouldResetToDefault {
            defaults.set(ShortcutConfig.defaultModifier, forKey: "SecretaryShortcutModifier")
            defaults.set(ShortcutConfig.defaultKey, forKey: "SecretaryShortcutKey")
        }
        lastModifiers = UInt32(effectiveModifiers)
        lastKeyCode = UInt32(effectiveKey)
        
        // Register the HotKey. This will fire on keydown.
        let target = GetEventDispatcherTarget()
        let err = RegisterEventHotKey(lastKeyCode, lastModifiers, hotKeyID, target, 0, &newHotKeyRef)
        
        if err == noErr {
            hotKeyRef = newHotKeyRef
            log("Global hotkey registered: \(ShortcutConfig.display(modifier: Int(lastModifiers), key: Int(lastKeyCode))) (Mod \(lastModifiers) Key \(lastKeyCode))")
        } else {
            log("Failed to register global hotkey: \(err)")
        }
        
        // Install handler for the hotkey press event
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(target, { (nextHandler, theEvent, userData) -> OSStatus in
            log("Global Hotkey Handler Triggered (Pressed)!")
            
            // Dispatch to Main Actor to access AppState safely
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("GlobalHotkeyPressed"), object: nil)
                guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else {
                    log("Hotkey ignored because onboarding is not completed.")
                    return
                }
                
                guard let appState = AppState.shared else {
                    log("AppState.shared missing in hotkey pressed handler")
                    return
                }
                
                // Always show the panel; recording starts on press, stops on release
                if !appState.isSpotlightVisible {
                    appState.showSpotlight()
                }
                if !appState.isRecording {
                    appState.startRecording()
                }
            }
            
            return noErr
        }, 1, &eventType, nil, nil)
        
        // Hotkey released handler: stop recording but keep panel open
        var releaseType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        InstallEventHandler(target, { (nextHandler, theEvent, userData) -> OSStatus in
            log("Global Hotkey Handler Triggered (Released)!")
            DispatchQueue.main.async {
                guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else {
                    log("Hotkey release ignored because onboarding is not completed.")
                    return
                }
                guard let appState = AppState.shared else {
                    log("AppState.shared missing in hotkey released handler")
                    return
                }
                if appState.isRecording {
                    appState.stopRecording()
                }
            }
            return noErr
        }, 1, &releaseType, nil, nil)
    }
}
struct ToolPayload: Codable {
    let name: String
    let arguments: String
}

private enum ShortcutConfig {
    static let defaultModifier: Int = Int(shiftKey) // Shift
    static let defaultKey: Int = 49 // Space
    
    static func display(modifier: Int, key: Int) -> String {
        let modText = modifierSymbols(modifier)
        let keyText = keyName(key)
        if modText.isEmpty { return keyText }
        return "\(modText)+\(keyText)"
    }
    
    private static func modifierSymbols(_ carbonMod: Int) -> String {
        var s = ""
        if (carbonMod & Int(cmdKey)) != 0 { s += "⌘" }
        if (carbonMod & Int(controlKey)) != 0 { s += "⌃" }
        if (carbonMod & Int(optionKey)) != 0 { s += "⌥" }
        if (carbonMod & Int(shiftKey)) != 0 { s += "⇧" }
        return s
    }
    
    private static func keyName(_ code: Int) -> String {
        switch code {
        case 50: return "`"
        case 49: return "Space"
        case 36: return "Return"
        case 53: return "Esc"
        case 48: return "Tab"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 51: return "Delete"
        case 117: return "Fwd Del"
        case 115: return "Home"
        case 119: return "End"
        case 116: return "PgUp"
        case 121: return "PgDn"
        default:
            return String(format: "%d", code)
        }
    }
}
