import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var serverManager = FunASRServerManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2.bold())

            GroupBox("FunASR 服务") {
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
                        Button("检查服务") { Task { await serverManager.check() } }
                        Button(serverManager.isReady ? "重新启动" : "一键安装并启动") {
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

                    Text("首次使用会安装 Python 环境、FunASR 及依赖，并启动本地 paraformer 服务。全程在本机完成。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("接口") {
                VStack(alignment: .leading, spacing: 10) {
                    labeledField("API 地址", text: $settings.serverBaseURL,
                                 placeholder: "http://127.0.0.1:8000/v1")
                    labeledField("模型 ID", text: $settings.model, placeholder: "paraformer")
                    Text("建议使用 paraformer，它支持分段时间戳；sensevoice 不输出时间戳，字幕会变成每块一大行。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            GroupBox("转写选项") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("输出格式", selection: $settings.outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    labeledField("语言代码（如 zh、en，留空自动检测）", text: $settings.language,
                                 placeholder: "留空自动检测")

                    HStack {
                        Text("分块时长：\(Int(settings.chunkDuration)) 秒")
                        Slider(value: $settings.chunkDuration, in: 10...60, step: 5)
                    }
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("完成") { dismiss() }
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
