import Foundation

struct LLMService {
    static let defaultModel = "gemma3:4b"
    static let defaultModels = ["gemma3:4b", "gemma3:12b", "gemma3:27b"]
    static let selectedModelKey = "StylometrySanitizer.SelectedModel"

    static func preferredModel() -> String {
        UserDefaults.standard.string(forKey: selectedModelKey) ?? defaultModel
    }

    static func savePreferredModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: selectedModelKey)
    }

    static func fetchAvailableModels() async throws -> [String] {
        let url = URL(string: "http://localhost:11434/api/models")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try parseModels(from: data)
    }

    static func rewrite(text: String, model: String = defaultModel) async throws -> String {
        let prompt = """
        Rewrite the following text in a more stylistically neutral and less personally distinctive manner.

        Requirements:
        - Preserve the original meaning, factual content, and level of detail.
        - Maintain approximately the same length as the original text.
        - Keep the writing natural, fluent, and human-sounding.
        - Reduce highly distinctive phrasing, emotional exaggeration, slang, unusual punctuation, and strongly personal stylistic quirks.
        - Normalize sentence structure and vocabulary toward a more common, broadly typical writing style.
        - Do not summarize, compress, or omit important details.
        - Do not make the writing sound robotic, legalistic, passive, or machine-generated.
        - Avoid dramatic or poetic phrasing, but preserve readability and coherence.

        Return only the rewritten text.

        \(text)
        """

        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
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

    private static func parseModels(from data: Data) throws -> [String] {
        let decoder = JSONDecoder()

        if let response = try? decoder.decode(OllamaModelsResponse.self, from: data) {
            return response.models.map { $0.id }
        }

        if let models = try? decoder.decode([OllamaModel].self, from: data) {
            return models.map { $0.id }
        }

        let json = try JSONSerialization.jsonObject(with: data)
        if let array = json as? [String] {
            return array
        }

        if let root = json as? [String: Any], let models = root["models"] as? [[String: Any]] {
            return models.compactMap { $0["id"] as? String }
        }

        return []
    }
}

struct OllamaResponse: Codable {
    let response: String
}

private struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]
}

private struct OllamaModel: Decodable {
    let id: String
}
