# ASR Tool

一款 macOS 原生应用：把视频/音频文件拖进去，借助本地 FunASR `paraformer` 模型，批量输出 SRT / WebVTT 字幕。

![ASR Tool 界面](Assets/app-screenshot.png)

## 下载与安装

从 GitHub Releases 下载：

- `ASR-Tool-macOS.dmg`：推荐。打开后会看到 `ASR Tool.app` 和 `Applications` 两个图标，把应用拖到 `Applications` 上即可完成安装。
- `ASR-Tool-macOS.zip`：解压后把 `ASR Tool.app` 拖到「应用程序」文件夹。

### 打开时提示“病毒 / 无法验证开发者”

这是 macOS Gatekeeper 对**未签名公证应用**的默认拦截，不代表应用真的有病毒。本项目是本地构建、ad-hoc 签名，没有使用 Apple Developer ID 做公证。

任选一种方法解决：

1. 右键点击 `ASR Tool.app` → 选择「打开」→ 在弹窗里再次点击「打开」
2. 在终端移除隔离属性：
   ```bash
   xattr -cr "/Applications/ASR Tool.app"
   ```
   如果应用还没拖进「应用程序」，把路径改成实际位置即可。
3. 如果是打开 DMG 时就提示，先移除 DMG 的隔离属性：
   ```bash
   xattr -d com.apple.quarantine ~/Downloads/ASR-Tool-macOS.dmg
   ```

要彻底消除这个提示，需要用 Apple Developer ID 重新签名并做公证（需要付费开发者账号）。

## 功能

- 拖入或选择 1-n 个视频/音频文件（MP4、MOV、M4A、MP3、WAV 等）
- 使用本地 FunASR 的 OpenAI 兼容转录接口进行语音识别，默认模型为 `paraformer`
- 首次启动时检测 FunASR 环境，未安装可一键安装并启动服务
- 长音频自动分块、时间戳自动拼接，结果保存为 SRT、VTT 或两者
- 字幕保存在各源文件所在目录，文件名与源文件一致（如 `video.mp4` → `video.srt` / `video.vtt`）
- 串行任务队列，实时查看进度和错误

## 环境要求

- macOS 13 及以上
- Xcode 命令行工具（`xcode-select --install`）
- Swift 5.9+
- Python 3（`python3 -m venv` 需要）

不再需要 LM Studio。应用会把 Python 虚拟环境和依赖安装到：

```text
~/Library/Application Support/SubtitleStudio/
```

## 使用步骤

1. 构建应用：
   ```bash
   chmod +x build.sh
   ./build.sh
   ```
   生成的 `ASR Tool.app` 位于项目根目录，双击运行。
2. 首次打开时，首页会显示 FunASR 服务状态。点击「一键安装并启动」，应用会自动创建虚拟环境、安装 `torch / torchaudio / funasr / fastapi / uvicorn / python-multipart` 并启动本地服务（默认 `http://127.0.0.1:8000/v1`）。
3. 安装可能需要几分钟，进度和日志会显示在首页横幅和「设置」中。
4. 在「设置」中可确认 API 地址与模型 ID（默认 `paraformer`），按需设置输出格式和语言。
5. 把音视频文件拖入窗口（或点击「选择文件」），点击「开始转写」。
6. 完成后点击任务行中的文件名可在 Finder 中定位字幕文件。

## 设置说明

| 项目 | 说明 |
| --- | --- |
| API 地址 | FunASR OpenAI 兼容服务地址，默认 `http://127.0.0.1:8000/v1` |
| 模型 ID | 默认 `paraformer`，支持分段时间戳；`sensevoice` 不输出时间戳 |
| 输出格式 | SRT / VTT / 两者 |
| 语言 | 如 `zh`、`en`；留空由模型自动检测 |
| 分块时长 | 默认 30 秒，可按机器性能调整 |

## 手动安装（可选）

如果想自己在终端安装和启动服务：

```bash
python3.11 -m venv ~/.funasr-venv
. ~/.funasr-venv/bin/activate
python -m pip install torch torchaudio funasr fastapi uvicorn python-multipart
funasr-server --host 127.0.0.1 --port 8000 --model paraformer --device cpu
```

然后在应用设置里把 API 地址填为 `http://127.0.0.1:8000/v1`。

## 项目结构

```
.
├── Assets/                     应用图标素材（AppIcon.icns 等）
├── Sources/SubtitleStudio/
│   ├── App/                    应用入口
│   ├── Models/                 设置、任务、API 数据模型
│   ├── Services/               音频提取、分块、FunASR 客户端、服务管理、字幕生成、处理队列
│   ├── Utils/                  WAV 工具
│   └── Views/                  主窗口、设置面板、任务行
├── build.sh                    构建并打包 .app
└── Package.swift               Swift Package 描述
```

## 常见问题

- **提示「文件中没有音轨」**：源文件是纯视频无音轨，或格式不受 macOS 解码支持。
- **首页显示 FunASR 未就绪**：点击「一键安装并启动」；如果失败，在设置中查看日志。
- **转写结果是一整段文字**：模型可能不支持时间戳，请把模型 ID 改为 `paraformer`。
- **想使用远程 FunASR 服务**：在设置中把 API 地址改为对应地址即可。
