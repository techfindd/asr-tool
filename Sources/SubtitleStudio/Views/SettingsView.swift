import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var serverManager = FunASRServerManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.bold())

            GroupBox("FunASR Service") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: serverManager.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(serverManager.isReady ? .green : .orange)
                        Text(serverManager.status)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(serverManager.progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if serverManager.isBusy || serverManager.progress > 0 {
                        ProgressView(value: serverManager.progress)
                            .progressViewStyle(.linear)
                        Text(serverManager.stage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button("Check Service") { Task { await serverManager.check() } }
                        Button(serverManager.isReady ? "Restart" : "Install and Start") {
                            Task {
                                if serverManager.isReady {
                                    await serverManager.start()
                                } else {
                                    await serverManager.installAndStart()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(serverManager.isBusy)
                    }

                    if !serverManager.log.isEmpty {
                        ScrollViewReader { proxy in
                            ScrollView {
                                Text(serverManager.log)
                                    .font(.system(size: 10, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Color.clear.frame(height: 1).id("logBottom")
                            }
                            .frame(height: 110)
                            .padding(6)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                            .onChange(of: serverManager.log) { _ in
                                withAnimation(.none) {
                                    proxy.scrollTo("logBottom", anchor: .bottom)
                                }
                            }
                        }
                    }

                    Text("On first launch, this installs the Python environment, FunASR and its dependencies, then starts the local paraformer service. Everything runs on this machine.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("Connection") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledField("API URL", text: $settings.serverBaseURL,
                                 placeholder: "http://127.0.0.1:8000/v1")
                    labeledField("Model ID", text: $settings.model, placeholder: "paraformer")
                    Text("Paraformer is recommended because it returns segment timestamps. SenseVoice does not output timestamps, which results in one long line per chunk.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("Transcription Options") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Output Format", selection: $settings.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    labeledField("Language code (e.g. zh, en; leave empty to auto-detect)", text: $settings.language,
                                 placeholder: "Auto-detect")

                    HStack {
                        Text("Chunk duration: \(Int(settings.chunkDuration)) s")
                        Slider(value: $settings.chunkDuration, in: 10...60, step: 5)
                    }
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 520)
        .task { await serverManager.check() }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }
}
