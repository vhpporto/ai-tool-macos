import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let content: String
}

final class OpenAIService: @unchecked Sendable {

    static let shared = OpenAIService()
    private init() {}

    private var endpoint: URL {
        let base = UserDefaults.standard.string(forKey: "aura_custom_endpoint")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !base.isEmpty, let url = URL(string: base) { return url }
        return URL(string: "https://api.openai.com/v1/chat/completions")!
    }

    static let devSystemPrompt = """
    Você é um assistente de engenharia de software rodando dentro de um launcher macOS para desenvolvedores. \
    Responda sempre em português do Brasil (pt-BR).

    Regras:
    - Sempre use code blocks markdown com a linguagem correta (bash, swift, python, sql, etc.)
    - Comandos de terminal sempre em blocos ```bash — nunca em texto puro
    - Seja extremamente direto. Sem introduções, sem explicações do que vai fazer, sem frases de fechamento
    - Prefira um exemplo funcionando a uma explicação longa
    - Se pedirem um comando, dê só o comando. Se contexto ajudar, adicione um comentário de uma linha dentro do bloco
    - Assuma macOS + zsh a menos que dito o contrário
    - Para git, docker, kubectl, npm, brew, curl, etc. — use sintaxe moderna e idiomática
    - Nunca adicione "Espero ter ajudado", "Qualquer dúvida é só perguntar" ou similares
    - Se ambíguo, use o caso de uso mais comum para desenvolvedores
    """

    static let generalSystemPrompt = """
    Você é um assistente prestativo e conciso rodando dentro de um launcher macOS. \
    Responda sempre em português do Brasil (pt-BR).

    Regras:
    - Seja direto e claro, sem enrolação
    - Use markdown quando ajudar a organizar a resposta
    - Sem frases de abertura desnecessárias ("Claro!", "Com certeza!", etc.)
    - Sem frases de fechamento ("Espero ter ajudado", "Qualquer dúvida...")
    - Respostas curtas quando possível, detalhadas apenas quando necessário
    """

    static let defaultSystemPrompt = devSystemPrompt

    func streamMessage(
        messages: [ChatMessage],
        systemPrompt: String = defaultSystemPrompt,
        model: String = "gpt-4o",
        onToken: @escaping @MainActor (String) -> Void,
        onComplete: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) async {
        let apiKey = KeychainHelper.read(key: "openai_api_key") ?? ""
        let hasCustomEndpoint = !(UserDefaults.standard.string(forKey: "aura_custom_endpoint") ?? "").isEmpty
        guard !apiKey.isEmpty || hasCustomEndpoint else {
            await MainActor.run { onError(OpenAIError.missingAPIKey) }
            return
        }

        var body: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in messages {
            body.append(["role": msg.role, "content": msg.content])
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": body,
            "stream": true
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        request.timeoutInterval = 30

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let error: OpenAIError = switch http.statusCode {
                case 401: .invalidAPIKey
                case 429: .rateLimited
                default: .httpError(http.statusCode)
                }
                await MainActor.run { onError(error) }
                return
            }

            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String
                else { continue }

                await MainActor.run { onToken(content) }
            }

            await MainActor.run { onComplete() }

        } catch let urlError as URLError where urlError.code == .timedOut {
            await MainActor.run { onError(OpenAIError.timeout) }
        } catch {
            await MainActor.run { onError(error) }
        }
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case timeout
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "API Key não configurada. Abra as Settings para adicionar."
        case .invalidAPIKey: "API Key inválida. Verifique a chave nas Settings."
        case .rateLimited: "Rate limit atingido. Aguarde um momento."
        case .timeout: "Conexão expirou. Verifique sua internet ou o endpoint."
        case .httpError(let code): "Erro HTTP \(code)."
        }
    }
}
