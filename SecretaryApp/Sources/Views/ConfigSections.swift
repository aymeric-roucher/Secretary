import SwiftUI
import AVFoundation
import ApplicationServices

enum ValidationStatus {
    case none, checking, valid, invalid
    
    var icon: String {
        switch self {
        case .none: return "circle"
        case .checking: return "hourglass"
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .gray
        case .checking: return .yellow
        case .valid: return .green
        case .invalid: return .red
        }
    }
}

struct ApiKeysSection: View {
    @Binding var openaiKey: String
    @Binding var hfKey: String
    @Binding var openaiStatus: ValidationStatus
    @Binding var hfStatus: ValidationStatus
    var onApiKeysValidate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Keys").font(Theme.headingFont).foregroundColor(Theme.textColor)
                Spacer()
                Button("Check APIs") { onApiKeysValidate() }.buttonStyle(ThemeButtonStyle())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI API Key").font(Theme.smallFont).foregroundColor(Theme.secondaryText)
                HStack {
                    SecureField("sk-...", text: $openaiKey)
                        .textFieldStyle(.plain)
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textColor)
                        .padding(10)
                        .background(Theme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
                        .onChange(of: openaiKey) { _, _ in openaiStatus = .none }
                    StatusIcon(status: openaiStatus)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hugging Face Token").font(Theme.smallFont).foregroundColor(Theme.secondaryText)
                HStack {
                    SecureField("hf_...", text: $hfKey)
                        .textFieldStyle(.plain)
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textColor)
                        .padding(10)
                        .background(Theme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
                        .onChange(of: hfKey) { _, _ in hfStatus = .none }
                    StatusIcon(status: hfStatus)
                }
            }
        }
    }
}

struct PermissionsSection: View {
    @Binding var micStatus: ValidationStatus
    @Binding var accessStatus: ValidationStatus
    var requestMic: () -> Void
    var checkAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions").font(Theme.headingFont).foregroundColor(Theme.textColor)

            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textColor)
                    .frame(width: 20)
                Text("Microphone").font(Theme.bodyFont).foregroundColor(Theme.textColor)
                Spacer()
                StatusIcon(status: micStatus)
                Button("Request") { requestMic() }
                    .buttonStyle(ThemeButtonStyle(disabled: micStatus == .valid))
                    .disabled(micStatus == .valid)
            }
            .padding(12)
            .background(Theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))

            HStack {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textColor)
                    .frame(width: 20)
                Text("Accessibility (Typing)").font(Theme.bodyFont).foregroundColor(Theme.textColor)
                Spacer()
                StatusIcon(status: accessStatus)
                Button("Check") { checkAccess() }.buttonStyle(ThemeButtonStyle())
            }
            .padding(12)
            .background(Theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
        }
    }
}

struct StatusIcon: View {
    var status: ValidationStatus
    
    var body: some View {
        Image(systemName: status.icon)
            .foregroundColor(status.color)
    }
}

enum ApiValidationResult {
    case valid
    case invalid
}

struct LanguageSelectionSection: View {
    @ObservedObject var store: LanguageStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Languages").font(Theme.headingFont).foregroundColor(Theme.textColor)
            Text("Select languages you speak. Whisper will auto-detect between them.")
                .font(Theme.smallFont)
                .foregroundColor(Theme.secondaryText)

            // Selected languages as chips
            if !store.selectedLanguages.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(store.selectedLanguages) { language in
                        LanguageChip(language: language) {
                            store.remove(language)
                        }
                    }
                }
            }

            // Search field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                TextField("Type to add a language...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textColor)
                    .padding(10)
                    .background(Theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
                    .focused($isSearchFocused)

                // Suggestions dropdown
                if !searchText.isEmpty && !filteredLanguages.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredLanguages.prefix(6), id: \.code) { language in
                            Button {
                                store.add(language)
                                searchText = ""
                            } label: {
                                Text(language.name)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.clear)
                            }
                            .buttonStyle(.plain)
                            .background(Color.clear)
                            .contentShape(Rectangle())
                            .onHover { hovering in }
                        }
                    }
                    .background(Theme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius).stroke(Theme.borderColor, lineWidth: 1))
                    .padding(.top, 4)
                }
            }
        }
    }

    private var filteredLanguages: [Language] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return Language.allLanguages.filter { lang in
            !store.selectedLanguages.contains(where: { $0.code == lang.code }) &&
            lang.name.lowercased().hasPrefix(query)
        }
    }
}

struct LanguageChip: View {
    let language: Language
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(language.name)
                .font(Theme.smallFont)
                .foregroundColor(Theme.textColor)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.inputBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.borderColor, lineWidth: 1))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

enum ApiValidator {
    static func validateOpenAI(openaiKey: String) async -> ApiValidationResult {
        guard !openaiKey.isEmpty else { return .invalid }
        let url = URL(string: "https://api.openai.com/v1/models")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(openaiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                return .valid
            }
        } catch { }
        return .invalid
    }
    
    static func validateHF(hfKey: String) async -> ApiValidationResult {
        guard !hfKey.isEmpty else { return .invalid }
        let url = URL(string: "https://huggingface.co/api/whoami-v2")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(hfKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                return .valid
            }
        } catch { }
        return .invalid
    }
}
