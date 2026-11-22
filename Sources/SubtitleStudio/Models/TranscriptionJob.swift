import Foundation

enum JobStatus: String {
    case pending = "Pending"
    case queued = "Queued"
    case extracting = "Extracting audio"
    case transcribing = "Transcribing"
    case writing = "Writing subtitles"
    case completed = "Completed"
    case failed = "Failed"
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
