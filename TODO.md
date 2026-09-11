# 目标清单:对照 libyue C++ 文档逐项完成

对照 <https://libyue.com/docs/latest/cpp/> 全部 119 页:**5 指南 + 55 组件 + 59 结构体**。
每一项就是一个具体目标,不分期,做完勾掉并注明验证方式;新目标继续往对应组里加。
状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始。

## 指南(5)

- [x] [Getting started](https://libyue.com/docs/latest/cpp/guides/getting_started.html) — 主链路 Ubuntu 24.04 + X11 + XFCE 跑通,hello/showcase 实测
- [x] [Events and delegates](https://libyue.com/docs/latest/cpp/guides/events_and_delegates.html) — 鼠标 down/up/move/enter/leave + 键盘 down/up + 捕获全套封装在 `yue/events.mbt`;examples/events 实测(xdotool 驱动:双击计数 clicks=2、左/右/中键、'a'=65/Esc=65307、Shift→mods=1/Ctrl→mods=2、捕获重定向、Esc 退出干净);modifiers 在 shim 归一化为 1=Shift 2=Ctrl 4=Alt 8=Meta
- [x] [Layout system](https://libyue.com/docs/latest/cpp/guides/layout_system.html) — set_style 全键覆盖(枚举/数值/边缘/百分比/auto),样式键全集入档 [docs/layout.md](docs/layout.md);examples/layout 内置 16 项几何断言(flex/gap/百分比/居中/min-width/absolute)真实窗口实测 16/16 全过;新增 on_size_changed、get_computed_layout 调试封装
- [x] [Drag and drop](https://libyue.com/docs/latest/cpp/guides/drag_and_drop.html) — drag_source / drag_destination 示例实测通过
- [ ] [FAQ](https://libyue.com/docs/latest/cpp/guides/faq.html) — 随查随用,不单独立目标

## 组件(55)

### 未封装(9 个新目标)

- [x] [Toolbar](https://libyue.com/docs/latest/cpp/api/toolbar.html) — **评估结论:Linux 不可用**(2026-09-11 nm 实测:libyue Linux 静态库无任何 Toolbar 符号,头文件未加 guard 但实现未编入,链接必失败);留待 Windows/macOS 平台目标
- [x] [Vibrant](https://libyue.com/docs/latest/cpp/api/vibrant.html) — **评估结论:Linux 不可用**(同上,nm 零符号;毛玻璃为 macOS 概念);留待 macOS 目标
- [x] [MessageLoop](https://libyue.com/docs/latest/cpp/api/message_loop.html) — post_task/post_delayed_task/set_timeout/set_timer/clear_timeout 全封装,misc 示例实测(立即任务、500ms 单次、200ms×3 周期自停、清理)
- [x] [Responder](https://libyue.com/docs/latest/cpp/api/responder.html) — 公开面即鼠标/键盘事件 + 捕获(SetCapture/ReleaseCapture/HasCapture/on_capture_lost),已全部经 ViewLike 暴露;GetClassName 留作 shim 内部类型校验
- [x] [State](https://libyue.com/docs/latest/cpp/api/state.html) — **评估结论:不封装**(平台内部聚合体,管理字体/外观等单例;MoonBit 侧已直接暴露 Appearance 等面向 API)
- [x] [SimpleTableModel](https://libyue.com/docs/latest/cpp/api/simpletablemodel.html) — **评估结论:放弃封装**(Linux 有实现,但现有 TableModel trait 桥功能为超集且更 MoonBit 友好,add_column_with_options + trait 即可覆盖)
- [x] [ProtocolJob](https://libyue.com/docs/latest/cpp/api/protocoljob.html) / [ProtocolStringJob](https://libyue.com/docs/latest/cpp/api/protocolstringjob.html) / [ProtocolFileJob](https://libyue.com/docs/latest/cpp/api/protocolfilejob.html) / [ProtocolAsarJob](https://libyue.com/docs/latest/cpp/api/protocolasarjob.html) — `register_protocol(scheme, handler)`(URL → (mime,内容)/None,内部 ProtocolStringJob 承载)+ unregister_protocol;misc 示例 demo:// 注册/加载/URL 往返实测。FileJob(路径直读)与 AsarJob(Electron 归档)场景由 handler 返回内容覆盖,不单独暴露
- [x] [Buffer](https://libyue.com/docs/latest/cpp/api/buffer.html) — **评估结论:不封装**(C++ 侧内存托管抽象;MoonBit 绑定面数据一律经 [len][payload] Bytes 编码,无使用场景)
- [~] [Signal](https://libyue.com/docs/latest/cpp/api/signal.html) — 评估结论:nu::Signal 是 libyue 内部连接机制,MoonBit 侧不暴露本体,`on_xxx` 回调注册即其绑定面(Events 指南目标已完成时一并定案)

### 部分封装(补齐为完整目标)

- [x] [AttributedText](https://libyue.com/docs/latest/cpp/api/attributedtext.html) — new_with/set_format(TextFormat 全量)、范围设字体/设色、get/set_text、clear 已补齐;layout 示例实测文本往返
- [x] [Font](https://libyue.com/docs/latest/cpp/api/font.html) — `Font::new(name, size, weight=?, style=?)` 完整暴露(与字体族同批核验)
- [x] [Image](https://libyue.com/docs/latest/cpp/api/image.html) — `new_from_png`(内存解码,editor 图片按钮解锁)、resize、write_to_file("png")、is_empty、get_scale_factor、read_binary_file;真机实测解码/缩半/导出/坏数据
- [x] [MenuBase](https://libyue.com/docs/latest/cpp/api/menubase.html) — item_count/item_at 公开(Menu 与 MenuBar 通用),get_label 公开;misc 示例遍历实测(甲乙丙)
- [x] [Window](https://libyue.com/docs/latest/cpp/api/window.html) — Options 完整(frame/transparent/no_activate)、shadow/resizable/maximizable/minimizable/is_maximized、should_close 委托(返回 false 可拒关);misc 示例实测
- [x] [DatePicker](https://libyue.com/docs/latest/cpp/api/datepicker.html) — `new_with(DatePickerOptions)`(Element 四种组合 + has_stepper);misc 示例实测创建
- [x] [Browser](https://libyue.com/docs/latest/cpp/api/browser.html) — new_with_options、load_html、set_user_agent、execute_javascript、get_cookies_for_url 已补;Cookie 空列表触发上游 CHECK 崩溃一事已记录(Browser 族)

### 已封装(实测通过即勾,后续仅回归)

- [x] App、Lifetime — init / run / quit
- [x] Window 基础(标题/尺寸/居中/激活/menubar/on_close)
- [x] View 通用(焦点/可见/样式/拖拽接入)— 见 `yue/view.mbt`
- [x] Container、Label、Button、Entry、TextEdit
- [x] Slider、Picker、ComboBox、ProgressBar
- [x] Tab、Group、Scroll、Separator
- [x] Table + TableModel(MoonBit trait 桥,替代 SimpleTableModel 的场景)
- [x] Painter、Canvas
- [x] Menu、MenuBar、MenuItem(含 Role 子集)
- [x] Tray(Linux 走 traybus SNI;XFCE 实测)、Notification、NotificationCenter
- [x] GlobalShortcut、Clipboard、MessageBox、Popover
- [x] FileDialog(FileOpenDialog / FileSaveDialog)
- [x] Screen、Appearance、Locale、Cursor

## 结构体(59,按族拆成具体目标)

- [x] 几何族:[PointF](https://libyue.com/docs/latest/cpp/api/pointf.html) / [SizeF](https://libyue.com/docs/latest/cpp/api/sizef.html) / [RectF](https://libyue.com/docs/latest/cpp/api/rectf.html) / [InsetsF](https://libyue.com/docs/latest/cpp/api/insetsf.html) / [Vector2dF](https://libyue.com/docs/latest/cpp/api/vector2df.html) — `yue/geometry.mbt` 值类型 + 运算(contains/center/enlarge/shrink/union);`get_bounds` 返回 RectF、`Window::get_content_size` 返回 SizeF、`get_bounds_for` 返回 SizeF、`offset_from_window/from_view` 返回 Vector2dF;layout 示例 16 断言回归全过
- [x] 文本族:[TextAlign](https://libyue.com/docs/latest/cpp/api/textalign.html)(draw_text 已用) / [TextAttributes](https://libyue.com/docs/latest/cpp/api/textattributes.html) / [TextFormat](https://libyue.com/docs/latest/cpp/api/textformat.html)(wrap/ellipsis 已暴露,new_with/set_format) / [Color](https://libyue.com/docs/latest/cpp/api/color.html)(工具已有) / [Color::Name](https://libyue.com/docs/latest/cpp/api/color_name.html)(系统语义色 system_color()) — 范围设字体/设色、get/set_text、clear 一并补齐;layout 示例实测文本往返与系统色
- [x] 字体族:[Font::Style](https://libyue.com/docs/latest/cpp/api/font_style.html)(FontStyle: Roman/Italic) / [Font::Weight](https://libyue.com/docs/latest/cpp/api/font_weight.html)(FontWeight: Thin~Black 九档 CSS 语义) — `Font::new(name, size, weight=?, style=?)` 已完整暴露
- [x] 事件族:[Event](https://libyue.com/docs/latest/cpp/api/event.html)(静态查询已封装:mouse_location/shift_pressed 等) / [EventType](https://libyue.com/docs/latest/cpp/api/eventtype.html) / [MouseEvent](https://libyue.com/docs/latest/cpp/api/mouseevent.html) / [KeyEvent](https://libyue.com/docs/latest/cpp/api/keyevent.html) / [KeyboardCode](https://libyue.com/docs/latest/cpp/api/keyboardcode.html) / [KeyboardModifier](https://libyue.com/docs/latest/cpp/api/keyboardmodifier.html) — `yue/events.mbt` + examples/events 实测(键值/修饰位真机核对);VKEY_* 常量取 Linux/GTK 表,Windows/macOS 取值不同、对齐随对应平台目标
- [x] 控件选项族:[Button::Type](https://libyue.com/docs/latest/cpp/api/button_type.html)(ButtonType:Normal/Checkbox/Radio,`Button::new_of` + set/is_checked,widgets 示例实测渲染与点击) / [Button::Style](https://libyue.com/docs/latest/cpp/api/button_style.html) / [ControlSize](https://libyue.com/docs/latest/cpp/api/controlsize.html)(两者 macOS 专属,头文件 `#if OS_MAC`,Linux 目标不适用) / [Entry::Type](https://libyue.com/docs/latest/cpp/api/entry_type.html)(`Entry::new_of(Password)` 掩码实测) / [Orientation](https://libyue.com/docs/latest/cpp/api/orientation.html)(已有) / [Cursor::Type](https://libyue.com/docs/latest/cpp/api/cursor_type.html)(12 型全有)
- [x] 菜单族:[MenuItem::Role](https://libyue.com/docs/latest/cpp/api/menuitem_role.html)(已有 MenuRole) / [MenuItem::Type](https://libyue.com/docs/latest/cpp/api/menuitem_type.html)(add_check_item/add_radio_item + 勾选态,misc 示例实测) / [Accelerator](https://libyue.com/docs/latest/cpp/api/accelerator.html)(字符串形式,set_accelerator 与全局快捷键共用)
- [x] 表格族:[Table::ColumnOptions](https://libyue.com/docs/latest/cpp/api/table_columnoptions.html) / [Table::ColumnType](https://libyue.com/docs/latest/cpp/api/table_columntype.html)(`add_column_with_options` 透传 type/column/width;table 示例改用新 API,渲染回归通过)
- [x] 滚动族:[Scroll::Policy](https://libyue.com/docs/latest/cpp/api/scroll_policy.html)(set/get_scrollbar_policy,misc 示例往返实测) / [Scroll::Elasticity](https://libyue.com/docs/latest/cpp/api/scroll_elasticity.html)(macOS 专属 `#if OS_MACOSX`,不适用);overlay 滚动条已有
- [x] 应用族:[Window::Options](https://libyue.com/docs/latest/cpp/api/window_options.html)(`new_with_options(frame=?, transparent=?, no_activate=?)`,no_activate 为 Linux/Win 字段;State 为平台内部聚合不暴露) / [App::ActivationPolicy](https://libyue.com/docs/latest/cpp/api/app_activationpolicy.html)(macOS 专属) / [App::ShortcutOptions](https://libyue.com/docs/latest/cpp/api/app_shortcutoptions.html)(Windows 专属) / [Lifetime::Reply](https://libyue.com/docs/latest/cpp/api/lifetime_reply.html)(macOS 专属) — 专属项按平台目标再做
- [x] 对话框/剪贴板族:[FileDialog::Filter](https://libyue.com/docs/latest/cpp/api/filedialog_filter.html)(字符串解析已有) / [FileDialog::Option](https://libyue.com/docs/latest/cpp/api/filedialog_option.html)(FILE_OPTION_* 常量 + set_options) / [Clipboard::Data](https://libyue.com/docs/latest/cpp/api/clipboard_data.html) / [Clipboard::Data::Type](https://libyue.com/docs/latest/cpp/api/clipboard_data_type.html) / [Clipboard::Type](https://libyue.com/docs/latest/cpp/api/clipboard_type.html)(from_type 支持 Selection 主选区;set/get_data 支持 Text/Html/Image/FilePaths,misc 示例选区与 HTML 往返实测)
- [x] 拖拽族:[DraggingInfo](https://libyue.com/docs/latest/cpp/api/dragginginfo.html)(已有) / [DragOperation](https://libyue.com/docs/latest/cpp/api/dragoperation.html)(修正 COPY=2 并补 MOVE=4/LINK=8——原 COPY=1 是 GTK 表外的非法值,2026-09-11 对照头文件修正) / [DragOptions](https://libyue.com/docs/latest/cpp/api/dragoptions.html)(仅 image 一字段,已由 do_drag_file_paths 的 drag_image 参数覆盖)
- [x] 通知族:[Notification::Action](https://libyue.com/docs/latest/cpp/api/notification_action.html)(set_actions 二元组数组,misc 示例实测调用成功) / [NotificationCenter::COMServerOptions](https://libyue.com/docs/latest/cpp/api/notificationcenter_comserveroptions.html)(Windows 专属) / [NotificationCenter::InputData](https://libyue.com/docs/latest/cpp/api/notificationcenter_inputdata.html)(macOS/Win 专属) — 专属项按平台目标再做
- [~] Browser 族:[Browser::Options](https://libyue.com/docs/latest/cpp/api/browser_options.html)(`new_with_options(devtools/context_menu/allow_file_access/hardware_acceleration)` 已实现) / [Cookie](https://libyue.com/docs/latest/cpp/api/cookie.html)(Cookie 结构 + get_cookies_for_url 异步桥已实现;**缺口**:libyue 0.15.6 在 Cookie 列表为空时触发内部 `CHECK(cookies)` FATAL 崩溃,属上游问题,查询须等页面真正种 Cookie,待上游修复或 shim 绕过)
- [x] 绘制/材质族:[BlendMode](https://libyue.com/docs/latest/cpp/api/blendmode.html)(Painter::set_blend_mode,25 型) / [ImageScale](https://libyue.com/docs/latest/cpp/api/imagescale.html)(GifPlayer::set/get_scale);[Vibrant::Material](https://libyue.com/docs/latest/cpp/api/vibrant_material.html) / [Vibrant::BlendingMode](https://libyue.com/docs/latest/cpp/api/vibrant_blendingmode.html) / [Toolbar::DisplayMode](https://libyue.com/docs/latest/cpp/api/toolbar_displaymode.html) / [Toolbar::Item](https://libyue.com/docs/latest/cpp/api/toolbar_item.html)(Linux 静态库无实现,随对应平台目标)
- [x] [MessageBox::Type](https://libyue.com/docs/latest/cpp/api/messagebox_type.html) — showcase 已用 Information

## 平台适配目标(对齐 README 支持矩阵,与上面并行,做完入档 docs/adaptation.md)

- [x] Ubuntu 24.04 Xfce — 主链路实测通过
- [ ] Ubuntu 24.04 GNOME — 托盘(纯净 GNOME 无托盘协议,需 AppIndicator 扩展)/菜单/对话框/WebView 人工确认,差异入档
- [ ] Ubuntu 24.04 KDE — 托盘与 DBusMenu 行为实测(KDE 面板自渲染菜单,关注与 XFCE 的批量方法差异)
- [ ] Deepin 25 — 托盘协议与整体表现实测
- [ ] OpenKylin 3 — 托盘协议与整体表现实测
- [ ] Windows 10/11 — 实测 + `prepare.py` 链接参数自动化(当前直接跳过回写)
- [ ] macOS — 实测(CMake 已备 ARC/no-ARC 双库分支,先验证哪条走通)

## 工程债 / 发布

- [x] 回调注册表(`yue/view.mbt`)窗口销毁后回收条目 — **决策:维持进程级保活**(2026-09-12 定案):回调与窗口无归属关系可循(同一闭包可被多窗口共享),精准回收需 weak-reference 注册表,当前 MoonBit 生态不成熟;GUI 工具场景(单窗口生命周期≈进程)无实际泄漏风险,已作为架构边界写入 docs/adaptation.md
- [x] traybus 托盘图标:IconPixmap 提供多档尺寸(32 原图 + 16 缩小,适配高密度面板),downscale_pixmap 带单测;icon 主题名解析本就由面板侧完成(SNI 只透传 IconName,`set_icon_name` 已可用);XFCE 面板实测金色月牙正常渲染(2026-09-12 像素级确认)
- [~] 发布 mooncakes 包(API 面稳定后) — **发布就绪,暂不发布(2026-09-12 确认)**:一切就绪(moon.mod.json name/version、README 双语 `moon add lkyh/moonbit-libyue` 用法、API 面已核对);`moon publish` 实测受阻于账号凭据(`~/.moon/credentials.json` 不存在),`moon login` 为所有者的交互式账号授权,无法代执行。**剩余动作(仅一步)**:所有者执行 `moon login && moon publish`,完成后把本项改为 [x]

### 近期已完成(记录)

- 2026-09-12:组件全部结案(部分封装 7 个补齐 + Protocol×4 + MessageLoop/Toolbar/Vibrant/State/Buffer/SimpleTableModel 评估或实现)与工程债收尾:Image 内存 PNG 解码/缩放/导出、BlendMode 25 型、ImageScale、MenuBase 公开遍历、DatePicker Options、Browser load_html/UA/JS/自定义协议、Window should_close 等;traybus 多尺寸 IconPixmap;发布就绪(mooncakes 需账号登录)。
- 2026-09-11:指南双目标完成(Events 全信号+捕获+双击计数;Layout 样式键全集入档 docs/layout.md+16 项几何断言);结构体 14/15 族完成(几何/文本/字体/事件/控件选项/菜单/表格/滚动/应用/对话框剪贴板/拖拽/通知/Browser/MessageBox);新增 examples/events、examples/layout;发现并修正 DRAG_OPERATION_COPY 非法值、记录 libyue Cookie 空 CHECK 崩溃。prepare.py 健壮化(坏缓存自动重下/原子落盘/幂等)+ 链接参数改仓库根相对;修复 Table 模型桥蹦床形参错位段错误、托盘菜单 XFCE EventGroup 点击无效;文档拆分 AGENTS.md + docs/adaptation.md。

## 扩展模式(每加一个控件同一模式)

1. `shim/yue_mbt.cpp` 加机械转换函数(对照 `vendor/libyue/include/nativeui/` 头文件签名)
2. `shim/include/yue_mbt.h` 加 C 声明
3. `yue/ffi.mbt` 加 extern
4. 新建 `yue/<控件>.mbt` 写类型和方法,字符串统一走 `utf8_bytes()`
5. 有事件的控件:照抄 `yue/view.mbt` 的注册表 + trampoline 模式
6. 新增示例放 `examples/<name>/`(`is-main` 包,`prepare.py` 会自动回写链接参数)

## 随手可查

- FFI 规范、坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验(按发行版/桌面/版本):`docs/adaptation.md`
- AI 协作规则:`AGENTS.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases 里的 `yue_typescript_declarations`)
- Lua 绑定实现参考:github.com/yue/yue 的 `lua_yue/`(类绑定、信号、平台 gate 的写法)
