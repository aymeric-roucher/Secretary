import Foundation
import AppKit
import Carbon

struct ToolManager {
    
    func execute(toolName: String, args: ToolArguments) {
        switch toolName {
        case "type":
            if case .text(let text) = args {
                typeString(text)
            }
        case "open_app":
            if case .text(let target) = args {
                openAppOrURL(target)
            }
        case "switch_to":
            if case .text(let appName) = args {
                switchToApp(appName)
            }
        default:
            print("Unknown tool: \(toolName)")
        }
    }
    
    private func typeString(_ string: String) {
        // Using CGEvent to simulate keystrokes
        let source = CGEventSource(stateID: .hidSystemState)
        
        for char in string {
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                // We need to map char to keycode or use unicodeString
                var uniChar = Array(String(char).utf16)
                event.keyboardSetUnicodeString(stringLength: uniChar.count, unicodeString: &uniChar)
                event.post(tap: .cghidEventTap)
                
                if let upEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                    upEvent.keyboardSetUnicodeString(stringLength: uniChar.count, unicodeString: &uniChar)
                    upEvent.post(tap: .cghidEventTap)
                }
            }
        }
    }
    
    private func openAppOrURL(_ target: String) {
        if let url = URL(string: target), (target.hasPrefix("http") || target.hasPrefix("https")) {
            NSWorkspace.shared.open(url)
        } else {
            // Try to launch app by name
            // Simple attempt:
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) {
                NSWorkspace.shared.open(appURL)
            } else {
                // Fallback: use shell open
                let process = Process()
                process.launchPath = "/usr/bin/open"
                process.arguments = ["-a", target]
                process.launch()
            }
        }
    }
    
    private func switchToApp(_ name: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let appName = app.localizedName, appName.lowercased().contains(name.lowercased()) {
                app.activate()
                return
            }
        }
    }
}
