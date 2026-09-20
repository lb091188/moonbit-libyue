# Component Method Quick Reference

A quick reference of component APIs for moonbit-libyue users. All types are referenced via `@yue`;
every widget has two usage styles: the **classic per-setter approach** (`X::new` + setters),
or the **props-style one-shot approach** (`X::make`). Both are semantically identical; `make` is just a bundle of setters.

For the declarative style (`@yue.mount` tree + `Store` binding), see [docs/declarative.md](declarative.md);
for the full set of layout style keys, see [docs/layout.md](layout.md);
for the complete record of platform adaptation and upstream defects, see [docs/adaptation.md](adaptation.md).

General conventions:

- Unless stated otherwise, every `make` accepts the optional parameters
  `style : Array[(String, Double)]` and `style_str : Array[(String, String)]`
  (style key-value pairs applied at creation); these are not repeated in the tables below.
- `on_*` methods register callbacks.

## Window

```moonbit
let win = @yue.Window::make(
                title="主窗口",
                size=Some((960.0, 640.0)),
                center=true)
win.on_close(fn(_w) { @yue.quit() })
win.set_content(content_view)
```

`Window::make` parameters (no `style`; windows have no parent layout):

| Parameter | Type | Default | Description |
|---|---|---|---|
| title | String | `""` | Title |
| size | (Double, Double)? | None | Content area size (width, height) |
| on_close | (Window) -> Unit | no-op | Close callback |
| center | Bool | false | Center after creation |

Common methods:

| Method | Purpose |
|---|---|
| set_title(t) | Set title |
| set_content(v) | Set content view |
| set_content_size(w, h) / get_content_size() | Set / read content area size |
| center() / activate() | Center / activate to front |
| maximize() / unmaximize() / is_maximized() | Maximize |
| set_fullscreen(b) / is_fullscreen() | Fullscreen |
| set_always_on_top(b) | Keep on top |
| set_resizable(b) / is_resizable() | Resizable |
| set_maximizable(b) / set_minimizable(b) | Title bar button toggles |
| set_has_shadow(b) / has_shadow() | Window shadow |
| set_menubar(mb) | Attach menu bar |
| on_close(fn(_w)) | Close callback |
| set_should_close(fn() -> Bool) | Return false to intercept close |

`Window::new_with_options` parameters (frameless / transparent / overlay windows):

| Parameter | Type | Default | Description |
|---|---|---|---|
| frame | Bool | true | false for frameless |
| transparent | Bool | false | Transparent background |
| no_activate | Bool | false | Do not steal focus (overlay / panel-style windows) |

## Container

```moonbit
let col = @yue.Container::make(style=[("padding", 12.0)])
col.add_child(child)
```

Parameters are only `style` / `style_str` (see the top of this document). Defaults are `flexDirection=column`,
`alignItems=stretch`; for horizontal layout use `set_style_str("flexDirection", "row")`;
see [docs/layout.md](layout.md) for key parsing rules.

| Method | Purpose |
|---|---|
| add_child(v) | Add child view (any ViewLike) |
| on_draw(fn(painter)) | Custom drawing |

## Label

```moonbit
let l = @yue.Label::make("文本", style_str=[("color", "#356AA0")])
l.set_text("新文本")
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| text | String | required | Initial text |

| Method | Purpose |
|---|---|
| set_text(t) | Change text |

## Button (including Checkbox / Radio)

```moonbit
let b = @yue.Button::make("确定", on_click=fn() { ... })
let c = @yue.Button::make("启用", button_type=Checkbox, checked=false,
                          on_click=fn() { ... })   // read state via is_checked() in the callback
let r = @yue.Button::make("主题甲", button_type=Radio, checked=true, on_click=...)
b.set_title("新标题")
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| title | String | required | Button text |
| button_type | ButtonType | Normal | Normal / Checkbox / Radio |
| on_click | () -> Unit | no-op | Click callback |
| checked | Bool | false | Initial checked state (Checkbox / Radio) |

Radio buttons under the same parent container are mutually exclusive automatically; for the initial callback and double notification, see "Inherent Pitfalls" at the end of this document.

| Method | Purpose |
|---|---|
| set_title(t) | Change text |
| is_checked() / set_checked(b) | Read / set checked state |
| on_click(fn()) | Click callback |

## Entry

```moonbit
let e = @yue.Entry::make(text="预填", entry_type=Password)
e.on_activate(fn() { check(e.get_text()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| text | String | `""` | Initial text |
| entry_type | EntryType | Normal | Normal / Password |
| on_activate | () -> Unit | no-op | Enter callback (no parameter; use get_text to read the text) |
| on_text_change | () -> Unit | no-op | Content change callback (same as above) |

| Method | Purpose |
|---|---|
| get_text() / set_text(t) | Read / set text |
| on_activate(fn()) | Enter callback |
| on_text_change(fn()) | Content change callback |

## TextEdit

```moonbit
let t = @yue.TextEdit::make(text="正文")
t.on_text_change(fn() { sync(t.get_text()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| text | String | `""` | Initial text |
| on_text_change | () -> Unit | no-op | Content change callback |

| Method | Purpose |
|---|---|
| get_text() / set_text(t) | Read / set full text |
| undo() / redo() / can_undo() / can_redo() | Undo and redo |
| cut() / copy() / paste() | Clipboard editing |
| select_all() / select_range(start, end) | Selection |
| get_text_in_range(start, end) | Read text in range |
| insert_text(t) / insert_text_at(t, pos) | Insert |
| delete() / delete_range(start, end) | Delete |
| get_text_bounds_height() | Actual height of the text (for auto-height layouts) |
| on_text_change(fn()) | Content change callback |

## Slider

```moonbit
let s = @yue.Slider::make(value=0.0, range=Some((0.0, 100.0)), step=Some(1.0))
s.on_value_change(fn() { update(s.get_value()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| value | Double | 0.0 | Initial value |
| range | (Double, Double)? | None | Range (min, max) |
| step | Double? | None | Step size |
| on_value_change | () -> Unit | no-op | Value change callback (no parameter; use get_value to read the value) |

| Method | Purpose |
|---|---|
| get_value() / set_value(v) | Read / set current value |
| set_range(min, max) / set_step(d) | Range / step size |
| on_value_change(fn()) | Value change callback |
| on_sliding_complete(fn()) | Drag-completed callback |

## ProgressBar

```moonbit
let p = @yue.ProgressBar::make(value=0.43)
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| value | Double | 0.0 | Initial value, in 0..1 |
| indeterminate | Bool | false | Back-and-forth scrolling mode |

| Method | Purpose |
|---|---|
| set_value(v) | Set value (0..1) |
| set_indeterminate(b) | Back-and-forth scrolling mode |

## Picker

```moonbit
let p = @yue.Picker::make(items=["甲", "乙", "丙"], selected=0)
p.on_selection_change(fn() { refresh(p.get_selected_item_index()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| items | Array[String] | `[]` | Option list |
| selected | Int | 0 | Initially selected index |
| on_selection_change | () -> Unit | no-op | Selection change callback |

| Method | Purpose |
|---|---|
| add_item(t) / remove_item_at(i) / clear() | Maintain options |
| select_item_at(i) | Select |
| get_selected_item() / get_selected_item_index() | Read selected item |
| on_selection_change(fn()) | Selection change callback |

## ComboBox (editable)

```moonbit
let c = @yue.ComboBox::make(items=["红", "绿"])
c.on_text_change(fn() { refresh(c.get_text()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| items | Array[String] | `[]` | Option list |
| selected | Int | 0 | Initially selected index |
| on_selection_change | () -> Unit | no-op | Option change callback |
| on_text_change | () -> Unit | no-op | Edit field text change callback |

| Method | Purpose |
|---|---|
| add_item(t) / select_item_at(i) / get_selected_item() | Same as Picker |
| get_text() / set_text(t) | Read / set edit field text |
| on_selection_change(fn()) / on_text_change(fn()) | The two change callbacks |

## DatePicker

```moonbit
let d = @yue.DatePicker::make(epoch=Some(1700000000L))
d.on_date_change(fn() { show(d.get_date()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| epoch | Int64? | None | Initial date (Unix epoch seconds) |
| on_date_change | () -> Unit | no-op | Date change callback |

| Method | Purpose |
|---|---|
| get_date() / set_date(epoch_seconds) | Read / set date (epoch seconds) |
| on_date_change(fn()) | Date change callback |

For customizations such as hiding the steppers, use `DatePicker::new_with(DatePickerOptions)`.

## Group / Scroll / Separator

```moonbit
let g = @yue.Group::make("标题", content_view)
let sc = @yue.Scroll::make(content_view, policy=Some((Automatic, Automatic)))
let sep = @yue.Separator::make(Horizontal)   // or Vertical
```

`Group::make` parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| title | String | required | Title |
| content | T : ViewLike | required | Content view (set via set_content internally) |

`Scroll::make` parameters:

| Parameter | Type | Default | Description |
|---|---|---|---|
| content | T : ViewLike | required | Content view |
| content_size | (Double, Double)? | None | Content size; if omitted, the whole page scrolls following the content's natural height |
| policy | (ScrollPolicy, ScrollPolicy)? | None | Scrollbar policy (horizontal, vertical): Always / Never / Automatic |
| overlay | Bool | false | Overlay scrollbars |

`Separator::make` parameters: `orientation : Orientation = Horizontal` (Horizontal / Vertical).

| Method | Purpose |
|---|---|
| Group::set_title(t) | Change title |
| Scroll::set_content(v) | Replace content |
| Scroll::set_content_size(w, h) | Explicitly set content size |
| Scroll::set_scroll_position(h, v) | Set scroll position |
| Scroll::set_scrollbar_policy(h, v) / set_overlay_scrollbar(b) | Scrollbars |

## Tab

```moonbit
let t = @yue.Tab::make(pages=[("第一页", page1), ("第二页", page2)])
t.on_selected_page_change(fn() { switch_to(t.get_selected_page_index()) })
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| pages | Array[(String, Container)] | `[]` | Page titles and contents (usually one Container per page) |
| on_change | () -> Unit | no-op | Page switch callback |

| Method | Purpose |
|---|---|
| add_page(title, v) / remove_page(v) | Maintain pages |
| select_page_at(i) / get_selected_page_index() / page_count() | Selection and queries |
| on_selected_page_change(fn()) | Page switch callback |

Each page's container is the root of an independent yoga subtree; for building pages declaratively, see the `tab` node in [docs/declarative.md](declarative.md).

## Canvas and Images

Custom drawing on any view:

```moonbit
view.on_draw(fn(painter) {
  painter.set_fill_color("#FF8800")
  painter.fill_rect(0.0, 0.0, 80.0, 80.0)
  painter.set_blend_mode(@yue.Multiply)   // 25 blend modes
})
```

Common Painter methods:

| Method | Purpose |
|---|---|
| set_fill_color(hex) / set_stroke_color(hex) | Colors |
| fill_rect / stroke_rect / clip_rect(x, y, w, h) | Rectangle drawing / clipping |
| begin_path / close_path / move_to / line_to / arc / bezier_curve_to | Paths |
| fill() / stroke() | Commit path |
| save() / restore() / translate / scale / rotate | Transforms |
| draw_text(...) / draw_attributed_text(...) | Text |
| draw_image(...) / draw_image_from_rect(...) | Images |
| draw_canvas(...) / draw_canvas_from_rect(...) | Offscreen canvas |
| set_blend_mode(m) | Blend mode (BlendMode) |

Images and offscreen bitmaps:

```moonbit
let img = @yue.Image::new_from_file("a.png")
let slot = @yue.ImageSlot::new()   // the widget that displays the image
slot.set(Some(img))
```

| API | Purpose |
|---|---|
| Image::new_from_file(path) / new_from_png(bytes, scale?) | Loading |
| img.resize(w, h, scale?) / get_width() / get_height() | Scaling and dimensions |
| img.write_to_file(format, path) | Export |
| img.is_empty() / get_scale_factor() | State |
| Canvas::new(w, h) + get_painter() | Offscreen bitmap |
| ImageSlot::new() + set(img?) / get() | Image display widget |

Attributed text:

```moonbit
let at = @yue.AttributedText::new("一段文本", wrap=true, ellipsis=false)
at.set_color_for("#FF0000", 0, 2)
```

| API | Purpose |
|---|---|
| AttributedText::new(text, align?, valign?, wrap?, ellipsis?) | Creation |
| set_font_for(font, start, end) / set_color_for(hex, start, end) | Set attributes per range (degraded on Windows; see "Inherent Pitfalls") |
| set_font(f) / set_color(hex) / set_text / set_format | Whole-text attributes |
| get_bounds_for(w, h) | Layout bounding box |
| Font::new(name, size, weight?, style?) | Font |

## Browser

```moonbit
let b = @yue.Browser::make(url="https://example.com")   // or html="<h1>本地</h1>"
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| url | String | `""` | URL to load |
| html | String | `""` | HTML to load; if both url and html are given, url wins |

| Method | Purpose |
|---|---|
| load_url(u) / load_html(html, base_url?) | Loading |
| get_url() / reload() | Current URL / reload |
| go_back() / go_forward() / can_go_back() / can_go_forward() | Navigation |
| is_loading() | Loading state |
| set_user_agent(s) | UA |
| execute_javascript(code) | Execute JS |
| register_protocol(scheme, fn(url) -> (mime, content)?) | Custom protocol (return None to refuse) |
| unregister_protocol(scheme) | Unregister protocol |
| get_cookies_for_url(url, fn(cookies)) | Query cookies (see "Inherent Pitfalls") |
| on_change_loading / on_update_title / on_commit_navigation / on_finish_navigation | Events |

For customization options, use `Browser::new_with_options(BrowserOptions)`.

## Clipboard

```moonbit
let clip = @yue.Clipboard::get()
clip.set_text("文本")
```

| Method | Purpose |
|---|---|
| Clipboard::get() | Default clipboard |
| Clipboard::from_type(t) | Get by type: CopyPaste / Selection (Linux primary selection) |
| set_text(t) / get_text() | Text |
| set_data(kind, t) / get_data(kind) / set_data_image(img) | Structured data |
| clear() | Clear |

## Notification / Notification Center

```moonbit
let n = @yue.Notification::new()
n.set_title("标题"); n.set_body("正文")
n.show()
```

| Method | Purpose |
|---|---|
| set_title(t) / set_body(s) | Content |
| set_silent(b) | Silent |
| set_actions([(id, title)]) | Buttons (used with NotificationCenter's action callbacks) |
| show() | Send (on Linux this is mandatory; see [docs/adaptation.md](adaptation.md)) |
| close() | Close |
| NotificationCenter::get() + add(n) | Send via the notification center |

## MessageBox

```moonbit
let box = @yue.MessageBox::new(Information)
box.add_button("好", 1)
box.on_response(fn(response) { ... })
box.show_for_window(win)
```

| Method | Purpose |
|---|---|
| MessageBox::new(type_) | Type (MessageBoxType) |
| set_title / set_text / set_informative_text | Text |
| add_button(title, response) | Custom buttons |
| on_response(fn(response)) | Button response (response is the button number) |
| show() / show_for_window(win) / close() | Show (modal) / close |

## FileDialog

```moonbit
let fd = @yue.FileDialog::new_open()
fd.set_filters("图片:png,jpg|全部:*")
if fd.run_for_window(win) { fd.get_result() }
```

| Method | Purpose |
|---|---|
| new_open() / new_save() | Open / save |
| set_filters("描述:扩展1,扩展2\|描述2:扩展3") | Filters (`*` matches all) |
| set_folder(path) / set_filename(name) | Initial directory / filename |
| set_options(FILE_OPTION_PICK_FOLDERS \| MULTI_SELECT \| SHOW_HIDDEN) | Option bit combination |
| run_for_window(win) -> Bool | Run modally |
| get_result() | Result path |

File I/O: `read_text_file(path) -> String?`, `read_binary_file(path) -> Bytes?`,
`write_text_file(path, content) -> Bool`.

## MenuBar / Menu / MenuItem

```moonbit
let mb = @yue.MenuBar::new()
let m = mb.add_menu("文件")
m.add_label_item("打开").on_click(fn() { ... })
win.set_menubar(mb)
```

| API | Purpose |
|---|---|
| MenuBar::new() + add_menu(title) -> Menu | Menu bar |
| Menu::new() | Popup menu (with popup_at(x, y)) |
| add_label_item(t) / add_check_item(t) / add_radio_item(t) | Plain / checkbox / radio items |
| add_role_item(role) / add_submenu(title) / add_separator() | System role items / submenu / separator |
| MenuItem::on_click(fn()) | Click callback |
| MenuItem::is_checked() / set_checked(b) | Checked state |
| MenuItem::get_label() / set_label(t) / set_accelerator(s) | Text and accelerator |
| Menu::item_count() / item_at(i); same for MenuBar | Iteration |

## Tray

```moonbit
let tray = match @yue.Tray::new("icon.png") {
  Ok(t) => t
  Err(e) => ...   // backend missing or icon read failure
}
```

| API | Purpose |
|---|---|
| Tray::is_supported() | Whether the backend is available |
| Tray::new(icon_path) -> Result[Tray, TrayError] | Create (with structured errors) |
| set_icon(path) / set_icon_name(name) | Change icon (theme name is Linux SNI only) |
| set_title(t) | No-op on platforms without this concept |
| set_tooltip(title, body) | Hover tooltip (Linux SNI only) |
| on_click(fn()) | Click callback |
| set_menu(menu) | Attach context menu |
| remove() | Remove icon |

On Linux the pure MoonBit `yue/traybus` backend is recommended (the unified `Tray` API selects it automatically);
see [docs/tray.md](tray.md) for details.

## Popover

```moonbit
let pop = @yue.Popover::new()
pop.set_content(view)
pop.show_relative_to(anchor_view)
```

| Method | Purpose |
|---|---|
| set_content(v) / set_content_size(w, h) | Content and size |
| show_relative_to(v) | Pop up near the target view |
| close() / on_close(fn()) | Close |

## Global Shortcuts / Cursor / System

| API | Purpose |
|---|---|
| register_global_shortcut("CmdOrCtrl+Shift+M", fn()) -> Int | Register; returns id; -1 means already taken (use another key) |
| unregister_global_shortcut(id) | Unregister |
| Cursor::new(type_) + view.set_cursor(c) | Cursor (CursorType) |
| Appearance::is_dark() | Dark appearance |
| locale() | Locale |
| Screen::scale_factor() / primary_size() | Scale / primary screen size |
| App::set_name(s) / App::get_name() | Application name |
| desktop_environment() | Desktop environment name (for diagnostics) |

## Events (common to all widgets)

All widgets (`ViewLike`) support:

| Method | Purpose |
|---|---|
| on_mouse_down / up / move / enter / leave | Mouse |
| on_key_down / up | Keyboard |
| on_size_changed | Size changes |
| set_capture(b) / release_capture() / has_capture() | Mouse capture |
| set_style(k, v) / set_style_str(k, v) | Layout styles |
| Drag registration and drop callbacks | Drag and drop (receivers must also register handle_drag_update returning allowed operations; without it every drag is rejected; demo in the components example, "Windows & Web" page) |

Event payload fields:

| Struct | Fields |
|---|---|
| MouseEvent | kind, button (1=left 2=right 3=middle), view_x/view_y (relative to view), window_x/window_y (relative to window), screen_x/screen_y (global screen coordinates, use directly for event-position popups like context menus), modifiers, timestamp |
| KeyEvent | kind, code (VKEY_* constants), modifiers, timestamp |

`modifiers` bits: 1=Shift 2=Ctrl 4=Alt 8=Meta; `KeyEvent::describe()` outputs
strings like "Ctrl+A". The key code constant table is unified across platforms (Windows VK codes are normalized at the event entry point),
see `yue/events.mbt`; for click counting use `ClickTracker` (default 400ms / 5px).

---

## Inherent Pitfalls

Caused by upstream libyue or platform behavior; read before using the corresponding APIs:

1. **`Browser::get_cookies_for_url` may crash**: when the target site has no cookies at all yet,
   the upstream internal `CHECK(cookies)` hits FATAL directly (verified with libyue 0.15.6). Only call it on sites
   that are known to already have cookies, or wait for an upstream fix.
2. **Browser rewrites the window title**: after WebKitGTK loads a page, it syncs the page's `<title>` to
   the window title and does not restore it after switching tabs. This affects tools that rely on window titles for window management.
3. **Initial callback for Checkbox/Radio**: a Checkbox/Radio created with `checked=true`
   will **asynchronously receive one callback** after mounting and entering the event loop (GTK toggled signal semantics).
   If callback logic depends on state, check `is_checked()` first, or tolerate this initial notification.
4. **Radio group switching is a double notification**: when a new item is selected, the deselected old item also receives a callback
   (at which point the old item's `is_checked()==false`). Just handle the business based on "the newly selected one".
5. **Virtual key codes use the GTK table**: `VKEY_ESCAPE = 0xFF1B` (65307), not the Windows
   VK value; letters and digits match ASCII. Do not mix the two tables in cross-platform code.
6. **Style key parsing rules**: only ASCII letters are kept and lowercased, so `flexDirection` /
   `flex-direction` / `flexdirection` are equivalent; **symbols other than digits and hyphens are dropped**,
   so do not use special characters in key names. See [docs/layout.md](layout.md) for the full key list.
7. **Callbacks are kept alive automatically, but do not synchronously pump the event loop inside a callback**: closures registered via `on_*` are held
   by the library with strong references; the same applies to `Store` subscriptions. After calling termination flows like `@yue.quit()` inside a callback,
   do not touch widgets anymore.
8. **Platform-specific APIs not wrapped**: Toolbar / Vibrant (no symbols in the Linux static library),
   Button styles and ControlSize, Scroll bounce, App activation policy, Browser zoom,
   Image template images (macOS), ShortcutOptions / Lifetime::Reply / notification
   COMServerOptions (Windows), etc.; see [docs/adaptation.md](adaptation.md) for the complete list.
