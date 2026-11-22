import Foundation

enum SubtitleWriter {
    static func srt(_ segments: [SubtitleSegment]) -> String {
        guard !segments.isEmpty else { return "" }
        return segments.enumerated().map { index, seg in
            "\(index + 1)\n\(srtTime(seg.start)) --> \(srtTime(seg.end))\n\(seg.text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }.joined(separator: "\n")
    }

    static func vtt(_ segments: [SubtitleSegment]) -> String {
        guard !segments.isEmpty else { return "WEBVTT\n" }
        return "WEBVTT\n\n" + segments.map { seg in
            "\(vttTime(seg.start)) --> \(vttTime(seg.end))\n\(seg.text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }.joined(separator: "\n")
    }

    private static func srtTime(_ t: TimeInterval) -> String {
        let clamped = max(0, t)
        let ms = Int((clamped.truncatingRemainder(dividingBy: 1)) * 1000)
        let total = Int(clamped)
        return String(
            format: "%02d:%02d:%02d,%03d",
            total / 3600, (total % 3600) / 60, total % 60, ms
        )
    }

    private static func vttTime(_ t: TimeInterval) -> String {
        srtTime(t).replacingOccurrences(of: ",", with: ".")
    }
}
