# 封装路线图：从复杂示例到全量封装

目标：把 libyue（nativeui + base）完整封装为平台无关的 MoonBit 库，所有封装在 Ubuntu 24.04 上构建、运行验证通过。

验证方式：每个封装面都有对应示例 `examples/<name>`，`moon build` 零错误 + `moon run` 实际启动运行（试跑存活、无段错误、功能日志符合预期）。

## 已完成

- 构建基建：`prepare.py`（固定 v0.15.6 下载 + CMake 静态库 + 回写链接参数）
- 最小链路：App / Window / Label / Tray（含 Linux 托盘探测降级）
- 示例：examples/hello（端到端实测通过）

## 阶段 1（已完成 2026-09-10）：复杂示例复刻，铺开常用封装面

复刻官方 4 个有代表性的示例，新增约 70 个 ABI（全部构建 + 试跑存活通过）：

| 示例 | 带出的封装 | 状态 |
|---|---|---|
| editor | MenuBar/Menu/MenuItem（role/加速键/点击）、Button、TextEdit 读写、FileOpen/SaveDialog、文件 IO、Container 背景/flex 布局 | ✅ 构建通过 + 运行存活 |
| browser | Browser(WebView) 全套信号与导航、Entry、View 启停（SetEnabled）、style 透传 | ✅ 构建通过 + 运行存活 |
| floating_heart | 无边框透明窗口、Container 自绘（Painter 路径/填充/变换）、鼠标拖动窗口 | ✅ 构建通过 + 运行存活 |
| auto_height_edit | TextEdit 自动高度联动窗口、View::focus | ✅ 构建通过 + 运行存活 |
| hello | App/Window/Label/Tray（含 Linux 托盘探测降级） | ✅ 构建通过 + 运行存活 |

不追求 1:1 还原的偏离（均有注释说明）：editor 的图片按钮改为文字按钮（不引入 Image 编码依赖）、 Vibrant 跳过（macOS 专属）。

新增能力要点：
- View 模型：控件为真实 struct（编译期区分）+ ViewLike trait（focus/启停/style/背景作为默认方法，所有控件自动获得；多态 API 经 trait 接受任意控件）
- shim 运行时 dynamic_cast 校验，错型调用拒绝并记日志而非崩溃
- Painter/Canvas/AttributedText/Font/Image 封装已就绪（待 drawing 示例消纳）

## 阶段 2（进行中 2026-09-10）：drawing 复刻 + 复杂模型桥接

- ✅ drawing 复刻（examples/drawing）：9 组绘制全通过，Canvas 离屏、AttributedText、Font、Image 实测
- ✅ Table + AbstractTableModel 桥接（examples/table）：TableModel trait 挂 C++ 虚表桥，
  10000 行虚拟数据 + Edit 列回写 + Custom 列自绘色块，运行存活
- ✅ Drag & Drop（examples/drag_source、examples/drag_destination）：DraggingInfo 数据读取、
  View 拖拽委托（enter/update/drop/leave）、RegisterDraggedTypes、DoDrag 文件拖动、SchedulePaint
- ✅ 组合控件（examples/widgets）：Slider（值/步进/范围/双信号）、Picker、ComboBox（文本+选项）、
  ProgressBar（含不定态）、Popover（内容/尺寸/相对弹出/关闭回调）——全部构建通过 + 运行存活

阶段 2 踩坑实录（都是 MoonBit native FFI 的硬约束）：
1. **opaque type 值参与引用计数**：extern 句柄存 C 指针/id 会被 GC incref/decref，
   必须声明 `#external type`（值不参与 RC）。崩溃点 moonbit_incref(0x2) 即此。
2. **MoonBit 运行时 mimalloc 段与 C++ new 混用**：C++ 对象落进 GC 管理段被
   扫描/移动，vtable 损坏。解法：shim 重载 operator new/delete 重定向到
   `__libc_malloc/__libc_free`（glibc 堆与 GC 段彻底隔离）。
3. **extern 句柄往返**：整数 id 作为 #external 值经 MoonBit 装箱后往返不一致
   （id=4 传回变堆地址）；C++ 对象指针往返无损。故句柄 = C++ 对象指针，
   生命周期由 shim 侧 scoped_refptr 注册表进程级持有。
4. libyue 按无 RTTI 惯例构建，dynamic_cast 段错误，运行时类型校验用
   虚函数 GetClassName 字符串比较。

## 阶段 3：全量 API 面

对照 `vendor/libyue/include/nativeui/*.h` 与官方 TS 声明逐类勾选：

- base 库实用面（CommandLine、FilePath、Color/几何类型已完成的部分、StringPrintf 等按需）
- Notification、GlobalShortcut、Appearance、Locale、App 单例 API
- Canvas 完整离屏能力、AttributedText 富文本全集（局部样式 SetFontFor/SetColorFor）、Image 编码写出
- GifPlayer、DatePicker 等长尾控件
- 每类完成标准：有 shim 函数 + ffi 声明 + MoonBit 包装 + 至少一个示例或测试触达

## 阶段 4：Ubuntu 24.04 系统化验证

- `moon check` / `moon build` 全仓零错误零警告
- 每个 `examples/*` 依次 `moon run` 试跑：进程存活、无 SIGSEGV、退出行为正确
- 托盘/菜单/对话框/WebView 在 GNOME(X11) 下人工确认功能表现，差异记入 README"已知边界"
- 纯 MoonBit 部分（颜色/布局参数解析等）补 `moon test`

## 风险与已知约束

- moon 的 link 段只对 main 包生效（prepare.py 自动回写）
- extern 不可返回可空类型（ABI 不兼容），成败经出参
- FFI 指针参数强制 `#borrow`，回调闭包由注册表保活
- Linux 托盘依赖系统 libappindicator3；webview 依赖 webkit2gtk-4.0/4.1
- macOS / Windows：CMake 分支已备，未实测（后续阶段）
