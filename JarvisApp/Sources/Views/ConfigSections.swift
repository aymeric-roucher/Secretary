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
    var onValidate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Keys")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Button("Check APIs") { onValidate() }
                    .buttonStyle(.bordered)
            }
            HStack {
                SecureField("OpenAI API Key", text: $openaiKey)
                    .onChange(of: openaiKey) { _, _ in openaiStatus = .none }
                StatusIcon(status: openaiStatus)
            }
            HStack {
                SecureField("Hugging Face Token", text: $hfKey)
                    .onChange(of: hfKey) { _, _ in hfStatus = .none }
                StatusIcon(status: hfStatus)
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
            Text("Permissions")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
            HStack {
                Image(systemName: "mic.fill")
                Text("Microphone")
                Spacer()
                StatusIcon(status: micStatus)
                Button("Request") { requestMic() }
                    .disabled(micStatus == .valid)
            }
            HStack {
                Image(systemName: "keyboard.fill")
                Text("Accessibility (Typing)")
                Spacer()
                StatusIcon(status: accessStatus)
                Button("Check") { checkAccess() }
            }
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
    static func validate(openaiKey: String, hfKey: String) async -> (ApiValidationResult, ApiValidationResult) {
        async let openaiResult: ApiValidationResult = {
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
        }()
        
        async let hfResult: ApiValidationResult = {
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
        }()
        
        return await (openaiResult, hfResult)
    }
}
