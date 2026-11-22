import Foundation
import SwiftUI

enum OutputFormat: String, CaseIterable {
    case srt = "SRT"
    case vtt = "VTT"
    case both = "SRT + VTT"
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var serverBaseURL: String {
        didSet { UserDefaults.standard.set(serverBaseURL, forKey: "funasrBaseURL") }
    }
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: "funasrModel") }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    @Published var chunkDuration: Double {
        didSet { UserDefaults.standard.set(chunkDuration, forKey: "chunkDuration") }
    }
    @Published var outputFormat: OutputFormat {
        didSet { UserDefaults.standard.set(outputFormat.rawValue, forKey: "outputFormat") }
    }

    init() {
        let d = UserDefaults.standard
        serverBaseURL = d.string(forKey: "funasrBaseURL") ?? "http://127.0.0.1:8000/v1"
        model = d.string(forKey: "funasrModel") ?? "paraformer"
        language = d.string(forKey: "language") ?? ""
        let savedChunk = d.double(forKey: "chunkDuration")
        chunkDuration = savedChunk > 0 ? savedChunk : 30
        outputFormat = OutputFormat(rawValue: d.string(forKey: "outputFormat") ?? "") ?? .srt
    }
}
