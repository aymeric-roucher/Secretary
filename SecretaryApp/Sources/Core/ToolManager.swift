import Foundation
import AppKit
import Carbon
import ApplicationServices

struct ToolManager {

    func execute(toolName: String, args: ToolArguments) {
        do {
            switch toolName {
            case "type":
                if case .text(let text) = args {
                    typeString(text)
                }
            case "open_app":
                if case .text(let target) = args {
                    try openAppOrURL(target)
                }
            case "switch_to":
                if case .text(let appName) = args {
                    try switchToApp(appName)
                }
            case "deep_research":
                if case .text(let topic) = args {
                    deepResearch(topic)
                }
            case "spotify":
                if case .text(let action) = args {
                    try spotifyControl(action)
                }
            default:
                throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown tool"])
            }
        } catch {
            handleToolError(toolName: toolName, error: error)
        }
    }

    private func handleToolError(toolName: String, error: Error) {
        let errorMessage = "Tool '\(toolName)' failed: \(error.localizedDescription)"
        log("Tool execution error: \(errorMessage)")

        Task { @MainActor in
            let errorMsg = ChatMessage(role: .system, content: errorMessage)
            AppState.shared?.messages.append(errorMsg)
        }
    }
    
    private func typeString(_ string: String) {
        let pasteboard = NSPasteboard.general
        Task { @MainActor in
            AppState.shared?.popupClipboardMessage = nil
        }

        if shouldFallbackToClipboard() {
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)

            Task { @MainActor in
                AppState.shared?.popupClipboardMessage = "Content pasted to clipboard"
                let notice = ChatMessage(role: .system, content: "Content pasted to clipboard")
                AppState.shared?.messages.append(notice)
            }
            log("No focused text input detected. Copied content to clipboard.")
            return
        }

        // Save current clipboard content
        let previousContents = pasteboard.string(forType: .string)

        // Set the text to paste
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        // Simulate Cmd+V to paste
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9 // 'v' key

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        // Restore previous clipboard content after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func shouldFallbackToClipboard() -> Bool {
        guard AXIsProcessTrusted() else {
            log("Accessibility permissions missing; proceeding with normal typing.")
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard focusedStatus == .success, let element = focusedElement else {
            return true
        }

        let axElement = element as! AXUIElement
        var roleValue: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)

        guard roleStatus == .success, let role = roleValue as? String else {
            return true
        }

        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField",
            "AXWebArea"
        ]

        if textRoles.contains(role) {
            return false
        }

        var isValueSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isValueSettable) == .success && isValueSettable.boolValue {
            return false
        }

        return true
    }
    
    private func openAppOrURL(_ target: String) throws {
        // Check if target looks like a URL
        let isURL = target.contains(".") && (
            target.hasPrefix("http://") ||
            target.hasPrefix("https://") ||
            target.hasPrefix("www.") ||
            target.range(of: #"^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}"#, options: .regularExpression) != nil
        )

        if isURL {
            // It's a URL - open in default browser
            var urlString = target
            if !target.hasPrefix("http://") && !target.hasPrefix("https://") {
                urlString = "https://" + target
            }
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(target)"])
            }
            NSWorkspace.shared.open(url)
        } else {
            // Try to launch app by name
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) {
                NSWorkspace.shared.open(appURL)
            } else {
                // Fallback: use shell open
                let process = Process()
                process.launchPath = "/usr/bin/open"
                process.arguments = ["-a", target]
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus != 0 {
                        throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not open app: \(target)"])
                    }
                } catch {
                    throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to open app: \(target)"])
                }
            }
        }
    }
    
    private func switchToApp(_ name: String) throws {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let appName = app.localizedName, appName.lowercased().contains(name.lowercased()) {
                app.activate()
                return
            }
        }
        throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No running app found: \(name)"])
    }
    
    private func deepResearch(_ topic: String) {
        // Simple implementation: open a web search for the topic
        let query = topic.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? topic
        if let url = URL(string: "https://www.google.com/search?q=\(query)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func spotifyControl(_ action: String) throws {
        let command: String
        switch action.lowercased() {
        case "play":
            command = "tell application \"Spotify\" to play"
        case "pause":
            command = "tell application \"Spotify\" to pause"
        case "next":
            command = "tell application \"Spotify\" to next track"
        default:
            throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Spotify action: \(action). Use play, pause, or next."])
        }

        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", command]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "ToolManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to control Spotify"])
        }
    }
}

enum ToolArguments: Codable {
    case text(String)
    case none
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .text(x)
            return
        }
        if let x = try? container.decode([String:String].self) {
            // Handle dictionary args if complex, for now simplify
            if let val = x.values.first {
                self = .text(val)
                return
            }
        }
        self = .none
    }
    
    func encode(to encoder: Encoder) throws {}
}
