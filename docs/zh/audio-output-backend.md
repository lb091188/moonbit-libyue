# 音频输出后端评估:内嵌 miniaudio 的下线方案

> 状态:**评估稿(未实施)** · 写于 2026-10-10 · 结论见末节「推荐」

## 背景与动机

- `modules/yue-media` 的音频链路是**两层**:**ffmpeg 管解码**(全格式 → s16 交错 PCM)、**内嵌 miniaudio 管输出设备**(WASAPI / CoreAudio / ALSA / PulseAudio)。
- miniaudio 以单头文件形式随 `modules/yue-media/src/miniaudio.h` **提交进仓库**(v0.11.25,95,864 行 / 4.1 MB),由 2026-10-08 的音视频重构 `a4e858d` 引入——当时定案「miniaudio 从 MoonBit 依赖降级为播放器的内部实现细节」。
- 副作用:它一个文件就让仓库的 C 系代码(表头 96.8k + C 3.9k + C++ 6.9k ≈ 10.8 万行)压过 MoonBit(8.35 万行),GitHub 语言条显示成 C;仓库源码体积多 4.1 MB。
- **不是合规问题**:miniaudio 许可为 public domain 或 MIT-0(声明在文件首尾)。故"下线"的动机只能是**仓库体积 / 语言统计 / 供应链偏好**。

## 当前用法面(极小)

`audio_stub.c` 只用到 miniaudio 的这几项能力:

| 类别 | 用到的 API |
|---|---|
| 设备 | `ma_device_config_init`、`ma_device_init`(playback,s16,交错)、`ma_device_start`、`ma_device_stop`、`ma_device_uninit` |
| 同步 | `ma_mutex_init` / `lock` / `unlock` / `uninit` |
| 回调 | 数据回调里从字节队列取数据、欠载补零、音量逐个样本钳制 |

**没有**用到解码、重采样、混音、文件 IO、设备枚举、格式转换。对 MoonBit 暴露的 C 函数共 12 个:
`mbt_adev_open`、`has_device`、`start`、`pause`、`is_started`、`push`、`queued_bytes`、`played_bytes`、`clear`、`set_volume`、`get_volume`、`close`;
另有 `mbt_now_ms`(`CLOCK_MONOTONIC` 毫秒,视频时钟基准,与 miniaudio 无关,任何方案都保留)。

结论:**替换面 = 一个「打开播放设备 + 回调」的抽象 + 一个互斥量**,约 100~150 行 C。

## 方案对比

| 方案 | 做法 | 仓库收益 | 工作量 | 主要风险 |
|---|---|---|---|---|
| **A 保持现状** | 不动 | 无 | 0 | 无 |
| **B 移出版本库、构建期拉取** | miniaudio.h 入 `.gitignore`,由构建脚本按钉死版本 + sha256 下载 | C 行数 **-89%**、体积 **-4.1 MB** | 小 | 消费方首次构建需联网;`moon publish` 校验需 prebuild 先备好头文件 |
| **C 平台原生后端** | Linux ALSA/PulseAudio + Windows WASAPI + macOS CoreAudio 各写一套 | 彻底去掉第三方 C 库 | 大(3 套) | Linux 引入 `libasound2-dev`;设备枚举/热插拔/无设备降级全部自管 |
| **D 换 SDL2 / PortAudio / RtAudio** | 同类替换 | 无(只是换一个依赖) | 中 | 普遍更重、依赖更多,单头零依赖优势尽失 |
| **E 回 MoonBit miniaudio 包** | 重新 import `CorvusCinereus/miniaudio` | 仓库不含 C | 小 | **已否决**:错误语义有 bug(`load_sound` 复用 `engine->result`),且解码器仅 WAV/MP3/FLAC |

## 推荐

- **若动机是仓库体积 / 语言统计(最可能)→ 选 B。**
  理由:runtime 一行不改、行为零变化,只把"随仓提交的头文件"换成"构建期拉取的依赖",与仓库既有的 libyue `vendor/` + sha256 模式**完全同构**,不引入新概念。
  - 现成钩子:`scripts/prepare.py` 已有 `download(url, expected_sha256)`(钉版本 + 校验 + 缓存 + 重试);`scripts/prebuild.py` 每次 `moon build` 都会执行(`moon.mod` 的 `--moonbit-unstable-prebuild`),天然可挂"若缺则拉取"。
  - 落地要点(实施期):①`miniaudio.h` 加进 `.gitignore`;②prebuild 里按 `MINIAUDIO_VERSION` + 钉死 sha256 下载到 `modules/yue-media/src/`(或缓存目录并给 native-stub 加 `-I`);③离线回退本地缓存;④版本常量与 sha256 集中一处。
  - **实施期待验项**(尚未验证,勿当已成立):消费方首次 `moon build` 的联网行为;`moon publish` 在临时目录独立校验时 prebuild 能否先备好头文件。
- **若动机是供应链纯净(去第三方 C 库)→ 选 C**,但成本最高,且 Linux 侧引入 `libasound` 开发包,与本仓库"降低消费方依赖"的方向相反。
- **若只是观感上不想看到 C → 选 A**,零风险。

## 影响面(仅针对推荐的 B)

- **改**:删 `modules/yue-media/src/miniaudio.h`;改 `.gitignore`;`scripts/prebuild.py`(+少量)、`scripts/prepare.py`(复用现有 `download`);文档提及处(`README`/`README_ZH`/`adaptation`)。
- **不动**:`audio_stub.c`、`audio_player.mbt`、`modules/yue-media/src/moon.pkg`。
- **门控**:`moon check` 零警告 + `moon test` 全绿 + `moon build examples/showcase` 重链零警告 + 无输出设备环境(CI/headless)静音降级仍成立。
