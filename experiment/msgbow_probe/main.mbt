// W20d 原生消息框探针：验 MessageBoxW 的 uType 位组合与返回值归一通路。
//
// 分两段：
//   ① **纯映射**（无显示服务也能跑）：语义参数 → uType 的位组合逐条打印，
//      与 yue/win/message_box_wbtest.mbt 的断言同源，这里只是可肉眼对照的读数。
//   ② **真弹框**（需后端可用 + 显式开关）：MessageBoxW 会**模态阻塞**到用户点
//      按钮，若探针自动弹会让无人值守的 CI/冒烟挂住——故真弹框仅在设了环境变量
//      `YUE_MSGBOX_PROBE=1` 时进行（真机手测：跑一次点一下按钮看返回编号）。
//      未设时只打印「SKIP」并证明调用路径可达（FFI 符号已链接）。
//
// 跑法：moon run experiment/msgbow_probe
//       YUE_MSGBOX_PROBE=1 moon run experiment/msgbow_probe   # 真弹一次

///|
/// MessageBoxResult → 编号（可读渲染用）
fn rcode(r : @win.MessageBoxResult) -> Int {
  match r {
    Ok => 1
    Cancel => 2
    Abort => 3
    Retry => 4
    Ignore => 5
    Yes => 6
    No => 7
    Failed => 0
  }
}

///|
fn show_utype(
  label : String,
  kind : @win.MessageBoxKind,
  buttons : @win.MessageBoxButtons,
  default_index : Int,
) -> Unit {
  let t = @win.message_box_utype(kind, buttons, default_index~)
  let icon = t & 0xF0
  let btn = t & 0xF
  let def = t & 0xF00
  println(
    "MSGBOX-UTYPE \{label} icon=\{icon} btn=\{btn} def=\{def} raw=\{t}",
  )
}

fn main {
  // ① 纯映射段（后端无关）
  show_utype("a", Information, Ok, 0)
  show_utype("b", Error, YesNoCancel, 1)
  show_utype("c", Warning, OkCancel, 0)
  show_utype("d", Question, YesNo, 0)
  show_utype("e", None, AbortRetryIgnore, 2)
  show_utype("f", Error, RetryCancel, 0)

  // 返回值归一段（后端无关，喂编号看归一）
  println("MSGBOX-RESULT 1=\{rcode(@win.message_box_result_of(1))}")
  println("MSGBOX-RESULT 2=\{rcode(@win.message_box_result_of(2))}")
  println("MSGBOX-RESULT 6=\{rcode(@win.message_box_result_of(6))}")
  println("MSGBOX-RESULT 7=\{rcode(@win.message_box_result_of(7))}")
  println("MSGBOX-RESULT 0=\{rcode(@win.message_box_result_of(0))}")

  // ② 真弹框段（后端 + 显式开关）
  if !@win.init_backend() {
    println("MSGBOX SKIP (无显示服务)")
    return
  }
  let armed = match @env.get_env_var("YUE_MSGBOX_PROBE") {
    Some(v) => v != ""
    None => false
  }
  if !armed {
    println("MSGBOX SKIP (未设 YUE_MSGBOX_PROBE；真弹框需人工点按)")
    return
  }
  // 真弹（会阻塞到点按钮）：错误 + 是/否/取消
  let r = @win.show_message_box(
    "libyue W20d 探针",
    "点任意按钮，返回编号会打印到控制台。",
    Error,
    YesNoCancel,
  )
  println(
    "MSGBOX-SHOWN result=\{rcode(r)} affirmative=\{@win.message_box_result_is_affirmative(r)}",
  )
  println("MSGBOX-OK")
}
