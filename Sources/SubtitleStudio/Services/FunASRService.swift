import Foundation

enum FunASRError: LocalizedError {
    case invalidURL(String)
    case requestFailed(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "无效的 API 地址：\(url)"
        case .requestFailed(415, let msg):
            return "请求失败 (415)：FunASR 服务没有收到正确的音频格式。原始响应：\(msg)"
        case .requestFailed(404, let msg):
            return "请求失败 (404)：找不到 /v1/audio/transcriptions，请确认已启动 funasr-server。原始响应：\(msg)"
        case .requestFailed(let code, let msg): return "请求失败 (\(code))：\(msg)"
        case .decodingFailed(let msg): return "响应解析失败：\(msg)"
        }
    }
}

struct FunASRService {
    let baseURL: String
    let model: String

    private func endpoint(_ path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)\(path)") else {
            throw FunASRError.invalidURL(baseURL)
        }
        return url
    }

    func transcribe(wavData: Data, fileName: String, language: String?) async throws -> TranscriptionResponse {
        let url = try endpoint("/audio/transcriptions")
        let boundary = "Boundary-\(UUID().uuidString)"

        var body = Data()
        func addField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        addField("model", model)
        addField("response_format", "verbose_json")
        if let language, !language.isEmpty {
            addField("language", language)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(wavData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            throw FunASRError.requestFailed(code, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        } catch {
            throw FunASRError.decodingFailed(error.localizedDescription)
        }
    }
}
