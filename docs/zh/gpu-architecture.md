# GPU 合成与 3D 路径

native-gui 从「全 CPU 光栅」走向「GPU 合成 + CPU 光栅并存」的架构决策与落地路径。

## 定位

**当前状态**：所有绘制走 CPU 路径——Painter 立即模式往 Bitmap 写像素，`wm_present` 拷贝到平台窗。这条路径在 1080p/典型桌面 GUI 场景每帧不到 2 ms，不是瓶颈。

**要走 GPU 的原因**：视频、地图、3D 场景、游戏这些内容类型对帧率与像素填充率有硬需求。全功能框架没有「暂不需要 GPU」这个选项——这些场景要求 GPU 在渲染主路径里，不是子视图能糊弄过去的。

## 架构方案

**两层落地 + 三级 fallback**。

### Layer 1：GPU 合成器（内部改造）

- 每个窗口的最终上屏从「bitmap 拷贝到平台窗」改成「bitmap 上传纹理 + GPU 全屏四边形合成」。
- 普通控件继续走 Painter 到 CPU bitmap；视频/地图/3D 控件（Layer 2）把自己的渲染目标当纹理挂进合成场景。
- **对外 API 零变化**——用户代码看不见内部从 CPU 拷贝换成 GPU 合成。
- 收益：大窗缩放流畅、多层动画不抖动、省电（桌面端感知弱）。

### Layer 2：控件级 GPU 绘制（协议扩展）

- `Widget.on_render(Widget, RenderCtx, Rect)` 走 GPU context 提交 shader/vertex buffer。
- `RenderCtx` 是 `@render` 包里的枚举：当前只有 `Cpu(Painter)` 变体；WebGPU 落地时新增 `Gpu(GpuContext)` 变体，`paint_walk` 派发时探测分派。
- **口子已留**：`Widget.on_render` 字段与 `RenderCtx` 枚举已在 2026-10-17 落地；现有控件走 `on_draw` 不受影响。

### 三级 fallback

运行时探测分派，遵循「不用 `#cfg(platform=)`」的跨平台硬规则：

```
WebGPU 可用 → GPU 合成（Layer 1+2 都开）
不可用 → Cairo 可用 → Cairo CPU 光栅（现状，Linux 主链路）
      不可用 → Pure MoonBit 光栅（现状回退档，Windows 主链路）
```

## 后端选型

**WebGPU via wgpu-native**。

| 方案 | 依赖重量 | C ABI | 三平台后端 | 判定 |
|---|---|---|---|---|
| **wgpu-native** | 9.3 MB .so | ✅ 纯 C11 | D3D12 / Vulkan / Metal 单 API | **选它** |
| Dawn (Google) | 数十 MB | ❌ C++ | 同上 | 依赖过重、FFI 要包一层 |
| Skia GPU | 20 MB+ | ❌ C++ | 需 gn/depot_tools 自编译 | 依赖链过长 |
| OpenGL 子视图 | 系统自带 | ✅ | Win/Linux 稳，macOS 已 deprecated | 平台定时炸弹 |
| 裸 Vulkan | 零额外 | ✅ | 三平台各写一套 surface/present | 工作量数倍 |

**MoonBit 侧现成绑定**：`moonbit-community/wgpu-mbt`（Apache-2.0，2026-09 活跃，pin v29.0.1.1）。它按 `native-stub` + `MBT_WGPU_NATIVE_LIB` dlopen + prebuild 下发链接参数的模式组织——与本仓 webview / media 模块的独立模块形态同构。

**回调线程坑**：`webgpu.h` 明确警告 `WGPURequestAdapterCallback` 等回调可能在任意线程自发触发，重入是 UB。wgpu-mbt 用 C 侧 mutex 守护的静态槽 + 1 ms 轮询吃掉回调，MoonBit 侧只见 `device_poll` 之类同步外形——与本仓 `wm_hotkey_poll` 同一手法。**这层轮询必须留在 C 侧**，不做 C→MoonBit 回调（对齐 AGENTS 规则 3）。

## 落地路线

**第一步**：X11 窗口里 wgpu 出三角形色块（真机肉眼验收，与 webview 首轮同形态）。

**第二步**：`wm_present` Linux 分支走纹理合成；Win / mac 后端各自跟上。

**第三步**：`RenderCtx` 开 `Gpu(GpuContext)` 变体。视频控件先切，地图 / 3D 场景控件随后续批次。

## 平台兼容档位

| 平台 | 后端 | 系统门槛 | 兼容跨度风险 |
|---|---|---|---|
| Windows | D3D12 | Win10 1809+（FL 11_0 实际要 20H2+） | 已承诺档全覆盖 |
| Linux | Vulkan | Vulkan 1.1+ 驱动 | **deepin 20 待真机复验** |
| macOS | Metal | macOS 10.15+ | mac 分支合流前不构成对外承诺 |

任一档缺时语义化降级到 CPU 合成，不阻断构建——这与 webview 引擎缺位时退占位、通知后端缺位时给 Unsupported 是同一档位口径。

## 与现有架构的接缝

- **@render** 的 `Backend` 枚举（`CairoBackend | PureBackend`）加 `GpuBackend(WebGpu)` 变体；`Painter::new` 探测顺序 WebGPU → Cairo → Pure。
- **@win** 的 `wm_present` C 桩按三分支加 GPU 上屏路径；`ChildSurface` 通道（现有 webview 嵌入机制）在 GPU 合成下语义不变。
- **@widget** 的 `paint_walk` 派发已经改到 `on_render` 优先、`on_draw` 回退。GPU 后端落地时只是往 `RenderCtx` 枚举加变体，不改派发。
- **@gui-media** 的视频解码帧已经是 RGBA `Bytes`，切 GPU 只是从「拷进 CPU Bitmap」换成「上传成纹理」，接口签名不动。

## 不做

- **shader 热重载 / 场景图 DSL**：本库给 `GpuContext` 原始接口，3D 引擎/场景图归独立模块（未来 `gui-3d`）。
- **文字 SDF/MSDF 迁移**：GPU 合成阶段文字仍走 Pango/DirectWrite 到位图再上传纹理。SDF 路线独立评估。
- **移动端**：只做三平台桌面。

## 时间线

- **十月**：`RenderCtx` + `on_render` 口子已交付（W38，2026-10-17）。
- **十一月**：native-gui + moon-launcher 参赛赛季，GPU 不动。
- **Q2 赛季起**：`modules/gui-gpu` 独立模块开工；第一步三角形色块验收。

架构决策与实测依据见 [roadmap.md](roadmap.md)「GPU 合成与 3D 路径」小节。跟踪项见 [TODO.md](https://github.com/lb091188/moonbit-native-gui/blob/master/TODO.md) §1 G11。
