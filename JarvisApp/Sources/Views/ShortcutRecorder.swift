import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    @State private var isRecording = false
    
    // Initial values loaded from UserDefaults or Defaults
    @AppStorage("JarvisShortcutModifier") var savedModifier: Int = Int(shiftKey) // Default: Shift
    @AppStorage("JarvisShortcutKey") var savedKey: Int = 49 // Default: Space
    
    @State private var displayModifier: String = ""
    @State private var displayKey: String = ""
    @State private var pressedFlash = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isRecording = true }) {
                HStack(spacing: 5) {
                    if isRecording {
                        Text("Press your shortcut combo...")
                            .foregroundColor(.blue)
                    } else {
                        Text(displayModifier)
                            .font(Theme.bodyFont)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textColor)
                            .frame(minWidth: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))

                        Text("+")
                            .foregroundColor(Theme.secondaryText)

                        Text(displayKey)
                            .font(Theme.bodyFont)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.textColor)
                            .frame(minWidth: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
                    }
                }
                .padding(8)
                .background(isRecording ? Theme.inputBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            }
            .buttonStyle(.plain)
            .onAppear(perform: updateDisplay)
            .onChange(of: savedModifier) { _, _ in updateDisplay() }
            .onChange(of: savedKey) { _, _ in updateDisplay() }
            
            if isRecording {
                Button("Cancel") { isRecording = false }
                    .buttonStyle(ThemeButtonStyle())
            }
            
            HStack(spacing: 6) {
                Circle()
                    .fill(pressedFlash ? Color.green : Color.gray.opacity(0.25))
                    .frame(width: 10, height: 10)
                    .animation(.easeInOut(duration: 0.15), value: pressedFlash)
                Text("Shortcut pressed")
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.secondaryText)
            }
        }
        .background(KeySniffer(isRecording: $isRecording, onKey: { mod, key in
            self.savedModifier = mod
            self.savedKey = key
            self.isRecording = false
            flashPressed()
            log("New shortcut saved: Mod \(mod), Key \(key)")
            NotificationCenter.default.post(name: NSNotification.Name("ReloadHotkey"), object: nil)
        }))
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("GlobalHotkeyPressed"))) { _ in
            flashPressed()
        }
    }
    
    func updateDisplay() {
        displayModifier = modString(savedModifier)
        displayKey = translatedKey(modifier: savedModifier, key: savedKey) ?? keyString(savedKey)
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
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 10: return "§"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        default:
            // Attempt to get character from key code
            return String(format: "%d", code) // Fallback to raw code
        }
    }
    
    private func translatedKey(modifier: Int, key: Int) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = unsafeBitCast(ptr, to: CFData.self)
        guard let keyLayoutPtr = CFDataGetBytePtr(data) else {
            return nil
        }
        let keyLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(keyLayoutPtr))
        
        var deadKeyState: UInt32 = 0
        var chars: [UniChar] = Array(repeating: 0, count: 4)
        var length: Int = 0
        
        var flags = NSEvent.ModifierFlags()
        if (modifier & Int(shiftKey)) != 0 { flags.insert(.shift) }
        if (modifier & Int(optionKey)) != 0 { flags.insert(.option) }
        if (modifier & Int(controlKey)) != 0 { flags.insert(.control) }
        if (modifier & Int(cmdKey)) != 0 { flags.insert(.command) }
        let modifierState = (flags.rawValue >> 16) & 0xFF
        
        let err = UCKeyTranslate(keyLayout,
                                 UInt16(key),
                                 UInt16(kUCKeyActionDisplay),
                                 UInt32(modifierState),
                                 UInt32(LMGetKbdType()),
                                 OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                 &deadKeyState,
                                 chars.count,
                                 &length,
                                 &chars)
        
        if err == noErr, length > 0 {
            let s = String(utf16CodeUnits: chars, count: length)
            return s == " " ? "Space" : s
        }
        return nil
    }
    
    private func flashPressed() {
        pressedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.25)) {
                pressedFlash = false
            }
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
