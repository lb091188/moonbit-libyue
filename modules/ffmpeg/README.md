# NoahLiu/ffmpeg

ffmpeg 的 MoonBit 动态链 FFI 绑定（libavformat/libavcodec/libswscale/
libavutil），进程内解码：容器 demux、视频逐帧解码为 RGBA、时间戳 seek。
零 ffmpeg 源码 vendored——编译期 `pkg-config` 链接系统库，运行期加载
系统 `libav*.so`。

## 依赖

构建机：ffmpeg 开发包（Ubuntu：`sudo apt install -y libavcodec-dev
libavformat-dev libavutil-dev libswscale-dev`）。运行机：对应运行库
（`libavcodec60` 等，通常随 ffmpeg 安装）。链接参数由本模块的
`prebuild.py` 在构建期探测并自动传播给依赖方 main 包（无需手写链接配置）。

## API

```moonbit
// 打开（width/height 为输出帧目标尺寸，0 = 源尺寸）
let d = @ffmpeg.Demuxer::open("demo.avi")?    // AVI/MP4/MKV/WebM…
d.stream_width()    // 视频流原生宽
d.stream_height()   // 视频流原生高
d.duration_s()      // 时长秒（容器未知时 0）

// 逐帧解码（RGBA 字节，恰好 w*h*4；流结束 None）
while let Some(frame) = d.decode_rgba() { ... }

d.seek(1.5)?        // 时间戳 seek（avformat_seek_file + 解码器 flush）
d.close()           // 释放（之后不可再用）
```

错误 `VfError`：`OpenFailed(String)` / `NoVideoStream` / `DecodeFailed(String)`。
`ffmpeg_supported()` / `ffmpeg_version()` 探测库可达性与版本。

## FFI 约定（坑，详见主仓库 docs/zh/adaptation.md）

- extern 类型声明必须带 `#external`（否则 MoonBit GC 把 FFI 返回的
  裸指针当 GC 堆对象 drop → mi_free 段错误）；
- C 侧句柄失败不返回 NULL，返回哑句柄 + 显式 ok 探测（规避 NULL↔Option
  语义不确定性）；中间裸值立即装进 struct 字段再传递。
