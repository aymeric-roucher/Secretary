import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @State private var isRecording = false
    
    // Initial values loaded from UserDefaults or Defaults
    @AppStorage("JarvisShortcutModifier") var savedModifier: Int = Int(shiftKey) // Default: Shift
    @AppStorage("JarvisShortcutKey") var savedKey: Int = 49 // Default: Space
    
    @State private var displayModifier: String = ""
    @State private var displayKey: String = ""
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: { isRecording = true }) {
                HStack(spacing: 5) {
                    if isRecording {
                        Text("Press your shortcut combo...")
                            .foregroundColor(.blue)
                    } else {
                        Text(displayModifier)
                            .font(.body)
                            .fontWeight(.bold)
                            .frame(minWidth: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        
                        Text("+")
                        
                        Text(displayKey)
                            .font(.body)
                            .fontWeight(.bold)
                            .frame(minWidth: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10).stroke(isRecording ? Color.blue : Color.gray, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .onAppear(perform: updateDisplay)
            .onChange(of: savedModifier) { _, _ in updateDisplay() }
            .onChange(of: savedKey) { _, _ in updateDisplay() }
            
            if isRecording {
                Button("Cancel") { isRecording = false }
            }
        }
        .background(KeySniffer(isRecording: $isRecording, onKey: { mod, key in
            self.savedModifier = mod
            self.savedKey = key
            self.isRecording = false
            log("New shortcut saved: Mod \(mod), Key \(key)")
            NotificationCenter.default.post(name: NSNotification.Name("ReloadHotkey"), object: nil)
        }))
    }
    
    func updateDisplay() {
        displayModifier = modString(savedModifier)
        displayKey = keyString(savedKey)
    }
    
    func modString(_ carbonMod: Int) -> String {
        var s = ""
        if (carbonMod & Int(cmdKey)) != 0 { s += "⌘" }
        if (carbonMod & Int(controlKey)) != 0 { s += "⌃" }
        if (carbonMod & Int(optionKey)) != 0 { s += "⌥" }
        if (carbonMod & Int(shiftKey)) != 0 { s += "⇧" }
        return s.isEmpty ? "None" : s
    }
    
    func keyString(_ code: Int) -> String {
        // Simple virtual key code to string mapping for common keys
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
            // Attempt to get character from key code
            return String(format: "%d", code) // Fallback to raw code
        }
    }
}

struct KeySniffer: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onKey: (Int, Int) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeySniffView()
        view.parent = self
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let view = nsView as! KeySniffView
        view.parent = self
        if isRecording {
            view.window?.makeFirstResponder(view)
        } else {
            view.window?.makeFirstResponder(nil) // Resign responder when not recording
        }
    }
}

class KeySniffView: NSView {
    var parent: KeySniffer?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard let parent = parent, parent.isRecording else {
            super.keyDown(with: event)
            return
        }
        
        // Extract modifier flags
        var mod = 0
        if event.modifierFlags.contains(.command) { mod |= Int(cmdKey) }
        if event.modifierFlags.contains(.control) { mod |= Int(controlKey) }
        if event.modifierFlags.contains(.option)  { mod |= Int(optionKey) }
        if event.modifierFlags.contains(.shift)   { mod |= Int(shiftKey) }
        
        let key = Int(event.keyCode)
        
        // Prevent recording only modifier presses as the key
        if key == Int(kVK_Shift) || key == Int(kVK_Control) || key == Int(kVK_Option) || key == Int(kVK_Command) {
            log("Modifier-only key press detected, ignoring as primary key for shortcut.")
            return
        }
        
        log("KeySniffer captured: Mod \(mod), Key \(key)")
        parent.onKey(mod, key)
    }
    
    // Crucial: Suppress system beep for unhandled key presses
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if parent?.isRecording == true {
            keyDown(with: event) // Process it
            return true // Indicate handled, suppress beep
        }
        return super.performKeyEquivalent(with: event)
    }
}