# 目标清单:对照 libyue C++ 文档逐项完成

对照 <https://libyue.com/docs/latest/cpp/> 全部 119 页:**5 指南 + 55 组件 + 59 结构体**。
状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## libyue 迁移

- [x] [Getting started](https://libyue.com/docs/latest/cpp/guides/getting_started.html) — 主链路跑通,hello/showcase 实测
- [x] [Events and delegates](https://libyue.com/docs/latest/cpp/guides/events_and_delegates.html) — 鼠标/键盘全信号 + 捕获,`yue/events.mbt`;examples/events 实测(键值/修饰位/双击);modifiers 在 shim 归一化(1=Shift 2=Ctrl 4=Alt 8=Meta)
- [x] [Layout system](https://libyue.com/docs/latest/cpp/guides/layout_system.html) — set_style 全键覆盖,样式键全集见 [docs/layout.md](docs/layout.md);examples/layout 16 项几何断言实测全过
- [x] [Drag and drop](https://libyue.com/docs/latest/cpp/guides/drag_and_drop.html) — drag_source / drag_destination 实测通过
- [ ] [FAQ](https://libyue.com/docs/latest/cpp/guides/faq.html) — 随查随用,不单独立目标

## 组件(55)

- [x] [Toolbar](https://libyue.com/docs/latest/cpp/api/toolbar.html) / [Vibrant](https://libyue.com/docs/latest/cpp/api/vibrant.html) — Linux 静态库无符号(nm 实测),链接必失败;留待其他平台
- [x] [State](https://libyue.com/docs/latest/cpp/api/state.html) — 平台内部聚合体,不封装
- [x] [SimpleTableModel](https://libyue.com/docs/latest/cpp/api/simpletablemodel.html) — 现有 TableModel trait 桥为超集,放弃
- [x] [Buffer](https://libyue.com/docs/latest/cpp/api/buffer.html) — C++ 内存托管抽象,MoonBit 侧无使用场景,不封装
- [x] [ProtocolJob](https://libyue.com/docs/latest/cpp/api/protocoljob.html) 系(×4)— `register_protocol(scheme, handler)` 承载,misc 示例实测
- [x] [MessageLoop](https://libyue.com/docs/latest/cpp/api/message_loop.html) — post_task/set_timeout/set_timer 等全封装,misc 实测
- [x] [Responder](https://libyue.com/docs/latest/cpp/api/responder.html) — 鼠标/键盘/捕获经 ViewLike 全暴露
- [~] [Signal](https://libyue.com/docs/latest/cpp/api/signal.html) — 内部连接机制,`on_xxx` 回调注册即绑定面,不暴露本体
- [x] [AttributedText](https://libyue.com/docs/latest/cpp/api/attributedtext.html) — new_with/set_format、范围设字体/设色、get/set_text
- [x] [Font](https://libyue.com/docs/latest/cpp/api/font.html) — `Font::new(name, size, weight=?, style=?)`
- [x] [Image](https://libyue.com/docs/latest/cpp/api/image.html) — new_from_png/resize/write_to_file/read_binary_file,真机实测
- [x] [MenuBase](https://libyue.com/docs/latest/cpp/api/menubase.html) — item_count/item_at/get_label 公开
- [x] [Window](https://libyue.com/docs/latest/cpp/api/window.html) — Options 全量、should_close 委托(可拒关)
- [x] [DatePicker](https://libyue.com/docs/latest/cpp/api/datepicker.html) — `new_with(DatePickerOptions)` 四种组合 + has_stepper
- [x] [Browser](https://libyue.com/docs/latest/cpp/api/browser.html) — load_html/set_user_agent/execute_javascript/get_cookies_for_url;Cookie 空列表触发上游 CHECK 崩溃,待上游修复
- [x] **Window**:close/minimize/restore/on_focus/on_blur/尺寸约束/set_skip_taskbar/set_icon 等
- [x] **View**:tooltip 三件套、set_font/set_color、on_focus_in/out、set_focusable/has_focus、schedule_paint_rect
- [x] **Container**:add_child_view_at/remove_child_view/child_count
- [x] **Table**:多选/选中行 + notify 刷新三件套
- [x] **Browser**:get_title/stop/execute_javascript_with_result(JS 回调 JSON 回传)/raw binding 增删查
- [x] **Scroll**:on_scroll 信号 + 位置/边界读写
- [x] **Label**:set_align/set_valign/set_attributed_text/set_font/set_color
- [x] **MessageBox**:default/cancel response、run/run_for_window
- [x] **剪贴板**:is_data_available/watching/on_change
- [~] **通知回调**:show/close/click/action + clear 已补;reply(OS_MAC)留平台目标
- [x] **多显示器与外观**:work_area/scale_factor/cursor/dark_mode/color_scheme
- [x] **杂项**:app id、menu_item 状态、file_dialog 标题、gif_player 控制、canvas 尺寸、拖拽通用版(start_drag/cancel_drag/is_dragging)等
- [~] **缓办**:Display 全字段枚举、mac 专属(Accelerator 类/Tray 原生后端等)
- [x] App、Lifetime、Window 基础、View 通用、Container、Label、Button、Entry、TextEdit
- [x] Slider、Picker、ComboBox、ProgressBar、Tab、Group、Scroll、Separator
- [x] Table + TableModel(MoonBit trait 桥)、Painter、Canvas
- [x] Menu、MenuBar、MenuItem、Tray(Linux 走 traybus)、Notification、NotificationCenter
- [x] GlobalShortcut、Clipboard、MessageBox、Popover、FileDialog
- [x] Screen、Appearance、Locale、Cursor

## 结构体

- [x] 几何族:PointF/SizeF/RectF/InsetsF/Vector2dF — `yue/geometry.mbt` 值类型 + 运算;layout 示例回归全过
- [x] 文本族:TextAlign/TextAttributes/TextFormat/Color/Color::Name — 范围设字体/设色、system_color 已补
- [x] 字体族:Font::Style/Weight — `Font::new` 完整暴露
- [x] 事件族:Event/EventType/MouseEvent/KeyEvent/KeyboardCode/KeyboardModifier — VKEY 取 GTK 表,其他平台随对应目标
- [x] 控件选项族:Button::Type/Entry::Type/Orientation/Cursor::Type;ControlSize/Button::Style 为 macOS 专属不适用
- [x] 菜单族:MenuItem::Role/Type、Accelerator(字符串形式)
- [x] 表格族:ColumnOptions/ColumnType
- [x] 滚动族:Scroll::Policy;Elasticity 为 macOS 专属不适用
- [x] 应用族:Window::Options/App::ShortcutOptions;ActivationPolicy/Reply 为 macOS 专属
- [x] 对话框/剪贴板族:FileDialog::Filter/Option、Clipboard::Data 系
- [x] 拖拽族:DraggingInfo/DragOperation(修正 COPY=2,补 MOVE/LINK)/DragOptions
- [x] 通知族:Notification::Action、NotificationCenter 专属选项
- [~] Browser 族:Options/Cookie 桥已实现;Cookie 空列表上游 CHECK 崩溃待修
- [x] 绘制/材质族:BlendMode 25 型/ImageScale;Vibrant/Toolbar 系随平台目标
- [x] [MessageBox::Type](https://libyue.com/docs/latest/cpp/api/messagebox_type.html)

## 平台适配

- [x] Ubuntu 24.04 Xfce / GNOME(Wayland+X11) / KDE
- [x] Deepin 23 / Deepin 25
- [x] Windows 10/11
- macOS — 放弃(无设备)
- OpenKylin — 移除(无测试环境)

## 主题组件库

对照 Element Plus,只收 desktop 适用项;API 见 [docs/zh/components-ui.md](docs/zh/components-ui.md)。

### 已完成(24)

- [x] 主题化控件:button_t / label_t / entry_t / checkbox_t
- [x] 单选与开关:radio_group / switch_t
- [x] 导航:side_menu / segmented / breadcrumb / pagination / steps
- [x] 数据展示:tag / avatar / badge / statistic / descriptions / timeline / collapse / card / code_view / progress_line
- [x] 反馈:alert / result / empty

### 第一批

- [ ] input-number 数字输入器 — entry_t + 加减按钮 + 范围钳制
- [ ] form 表单布局 — label 对齐 + 控件区 + 分组
- [ ] link 链接文字 — label_t 变体
- [ ] page-header 页头 — 返回 + 标题 + 操作区
- [ ] backtop 返回顶部 — Scroll 定位 + 浮动按钮

### 第二批

- [ ] tree 树形控件 — 递归行 + 缩进 + 展开折叠
- [ ] transfer 穿梭框 — 双列表互移
- [ ] autocomplete 自动补全 — entry_t + 候选下拉
- [ ] date_picker_t / time_picker_t — 原生 DatePicker 主题化封装

### 候选

skeleton / loading / ellipsis / infinite-scroll / calendar / color-picker / rate

## 随手可查

- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验:`docs/adaptation.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases);Lua 绑定参考(github.com/yue/yue 的 `lua_yue/`)
