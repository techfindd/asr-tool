import Foundation

enum WAV {
    static let headerSize = 44
    static let sampleRate: Double = 16000
    static let channels: UInt16 = 1
    static let bitDepth: UInt16 = 16
    static let bytesPerSecond = Int(sampleRate * Double(channels * bitDepth / 8))

    static func wrapPCM(_ pcmData: Data) -> Data {
        let dataSize = UInt32(pcmData.count)
        let byteRate = UInt32(Double(channels) * Double(bitDepth) / 8.0 * sampleRate)
        let blockAlign = UInt16(channels * bitDepth / 8)

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.append(le: UInt32(36 + dataSize))
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(le: UInt32(16))
        header.append(le: UInt16(1))
        header.append(le: channels)
        header.append(le: UInt32(sampleRate))
        header.append(le: byteRate)
        header.append(le: blockAlign)
        header.append(le: bitDepth)
        header.append(contentsOf: "data".utf8)
        header.append(le: dataSize)
        return header + pcmData
    }

    static func pcmData(fromWAV data: Data) -> Data? {
        guard data.count > headerSize else { return nil }
        return data.subdata(in: headerSize..<data.count)
    }

    static func isSilent(wavData: Data, rmsThreshold: Double = 0.01) -> Bool {
        guard let pcm = pcmData(fromWAV: wavData) else { return true }
        var sum: Double = 0
        var count = 0
        var offset = 0
        while offset + 1 < pcm.count {
            let low = UInt16(pcm[pcm.startIndex + offset])
            let high = UInt16(pcm[pcm.startIndex + offset + 1])
            let raw = low | (high << 8)
            let sample = Double(Int16(bitPattern: raw)) / 32768.0
            sum += sample * sample
            count += 1
            offset += 2
        }
        guard count > 0 else { return true }
        return sqrt(sum / Double(count)) < rmsThreshold
    }
}

extension Data {
    mutating func append<T: FixedWidthInteger>(le value: T) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
