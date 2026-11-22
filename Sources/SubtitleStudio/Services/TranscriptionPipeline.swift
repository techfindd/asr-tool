import Foundation

@MainActor
final class TranscriptionPipeline {
    static let shared = TranscriptionPipeline()

    private var queue: [TranscriptionJob] = []
    private var isRunning = false
    private var runTask: Task<Void, Never>?

    func enqueue(jobs: [TranscriptionJob], settings: AppSettings) {
        guard !jobs.isEmpty else { return }
        for job in jobs { job.status = .queued }
        queue.append(contentsOf: jobs)
        guard !isRunning else { return }
        isRunning = true
        runTask = Task { await self.runQueue(settings: settings) }
    }

    func cancelAll() {
        runTask?.cancel()
        runTask = nil
        queue.removeAll()
        isRunning = false
    }

    private func runQueue(settings: AppSettings) async {
        defer {
            isRunning = false
            runTask = nil
        }
        while let job = queue.first {
            if Task.isCancelled { break }
            await process(job: job, settings: settings)
            queue.removeFirst()
        }
    }

    private func process(job: TranscriptionJob, settings: AppSettings) async {
        do {
            try Task.checkCancellation()
            job.errorMessage = nil
            job.warningMessage = nil
            job.outputFiles.removeAll()

            job.status = .extracting
            job.progress = 0.05

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("SubtitleStudio-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let wavURL = tempDir.appendingPathComponent("audio.wav")
            try await AudioExtractor.extractMonoPCM16WAV(from: job.fileURL, to: wavURL)

            job.status = .transcribing
            let chunks = try AudioChunker.split(wavURL: wavURL, chunkDuration: settings.chunkDuration)
            guard !chunks.isEmpty else { throw AudioExtractionError.emptyAudio }

            let service = FunASRService(
                baseURL: settings.serverBaseURL,
                model: settings.model
            )

            var segments: [SubtitleSegment] = []
            var skippedChunks = 0
            var failedChunks = 0
            var firstFailure: String?

            for (index, chunk) in chunks.enumerated() {
                try Task.checkCancellation()
                job.progress = 0.1 + 0.8 * Double(index) / Double(chunks.count)

                if chunk.duration < 0.3 || WAV.isSilent(wavData: chunk.wavData) {
                    skippedChunks += 1
                    continue
                }

                let response: TranscriptionResponse
                do {
                    response = try await service.transcribe(
                        wavData: chunk.wavData,
                        fileName: "chunk-\(index).wav",
                        language: settings.language
                    )
                } catch {
                    failedChunks += 1
                    if firstFailure == nil { firstFailure = error.localizedDescription }
                    continue
                }

                if let items = response.segments, !items.isEmpty {
                    for item in items {
                        segments.append(
                            SubtitleSegment(
                                start: item.start + chunk.startTime,
                                end: item.end + chunk.startTime,
                                text: item.text
                            )
                        )
                    }
                } else if let text = response.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(
                        SubtitleSegment(
                            start: chunk.startTime,
                            end: chunk.startTime + chunk.duration,
                            text: text
                        )
                    )
                }
            }

            var warnings: [String] = []
            if skippedChunks > 0 {
                warnings.append("Skipped \(skippedChunks) silent or too-short chunk(s)")
            }
            if failedChunks > 0 {
                warnings.append("\(failedChunks) chunk(s) failed to transcribe (\(firstFailure ?? "Unknown error")); skipped")
            }
            job.warningMessage = warnings.isEmpty ? nil : warnings.joined(separator: "; ")

            guard !segments.isEmpty else {
                throw FunASRError.decodingFailed("Transcription result is empty. Check whether paraformer returns segment timestamps")
            }

            job.status = .writing
            job.progress = 0.95

            let baseName = job.fileURL.deletingPathExtension().lastPathComponent
            let outputDir = job.fileURL.deletingLastPathComponent()

            if settings.outputFormat == .srt || settings.outputFormat == .both {
                let url = outputDir.appendingPathComponent("\(baseName).srt")
                try SubtitleWriter.srt(segments).write(to: url, atomically: true, encoding: .utf8)
                job.outputFiles.append(url)
            }
            if settings.outputFormat == .vtt || settings.outputFormat == .both {
                let url = outputDir.appendingPathComponent("\(baseName).vtt")
                try SubtitleWriter.vtt(segments).write(to: url, atomically: true, encoding: .utf8)
                job.outputFiles.append(url)
            }

            job.status = .completed
            job.progress = 1.0
        } catch is CancellationError {
            job.status = .pending
            job.errorMessage = nil
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
        }
    }
}
