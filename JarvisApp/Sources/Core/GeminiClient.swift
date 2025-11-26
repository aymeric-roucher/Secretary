import Foundation

struct GeminiClient {
    let apiKey: String
    
    func transcribeAudio(fileURL: URL) async throws -> String {
        let mimeType = "audio/m4a" // Assuming m4a from AudioRecorder
        let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let fileData = try Data(contentsOf: fileURL)
        
        // 1. Start Resumable Upload
        let uploadURL = try await startUpload(mimeType: mimeType, fileSize: fileSize)
        
        // 2. Upload Bytes
        let fileURI = try await uploadBytes(uploadURL: uploadURL, data: fileData)
        
        // 3. Generate Content
        let text = try await generateContent(fileURI: fileURI, mimeType: mimeType)
        return text
    }
    
    private func startUpload(mimeType: String, fileSize: Int) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue("resumable", forHTTPHeaderField: "X-Goog-Upload-Protocol")
        request.addValue("start", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.addValue("\(fileSize)", forHTTPHeaderField: "X-Goog-Upload-Header-Content-Length")
        request.addValue(mimeType, forHTTPHeaderField: "X-Goog-Upload-Header-Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let metadata = ["file": ["display_name": "audio_recording"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              let uploadUrlString = httpResponse.value(forHTTPHeaderField: "x-goog-upload-url") else {
            throw URLError(.badServerResponse)
        }
        
        return uploadUrlString
    }
    
    private func uploadBytes(uploadURL: String, data: Data) async throws -> String {
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        request.addValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.addValue("0", forHTTPHeaderField: "X-Goog-Upload-Offset")
        request.addValue("upload, finalize", forHTTPHeaderField: "X-Goog-Upload-Command")
        request.httpBody = data
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        guard let fileInfo = json?["file"] as? [String: Any],
              let uri = fileInfo["uri"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        return uri
    }
    
    private func generateContent(fileURI: String, mimeType: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": "Describe this audio clip"],
                    ["file_data": ["mime_type": mimeType, "file_uri": fileURI]]
                ]
            ]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse response for text
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }
        
        return "Error: No text found"
    }
}
