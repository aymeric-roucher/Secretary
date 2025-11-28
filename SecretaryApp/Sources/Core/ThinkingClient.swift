import Foundation

struct ThinkingClient {
    let apiKey: String

    func processCommand(input: String, defaultBrowser: String, openAppsDescription: String, installedAppsDescription: String, dictionaryEntries: [DictionaryEntry], styleExamples: String) async throws -> ToolCallResponse? {
        let url = URL(string: "https://router.huggingface.co/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var systemPrompt = """
        You are a scribe for macOS. The user has provided vocal guidance. You have to do one of two things:
        1. By default, what they want is to type what they've said.
        2. In the very specific case that their text says to perform a command like "open app" or "switch to app" or "deep research", execute it instead, ONLY if that command is extremely clearly precised and exactly matches one of the tools ; if unclear, just type what they said.
        In NO case should you answer to what they say or ask clarification. You either transcribe or execute.
        Output ONLY valid JSON with keys: "tool_name", "tool_arguments".
        Tools available:
        - type(text: String): Type text into active window.
        - open_app(name_or_url: String): Open app or URL. FYI, if mentioning a url or website, open the default browser "\(defaultBrowser)". Else, this command should only be executed if the app mentioned is one of the installed apps: <installed_apps>\(installedAppsDescription)</installed_apps>.
        - switch_to(app_name: String): Switch focus to app. Currently open apps: \(openAppsDescription).
        - deep_research(topic: String): Research a topic.
        """

        if !dictionaryEntries.isEmpty {
            var dictionarySection = "\n\nDictionary - Use these when transcribing:"
            for entry in dictionaryEntries {
                if entry.kind == .word {
                    dictionarySection += "\n- Keep word as-is: \"\(entry.input)\""
                } else if let output = entry.output {
                    dictionarySection += "\n- Replace \"\(entry.input)\" with \"\(output)\""
                }
            }
            systemPrompt += dictionarySection
        }

        let trimmedStyle = styleExamples.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedStyle.isEmpty {
            systemPrompt += "\n\nWriting style examples - Match this style when transcribing:\n\(trimmedStyle)"
        }
        
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
    let tool_name: String
    let tool_arguments: ToolArguments
}
