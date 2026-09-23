// Browser 类型定义与 View 通用能力挂载。

///|
pub(all) struct Browser {
  view : @yue.View
}

///|
pub impl @yue.ViewLike for Browser with fn view(self) {
  self.view
}

///|
pub extend Browser with @yue.ViewLike::{get_bounds_in_screen, on_key_up, view, set_background_color, on_mouse_move, on_mouse_up, has_capture, set_visible, on_focus_out, has_focus, schedule_paint, add_tooltip_for_rect, set_enabled, handle_drop, set_color, set_focusable, remove_tooltip, set_style, on_mouse_enter, on_capture_lost, focus, register_dragged_types, set_font, schedule_paint_rect, get_computed_layout, set_mouse_down_can_move_window, set_tooltip, set_borderless, on_wheel, handle_drag_enter, handle_drag_update, on_mouse_down, on_focus_in, on_size_changed, is_dragging, on_mouse_leave, on_drag_leave, set_capture, set_style_str, update_layout, on_key_down, do_drag_file_paths, get_bounds, release_capture, do_drag_data_full, cancel_drag}
