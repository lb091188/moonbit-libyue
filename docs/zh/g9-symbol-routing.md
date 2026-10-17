# G9 收尾：@core 符号路由表

全量替换 `@core.X` → 直连目标包后，删除 `gui/core/compat*.mbt`。
本表是迁移期唯一的查找字典。

## @base（响应式内核 / 几何 / 键码 / 记账）

| 类别 | 符号 |
|------|------|
| 类型 | `Signal[T]` `Store[T]` `ListStore[T]` `Item` `KeyDiff[T]` `FocusStack` `Rect` |
| 函数 | `batch` `watch` `watch_store` `index_diff` `index_same` `keyed_diff` `keyed_align` `next_tick` `tick_pending` `tick_flush` `tick_clear` `prof_record` `paint_profile_reset` `paint_profile_summary` `keysym_is_printable` `sub_bag_register` `sub_bag_begin` `sub_bag_end` `sub_bag_discard` |
| 常量 | `MOD_SHIFT` `MOD_CTRL` `MOD_ALT` `MOD_META` `KS_BACKSPACE` `KS_TAB` `KS_SPACE` `KS_RETURN` `KS_ESCAPE` `KS_LEFT` `KS_UP` `KS_RIGHT` `KS_DOWN` `KS_HOME` `KS_END` `KS_DELETE` `KS_ISO_LEFT_TAB` |

## @shell（壳层窗 / 泵 / 系统能力）

| 类别 | 符号 |
|------|------|
| 类型 | `Menu` `MenuBar` `MenuItem` `MenuRole` `MenuItemKind` `Hotkey` `HotkeyError` `Tray` `TrayBackend` `TrayError` `NotifyBackend` `NotifyError` `NotifyCaps` `Loop` `Job` `Session` |
| 函数 | `dispatch_menu_command` `dispatch_tray_event` `menu_role_id` `hotkey_supported` `hotkey_register` `hotkey_unregister` `hotkey_poll` `hotkey_registered_count` `notify_supported` `notify_send` `reveal_in_file_manager` `set_timer_hooks` `set_timeout` `clear_timeout` `now_ms` `sys_color_scheme` `sys_accent` `local_ymd` `host_loop` `host_new_wid` `host_window_count` `host_close_action` `host_add_session` `host_deregister` `host_mark_active` `shell_sessions` `session_active` |

## @widget（控件宿主 / App / 声明式 / 浮层 / 拖放 / 输入映射）

| 类别 | 符号 |
|------|------|
| 类型 | `App` `Widget` `Node` `OverlayHost` `OverlayItem` `DragData` `DataKind` `DragSession` `DragEffect` `DragError` `ImeRoute` `RawEvent` `PointerKind` `PointerEvent` `KeyEvent` `ScrollEvent` |
| 常量 | `CURSOR_DEFAULT` `CURSOR_HAND` `CURSOR_TEXT` `CURSOR_RESIZE_H` `CURSOR_RESIZE_V` |
| 函数 | `fake_session` `test_app` `overlay_native_tier` `overlay_native_count` `overlay_fit_pass` `overlay_set_dismiss_on_blur` `overlay_dismiss_on_blur` `overlay_on_lost_focus` `overlay_close_all_native` `data_kind_id` `data_kind_of_id` `drag_encode` `drag_decode` `set_drag_root_provider` `set_drag_root` `clear_drag_root` `drag_active` `drag_data` `drag_source` `drag_position` `drag_hover` `drag_begin` `drag_move` `drag_drop` `drag_cancel` `drag_external_supported` `drag_external_enable` `drag_external_disable` `drag_external_effect` `drag_external_pump` `drag_effect_of_flag` `drag_data_has_system_form` `drag_external_send_supported` `drag_external_send` `make_overlay_host` `set_overlay_host` `set_overlay_provider` `overlay_count` `overlay_ids` `overlay_top_id` `overlay_visible` `overlay_show_at` `overlay_show_full` `overlay_set_pos` `overlay_hide` `overlay_hide_top` `overlay_clear` `overlay_raise` `overlay_root_of` `overlay_rect_of` `gtk_mods_to_mods` `win_mods_to_mods` `mac_mods_to_mods` `mac_caps_lock` `win_vk_to_keysym` `win_apply_shift` `mac_vk_to_keysym` `win_button_to_index` `mac_button_to_index` `ime_route` `ime_should_reset` `ime_should_feed_surrounding` `raw_to_event` `bump_paint_epoch` `paint_epoch` `set_widget_discard_hook` `route_pointer` `host_add_app` `host_remove_app` `host_active` `host_windows` `host_repaint_all` `invalidate_id` `host_reset` `popup_place` `node_of` `node_of_new` `mount_children` `set_repaint_hook` `invalidate` `swap_node` `bind_node` |

## @win（不经 compat，Event 类型直接来自 win）

| 类别 | 符号 |
|------|------|
| 类型 | `Event` `FocusOwner` |

> `@core.Event` 在 compat_widget.mbt 定义为 `pub type Event = @win.Event`。
> 迁移后消费方直用 `@win.Event`，不经任何中间包。

## 特殊迁移注意事项

1. **枚举构造子（PointerKind / KeyEvent / DragData 等变体）**：别名不导出构造子，compat 里只有 `pub type`。widget 包内的事件变体（`Down` `Up` `Move` `Leave` `FilePaths` 等）已在步骤 3 全仓 290 处改成 `@widget.PointerKind::Down` 全限定；后续迁移不需要再处理这批——已改完。

2. **Widget 方法**：`w.drag_wants(data)` / `w.on_pointer` / `w.rect` 等是 `@widget.Widget` 的方法，通过 `@core.Widget` 类型别名访问。迁移只需把类型引用 `@core.Widget` 改 `@widget.Widget`，方法调用本身不变。

3. **`@core.test_app` / `@core.fake_session`**：跨模块测试通道，迁移后走 `@widget.test_app(@shell.fake_session(...))`。

4. **moon.pkg import 调整**：每个消费方删 `"NoahLiu/native-gui/core"`，按需加 `"NoahLiu/native-gui/base"` / `"NoahLiu/native-gui/shell"` / `"NoahLiu/native-gui/widget"`。已有 `@widget` 别名的包（ui / chart / mdview）只补 `base` 和 `shell`。

5. **sys 包**：`@core.` 出现只在注释文档里，不在代码中。可选清理，不阻塞编译。
