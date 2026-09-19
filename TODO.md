# 目标清单:对照 libyue C++ 文档逐项完成

对照 <https://libyue.com/docs/latest/cpp/> 全部 119 页:**5 指南 + 55 组件 + 59 结构体**。
状态:`[x]` 完成 · `[~]` 部分(括号内是缺口) · `[ ]` 未开始;做完勾掉并注明验证方式。

## libyue 迁移

- [x] [Getting started](https://libyue.com/docs/latest/cpp/guides/getting_started.html) — 主链路跑通
- [x] [Events and delegates](https://libyue.com/docs/latest/cpp/guides/events_and_delegates.html) — 鼠标/键盘全信号 + 捕获
- [x] [Layout system](https://libyue.com/docs/latest/cpp/guides/layout_system.html) — set_style 全键覆盖,样式键全集见 [docs/layout.md](docs/layout.md);examples/layout
- [x] [Drag and drop](https://libyue.com/docs/latest/cpp/guides/drag_and_drop.html) — drag_source / drag_destination
- [ ] [FAQ](https://libyue.com/docs/latest/cpp/guides/faq.html)

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
- [x] 图标系统 — IconKind 37 种矢量图标(draw_icon 统一入口,收编散落 glyph)+ icon 展示视图 + icon_button_t 图标按钮(演示板「基础组件」页图标墙;视觉细节待真机复验)
- [x] Splitter 可拖动分隔 — hsplit/vsplit:6px 把手 + set_capture 拖动 + flexbasis 改写 + min 钳制(演示板「导航组件」页左树右栏/上下分栏;拖动手感待真机复验)
- [x] 单选与开关:radio_group / switch_t
- [x] 导航:side_menu / segmented / breadcrumb / pagination / steps
- [x] 数据展示:tag / avatar / badge / statistic / descriptions / timeline / collapse / card / code_view / progress_line
- [x] 反馈:alert / result / empty
- [x] input-number 数字输入器 — `-`/`+` 步进按钮 + Store[Double] + 范围钳制;演示板实测渲染
- [x] form 表单布局 — form_item(标签右对齐定宽 + 控件区)+ form 分组标题
- [x] link 链接文字 — 主题色 + 悬停下划线 + 点击回调
- [x] page-header 页头 — ‹ 返回(悬停变主题色)+ 标题 + 右侧操作区
- [x] backtop 返回顶部 — backtop_t 回调按钮 + Scroll::set_scroll_position(既有 ABI);演示页含滚动区实测
- [x] tree 树形控件 — TreeNode 嵌套 + 缩进层级 + 点击 ▸/▾ 展开折叠
- [x] transfer 穿梭框 — 双列 + 行点击选中(方块标记)+ ›/‹ 互移(动态行经 remove_child_view 重建)
- [x] autocomplete 自动补全 — 已移除(2026-09-18):过滤/键盘交互并入 select_t Linux 可过滤形态

### 第三批:table_t 全自绘表格
- [x] date_picker_t — 和日历共用算法逻辑，采用和 自动补全的方式进行日历的自渲染，和 Element Pluas date Picker 样式(全自绘月历面板经 Popover 弹出,与 calendar_t 共用 build_calendar;演示板「进阶」页;弹层焦点/选中回填待真机复验)

纯 MoonBit 自绘(Container+Painter+Store,tree/transfer 同路线),零平台原生控件,三平台像素一致、theme_apply 即暗色。按级迭代,每级可独立交付:

- [x] L1 静态表格 — 列定义(标题/宽/对齐)+ 行渲染 + 行点击选中 + hover 底 + 斑马纹 + 表头样式;数据经 Store[Array[Row]] 驱动(演示板「数据展示」页实测挂载;hover/斑马纹视觉待真机复验)
- [x] L2 选择与自定义单元格 — 复选框列(checkbox_t 画法)+ 多选/全选 + 自定义单元格(颜色块/tag/多行文本)(演示板「数据展示」页实测挂载;勾选/全选交互待真机复验)
- [x] L3 虚拟化 — 按滚动 offset 只画可见行,万行级流畅(实现为 table_v_t:整面 canvas 自绘 + 自管滚动,滚轮走 shim 新增 yue_mbt_view_on_wheel(Linux scroll-event);演示板 1 万行;流畅度与滚轮手感待真机复验)

- [x] select_t 下拉选择 — 全自绘路线(只读字段 + Popover 候选列表,选中 ✓ 标记);Linux 升级可过滤形态(2026-09-18:字段可输入实时筛选,↑↓ 高亮、回车选中、Esc 收起,弹层弃焦 set_accept_focus + 开层推迟一拍;演示板「进阶」页;输入/键盘/焦点行为待真机复验)
- [x] textarea_t 多行输入 — input_t 同套路(TextEdit + 自绘边框/聚焦色/8px 内边距)(演示板「基础组件」页;滚动行为待真机复验)
- [x] slider_t 滑杆 — 自绘轨道+thumb+拖拽(step 量化/Store 驱动;演示板「基础组件」页;拖拽手感待真机复验)
- [x] tabs_t 页签 — 顶部页签形态(选中指示条 + set_visible 切换;演示板「导航」页)
- [x] divider 分隔线 — 水平/竖直,1px 主题边框色(演示板「基础组件」页)
- [x] tooltip_t / popover_t — tooltip 走原生悬浮提示;popover_t 任意 Node 弹层(Popover 承载,点击开关)(演示板「进阶」页;弹层交互待真机复验)
- [x] calendar_t 日历面板 — 日期网格自绘(独立于原生 DatePicker;与 date_picker_t 共用 build_calendar,42 格月网格 + ‹/› 切月 + 今天高亮;演示板「进阶」页)
- [x] rate_t 评分 — 五角星矢量自绘 + hover 预亮 + 点击评分(演示板「进阶」页)
- [x] dropdown_menu 下拉菜单 — 触发字段 + 自绘菜单弹层("-" 分隔线;演示板「进阶」页)
- [x] carousel_t 轮播 — 面板/箭头/指示点 + 自动轮播(悬停暂停;演示板「数据展示」页;切换动画未做)
- [x] color_picker_t 取色器 — 预设色板形态(选中描边+白勾/hex 响应式;HSL 面板未做,按需后置)(演示板「数据展示」页)

### 已知边界(详见 docs/zh/adaptation.md)

- 原生控件不跟暗色:Table/ DatePicker / Picker / ComboBox / 原生 Button;RichEdit 输入框可经消息通道暗色化
- 主题库新组件一律全自绘,不再引入新的原生皮肤依赖——第三批交付后,表格(table_t/table_v_t)、日历(calendar_t/date_picker_t)、下拉(select_t/dropdown_menu)、输入(textarea_t)等全部走自绘/Popover 弹层路线,原生 DatePicker 仅存于底层封装,组件库不再使用
- 滚轮事件 Linux( GTK scroll-event)/ Windows(WM_MOUSEWHEEL 命中下发补丁)已接入;mac 的 canvas 自绘视图滚轮待补
- color_picker_t 为预设色板形态,HSL 面板未做;carousel_t 无切换动画

## 随手可查

- FFI 规范与坑清单:`.agents/skills/moonbit-c-binding/`
- 平台适配经验:`docs/adaptation.md`
- 完整 API 对照:libyue TS 声明(github.com/yue/yue releases);Lua 绑定参考(github.com/yue/yue 的 `lua_yue/`)
