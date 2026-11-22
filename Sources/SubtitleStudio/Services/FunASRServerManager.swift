import Foundation

@MainActor
final class FunASRServerManager: ObservableObject {
    static let shared = FunASRServerManager()

    @Published private(set) var isReady = false
    @Published private(set) var isBusy = false
    @Published private(set) var status = "尚未检查"
    @Published private(set) var stage = ""
    @Published private(set) var progress: Double = 0
    @Published var log = ""

    private let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SubtitleStudio", isDirectory: true)
    }()

    private var venvURL: URL {
        supportDir.appendingPathComponent("funasr-venv", isDirectory: true)
    }

    private var serverExecutable: String {
        venvURL.appendingPathComponent("bin/funasr-server").path
    }

    private var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: serverExecutable)
    }

    func check() async {
        status = "正在检查 FunASR 服务…"
        let running = await isServerReachable()
        isReady = running
        if running {
            status = "FunASR 服务已就绪"
            stage = "服务已就绪"
            progress = 1
        } else if isInstalled {
            status = "FunASR 已安装，但服务未启动"
            stage = "服务未启动"
            progress = 0
        } else {
            status = "FunASR 未安装"
            stage = "等待安装"
            progress = 0
        }
    }

    func installAndStart() async {
        guard !isBusy else { return }
        isBusy = true
        log = ""
        progress = 0
        status = "正在安装 FunASR"
        do {
            stage = "1/4 准备 Python 环境"
            progress = 0.05
            try await runShell(Self.prepareScript)

            stage = "2/4 更新 pip"
            progress = 0.15
            try await runShell(Self.upgradePipScript)

            stage = "3/4 安装 FunASR 及依赖（可能需要几分钟）"
            progress = 0.25
            try await runShell(Self.installDepsScript)
            progress = 0.9

            stage = "4/4 启动本地服务"
            progress = 0.94
            try await runShell(Self.startScript)
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await check()
            progress = isReady ? 1.0 : 0.94
            stage = isReady ? "安装完成" : "服务未能启动，请查看日志"
        } catch {
            status = "安装失败：\(error.localizedDescription)"
            stage = "安装失败"
            appendLog("\n==> 失败：\(error.localizedDescription)\n")
        }
        isBusy = false
    }

    func start() async {
        guard !isBusy else { return }
        guard isInstalled else {
            await installAndStart()
            return
        }
        isBusy = true
        log = ""
        progress = 0
        status = "正在启动 FunASR 服务…"
        do {
            stage = "启动本地服务"
            progress = 0.3
            try await runShell(Self.startScript)
            progress = 0.8
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await check()
            progress = isReady ? 1.0 : 0.8
            stage = isReady ? "服务已就绪" : "服务未能启动，请查看日志"
        } catch {
            status = "启动失败：\(error.localizedDescription)"
            stage = "启动失败"
            appendLog("\n==> 失败：\(error.localizedDescription)\n")
        }
        isBusy = false
    }

    private func isServerReachable() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8000/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    private func appendLog(_ text: String) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        log.append(normalized)
        if log.count > 20_000 {
            log = String(log.suffix(20_000))
        }
        guard stage.hasPrefix("3/4"), let pct = lastPercentage(in: normalized) else { return }
        let candidate = 0.25 + 0.65 * pct
        if candidate > progress { progress = candidate }
    }

    private func lastPercentage(in text: String) -> Double? {
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last else { return nil }
        return Double(ns.substring(with: last.range(at: 1))).map { min(max($0 / 100, 0), 1) }
    }

    private func runShell(_ script: String) async throws {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let handle = pipe.fileHandleForReading

        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data, as: UTF8.self)
            Task { @MainActor in
                self.appendLog(text)
            }
        }

        try process.run()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                handle.readabilityHandler = nil
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let error = NSError(
                        domain: "FunASRInstaller",
                        code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "命令执行失败（退出码 \(proc.terminationStatus)）"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static let prepareScript = """
    set -e
    SUPPORT="$HOME/Library/Application Support/SubtitleStudio"
    VENV="$SUPPORT/funasr-venv"
    mkdir -p "$SUPPORT"
    if [ ! -x "$VENV/bin/python" ]; then
      python3 -m venv "$VENV"
    fi
    echo "==> Python 环境就绪"
    """

    private static let upgradePipScript = """
    set -e
    VENV="$HOME/Library/Application Support/SubtitleStudio/funasr-venv"
    "$VENV/bin/python" -m pip install --upgrade pip
    echo "==> pip 已更新"
    """

    private static let installDepsScript = """
    set -e
    VENV="$HOME/Library/Application Support/SubtitleStudio/funasr-venv"
    "$VENV/bin/python" -m pip install torch torchaudio funasr fastapi uvicorn python-multipart
    echo "==> 依赖安装完成"
    """

    private static let startScript = """
    set -e
    SUPPORT="$HOME/Library/Application Support/SubtitleStudio"
    VENV="$SUPPORT/funasr-venv"
    if [ ! -x "$VENV/bin/funasr-server" ]; then
      echo "找不到 funasr-server，请先安装" >&2
      exit 2
    fi
    nohup "$VENV/bin/funasr-server" --host 127.0.0.1 --port 8000 --model paraformer --device cpu > "$SUPPORT/funasr-server.log" 2>&1 &
    echo $! > "$SUPPORT/funasr-server.pid"
    echo "==> 服务已启动"
    """
}
