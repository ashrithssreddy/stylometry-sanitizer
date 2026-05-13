import Foundation

struct LLMService {
    static func rewrite(text: String) async throws -> String {
        let prompt = """
        Rewrite the following text in a neutral, impersonal tone. Remove any slang, emotional language, unique phrasing, varied sentence lengths, and other stylometric markers that could identify the author. Provide only the rewritten text without any additional comments or options:

        \(text)
        """

        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gemma3:4b",  // Small model
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let ollamaResponse = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return ollamaResponse.response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OllamaResponse: Codable {
    let response: String
}