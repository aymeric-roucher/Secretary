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
        
        // The "Spotlight" Window
        WindowGroup(id: "spotlight") {
            SpotlightView()
                .environmentObject(appState)
                .onAppear {
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "spotlight" }) {
                        window.styleMask = [.borderless, .fullSizeContentView]
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.level = .floating
                        window.center()
                        window.isMovableByWindowBackground = true
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
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
    let id = UUID()
    let role: MessageRole
    let content: String
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
    @Published var messages: [ChatMessage] = [ChatMessage(role: .system, content: "Ready")]
    @Published var selectedTab: SettingsTab = .home
    
    let audioRecorder = AudioRecorder()
    let toolManager = ToolManager()
    
    init() {
        AppState.shared = self
        // Listen for the toggle notification here, in the persistent state object
        NotificationCenter.default.addObserver(self, selector: #selector(handleToggleNotification), name: NSNotification.Name("ToggleJarvis"), object: nil)
    }
    
    @objc func handleToggleNotification() {
        log("AppState received ToggleJarvis")
        toggleSpotlight()
    }
    
    func toggleSpotlight() {
        isSpotlightVisible.toggle()
        log("Toggle Spotlight: \(isSpotlightVisible)")
        
        if isSpotlightVisible {
            activateSpotlight()
        } else {
            hideSpotlight()
        }
    }
    
    private func activateSpotlight() {
        NSApp.activate(ignoringOtherApps: true)
        // Check if window is already open
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "spotlight" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // If not found, try to open via URL
            log("Spotlight window not found, opening via URL...")
            if let url = URL(string: "jarvis://spotlight") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func hideSpotlight() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "spotlight" }) {
            window.orderOut(nil)
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
        isRecording = true
        audioRecorder.startRecording()
        // We don't clear messages, we append.
    }
    
    func stopRecording() {
        log("Stopped recording")
        guard let fileURL = audioRecorder.stopRecording() else {
            log("Error: No file URL returned from recorder")
            return 
        }
        isRecording = false
        
        // Add placeholder while processing? Or just wait.
        // self.messages.append(ChatMessage(role: .system, content: "Processing..."))
        
        Task {
            do {
                let geminiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
                let hfKey = UserDefaults.standard.string(forKey: "hfApiKey") ?? ""
                
                if geminiKey.isEmpty || hfKey.isEmpty {
                    self.messages.append(ChatMessage(role: .system, content: "Please set API Keys in Settings."))
                    log("Missing API Keys")
                    return
                }
                
                let gemini = GeminiClient(apiKey: geminiKey)
                log("Starting transcription...")
                let text = try await gemini.transcribeAudio(fileURL: fileURL)
                log("Transcription result: \(text)")
                
                self.messages.append(ChatMessage(role: .user, content: text))
                
                // Process with Cerebras
                let cerebras = CerebrasClient(apiKey: hfKey)
                log("Requesting tool call...")
                if let toolCall = try await cerebras.processCommand(input: text) {
                    
                    if !toolCall.reasoning.isEmpty {
                        self.messages.append(ChatMessage(role: .assistant, content: toolCall.reasoning))
                    }
                    
                    let toolMsg = "Running: \(toolCall.tool_name)(\(toolCall.tool_arguments))"
                    self.messages.append(ChatMessage(role: .tool, content: toolMsg))
                    
                    log("Tool call: \(toolCall.tool_name) args: \(toolCall.tool_arguments)")
                    self.toolManager.execute(toolName: toolCall.tool_name, args: toolCall.tool_arguments)
                    
                } else {
                    log("No tool call generated")
                }
                
            } catch {
                self.messages.append(ChatMessage(role: .system, content: "Error: \(error.localizedDescription)"))
                log("Error processing: \(error)")
            }
        }
    }
    
    func showSettings() {
        if let url = URL(string: "jarvis://settings") {
            NSWorkspace.shared.open(url)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyRef: EventHotKeyRef?
    var pollingTimer: Timer? // For Hold-to-Talk
    var lastKeyCode: UInt32 = 0
    var lastModifiers: UInt32 = 0
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        // Default: Shift (512) + Space (49)
        lastModifiers = savedMod == 0 ? UInt32(shiftKey) : UInt32(savedMod)
        lastKeyCode = savedKey == 0 ? 49 : UInt32(savedKey)
        
        // Register the HotKey. This will fire on keydown.
        let err = RegisterEventHotKey(lastKeyCode, lastModifiers, hotKeyID, GetApplicationEventTarget(), 0, &newHotKeyRef)
        
        if err == noErr {
            hotKeyRef = newHotKeyRef
            log("Global hotkey registered: Mod \(lastModifiers) Key \(lastKeyCode)")
        } else {
            log("Failed to register global hotkey: \(err)")
        }
        
        // Install handler for the hotkey press event
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            log("Global Hotkey Handler Triggered (Pressed)!")
            
            // Dispatch to Main Actor to access AppState safely
            DispatchQueue.main.async {
                guard let appState = AppState.shared else { return }
                
                // Check if recording, if so, this is a toggle to stop early
                if appState.isRecording {
                     appState.stopRecording()
                     // We need to access AppDelegate instance to stop timer
                     if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                         appDelegate.pollingTimer?.invalidate()
                         appDelegate.pollingTimer = nil
                     }
                     return
                }
                
                // Start recording and polling
                appState.startRecording()
                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                    appDelegate.startPollingForKeyState()
                }
                
                // We still toggle the spotlight view so the user sees the input field
                NotificationCenter.default.post(name: NSNotification.Name("ToggleJarvis"), object: nil)
            }
            
            return noErr
        }, 1, &eventType, nil, nil)
    }
    
    func startPollingForKeyState() {
        log("Starting polling for key state...")
        pollingTimer?.invalidate() // Stop any previous timer
        
        let keyToMonitor = self.lastKeyCode
        let modifiersToMonitor = self.lastModifiers
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let appState = AppState.shared, appState.isRecording else {
                    self?.pollingTimer?.invalidate()
                    self?.pollingTimer = nil
                    log("Polling stopped (not recording or appState missing).")
                    return
                }
                
                // Correctly use static CGEventSource.keyState
                let isKeyPressed = CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(keyToMonitor))
                
                // Check modifiers using CGEventSource flags
                let flags = CGEventSource.flagsState(.combinedSessionState)
                
                // Check modifier keys explicitly (Control, Option, Shift, Command)
                var currentModifiers: UInt32 = 0
                if flags.contains(.maskControl) { currentModifiers |= UInt32(controlKey) }
                if flags.contains(.maskAlternate) { currentModifiers |= UInt32(optionKey) }
                if flags.contains(.maskShift) { currentModifiers |= UInt32(shiftKey) }
                if flags.contains(.maskCommand) { currentModifiers |= UInt32(cmdKey) }
                
                // Strict check: key must be pressed. Modifiers are looser (if they release mods but hold key, maybe keep recording?)
                // Let's enforce both for Hold-to-Talk behavior.
                if !isKeyPressed || (currentModifiers & modifiersToMonitor) != modifiersToMonitor {
                    log("Hotkey released. Stopping recording.")
                    appState.stopRecording()
                    self.pollingTimer?.invalidate()
                    self.pollingTimer = nil
                }
            }
        }
    }
}