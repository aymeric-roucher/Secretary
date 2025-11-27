import SwiftUI
import AppKit
import Carbon

@main
struct JarvisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appState = AppState()
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        // Menu Bar Icon
        MenuBarExtra("Jarvis", systemImage: "waveform.circle") {
            Button("Home") {
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
                Button("Toggle Jarvis (⌃Space)") { appState.toggleSpotlight() }
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
            
            Button("Help Center") { NSWorkspace.shared.open(URL(string: "https://help.jarvis.app")!) }
            Button("Talk to support") {}
            Button("General feedback") {}
            
            Divider()
            
            Button("Quit Jarvis") {
                NSApplication.shared.terminate(nil)
            }
        }
        
        // The "Spotlight" Window (single instance)
        Window("Jarvis", id: "spotlight") {
            SpotlightView()
                .environmentObject(appState)
                .onAppear {
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "spotlight" }) {
                        window.identifier = NSUserInterfaceItemIdentifier("spotlight")
                        window.styleMask = [.borderless, .fullSizeContentView]
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.level = .floating
                        window.center()
                        window.isMovableByWindowBackground = true
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                        window.standardWindowButton(.closeButton)?.isHidden = true
                        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                        window.standardWindowButton(.zoomButton)?.isHidden = true
                    }
                    log("Spotlight window appeared")
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: Set(arrayLiteral: "spotlight"))
        
        // Settings / Dashboard Window
        Window("Jarvis Dashboard", id: "settings") {
            if hasCompletedOnboarding {
                SettingsView()
                    .environmentObject(appState)
            } else {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
                    .frame(width: 600, height: 500)
            }
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "settings"))
    }
}

enum SettingsTab: String {
    case home, dictionary, style, settings
}

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    
    init(id: UUID = UUID(), role: MessageRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
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
    @Published var shortRecordingWarning: Bool = false
    @Published var messages: [ChatMessage] = []
    @Published var selectedTab: SettingsTab = .home

    let audioRecorder = AudioRecorder()
    let toolManager = ToolManager()
    private let minimumRecordingDuration: TimeInterval = 0.4
    private var panelConfigured = false
    init() {
        AppState.shared = self
        // Listen for the toggle notification here, in the persistent state object
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleNotification), name: NSNotification.Name("ToggleJarvis"), object: nil)
        configurePanelHandler()
    }
    
    @objc func handleToggleNotification() {
        log("AppState received ToggleJarvis")
        toggleSpotlight()
    }
    
    func toggleSpotlight() {
        if let handler = AppDelegate.shared?.floatingPanelHandler {
            handler.toggle(appState: self)
        }
    }
    
    func showSpotlight() {
        configurePanelHandler()
        AppDelegate.shared?.floatingPanelHandler.show(appState: self)
        isSpotlightVisible = true
        if !isRecording {
            startRecording()
        }
    }
    
    func hideSpotlight() {
        AppDelegate.shared?.floatingPanelHandler.hide()
        if isRecording {
            stopRecording()
        }
        isSpotlightVisible = false
    }
    
    private func configurePanelHandler() {
        guard !panelConfigured, let handler = AppDelegate.shared?.floatingPanelHandler else { return }
        handler.configureOnClose { [weak self] in
            Task { @MainActor in
                self?.panelDidClose()
            }
        }
        panelConfigured = true
    }
    
    private func panelDidClose() {
        isSpotlightVisible = false
        if isRecording {
            stopRecording()
        }
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
        isRecording = true
        audioRecorder.startRecording()
        // We don't clear messages, we append.
    }
    
    func stopRecording() {
        log("Stopped recording")
        SoundPlayer.playStop()
        isRecording = false
        
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
        
        isProcessing = true
        
        Task {
            defer { Task { @MainActor in self.isProcessing = false } }
            do {
                let openaiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
                
                if openaiKey.isEmpty {
                    pushEphemeral(role: .system, content: "Please set OpenAI API Key in Settings.")
                    log("Missing OpenAI API Key")
                    return
                }
                
                let whisper = WhisperClient(apiKey: openaiKey)
                log("Sending audio to OpenAI Whisper...")
                
                let transcript = try await whisper.transcribe(fileURL: fileURL)
                
                // Append as user message (what was said)
                pushEphemeral(role: .user, content: transcript)
                log("Whisper transcription: \(transcript)")
                
                // Decide action using Cerebras
                let hfKey = UserDefaults.standard.string(forKey: "hfApiKey") ?? ""
                guard !hfKey.isEmpty else {
                    pushEphemeral(role: .system, content: "Please set Hugging Face Token in Settings.")
                    log("Missing Hugging Face token for Cerebras routing.")
                    return
                }
                
                let defaultBrowser = Self.currentDefaultBrowserName()
                let openAppsDescription = Self.currentOpenAppsDescription()
                
                let cerebras = CerebrasClient(apiKey: hfKey)
                if let toolCall = try await cerebras.processCommand(input: transcript, defaultBrowser: defaultBrowser, openAppsDescription: openAppsDescription) {
                    let reasoning = toolCall.thought ?? "Executing \(toolCall.tool_name)..."
                    log("Cerebras output: \(reasoning)")
                    log("Tool call: \(toolCall.tool_name), \(toolCall.tool_arguments)")
                    pushEphemeral(role: .assistant, content: reasoning)
                    
                    // For typing, hide panel to return focus to previous app
                    if toolCall.tool_name == "type" {
                        hideSpotlight()
                    }
                    self.toolManager.execute(toolName: toolCall.tool_name, args: toolCall.tool_arguments)
                } else {
                    pushEphemeral(role: .system, content: "Could not understand the command.")
                    log("Cerebras returned no tool call.")
                }
            } catch {
                pushEphemeral(role: .system, content: "Error: \(error.localizedDescription)")
                log("Error processing: \(error)")
            }
        }
    }
    
    func showSettings() {
        if let url = URL(string: "jarvis://settings") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @MainActor
    private func pushEphemeral(role: MessageRole, content: String) {
        let msg = ChatMessage(role: role, content: content)
        messages.append(msg)
        ToastManager.shared.show(message: msg)
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
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    var hotKeyRef: EventHotKeyRef?
    var pollingTimer: Timer? // Unused now, kept for potential future hold-to-talk
    var lastKeyCode: UInt32 = 0
    var lastModifiers: UInt32 = 0
    let floatingPanelHandler = FloatingPanelHandler()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        log("Application finished launching")
        registerHotKey()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reloadHotkey), name: NSNotification.Name("ReloadHotkey"), object: nil)
        
        // Auto-open onboarding if needed
        if !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            log("Onboarding not completed. Attempting to open settings window.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                if let url = URL(string: "jarvis://settings") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
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
        
        // Load from defaults or use Shift+Space (default)
        let savedMod = UserDefaults.standard.integer(forKey: "JarvisShortcutModifier")
        let savedKey = UserDefaults.standard.integer(forKey: "JarvisShortcutKey")
        
        // Default: Backtick key (keyCode 50), no modifiers
        lastModifiers = UInt32(savedMod)
        lastKeyCode = savedKey == 0 ? 50 : UInt32(savedKey)
        
        // Register the HotKey. This will fire on keydown.
        let target = GetEventDispatcherTarget()
        let effectiveModifiers = lastModifiers == 0 ? UInt32(shiftKey) : lastModifiers
        let effectiveKey = lastKeyCode == 0 ? UInt32(49) : lastKeyCode // Space key default
        lastModifiers = effectiveModifiers
        lastKeyCode = effectiveKey
        let err = RegisterEventHotKey(effectiveKey, effectiveModifiers, hotKeyID, target, 0, &newHotKeyRef)
        
        if err == noErr {
            hotKeyRef = newHotKeyRef
            log("Global hotkey registered: Mod \(lastModifiers) Key \(lastKeyCode)")
        } else {
            log("Failed to register global hotkey: \(err)")
        }
        
        // Install handler for the hotkey press event
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(target, { (nextHandler, theEvent, userData) -> OSStatus in
            log("Global Hotkey Handler Triggered (Pressed)!")
            
            // Dispatch to Main Actor to access AppState safely
            DispatchQueue.main.async {
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
