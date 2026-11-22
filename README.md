# ASR Tool

一款 macOS 原生应用：把视频/音频文件拖进去，借助本地 FunASR `paraformer` 模型，批量输出 SRT / WebVTT 字幕。

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
   生成的 `SubtitleStudio.app` 位于项目根目录，双击运行。
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
