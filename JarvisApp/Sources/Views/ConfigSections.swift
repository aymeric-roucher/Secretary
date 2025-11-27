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
