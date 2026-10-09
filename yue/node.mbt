// Node 协议:未挂载的 UI 片段(Node)+ 挂载原语(attach)。
// 放在核心包:yue/declarative 包的节点构造器产生 Node,components /
// icons / markdown / charts 等包也直接引用 Node(它们 import 的是核心包),
// 故 Node 与 attach 不随声明式层拆分搬走。
// Node 是"未挂载的 UI 片段":构造器只建树,mount 时才实例化控件、挂到
// 父视图并注册回调;children 数组天然异构(Node 是函数字段的存在类型)。
// 自定义控件:用 @declarative.node_of 包已有视图,或直接写 Node 字面量。

///|
/// 把子视图挂到父视图（父须为容器：Container/Group/Scroll/Tab 均可，
/// 错型由 shim 侧 dynamic_cast 校验拒绝）。
pub fn attach(parent : View, child : View) -> Unit {
  ffi_container_add_child(parent, child)
}

///|
/// 未挂载的 UI 片段：mount 把自己实例化并挂到 parent，返回自己的视图句柄。
pub(all) struct Node {
  mount : (View) -> View
}

///|
/// 把节点挂到 parent，返回该节点的视图句柄。
pub fn Node::mount_into(self : Node, parent : View) -> View {
  (self.mount)(parent)
}
