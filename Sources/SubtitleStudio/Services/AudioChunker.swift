import Foundation

enum AudioChunkerError: LocalizedError {
    case invalidWAV

    var errorDescription: String? {
        switch self {
        case .invalidWAV: return "音频文件不是有效的 WAV 格式"
        }
    }
}

struct AudioChunk {
    let index: Int
    let startTime: TimeInterval
    let duration: TimeInterval
    let wavData: Data
}

struct AudioChunker {
    static func split(wavURL: URL, chunkDuration: TimeInterval) throws -> [AudioChunk] {
        let data = try Data(contentsOf: wavURL)
        guard let pcm = WAV.pcmData(fromWAV: data) else { throw AudioChunkerError.invalidWAV }

        let chunkBytes = max(1, Int(chunkDuration * Double(WAV.bytesPerSecond)))
        var chunks: [AudioChunk] = []
        var offset = 0

        while offset < pcm.count {
            let end = min(offset + chunkBytes, pcm.count)
            let chunkPCM = pcm.subdata(in: offset..<end)
            let startTime = Double(offset) / Double(WAV.bytesPerSecond)
            let duration = Double(chunkPCM.count) / Double(WAV.bytesPerSecond)
            chunks.append(
                AudioChunk(
                    index: chunks.count,
                    startTime: startTime,
                    duration: duration,
                    wavData: WAV.wrapPCM(chunkPCM)
                )
            )
            offset = end
        }
        return chunks
    }
}
