// 声明式地基：`Node` 是「未挂载的 UI 片段」，构造器只建树、`mount` 才实例化
// 控件并挂到父控件（闭包字段是存在类型，兄弟节点天然异构）。
//
// 与 master 线 `yue/node.mbt` 的唯一结构差：挂载目标从 libyue 的 `View` 换成
// 本栈自绘的 `Widget`（`mount : (Widget) -> Widget`），语义一字不改。
//
// 重挂（relink）形态定案三条：
// ① **原位替换**而不是「清空再追加」——新一代先挂到尾部、再挪回旧一代原先的
//    位置，兄弟项的顺序与坐标不受被换掉的这项影响（布局引擎为此加了
//    `insert_child` / `remove_child_at`）；
// ② **不需要**旧链路 Windows 的那两条规避（`post_task` 推迟一拍、重挂后
//    `refresh_layout` 整窗重算）：它们防的是 native 侧 remove+add 之后 yoga 根
//    不重算、hit-test 恒命中旧矩形；本栈的命中矩形每帧从布局结果重取
//    （`App::paint_frame` → `relayout` → `collect_abs`），没有这个洞；
// ③ 每一代子树的订阅进**回收袋**，重建前整袋退订——死订阅不随重建次数累积。

///|
/// 未挂载的 UI 片段：`mount` 把自己实例化、挂进 parent，返回自己的控件句柄。
pub(all) struct Node {
  mount : (Widget) -> Widget
}

///|
/// 把节点挂进 parent，返回该节点的控件句柄。
pub fn Node::mount_into(self : Node, parent : Widget) -> Widget {
  (self.mount)(parent)
}

///|
/// 已有控件包成节点（挂上去即成为 parent 的直接子项）。
pub fn node_of(w : Widget) -> Node {
  { mount: fn(parent : Widget) -> Widget {
      parent.append_child(w)
      w
    } }
}

///|
/// 新建一个控件、交给 `finish` 配置并拿到它（等价于「先 new 再 node_of」，
/// 少一行临时变量；组件层与示例都用它）。`finish` 返回要挂出去的控件，
/// 允许在里面再建子控件。
pub fn node_of_new(finish : (Widget) -> Widget) -> Node {
  node_of(finish(Widget::new()))
}

///|
/// 一组节点按顺序挂进 parent。
pub fn mount_children(parent : Widget, children : Array[Node]) -> Unit {
  for n in children {
    let _ = (n.mount)(parent)
  }
}

// ---- 重绘请求：内容变了要让宿主再画一帧 ----

let repaint_hook : Ref[(() -> Unit)] = Ref(fn() { () })

///|
/// 安装「请求重绘」回调。`App::new` 建窗时装自己的 `schedule_paint`，
/// 于是信号回调里的 `invalidate()` 就是「置脏 + 唤醒平台泵」。
/// 进程级单槽（当前形态一进程一宿主）；多窗口各自路由要到宿主层做
/// 「按控件找所属 App」时才需要升级。
pub fn set_repaint_hook(f : () -> Unit) -> Unit {
  repaint_hook.val = f
}

///|
/// 内容变了、需要重画一帧。没有宿主（无头测试）时是空操作。
pub fn invalidate() -> Unit {
  (repaint_hook.val)()
}

///|
/// 信号变化时重挂子树：值 v → 子树 `f(v)`，**原位**替换上一代。
/// 适合低频换整块视图（随状态换图标、换面板）；高频改属性请让控件自己
/// 订阅并就地更新（文本绑定那类），别每变一次重建一棵树。
pub fn[T] bind_node(sig : Signal[T], f : (T) -> Node) -> Node {
  {
    mount: fn(parent : Widget) -> Widget {
      let current : Ref[Widget?] = Ref(None)
      // 本代子树注册的退订闭包（重建前整袋退订）
      let gen : Ref[Array[() -> Unit]] = Ref([])
      fn rebuild(v : T) -> Unit {
        sub_bag_discard(gen.val)
        let old = current.val
        let at = match old {
          Some(o) => parent.index_of(o)
          None => -1
        }
        match old {
          Some(o) => {
            let _ = parent.remove_child(o)
          }
          None => ()
        }
        sub_bag_begin()
        let w = (f(v).mount)(parent)
        gen.val = sub_bag_end()
        current.val = Some(w)
        if at >= 0 && parent.index_of(w) != at {
          parent.move_child(parent.index_of(w), at)
        }
        invalidate()
      }
      rebuild(sig.get())
      ignore(sig.subscribe(rebuild))
      match current.val {
        Some(w) => w
        None => Widget::new()
      }
    },
  }
}

///|
/// 两态切换：a/b 两棵都预建，按布尔信号显隐，不销毁也不重建。
/// 与 `bind_node` 的取舍：切换频繁用这个（零重建、代价是两棵常驻），
/// 切换稀疏或两态结构差很大用 `bind_node`。
pub fn swap_node(sig : Signal[Bool], a : Node, b : Node) -> Node {
  {
    mount: fn(parent : Widget) -> Widget {
      let va = (a.mount)(parent)
      let vb = (b.mount)(parent)
      fn apply(v : Bool) -> Unit {
        va.set_visible(!v)
        vb.set_visible(v)
        invalidate()
      }
      apply(sig.get())
      ignore(sig.subscribe(apply))
      va
    },
  }
}
