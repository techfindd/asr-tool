import Foundation

enum JobStatus: String {
    case pending = "等待中"
    case queued = "排队中"
    case extracting = "提取音频"
    case transcribing = "转写中"
    case writing = "生成字幕"
    case completed = "完成"
    case failed = "失败"
}

@MainActor
final class TranscriptionJob: ObservableObject, Identifiable {
    let id = UUID()
    let fileURL: URL
    @Published var status: JobStatus = .pending
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published var warningMessage: String?
    @Published var outputFiles: [URL] = []

    var fileName: String { fileURL.lastPathComponent }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }
}
