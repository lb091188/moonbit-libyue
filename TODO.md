# 路线图 — MoonBit 原生 GUI 栈

记号：`[x]` 完成 · `[~]` 部分（缺口写在子条目）· `[ ]` 未开始。

- **唯一主线**：自绘栈（新栈拥有窗口/像素/事件循环/布局，控件全部基于 Painter 自绘 + 自定义主题，不提供独立原生控件）。方案见 [docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)。
- **本分支不保留老 libyue 绑定**：`shim/`、`lib/` 预构建库、`scripts/prepare.py` 已删除；libyue 只作**老师**（行为参考、可平移资产来源、`patches/` 的真实 bug 语料）。
- **旧链路的完成项与实测结论不在本文件重述**：代码在 `master`（`shim + libyue`，0.5.x 与 `bin-*`/`vendor-*` 发布照旧），踩坑与验收细节在 [docs/zh/adaptation.md](docs/zh/adaptation.md) 与 `git log`。**凡旧栈做过、新栈尚未重做的能力，本文件一律记为未完成。**
- **门禁口径（本分支例外）**：全仓 `moon check` 允许为红（红点=工作队列，只减不增，当前基线 **290 errors / 68 warnings**，明细见方案 §5）；逐批验收改分包：`yoga-mbt` 基线不掉 + 新栈各包 `moon check` 零警告且各自测试全绿；组件与声明式层接线完成的那一批恢复全仓门禁。

## 1. 地基（新栈自身进度）

- [x] **G0** 输入法探针（`experiment/ime_probe`）— 纯通道四条件真机闭环（fcitx5）
- [x] **G0b** 绑定层摘除与目录重排
- [x] **G1** 绘制契约 + 离屏像素回归（`yue/render`）
- [x] **G2** GTK3 窗口地基 + 循环归 MoonBit（`yue/win`、`yue/core/loop.mbt`）
- [x] **G3** Cairo 光栅 + Pango 文本（`yue/render/cairo.mbt`、`yue/text`）
- [x] **G4** 焦点栈 + 键鼠接入 + 编辑内核（`yue/core/focus.mbt`、`yue/input`）
- [x] **G5a** Linux 纯通道输入法接入（xdotool 注入验通中文提交）
- [ ] **G5b** 输入通道补齐
  - ibus 一套复验（探针侧归因 libpinyin display-style，待确认）
  - Windows：`ImmAssociateContext` 优先、可见 `EDIT` 作可切换兜底（触发条件：只走 TSF 的 IME 在 legacy 通道打不出中文）
  - macOS：`NSTextInputClient`（前置：有 mac 真机）
  - 肉眼确认项：preedit 下划线观感、候选窗是否贴组合串末尾、点击定位与 caret 闪烁观感
  - `TextEditorHost` 抽象收口（四签名 `process_key`/`commit`/`preedit`/`set_cursor_rect`）
- [ ] **G6** 布局层承接
  - 脏区增量重排 + 测量/内在缓存跨布局驻留
  - [x] `patches/` 的 yoga bug 语料转回归用例：首条 `93078300` 已落成 `modules/yoga-mbt/src/patches_regression_wbtest.mbt`（守的是可观察契约——auto 高列容器下的弹性项隐藏/重显一轮后高度仍来自内容测量；本引擎无 Yoga 那条 computedFlexBasis 驻留路径）
  - [ ] 语料派生待查：显式 `flex-basis:0` + `min-height:0` 在 auto 高列容器下本引擎给 60、按 CSS 推导应为 0，需 Chrome 对照后再定修引擎还是记为取舍（涉及 §4.5 min:auto 与 auto 主轴尺寸推算的交互）
  - 布局树 ↔ 自绘控件树映射、命中测试坐标对齐
- [ ] **G7** 声明式层与组件宿主接线（`mount` 目标从 `View` 换 yoga-mbt 节点；恢复全仓门禁）
- [ ] **G8** 原生子表面通道与其消费者（见 §4「浏览器」「视频」）

## 2. 框架能力域 — 全部待在新栈重做

### 绘图与资源
- [ ] Painter 语义补齐到旧契约同等面：路径/曲线/渐变/`blend`/`clip`/变换、`draw_image`、离屏 `Canvas`（对照 `docs/zh/components.md` 的 Painter 章）
- [ ] 图片解码（现 `yue/png_rgba.mbt` **只有编码**）：PNG/JPEG/GIF 解码或直连 GdkPixbuf 的等价替代
- [ ] 图标渲染：803 条路径数据经新 Painter 出图（`yue/icons`）
- [ ] 字体子系统：字体枚举与回退、`Font`/`TextFormat`/`AttributedText` 语义镜像（富文本区间测量、省略、换行、行高）

### 控件（一律自绘，不再引入原生控件皮肤）
- [ ] 基础：按钮 / 复选 / 单选 / 开关 / 滑块 / 进度 / 步进 / 标签 / 分隔线 / 图像 / 图标
- [ ] 文本输入：单行与多行（选区、双击选词、拖放插入点、Shift+箭头、undo/redo、placeholder、粘贴降级、只读、密码遮罩、IME 与 preedit 内联）
- [ ] 容器与滚动：`container`/`group`/`splitter`/`tab`/垂直滚动条与滚轮+拖动、虚拟列表、粘性列表
- [ ] 选择类：下拉 `picker` / 日期选择 / 颜色选择（旧 `color_picker_t` 是色板形态，HSL 面板未做）
- [ ] 表格 `table_v_t`：虚拟滚动、列宽拖动、排序、搜索、行选择
- [ ] 弹层：菜单 / 上下文菜单 / 气泡提示 / 对话框 / 消息框 / 通知 / 通知进度条 / 轮播（切换动画旧栈即缺）
- [ ] 托盘（含 DBusMenu 协议，按规则 5 上真实总线+真实面板复验）

### 主题、声明式与应用层
- [ ] 主题系统：色板派生 + 浅深自动跟随 + 组件皮肤全走新 Painter（旧「原生控件不跟暗色」这条边界随自绘自然消失）
- [ ] 声明式层：`Node`/`mount`/relink/`Store`/signals 在新宿主上跑通，公开签名对齐旧 `@yue`
- [ ] 组件库约 58 个组件（`yue/components`，调用点应不变，只换实现）
- [ ] 图表 20 种 + 3 个交互变体（纯算法层可直接复用，绘制段换新 Painter）
- [ ] Markdown：解析产物（mdast）→ 新 AttributedText；GFM 渲染面（表格/任务列表/脚注/删除线/图片/可点击链接）
- [ ] 富文本编辑（远期 WYSIWYG 块编辑器）
- [ ] 代码高亮、终端模拟器、WebGL 画布（旧栈即无，列为待评估）

### 系统集成（`yue/system` 559 fn + `yue/traybus` 175 fn 属可平移资产）
- [ ] 平移 A 类纯 MoonBit 能力：文件/目录读写、进程与子进程执行、系统信息、locale、剪贴板监听、音量、亮度、电源与电量、在线状态、空闲秒数、保活/屏保、勿扰、关机重启注销、蓝牙、打印机、壁纸、默认应用与 URL 打开、文件管理器定位、浏览器历史与书签与下载、VSCode/Firefox 历史、开机自启、单实例与二次唤起、任务栏固定、窗口管理、显示器信息、传感器、磁盘
- [ ] DBus 系（托盘 / 通知 / logind / UPower / NetworkManager / 屏保 / 媒体键 MPRIS）在新栈事件循环下重验：总线重连、fd 泄漏、信号注册表、注销与注册对称清理
- [ ] 系统集成剩余项：任务栏进度、dock 徽标、最近文档（旧栈 P13 后置）
- [ ] Wayland 后端（旧栈用 X11 屏保扩展查空闲，Wayland 不适用）

### 浏览器与视频（原生子表面）
- [ ] `mount_child_surface(handle, rect)` 的 C 端实现（形状已在方案 §4 冻结）
- [ ] 浏览器自研薄绑定：Linux WebKitGTK（自定义 scheme 注册 + `GInputStream` 流式回灌 + 拒绝路径），Windows WebView2（两级异步 COM 创建、失败回退、就绪前排队、跨 HWND 焦点与滚轮转发），macOS WKWebView（自定义协议依赖私有 API，列为 mac 线风险）；协议载荷改**结构化返回**（CORE1 越界读教训）
- [ ] 视频：`modules/ffmpeg-mbt` 与解码链路可沿用（不依赖 libyue），但 VideoPlayer 的 UI（悬浮控制条、全屏、进度与音量交互）需按新自绘组件重写，画面走子表面通道
- [ ] 音频：`AudioPlayer` 在新栈下的设备与时钟复验；精确音画同步（音频光标回读）

### 交付面
- [ ] 示例迁移：`hello` / `hello-themed` / `showcase`（全功能演示板）/ `sysmonitor` / `systemprobe` / `yue-examples`
- [ ] 文档：中英使用文档按新栈重写（`components`/`components-ui`/`declarative`/`layout`/`relink`/`system-capabilities`/`tutorial`），README 挂新截图
- [ ] 发布：mooncakes 新版本；旧 `bin-*`/`vendor-*` 预构建发布链退役
- [ ] CI：三平台构建与测试脚本随新栈调整（当前分支构建预期为红）
- [ ] 真机验证矩阵：Ubuntu GNOME / KDE / XFCE；Windows 10 / 11；macOS（前置：取得设备）

## 3. 里程碑

- **M1** 新栈跑通一个完整 `showcase`（组件 + 图表 + 系统集成页），与旧链路逐页视觉对照 → 同时恢复全仓门禁
- **M2** Windows 地基与输入通道
- **M3** macOS 地基（取得设备后）
- **M4** 发布新版本并冻结旧 `shim + libyue` 链路

## 4. 已知边界与风险

- 自绘文本的**无障碍**（ATK / UIA / NSAccessibility）本栈暂不含，只记不办。
- 例外扩散警戒：可见原生控件覆盖只作**按平台开关的兜底**，默认关；子表面（浏览器/视频）属能力型例外，需逐条登记评审。
- 过渡期红点：`examples/*`、`modules/yue-examples`、`modules/yue-media` 成片编译失败属工作队列，不影响 `master` 发布链；分支寿命越长与 master 漂移越大，故每批完成即提交推送。
- 回归基线：旧栈约 660 条测试随绑定文件消失，属净覆盖损失；补法是新栈每包自建 wbtest 并随资产平移测试。
- mac 线整体风险后置：无真机（旧栈遗留项 reply 通知回调、mac canvas 滚轮、Accelerator/Tray 原生后端等一并留在 master 侧记录）。

## 5. 随手可查

- 方案与阶段：[docs/zh/native-gui-plan.md](docs/zh/native-gui-plan.md)
- 平台实测坑：[docs/zh/adaptation.md](docs/zh/adaptation.md)（中英两份）
- 布局引擎交接与决策：[modules/yoga-mbt/HANDOFF.md](modules/yoga-mbt/HANDOFF.md)
- libyue 源码（只读老师）：`/home/lkyh/ownCode/yue`，含 `patches/` bug 语料
- FFI 规范与坑：`.agents/skills/moonbit-c-binding/`
