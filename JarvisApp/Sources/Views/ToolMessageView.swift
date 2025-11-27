import SwiftUI

struct ToolMessageView: View {
    var role: MessageRole
    var content: String
    var toolName: String?

    private var iconName: String {
        switch role {
        case .tool: return Theme.toolIcon(for: toolName)
        case .user: return "waveform"
        case .assistant, .system: return "info.circle.fill"
        }
    }

    private var messageBackgroundColor: Color {
        switch role {
        case .tool: return .indigo
        case .user: return .blue
        case .assistant, .system: return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(.secondary)
            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(messageBackgroundColor.opacity(0.08))
        .cornerRadius(10)
    }
}
