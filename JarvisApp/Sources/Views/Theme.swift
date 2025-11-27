import SwiftUI

// MARK: - Theme Constants
enum Theme {
    // MARK: Fonts
    static let titleFont = Font.custom("Georgia", size: 28).weight(.bold)
    static let headingFont = Font.custom("Georgia", size: 16).weight(.semibold)
    static let bodyFont = Font.custom("Georgia", size: 14)
    static let smallFont = Font.custom("Georgia", size: 13)
    static let captionFont = Font.custom("Georgia", size: 11).weight(.bold)

    // MARK: Colors
    static let background = Color.white
    static let sidebarBackground = Color(white: 0.97)
    static let inputBackground = Color(white: 0.97)
    static let buttonBackground = Color(white: 0.93)
    static let borderColor = Color(white: 0.85)
    static let buttonBorder = Color(white: 0.75)
    static let dividerColor = Color(white: 0.75)
    static let textColor = Color.black
    static let secondaryText = Color.gray

    // MARK: Dimensions
    static let cornerRadius: CGFloat = 12

    // MARK: Tool Icons
    static let toolIcons: [String: String] = [
        "type": "rectangle.and.pencil.and.ellipsis",
        "deep_research": "magnifyingglass",
        "open_app": "desktopcomputer",
        "switch_to": "arrow.triangle.2.circlepath"
    ]

    // MARK: App Icons
    static let appIcons: [String: String] = [
        // Browsers
        "safari": "safari",
        "google chrome": "globe",
        "firefox": "flame",
        "arc": "globe",
        "brave browser": "shield",
        "desk browser": "chevron.left.forwardslash.chevron.right",
        // Communication
        "mail": "envelope",
        "outlook": "envelope",
        "microsoft outlook": "envelope",
        "messages": "message",
        "slack": "number",
        "discord": "bubble.left.and.bubble.right",
        "zoom": "video",
        "facetime": "video",
        "teams": "person.3",
        "microsoft teams": "person.3",
        "telegram": "paperplane",
        "whatsapp": "phone.bubble",
        // Productivity
        "notes": "note.text",
        "reminders": "checklist",
        "calendar": "calendar",
        "contacts": "person.crop.rectangle.stack",
        "finder": "folder",
        "preview": "doc",
        "pages": "doc.richtext",
        "numbers": "tablecells",
        "keynote": "play.rectangle",
        "microsoft word": "doc.richtext",
        "microsoft excel": "tablecells",
        "microsoft powerpoint": "play.rectangle",
        "notion": "doc.text",
        "obsidian": "link",
        "bear": "note.text",
        "evernote": "elephant",
        // Development
        "xcode": "hammer",
        "visual studio code": "chevron.left.forwardslash.chevron.right",
        "terminal": "terminal",
        "iterm": "terminal",
        "github desktop": "arrow.triangle.branch",
        "sublime text": "chevron.left.forwardslash.chevron.right",
        "cursor": "chevron.left.forwardslash.chevron.right",
        // Media
        "music": "music.note",
        "spotify": "music.note",
        "apple music": "music.note",
        "photos": "photo",
        "tv": "tv",
        "podcasts": "mic",
        "books": "book",
        "vlc": "play.circle",
        "quicktime player": "play.rectangle",
        // Utilities
        "system preferences": "gearshape",
        "system settings": "gearshape",
        "app store": "bag",
        "activity monitor": "chart.bar",
        "disk utility": "internaldrive",
        "calculator": "plus.forwardslash.minus",
        "clock": "clock",
        "weather": "cloud.sun",
        "maps": "map",
        // Creative
        "figma": "pencil.and.ruler",
        "sketch": "pencil.tip",
        "photoshop": "photo.artframe",
        "illustrator": "paintbrush",
        "final cut pro": "film",
        "logic pro": "waveform",
        "garageband": "pianokeys",
        // Other
        "1password": "key",
        "bitwarden": "key",
        "docker": "shippingbox",
        "postman": "paperplane",
        "insomnia": "moon"
    ]

    // MARK: Icon Functions
    static func toolIcon(for name: String?) -> String {
        toolIcons[name ?? ""] ?? "hammer.fill"
    }

    static func appIcon(for appName: String?) -> String {
        guard let app = appName?.lowercased() else { return "desktopcomputer" }
        return appIcons[app] ?? "desktopcomputer"
    }

    static func iconForTool(name: String?, arguments: String?) -> String {
        log("iconForTool called - name: \(name ?? "nil"), arguments: \(arguments ?? "nil")")
        if name == "open_app", let args = arguments,
           let data = args.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let appName = json["app_name"] as? String {
            let icon = appIcon(for: appName)
            log("iconForTool - matched app: \(appName) -> icon: \(icon)")
            return icon
        }
        let icon = toolIcon(for: name)
        log("iconForTool - using toolIcon for name: \(name ?? "nil") -> icon: \(icon)")
        return icon
    }
}

// MARK: - Reusable Button Styles
struct ThemeButtonStyle: ButtonStyle {
    var disabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.smallFont)
            .foregroundColor(disabled ? Theme.secondaryText : Theme.textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Theme.borderColor : Theme.buttonBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.borderColor, lineWidth: 1))
    }
}

struct ThemePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.bodyFont.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color(white: 0.2) : Theme.textColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.borderColor, lineWidth: 1))
    }
}

// MARK: - Themed Input Components
struct ThemedTextField: View {
    var placeholder: String
    @Binding var text: String
    var font: Font = Theme.bodyFont

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundColor(Theme.textColor)
            .padding(10)
            .background(Theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
    }
}

struct ThemedTextArea: View {
    var placeholder: String
    @Binding var text: String
    var height: CGFloat = 80
    var font: Font = Theme.bodyFont

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(Theme.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(font)
                .foregroundColor(Theme.textColor)
                .padding(8)
                .scrollContentBackground(.hidden)
        }
        .background(Theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
        .frame(height: height)
    }
}

// MARK: - Themed Container
struct ThemedBox<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(Theme.sidebarBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
    }
}