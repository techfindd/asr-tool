import AVFoundation
import Foundation

enum AudioExtractionError: LocalizedError {
    case noAudioTrack(String)
    case readerFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .noAudioTrack(let name): return "文件中没有音轨：\(name)"
        case .readerFailed(let msg): return "音频读取失败：\(msg)"
        case .emptyAudio: return "未能提取到音频数据"
        }
    }
}

struct AudioExtractor {
    static func extractMonoPCM16WAV(from inputURL: URL, to outputURL: URL) async throws {
        let asset = AVAsset(url: inputURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw AudioExtractionError.noAudioTrack(inputURL.lastPathComponent)
        }

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: WAV.sampleRate,
            AVNumberOfChannelsKey: Int(WAV.channels),
            AVLinearPCMBitDepthKey: Int(WAV.bitDepth),
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        trackOutput.alwaysCopiesSampleData = false
        reader.add(trackOutput)

        guard reader.startReading() else {
            throw AudioExtractionError.readerFailed(reader.error?.localizedDescription ?? "未知错误")
        }

        var pcmData = Data()
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            var length: Int = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &length,
                dataPointerOut: &dataPointer
            )
            guard status == kCMBlockBufferNoErr, let pointer = dataPointer else { continue }
            pcmData.append(contentsOf: UnsafeRawBufferPointer(start: pointer, count: length))
        }

        if reader.status == .failed {
            throw AudioExtractionError.readerFailed(reader.error?.localizedDescription ?? "未知错误")
        }
        guard !pcmData.isEmpty else { throw AudioExtractionError.emptyAudio }

        try WAV.wrapPCM(pcmData).write(to: outputURL)
    }
}
