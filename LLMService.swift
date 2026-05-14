import Foundation

struct OllamaCatalogEntry: Hashable, Identifiable {
    let name: String
    let sizes: [String]

    var id: String { name }

    var displayName: String {
        sizes.isEmpty ? name : "\(name) (\(sizes.joined(separator: ", ")))"
    }
}

struct LLMService {
    static let defaultModel = "gemma3:4b"
    static let defaultModels = ["gemma3:4b", "gemma3:12b", "gemma3:27b"]
    static let fallbackDownloadModels = [
        OllamaCatalogEntry(name: "gemma3", sizes: ["1b", "4b", "12b", "27b"]),
        OllamaCatalogEntry(name: "qwen3", sizes: ["0.6b", "1.7b", "4b", "8b", "14b", "32b"]),
        OllamaCatalogEntry(name: "llama3.2", sizes: ["1b", "3b"]),
        OllamaCatalogEntry(name: "phi4", sizes: ["14b"]),
        OllamaCatalogEntry(name: "mistral", sizes: ["7b"]),
        OllamaCatalogEntry(name: "deepseek-r1", sizes: ["1.5b", "7b", "8b", "14b", "32b", "70b", "671b"])
    ]
    static let selectedModelKey = "StylometrySanitizer.SelectedModel"

    static func preferredModel() -> String {
        UserDefaults.standard.string(forKey: selectedModelKey) ?? defaultModel
    }

    static func savePreferredModel(_ model: String) {
        UserDefaults.standard.set(model, forKey: selectedModelKey)
    }

    static func fetchAvailableModels() async throws -> [String] {
        let url = URL(string: "http://localhost:11434/api/tags")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try parseModels(from: data)
    }

    static func fetchOllamaCatalogModels() async throws -> [OllamaCatalogEntry] {
        let urls = [
            URL(string: "https://ollama.com/search")!,
            URL(string: "https://ollama.com/search?sort=newest")!
        ]
        var catalogModels: [OllamaCatalogEntry] = []

        for url in urls {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                continue
            }

            catalogModels.append(contentsOf: parseOllamaCatalogModels(from: data))
        }

        var seen = Set<String>()
        return catalogModels.filter { entry in
            guard !seen.contains(entry.name) else { return false }
            seen.insert(entry.name)
            return true
        }
    }

    static func installModel(named model: String) async throws -> String {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "LLMService", code: 1, userInfo:[NSLocalizedDescriptionKey: "Model name cannot be empty."])
        }

        return try await Task.detached { () throws -> String in
            let executable = try ollamaExecutableURL()
            let process = Process()
            process.executableURL = executable
            process.arguments = ["pull", trimmed]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8) ?? ""

            if process.terminationStatus != 0 {
                let message = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
                throw NSError(domain: "LLMService", code: Int(process.terminationStatus), userInfo:[NSLocalizedDescriptionKey: message.isEmpty ? "ollama pull failed" : message])
            }

            return stdout.isEmpty ? stderr : stdout
        }.value
    }

    private static func ollamaExecutableURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
            "/usr/bin/ollama",
            "/bin/ollama"
        ]

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.components(separatedBy: ":") {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("ollama").path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        throw NSError(domain: "LLMService", code: 2, userInfo:[NSLocalizedDescriptionKey: "Could not find the ollama executable on PATH."])
    }

    static func rewrite(text: String, model: String = defaultModel) async throws -> String {
        let prompt = """
        Rewrite the following text in a more stylistically neutral and less personally distinctive manner.

        Requirements:
        - Rewrite the text sentence by sentence to preserve depth, detail, and meaning.
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
            return response.models.compactMap { $0.displayName }
        }

        if let models = try? decoder.decode([OllamaModel].self, from: data) {
            return models.compactMap { $0.displayName }
        }

        let json = try JSONSerialization.jsonObject(with: data)
        if let array = json as? [String] {
            return array
        }

        if let root = json as? [String: Any], let models = root["models"] as? [[String: Any]] {
            return models.compactMap {
                ($0["name"] as? String) ?? ($0["model"] as? String) ?? ($0["id"] as? String)
            }
        }

        return []
    }

    private static func parseOllamaCatalogModels(from data: Data) -> [OllamaCatalogEntry] {
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        let pattern = ##"href="/library/([^"#?]+)"[^>]*>(.*?)</a>"##

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        return regex.matches(in: html, range: range).compactMap { match in
            guard let modelRange = Range(match.range(at: 1), in: html) else { return nil }
            let model = String(html[modelRange]).removingPercentEncoding ?? String(html[modelRange])
            guard !model.contains("/") else { return nil }

            let bodyRange = Range(match.range(at: 2), in: html)
            let body = bodyRange.map { String(html[$0]) } ?? ""
            return OllamaCatalogEntry(name: model, sizes: parseParameterSizes(from: body))
        }
    }

    private static func parseParameterSizes(from text: String) -> [String] {
        let pattern = #"(?i)\b(?:\d+(?:\.\d+)?|e\d+)[bm]\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let sizes = regex.matches(in: text, range: range).compactMap { match -> String? in
            guard let sizeRange = Range(match.range, in: text) else { return nil }
            return String(text[sizeRange]).lowercased()
        }

        var seen = Set<String>()
        return sizes.filter { size in
            guard !seen.contains(size) else { return false }
            seen.insert(size)
            return true
        }
    }
}

struct OllamaResponse: Codable {
    let response: String
}

private struct OllamaModelsResponse: Decodable {
    let models: [OllamaModel]
}

private struct OllamaModel: Decodable {
    let name: String?
    let model: String?
    let id: String?

    var displayName: String? {
        name ?? model ?? id
    }
}
