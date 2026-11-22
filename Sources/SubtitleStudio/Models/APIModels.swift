import Foundation

struct ModelsResponse: Codable {
    let data: [ModelInfo]
}

struct ModelInfo: Codable, Identifiable {
    let id: String
}

struct TranscriptionResponse: Codable {
    let text: String?
    let segments: [TranscriptionSegment]?
    let language: String?
}

struct TranscriptionSegment: Codable {
    let start: Double
    let end: Double
    let text: String
}

struct SubtitleSegment {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}
