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

        // Check focus state: .yes = text area focused, .no = no text area, .unknown = check failed
        let focusState = checkFocusedTextArea()
        log("Focus state: \(focusState)")

        if focusState == .no {
            // We know for sure there's no text area - copy to clipboard
            log("No focused text area detected - copying to clipboard")
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
            Task { @MainActor in
                AppState.shared?.popupClipboardMessage = "Content copied to clipboard"
            }
            return
        }

        // Either we have focus (.yes) or check failed (.unknown) - try to paste
        let previousContents = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private enum FocusState { case yes, no, unknown }

    private func checkFocusedTextArea() -> FocusState {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard status == .success, let element = focusedElement else {
            log("checkFocusedTextArea: failed to get focused element (status: \(status.rawValue))")
            return .unknown
        }

        let axElement = element as! AXUIElement
        var roleValue: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)

        guard roleStatus == .success, let role = roleValue as? String else {
            log("checkFocusedTextArea: failed to get role")
            return .unknown
        }

        log("checkFocusedTextArea: focused element role = \(role)")

        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
            "AXSearchField",
            "AXWebArea"
        ]

        if textRoles.contains(role) {
            return .yes
        }

        var isValueSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &isValueSettable) == .success && isValueSettable.boolValue {
            return .yes
        }

        return .no
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
