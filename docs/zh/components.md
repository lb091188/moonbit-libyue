# 组件方法速查

面向 moonbit-libyue 使用者的组件 API 速查。所有类型经 `@yue` 引用；
每个控件都有两种用法：**逐个 setter 的经典写法**（`X::new` + setter），
或 **props 风格一步到位**（`X::make`）。两者语义完全一致，`make` 只是 setter 的打包。

声明式写法（`@yue.mount` 树 + `Store` 绑定）见 [docs/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md)；
布局样式键全集见 [docs/layout.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/layout.md)；
平台适配与上游缺陷的完整记录见 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)。

通用约定：

- 除单独说明外，所有 `make` 均有可选参数
  `style : Array[(String, Double)]` 与 `style_str : Array[(String, String)]`
  （创建即应用的样式键值对），下表不再重复列出。
- `on_*` 为回调注册方法。

## 窗口 Window

```moonbit
let win = @yue.Window::make(
                title="主窗口",
                size=Some((960.0, 640.0)),
                center=true)
win.on_close(fn(_w) { @yue.quit() })
win.set_content(content_view)
```

`Window::make` 入参（无 `style`，窗口没有父布局）：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| title | String | `""` | 标题 |
| size | (Double, Double)? | None | 内容区尺寸（宽, 高） |
| on_close | (Window) -> Unit | 空操作 | 关闭回调 |
| center | Bool | false | 创建后居中 |

常用方法：

| 方法 | 用途 |
|---|---|
| set_title(t) | 设标题 |
| set_content(v) | 设内容视图 |
| set_content_size(w, h) / get_content_size() | 设 / 读内容区尺寸 |
| center() / activate() | 居中 / 激活到前台 |
| maximize() / unmaximize() / is_maximized() | 最大化 |
| set_fullscreen(b) / is_fullscreen() | 全屏 |
| set_always_on_top(b) | 置顶 |
| set_resizable(b) / is_resizable() | 可缩放 |
| set_maximizable(b) / set_minimizable(b) | 标题栏按钮开关 |
| set_has_shadow(b) / has_shadow() | 窗口阴影 |
| set_menubar(mb) | 挂菜单条 |
| on_close(fn(_w)) | 关闭回调 |
| set_should_close(fn() -> Bool) | 返回 false 拦截关闭 |

`Window::new_with_options` 入参（无边框 / 透明 / 浮层窗口）：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| frame | Bool | true | false 为无边框 |
| transparent | Bool | false | 透明背景 |
| no_activate | Bool | false | 不抢焦点（浮层 / 面板类窗口） |

## 容器 Container

```moonbit
let col = @yue.Container::make(style=[("padding", 12.0)])
col.add_child(child)
```

入参只有 `style` / `style_str`（见文首）。默认 `flexDirection=column`、
`alignItems=stretch`，水平排列 `set_style_str("flexDirection", "row")`；
键的解析规则见 [docs/layout.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/layout.md)。

| 方法 | 用途 |
|---|---|
| add_child(v) | 添加子视图（任何 ViewLike） |
| on_draw(fn(painter)) | 自绘 |

## 标签 Label

```moonbit
let l = @yue.Label::make("文本", style_str=[("color", "#356AA0")])
l.set_text("新文本")
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | 必填 | 初始文本 |

| 方法 | 用途 |
|---|---|
| set_text(t) | 改文本 |

## 按钮 Button（含复选框 / 单选框）

```moonbit
let b = @yue.Button::make("确定", on_click=fn() { ... })
let c = @yue.Button::make("启用", button_type=Checkbox, checked=false,
                          on_click=fn() { ... })   // 回调里用 is_checked() 读状态
let r = @yue.Button::make("主题甲", button_type=Radio, checked=true, on_click=...)
b.set_title("新标题")
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| title | String | 必填 | 按钮文本 |
| button_type | ButtonType | Normal | Normal / Checkbox / Radio |
| on_click | () -> Unit | 空操作 | 点击回调 |
| checked | Bool | false | 初始勾选（Checkbox / Radio） |

同一父容器内的 Radio 自动互斥；初始回调与双通知见文末「固有坑」。

| 方法 | 用途 |
|---|---|
| set_title(t) | 改文本 |
| is_checked() / set_checked(b) | 读 / 设勾选 |
| on_click(fn()) | 点击回调 |

## 单行输入 Entry

```moonbit
let e = @yue.Entry::make(text="预填", entry_type=Password)
e.on_activate(fn() { check(e.get_text()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | `""` | 初始文本 |
| entry_type | EntryType | Normal | Normal / Password |
| on_activate | () -> Unit | 空操作 | 回车回调（不带参数，取文本用 get_text） |
| on_text_change | () -> Unit | 空操作 | 内容变化回调（同上） |

| 方法 | 用途 |
|---|---|
| get_text() / set_text(t) | 读 / 设文本 |
| on_activate(fn()) | 回车回调 |
| on_text_change(fn()) | 内容变化回调 |

## 多行文本 TextEdit

```moonbit
let t = @yue.TextEdit::make(text="正文")
t.on_text_change(fn() { sync(t.get_text()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| text | String | `""` | 初始文本 |
| on_text_change | () -> Unit | 空操作 | 内容变化回调 |

| 方法 | 用途 |
|---|---|
| get_text() / set_text(t) | 读 / 设全文 |
| undo() / redo() / can_undo() / can_redo() | 撤销重做 |
| cut() / copy() / paste() | 剪贴板编辑 |
| select_all() / select_range(start, end) | 选区 |
| get_text_in_range(start, end) | 读区间文本 |
| insert_text(t) / insert_text_at(t, pos) | 插入 |
| delete() / delete_range(start, end) | 删除 |
| get_text_bounds_height() | 文本实际高度（自适应高度布局用） |
| on_text_change(fn()) | 内容变化回调 |

## 滑块 Slider

```moonbit
let s = @yue.Slider::make(value=0.0, range=Some((0.0, 100.0)), step=Some(1.0))
s.on_value_change(fn() { update(s.get_value()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| value | Double | 0.0 | 初值 |
| range | (Double, Double)? | None | 量程（min, max） |
| step | Double? | None | 步长 |
| on_value_change | () -> Unit | 空操作 | 值变化回调（不带参数，取值用 get_value） |

| 方法 | 用途 |
|---|---|
| get_value() / set_value(v) | 读 / 设当前值 |
| set_range(min, max) / set_step(d) | 量程 / 步长 |
| on_value_change(fn()) | 值变化回调 |
| on_sliding_complete(fn()) | 拖动结束回调 |

## 进度条 ProgressBar

```moonbit
let p = @yue.ProgressBar::make(value=0.43)
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| value | Double | 0.0 | 初值，取值 0..1 |
| indeterminate | Bool | false | 往返滚动模式 |

| 方法 | 用途 |
|---|---|
| set_value(v) | 设值（0..1） |
| set_indeterminate(b) | 往返滚动模式 |

## 选择器 Picker

```moonbit
let p = @yue.Picker::make(items=["甲", "乙", "丙"], selected=0)
p.on_selection_change(fn() { refresh(p.get_selected_item_index()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| items | Array[String] | `[]` | 选项列表 |
| selected | Int | 0 | 初始选中下标 |
| on_selection_change | () -> Unit | 空操作 | 选择变化回调 |

| 方法 | 用途 |
|---|---|
| add_item(t) / remove_item_at(i) / clear() | 维护选项 |
| select_item_at(i) | 选中 |
| get_selected_item() / get_selected_item_index() | 读选中项 |
| on_selection_change(fn()) | 选择变化回调 |

## 组合框 ComboBox（可编辑）

```moonbit
let c = @yue.ComboBox::make(items=["红", "绿"])
c.on_text_change(fn() { refresh(c.get_text()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| items | Array[String] | `[]` | 选项列表 |
| selected | Int | 0 | 初始选中下标 |
| on_selection_change | () -> Unit | 空操作 | 选项变化回调 |
| on_text_change | () -> Unit | 空操作 | 编辑区文本变化回调 |

| 方法 | 用途 |
|---|---|
| add_item(t) / select_item_at(i) / get_selected_item() | 同 Picker |
| get_text() / set_text(t) | 读 / 设编辑区文本 |
| on_selection_change(fn()) / on_text_change(fn()) | 两个变化回调 |

## 日期 DatePicker

```moonbit
let d = @yue.DatePicker::make(epoch=Some(1700000000L))
d.on_date_change(fn() { show(d.get_date()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| epoch | Int64? | None | 初始日期（Unix epoch 秒） |
| on_date_change | () -> Unit | 空操作 | 日期变化回调 |

| 方法 | 用途 |
|---|---|
| get_date() / set_date(epoch_seconds) | 读 / 设日期（epoch 秒） |
| on_date_change(fn()) | 日期变化回调 |

隐藏步进器等定制用 `DatePicker::new_with(DatePickerOptions)`。

## 分组 Group / 滚动 Scroll / 分隔线 Separator

```moonbit
let g = @yue.Group::make("标题", content_view)
let sc = @yue.Scroll::make(content_view, policy=Some((Automatic, Automatic)))
let sep = @yue.Separator::make(Horizontal)   // 或 Vertical
```

`Group::make` 入参：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| title | String | 必填 | 标题 |
| content | T : ViewLike | 必填 | 内容视图（内部走 set_content） |

`Scroll::make` 入参：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| content | T : ViewLike | 必填 | 内容视图 |
| content_size | (Double, Double)? | None | 内容尺寸；不传则整页滚动跟随内容自然高度 |
| policy | (ScrollPolicy, ScrollPolicy)? | None | 滚动条策略（水平, 垂直）：Always / Never / Automatic |
| overlay | Bool | false | 覆盖式滚动条 |

`Separator::make` 入参：`orientation : Orientation = Horizontal`（Horizontal / Vertical）。

| 方法 | 用途 |
|---|---|
| Group::set_title(t) | 改标题 |
| Scroll::set_content(v) | 换内容 |
| Scroll::set_content_size(w, h) | 显式设内容尺寸 |
| Scroll::set_scroll_position(h, v) | 设滚动位置 |
| Scroll::set_scrollbar_policy(h, v) / set_overlay_scrollbar(b) | 滚动条 |

## 页签 Tab

```moonbit
let t = @yue.Tab::make(pages=[("第一页", page1), ("第二页", page2)])
t.on_selected_page_change(fn() { switch_to(t.get_selected_page_index()) })
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| pages | Array[(String, Container)] | `[]` | 页标题与页内容（每页通常一个 Container） |
| on_change | () -> Unit | 空操作 | 切页回调 |

| 方法 | 用途 |
|---|---|
| add_page(title, v) / remove_page(v) | 维护页 |
| select_page_at(i) / get_selected_page_index() / page_count() | 选中与查询 |
| on_selected_page_change(fn()) | 切页回调 |

页内容器是独立 yoga 子树的根；声明式建页见 [docs/declarative.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/declarative.md) 的 `tab` 节点。

## 画布与图片

任意视图绘制：

```moonbit
view.on_draw(fn(painter) {
  painter.set_fill_color("#FF8800")
  painter.fill_rect(0.0, 0.0, 80.0, 80.0)
  painter.set_blend_mode(@yue.Multiply)   // 25 种混合模式
})
```

Painter 常用方法：

| 方法 | 用途 |
|---|---|
| set_fill_color(hex) / set_stroke_color(hex) | 颜色 |
| fill_rect / stroke_rect / clip_rect(x, y, w, h) | 矩形绘制 / 裁剪 |
| begin_path / close_path / move_to / line_to / arc / bezier_curve_to | 路径 |
| fill() / stroke() | 提交路径 |
| save() / restore() / translate / scale / rotate | 变换 |
| draw_text(...) / draw_attributed_text(...) | 文本 |
| draw_image(...) / draw_image_from_rect(...) | 图片 |
| draw_canvas(...) / draw_canvas_from_rect(...) | 离屏画布 |
| set_blend_mode(m) | 混合模式（BlendMode） |

图片与离屏位图：

```moonbit
let img = @yue.Image::new_from_file("a.png")
let slot = @yue.ImageSlot::new()   // 显示图片的控件
slot.set(Some(img))
```

| API | 用途 |
|---|---|
| Image::new_from_file(path) / new_from_png(bytes, scale?) | 加载 |
| img.resize(w, h, scale?) / get_width() / get_height() | 缩放与尺寸 |
| img.write_to_file(format, path) | 导出 |
| img.is_empty() / get_scale_factor() | 状态 |
| Canvas::new(w, h) + get_painter() | 离屏位图 |
| ImageSlot::new() + set(img?) / get() | 图片显示控件 |

富文本：

```moonbit
let at = @yue.AttributedText::new("一段文本", wrap=true, ellipsis=false)
at.set_color_for("#FF0000", 0, 2)
```

| API | 用途 |
|---|---|
| AttributedText::new(text, align?, valign?, wrap?, ellipsis?) | 创建 |
| set_font_for(font, start, end) / set_color_for(hex, start, end) | 按区间设属性（Windows 降级，见「固有坑」） |
| set_font(f) / set_color(hex) / set_text / set_format | 全文属性 |
| get_bounds_for(w, h) | 布局包围盒 |
| Font::new(name, size, weight?, style?) | 字体 |

## 浏览器 Browser

```moonbit
let b = @yue.Browser::make(url="https://example.com")   // 或 html="<h1>本地</h1>"
```

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| url | String | `""` | 加载的地址 |
| html | String | `""` | 加载的 HTML；url 与 html 都给时以 url 为准 |

| 方法 | 用途 |
|---|---|
| load_url(u) / load_html(html, base_url?) | 加载 |
| get_url() / reload() | 当前地址 / 重载 |
| go_back() / go_forward() / can_go_back() / can_go_forward() | 导航 |
| is_loading() | 加载状态 |
| set_user_agent(s) | UA |
| execute_javascript(code) | 执行 JS |
| register_protocol(scheme, fn(url) -> (mime, content)?) | 自定义协议（返回 None 拒绝） |
| unregister_protocol(scheme) | 注销协议 |
| get_cookies_for_url(url, fn(cookies)) | 查 Cookie（见「固有坑」） |
| on_change_loading / on_update_title / on_commit_navigation / on_finish_navigation | 事件 |

定制选项用 `Browser::new_with_options(BrowserOptions)`。

## 剪贴板 Clipboard

```moonbit
let clip = @yue.Clipboard::get()
clip.set_text("文本")
```

| 方法 | 用途 |
|---|---|
| Clipboard::get() | 默认剪贴板 |
| Clipboard::from_type(t) | 按类型取：CopyPaste / Selection（Linux 主选区） |
| set_text(t) / get_text() | 文本 |
| set_data(kind, t) / get_data(kind) / set_data_image(img) | 结构化数据 |
| clear() | 清空 |

## 通知 Notification / 通知中心

```moonbit
let n = @yue.Notification::new()
n.set_title("标题"); n.set_body("正文")
n.show()
```

| 方法 | 用途 |
|---|---|
| set_title(t) / set_body(s) | 内容 |
| set_silent(b) | 静默 |
| set_actions([(id, 标题)]) | 按钮（配合 NotificationCenter 的 action 回调） |
| show() | 发送（Linux 必须经此，见 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)） |
| close() | 关闭 |
| NotificationCenter::get() + add(n) | 经通知中心发送 |

## 消息框 MessageBox

```moonbit
let box = @yue.MessageBox::new(Information)
box.add_button("好", 1)
box.on_response(fn(response) { ... })
box.show_for_window(win)
```

| 方法 | 用途 |
|---|---|
| MessageBox::new(type_) | 类型（MessageBoxType） |
| set_title / set_text / set_informative_text | 文本 |
| add_button(title, response) | 自定义按钮 |
| on_response(fn(response)) | 按钮响应（response 为按钮编号） |
| show() / show_for_window(win) / close() | 弹出（模态）/ 关闭 |

## 文件对话框 FileDialog

```moonbit
let fd = @yue.FileDialog::new_open()
fd.set_filters("图片:png,jpg|全部:*")
if fd.run_for_window(win) { fd.get_result() }
```

| 方法 | 用途 |
|---|---|
| new_open() / new_save() | 打开 / 保存 |
| set_filters("描述:扩展1,扩展2\|描述2:扩展3") | 过滤器（`*` 匹配全部） |
| set_folder(path) / set_filename(name) | 初始目录 / 文件名 |
| set_options(FILE_OPTION_PICK_FOLDERS \| MULTI_SELECT \| SHOW_HIDDEN) | 选项位组合 |
| run_for_window(win) -> Bool | 模态运行 |
| get_result() | 结果路径 |

文件读写：`read_text_file(path) -> String?`、`read_binary_file(path) -> Bytes?`、
`write_text_file(path, content) -> Bool`。

## 菜单 MenuBar / Menu / MenuItem

```moonbit
let mb = @yue.MenuBar::new()
let m = mb.add_menu("文件")
m.add_label_item("打开").on_click(fn() { ... })
win.set_menubar(mb)
```

| API | 用途 |
|---|---|
| MenuBar::new() + add_menu(title) -> Menu | 菜单条 |
| Menu::new() | 弹出菜单（配 popup_at(x, y)） |
| add_label_item(t) / add_check_item(t) / add_radio_item(t) | 普通项 / 复选 / 单选 |
| add_role_item(role) / add_submenu(title) / add_separator() | 系统角色项 / 子菜单 / 分隔线 |
| MenuItem::on_click(fn()) | 点击回调 |
| MenuItem::is_checked() / set_checked(b) | 勾选 |
| MenuItem::get_label() / set_label(t) / set_accelerator(s) | 文本与快捷键 |
| Menu::item_count() / item_at(i)；MenuBar 同 | 遍历 |

## 托盘 Tray

```moonbit
let tray = match @yue.Tray::new("icon.png") {
  Ok(t) => t
  Err(e) => ...   // 后端缺失或图标读取失败
}
```

| API | 用途 |
|---|---|
| Tray::is_supported() | 后端是否可用 |
| Tray::new(icon_path) -> Result[Tray, TrayError] | 创建（结构化报错） |
| set_icon(path) / set_icon_name(name) | 换图标（主题名仅 Linux SNI） |
| set_title(t) | 部分平台无此概念，空操作 |
| set_tooltip(title, body) | 悬浮提示（仅 Linux SNI） |
| on_click(fn()) | 点击回调 |
| set_menu(menu) | 挂右键菜单 |
| remove() | 移除图标 |

Linux 推荐纯 MoonBit 的 `yue/traybus` 后端（`Tray` 统一 API 内部自动选择），
方案见 [docs/tray.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/tray.md)。

## 气泡 Popover

```moonbit
let pop = @yue.Popover::new()
pop.set_content(view)
pop.show_relative_to(anchor_view)
```

| 方法 | 用途 |
|---|---|
| set_content(v) / set_content_size(w, h) | 内容与尺寸 |
| show_relative_to(v) | 弹出到目标视图附近 |
| close() / on_close(fn()) | 关闭 |

## 全局快捷键 / 光标 / 系统

| API | 用途 |
|---|---|
| register_global_shortcut("CmdOrCtrl+Shift+M", fn()) -> Int | 注册，返回 id；-1 为被占用（需换键） |
| unregister_global_shortcut(id) | 注销 |
| Cursor::new(type_) + view.set_cursor(c) | 光标（CursorType） |
| Appearance::is_dark() | 深色外观 |
| locale() | 区域 |
| Screen::scale_factor() / primary_size() | 缩放 / 主屏尺寸 |
| App::set_name(s) / App::get_name() | 应用名 |
| desktop_environment() | 桌面环境名（诊断用） |

## 事件（所有控件通用）

所有控件（`ViewLike`）支持：

| 方法 | 用途 |
|---|---|
| on_mouse_down / up / move / enter / leave | 鼠标 |
| on_key_down / up | 键盘 |
| on_size_changed | 尺寸变化 |
| set_capture(b) / release_capture() / has_capture() | 鼠标捕获 |
| set_style(k, v) / set_style_str(k, v) | 布局样式 |
| 拖拽注册与拖放回调 | 拖放（接收方必须注册 handle_drag_update 返回允许的操作位，缺省一律拒绝；演示见 components「窗口与网页」页） |

事件载荷字段：

| 结构 | 字段 |
|---|---|
| MouseEvent | kind、button（1=左 2=右 3=中）、view_x/view_y（相对视图）、window_x/window_y（相对窗口）、screen_x/screen_y（屏幕全局坐标，右键菜单等按事件位置弹出直接用）、modifiers、timestamp |
| KeyEvent | kind、code（VKEY_* 常量）、modifiers、timestamp |

`modifiers` 位：1=Shift 2=Ctrl 4=Alt 8=Meta；`KeyEvent::describe()` 输出
"Ctrl+A" 形式。键码常量表跨平台统一（Windows VK 码在事件入口归一化），
见 `yue/events.mbt`；连击计数用 `ClickTracker`（默认 400ms / 5px）。

---

## 固有坑

上游 libyue 或平台行为带来，使用对应 API 前先读：

1. **`Browser::get_cookies_for_url` 可能崩溃**：目标站点尚无任何 Cookie 时，
   上游内部 `CHECK(cookies)` 直接 FATAL（libyue 0.15.6 实测）。只对确定已
   存有 Cookie 的站点调用，或等上游修复。
2. **Browser 会改写窗口标题**：WebKitGTK 加载网页后把页面 `<title>` 同步为
   窗口标题，且切走页签后不会恢复。依赖窗口标题做窗口管理的工具会受影响。
3. **复选/单选的初始化回调**：以 `checked=true` 创建的 Checkbox/Radio，
   挂载完成进入事件循环后会**异步收到一次回调**（GTK toggled 信号语义）。
   回调逻辑依赖状态时先 `is_checked()` 判断，或容忍这次初始通知。
4. **单选组切换是双通知**：点选新项时，被取消选中的旧项也会收到一次回调
   （此时旧项 `is_checked()==false`）。按"新选中的那个"处理业务即可。
5. **虚拟键码是 GTK 表**：`VKEY_ESCAPE = 0xFF1B`（65307），不是 Windows
   VK 值；字母与数字与 ASCII 相同。跨平台代码不要混用两张表。
6. **样式键的解析规则**：只保留 ASCII 字母并转小写，`flexDirection` /
   `flex-direction` / `flexdirection` 等价；**数字和连字符以外的符号会被丢弃**，
   不要用特殊字符拼键名。键值全集见 [docs/layout.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/layout.md)。
7. **回调自动保活，但别在回调里同步弹事件循环**：`on_*` 注册的闭包由库持有
   强引用；`Store` 订阅同理。回调里调用 `@yue.quit()` 等终止流程后不要再
   操作控件。
8. **平台专属 API 未封装**：Toolbar / Vibrant（Linux 静态库无符号）、
   Button 样式与 ControlSize、Scroll 弹性、App 激活策略、Browser 缩放、
   Image 模板图（macOS），ShortcutOptions / Lifetime::Reply / 通知
   COMServerOptions（Windows）等，完整清单见 [docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)。
