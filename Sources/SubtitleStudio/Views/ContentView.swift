import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @ObservedObject private var serverManager = FunASRServerManager.shared
    @State private var jobs: [TranscriptionJob] = []
    @State private var isDropTargeted = false
    @State private var showingSettings = false
    private let pipeline = TranscriptionPipeline.shared

    private var pendingCount: Int {
        jobs.filter { $0.status == .pending || $0.status == .failed }.count
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASR Tool")
                        .font(.title2.bold())
                    Text("基于 FunASR Paraformer 的本地音视频转字幕工具")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingSettings = true } label: {
                    Label("设置", systemImage: "gear")
                }
            }
            .padding(.horizontal)

            if !serverManager.isReady {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: serverManager.isBusy ? "hourglass" : "exclamationmark.triangle.fill")
                            .foregroundStyle(serverManager.isBusy ? Color.accentColor : .orange)
                        Text(serverManager.status)
                            .font(.caption)
                        Spacer()
                        Button(serverManager.isBusy ? "处理中…" : "一键安装并启动") {
                            Task { await serverManager.installAndStart() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(serverManager.isBusy)
                    }
                    if serverManager.isBusy {
                        ProgressView(value: serverManager.progress)
                            .progressViewStyle(.linear)
                        Text(serverManager.stage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            dropZone
                .padding(.horizontal)

            HStack {
                Button { openFilePicker() } label: {
                    Label("选择文件", systemImage: "folder")
                }
                Button(role: .destructive) {
                    pipeline.cancelAll()
                    jobs.removeAll()
                } label: {
                    Label("清空列表", systemImage: "trash")
                }
                .disabled(jobs.isEmpty)

                Spacer()

                Text(settings.model.isEmpty ? "未选择模型" : "模型：\(settings.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button { startTranscription() } label: {
                    Label("开始转写", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pendingCount == 0 || settings.model.isEmpty || !serverManager.isReady)
            }
            .padding(.horizontal)

            List {
                if jobs.isEmpty {
                    Text("暂无任务，拖入文件后将显示在这里")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    ForEach(jobs) { job in
                        JobRowView(job: job)
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(.vertical)
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings)
        }
        .frame(minWidth: 760, minHeight: 560)
        .task { await serverManager.check() }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.and.movie")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("拖入视频或音频文件")
                        .font(.headline)
                    Text("支持 MP4、MOV、M4A、MP3、WAV 等格式，可同时拖入多个文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
                return true
            }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    addFiles([url])
                }
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .audio, .data]
        panel.begin { response in
            guard response == .OK else { return }
            addFiles(panel.urls)
        }
    }

    private func addFiles(_ urls: [URL]) {
        for url in urls where !jobs.contains(where: { $0.fileURL == url }) {
            jobs.append(TranscriptionJob(fileURL: url))
        }
    }

    private func startTranscription() {
        let targets = jobs.filter { $0.status == .pending || $0.status == .failed }
        pipeline.enqueue(jobs: targets, settings: settings)
    }
}
