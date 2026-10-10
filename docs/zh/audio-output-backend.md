# 音频输出后端评估:内嵌 miniaudio 的下线方案

> 状态:**B 方案已实施并验证(2026-10-10)** · 上方为评估过程,末三节为结论、取舍理由与实施结果

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

## 推荐与结论

- **已采纳并实施 B(2026-10-10)**:动机是仓库体积 / 语言统计。runtime 一行不改、行为零变化,只把"随仓提交的头文件"换成"构建期按钉版本 + sha256 取回"。
  - **实际落点**(与初稿设想不同,照仓内既有先例更省事):钩子挂在**模块级**——新增 `modules/yue-media/prebuild.py`,并在 `modules/yue-media/moon.mod` 写 `options("--moonbit-unstable-prebuild": "prebuild.py")`,与 `modules/ffmpeg-mbt/prebuild.py` 完全同一模式;**不必**改根 `scripts/prebuild.py` / `scripts/prepare.py`。
  - 脚本行为:已存在且 sha256 相符 → 跳过(幂等、离线可预置);缺失或不符 → 下载 → 校验 → 原子替换;失败非零退出并给出手动放置路径。stdout 只出 JSON(`{"link_configs": []}`),进度与错误走 stderr。
  - 代价(唯一新增):消费方首次构建需能访问 `raw.githubusercontent.com`。评估初稿低估了这点——libyue 的预构建库**随包分发**,消费方原本无需 GitHub;miniaudio 走构建期拉取则新增了一次 GitHub 依赖。
- **若动机是供应链纯净(去第三方 C 库)→ 选 C**,但成本最高,且 Linux 侧引入 `libasound` 开发包,与本仓库"降低消费方依赖"的方向相反。
- **若只是观感上不想看到 C → 选 A**,零风险。

## 为什么不做「预构建」

- miniaudio 是**单头文件**、**零链接依赖**——音频后端默认走运行期 `dlopen`(`miniaudio.h` 明确:只有开了 `-DMA_NO_RUNTIME_LINKING` 才需要链接),故它没有链接参数要托管,单翻译单元编译也极便宜。
- 它的"编译"本就发生在 yue-media 自己的 native-stub 里(`audio_stub.c` 的 `#define MINIAUDIO_IMPLEMENTATION`),所以唯一缺的是"编译时头文件在场"。
- 反过来做预构建,代价全在负面:①要另出**三份平台二进制**(且各平台后端本就是编译期选定,等于还是三套);②要把它拉进**链接参数托管**链路,违背仓库「库包不写链接参数、链接统一走 prebuild 传播」的硬性规则;③二进制把**编译器与 `MA_NO_*` 宏配置钉死**,而单头本地编译永远匹配本机工具链;④收益接近于零。
- 对照:**libyue 必须预构建**,是因为它体量大且依赖 GTK3 / WebKit2GTK 等系统开发包(`scripts/prebuild.py` 的 `link_configs()` 只服务它)。一句话——libyue 预构建是为了"让消费方免装系统开发包";miniaudio 本来就免依赖、编译又便宜,预构建反而丢掉它最大的优势。

## 实施结果(2026-10-10)

- **改动**:新增 `modules/yue-media/prebuild.py`;`modules/yue-media/moon.mod` 加 prebuild 钩子;`git rm --cached modules/yue-media/src/miniaudio.h` 并写进 `.gitignore`;文档回写(`docs/zh/adaptation.md`、`TODO.md`、本页、`modules/yue-media/README.md`)。
- **零改动**:`audio_stub.c`、`audio_player.mbt`、`modules/yue-media/src/moon.pkg`、根 `scripts/`。
- **钉死**:版本 `0.11.25` + `sha256 ac7af4de748b7e26b777f37e01cee313a308a7296a3eb080e2906b320cc55c89`(与上游 tag **逐字节一致**,`cmp` 实测)。
- **验证**:①脚本三场景实测——在场跳过 / 缺失取回 / sha256 不符重下,三次结果均与上游逐字节一致、无 `.partial` 残留;②删 `src/miniaudio.h` 后 `moon test modules/yue-media/src`,`prebuild.py` 被 moon 自动调用并取回头文件,11/11 通过;③全仓 `moon check` 零警告 + `moon test` 661/661。
- **未覆盖**:受限网络下消费方的实际表现(有正确文件即跳过,可预置规避);`moon publish` 临时目录内的校验路径未实测。
