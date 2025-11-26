import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @State private var isRecording = false
    @State private var modifier: Int = 0
    @State private var keyCode: Int = 0
    
    // Initial values loaded from UserDefaults or Defaults
    @AppStorage("JarvisShortcutModifier") var savedModifier: Int = 4096 // Control
    @AppStorage("JarvisShortcutKey") var savedKey: Int = 49 // Space
    
    var body: some View {
        VStack {
            Text("Global Shortcut")
                .font(.headline)
            
            HStack(spacing: 10) {
                // Visual representation
                Button(action: { isRecording = true }) {
                    HStack {
                        if isRecording {
                            Text("Press Combo...")
                                .foregroundColor(.blue)
                        } else {
                            Text(modString(savedModifier))
                                .fontWeight(.bold)
                                .frame(width: 50, height: 40)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            
                            Text("+")
                            
                            Text(keyString(savedKey))
                                .fontWeight(.bold)
                                .frame(width: 50, height: 40)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(isRecording ? Color.blue : Color.gray, lineWidth: 2))
                }
                .buttonStyle(.plain)
                
                if isRecording {
                    Button("Cancel") { isRecording = false }
                }
            }
        }
        .background(KeySniffer(isRecording: $isRecording, onKey: { mod, key in
            self.savedModifier = mod
            self.savedKey = key
            self.isRecording = false
            
            // Notify app to re-register hotkey immediately
            NotificationCenter.default.post(name: NSNotification.Name("ReloadHotkey"), object: nil)
        }))
    }
    
    func modString(_ carbonMod: Int) -> String {
        var s = ""
        if (carbonMod & cmdKey) != 0 { s += "⌘" }
        if (carbonMod & controlKey) != 0 { s += "⌃" }
        if (carbonMod & optionKey) != 0 { s += "⌥" }
        if (carbonMod & shiftKey) != 0 { s += "⇧" }
        return s.isEmpty ? "?" : s
    }
    
    func keyString(_ code: Int) -> String {
        // Mapping some common codes manually for display
        switch code {
        case 49: return "Space"
        case 36: return "Enter"
        case 48: return "Tab"
        case 53: return "Esc"
        default:
            // Try to convert keycode to char (very rough)
            return String(format: "%d", code)
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
        if event.modifierFlags.contains(.command) { mod |= cmdKey }
        if event.modifierFlags.contains(.control) { mod |= controlKey }
        if event.modifierFlags.contains(.option)  { mod |= optionKey }
        if event.modifierFlags.contains(.shift)   { mod |= shiftKey }
        
        let key = Int(event.keyCode)
        
        // Don't record just a modifier press (wait for a key)
        // But if they press a key with no modifiers, that's allowed but risky?
        // Let's allow it.
        
        parent.onKey(mod, key)
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if parent?.isRecording == true {
            keyDown(with: event)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}