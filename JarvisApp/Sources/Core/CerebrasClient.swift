import Foundation

struct CerebrasClient {
    let apiKey: String
    
    func processCommand(input: String, defaultBrowser: String, openAppsDescription: String) async throws -> ToolCallResponse? {
        let url = URL(string: "https://router.huggingface.co/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are a system assistant for macOS. The user has provided vocal guidance.
        By default, what they want is to type what they've said. But they can also ask you to perform commands.
        Output ONLY valid JSON with keys: "thought", "tool_name", "tool_arguments".
        Tools available:
        - type(text: String): Type text into active window.
        - open_app(name_or_url: String): Open app or URL. Default browser is "\(defaultBrowser)".
        - switch_to(app_name: String): Switch focus to app. Currently open apps: \(openAppsDescription).
        - deep_research(topic: String): Research a topic.
        """
        
        let body: [String: Any] = [
            "model": "Qwen/Qwen3-235B-A22B-Instruct-2507:cerebras",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ],
            "max_tokens": 500
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse response
        // For simplicity, we assume the model adheres to JSON output or we try to extract it.
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            // Helper to extract JSON from markdown block if present
            let cleanContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
            
            if let data = cleanContent.data(using: .utf8),
               let responseObj = try? JSONDecoder().decode(ToolCallResponse.self, from: data) {
                return responseObj
            }
        }
        return nil
    }
}

struct ToolCallResponse: Codable {
    let thought: String?
    let tool_name: String
    let tool_arguments: ToolArguments
}
