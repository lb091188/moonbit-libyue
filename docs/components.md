# 组件方法速查

面向 moonbit-libyue 使用者的组件 API 速查。所有类型经 `@yue` 引用；
每个控件都有两种用法：**逐个 setter 的经典写法**（`X::new` + setter），
或 **props 风格一步到位**（`X::make`，全部参数可选具名，仅"内容性"参数必填）。
两者的语义完全一致，`make` 只是 setter 的打包。

声明式写法（`@yue.mount` 树 + `Store` 绑定）见 [docs/declarative.md](docs/declarative.md)；
布局样式键全集见 [docs/layout.md](docs/layout.md)；
平台适配与上游缺陷的完整记录见 [docs/adaptation.md](docs/adaptation.md)。

## 窗口 Window

```moonbit
let win = @yue.Window::make(title="主窗口", size=Some((960.0, 640.0)), center=true)
win.on_close(fn(_w) { @yue.quit() })
win.set_content(content_view)   // 接受任何 ViewLike
```

其他常用：`set_title` / `set_content_size` / `center` / `activate` /
`maximize` / `unmaximize` / `set_always_on_top` / `set_should_close(fn() -> Bool)`
（返回 false 拦截关闭）/ `set_menubar` / `resizable` / `shadow` 等窗口外观开关。
需要无边框、透明、不抢焦点的窗口用 `Window::new_with_options(frame?=true, transparent?=false, no_activate?=false)`。

## 容器 Container

```moonbit
let col = @yue.Container::make(style=[("padding", 12.0)])
col.add_child(child)      // 接受任何 ViewLike
```

容器默认 `flexDirection=column`、`alignItems=stretch`；水平排列
`set_style_str("flexDirection", "row")`。样式键的解析规则与实测记录见
[docs/layout.md](docs/layout.md)。绘制用 `on_draw(fn(painter) { ... })`。

## 标签 Label

```moonbit
let l = @yue.Label::make("文本", style_str=[("color", "#356AA0")])
l.set_text("新文本")
```

## 按钮 Button（含复选框 / 单选框）

```moonbit
let b = @yue.Button::make("确定", on_click=fn() { ... })
let c = @yue.Button::make("启用", button_type=Checkbox, checked=false,
                          on_click=fn() { ... })   // 回调里用 is_checked() 读状态
let r = @yue.Button::make("主题甲", button_type=Radio, checked=true, on_click=...)
b.set_title("新标题")
```

同一父容器内的 Radio 自动互斥。

## 单行输入 Entry / 多行 TextEdit

```moonbit
let e = @yue.Entry::make(text="预填", password=false,
                         on_enter=fn(s) { ... },   // 回车，携带当前文本
                         on_input=fn(s) { ... })   // 内容变化，携带当前文本
e.get_text() / e.set_text(...)
let t = @yue.TextEdit::make(text="正文", on_input=fn(s) { ... })
```

TextEdit 另有 `undo` / `redo` / `cut` / `copy` / `paste` / `select_all` 编辑方法。

## 滑块 Slider / 进度条 ProgressBar

```moonbit
let s = @yue.Slider::make(value=0.0, range=Some((0.0, 100.0)), step=Some(1.0),
                          on_change=fn(v) { ... })     // v 为当前值
let p = @yue.ProgressBar::make(value=0.43)             // 取值 0..1
p.set_indeterminate(true)                              // 往返滚动模式
```

## 选择器 Picker / ComboBox

```moonbit
let p = @yue.Picker::make(items=["甲", "乙", "丙"], selected=0,
                          on_change=fn() { p.get_selected_item_index() })
let c = @yue.ComboBox::make(items=["红", "绿"], on_select=..., on_input=...) // 可编辑
```

`selected` 为初始选中下标；`Picker::get_selected_item() : String`、
`ComboBox::get_text() : String`。

## 日期 DatePicker

```moonbit
let d = @yue.DatePicker::make(epoch=None, on_change=fn() { d.get_date() })  // epoch 秒（Int64）
```

需要隐藏步进器等定制时用 `DatePicker::new_with(DatePickerOptions)`。

## 分组 Group / 滚动 Scroll / 分隔线 Separator

```moonbit
let g = @yue.Group::make("标题", content_view)
let sc = @yue.Scroll::make(content_view, content_size=Some((600.0, 400.0)),
                           policy=Some((Automatic, Automatic)))
let sep = @yue.Separator::make(Horizontal)   // 或 Vertical
```

## 页签 Tab

```moonbit
let t = @yue.Tab::make(pages=[("第一页", page1_container), ("第二页", page2_container)],
                       on_change=fn() { t.get_selected_page_index() })
t.select_page_at(1)
```

页内容通常各建一个 `Container`；声明式建页见 [docs/declarative.md](docs/declarative.md) 的 `tab` 节点。

## 画布与图片

离屏画布 + 任意视图绘制：

```moonbit
view.on_draw(fn(painter) {
  painter.set_fill_color("#FF8800")
  painter.fill_rect(0.0, 0.0, 80.0, 80.0)
  painter.set_blend_mode(@yue.Multiply)   // 25 种混合模式
})
```

图片：`Image::new_from_file(path)` / `Image::new_from_png(bytes)` /
`resize` / `write_to_file(format, path)` / `is_empty`。
离屏位图用 `Canvas::new(w, h)` + `get_painter`；显示图片用 `ImageSlot::new()` + `set(Some(img))`。

富文本：`AttributedText::new(text, align?=..., wrap?=true, ellipsis?=false)`，
`set_font_for(font, start, end)` / `set_color_for(hex, start, end)` 按范围设属性，
`get_bounds_for(w, h)` 查询布局包围盒。

## 浏览器 Browser

```moonbit
let b = @yue.Browser::make(url="https://example.com")   // 或 html="<h1>本地</h1>"
b.execute_javascript("document.title")
b.load_html("<p>...</p>")
b.register_protocol("demo", fn(url) { Some(("text/plain", "内容")) })
```

## 剪贴板 / 通知 / 对话框

```moonbit
let clip = @yue.Clipboard::get()
clip.set_text("文本")          // from_type(Selection) 操作主选区
let n = @yue.Notification::new()
n.set_title("标题"); n.set_body("正文")
n.set_actions([("id1", "打开")])   // 配合 NotificationCenter 的 action 回调
n.show()
let box = @yue.MessageBox::new(Information)  // add_button + on_response + show_for_window
let fd = @yue.FileDialog::new_open()         // set_filters/set_folder/get_result
```

## 菜单 / 托盘

```moonbit
let m = @yue.Menu::new()
let it = m.add_check_item("自动保存")      // 另有 add_label_item/add_radio_item/add_submenu
it.on_click(fn() { it.is_checked() })
win.set_menubar(menubar)                   // 菜单条构建见 MenuBar
```

Linux 托盘推荐纯 MoonBit 实现的 `yue/traybus`（SNI 直连面板，无 AppIndicator
运行库依赖）；`Tray::set_menu` 可直接挂上面的 `Menu` 模型（XFCE 下自绘弹出）。
方案设计（后端降级、桌面兼容性、调试方法）见 [docs/tray.md](tray.md)。

## 事件（所有控件通用）

所有控件（`ViewLike`）支持：`on_mouse_down/up/move/enter/leave`、
`on_key_down/up`、`on_size_changed`、`set_capture/release_capture`、
拖拽注册与拖放回调、`set_style` 布局属性。事件载荷结构
`MouseEvent` / `KeyEvent`（`modifiers`：1=Shift 2=Ctrl 4=Alt 8=Meta），
虚拟键码 `VKEY_*` 常量见 `yue/events.mbt`。

---

## 固有坑（务必了解）

以下坑由上游 libyue 或平台行为带来，使用对应 API 前先读一遍：

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
   不要用特殊字符拼键名。键值全集见 [docs/layout.md](docs/layout.md)。
7. **回调自动保活，但别在回调里同步弹事件循环**：`on_*` 注册的闭包由库持有
   强引用；`Store` 订阅同理。回调里调用 `@yue.quit()` 等终止流程后不要再
   操作控件。
8. **平台专属 API 未封装**：Toolbar / Vibrant（Linux 静态库无符号）、
   Button 样式与 ControlSize、Scroll 弹性、App 激活策略、Browser 缩放、
   Image 模板图（macOS），ShortcutOptions / Lifetime::Reply / 通知
   COMServerOptions（Windows）等，完整清单见 [docs/adaptation.md](docs/adaptation.md)。
