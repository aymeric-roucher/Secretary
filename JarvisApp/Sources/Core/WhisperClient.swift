import Foundation

struct WhisperClient {
    let apiKey: String
    let model: String
    
    init(apiKey: String, model: String = "whisper-1") {
        self.apiKey = apiKey
        self.model = model
    }
    
    func transcribe(fileURL: URL) async throws -> String {
        let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let body = try makeMultipartBody(fileURL: fileURL, boundary: boundary)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "WhisperClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let text = json?["text"] as? String {
            return text
        }
        throw NSError(domain: "WhisperClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in response"])
    }
    
    private func makeMultipartBody(fileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        func appendField(name: String, value: String) {
            body.append("--\(boundary)\(lineBreak)")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
            body.append("\(value)\(lineBreak)")
        }
        
        appendField(name: "model", value: model)
        
        let filename = fileURL.lastPathComponent
        let mimeType = mimeTypeFor(fileExtension: fileURL.pathExtension)
        let fileData = try Data(contentsOf: fileURL)
        
        body.append("--\(boundary)\(lineBreak)")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(lineBreak)")
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        body.append(fileData)
        body.append(lineBreak)
        
        body.append("--\(boundary)--\(lineBreak)")
        return body
    }
    
    private func mimeTypeFor(fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "mp4": return "audio/mp4"
        case "mpeg", "mpg": return "audio/mpeg"
        case "mpga": return "audio/mpeg"
        case "m4a": return "audio/m4a"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        default: return "application/octet-stream"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
