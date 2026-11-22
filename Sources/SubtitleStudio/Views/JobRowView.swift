import SwiftUI

struct JobRowView: View {
    @ObservedObject var job: TranscriptionJob

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(job.fileName)
                    .lineLimit(1)
                Spacer()
                Text(job.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if job.status == .extracting || job.status == .transcribing || job.status == .writing {
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
            }

            if let error = job.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let warning = job.warningMessage {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !job.outputFiles.isEmpty {
                HStack(spacing: 12) {
                    ForEach(job.outputFiles, id: \.self) { url in
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: {
                            Label(url.lastPathComponent, systemImage: "doc.text")
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch job.status {
        case .pending: return "clock"
        case .queued: return "hourglass"
        case .extracting: return "waveform"
        case .transcribing: return "brain"
        case .writing: return "doc.text"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        default: return .secondary
        }
    }
}
