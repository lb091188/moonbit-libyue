// W20b 全局快捷键探针：验 RegisterHotKey 的注册/注销通路与 WM_HOTKEY 抽取。
//
// 分两段：
//   ① **纯解析**（无显示服务也能跑）：加速键串 → (mods, vk) 的映射逐条打印，
//      与 win/hotkey_wbtest.mbt 的断言同源，这里只是可肉眼对照的读数。
//   ② **真注册**（需后端可用）：注册两个组合键，打印返回的 id（>=1 即成功、
//      None 即失败）；再注销其一、验证幂等注销不崩。**真正的按下触发需人工**
//      （切到别的程序按组合键，宿主经 poll 拿到 id）——本探针不模拟按键，
//      只证明「注册成功 + 泵不崩 + 抽取接口可达」。
//
// 跑法：moon run experiment/hotkey_probe

///|
/// Option[Int] 的可读渲染（Some(3) / None）。
fn opt_str(v : Int?) -> String {
  match v {
    Some(x) => "Some(\{x})"
    None => "None"
  }
}

///|
fn show(label : String, spec : String) -> Unit {
  match @win.parse_accelerator(spec, false) {
    Some(hk) =>
      println(
        "HOTKEY-PARSE \{label} spec=\{spec} mods=\{hk.mods} vk=\{hk.vk} name=\{hk.name}",
      )
    None => println("HOTKEY-PARSE \{label} spec=\{spec} FAIL")
  }
}

fn main {
  // ① 纯解析段（后端无关）
  show("a", "CmdOrCtrl+Shift+M")
  show("b", "Ctrl+Alt+Delete")
  show("c", "F5")
  show("d", "Ctrl+,")
  show("e", "Shift+Space")
  show("f", "CmdOrCtrl+NotAKey") // 预期 FAIL
  show("g", "Ctrl+A+B") // 预期 FAIL（两个主键）

  // ② 真注册段
  if !@win.init_backend() {
    println("HOTKEY SKIP (无显示服务)")
    return
  }
  // 用较冷门的组合避免与系统/其它程序冲突
  let m = match @win.parse_accelerator("Ctrl+Alt+F9", false) {
    Some(hk) => hk
    None => {
      println("HOTKEY FAIL (解析 Ctrl+Alt+F9)")
      return
    }
  }
  let id1 = @win.register_global_shortcut(m.mods, m.vk)
  println("HOTKEY-REG id1=\{opt_str(id1)} (Some=成功 None=被占用/不支持)")
  let m2 = match @win.parse_accelerator("Ctrl+Alt+F10", false) {
    Some(hk) => hk
    None => {
      println("HOTKEY FAIL (解析 Ctrl+Alt+F10)")
      return
    }
  }
  let id2 = @win.register_global_shortcut(m2.mods, m2.vk)
  println("HOTKEY-REG id2=\{opt_str(id2)}")
  // 泵几轮：真按键没来时 poll 应恒 None（不崩、不假报）
  @win.pump()
  let fired = @win.poll_global_shortcut()
  println("HOTKEY-POLL fired=\{opt_str(fired)} (无按键应为 None)")
  // 注销其一 + 重复注销（幂等）
  match id1 {
    Some(i) => {
      @win.unregister_global_shortcut(i)
      @win.unregister_global_shortcut(i) // 幂等，不应崩
      println("HOTKEY-UNREG id1=\{i} (含重复注销)")
    }
    None => ()
  }
  match id2 {
    Some(i) => {
      @win.unregister_global_shortcut(i)
      println("HOTKEY-UNREG id2=\{i}")
    }
    None => ()
  }
  // 注销后再注册同一组合，应能拿到新 id（槽位释放可复用）
  let again = @win.register_global_shortcut(m.mods, m.vk)
  println("HOTKEY-REREG id=\{opt_str(again)} (释放后应可再注册)")
  match again {
    Some(i) => @win.unregister_global_shortcut(i)
    None => ()
  }
  println("HOTKEY-OK")
}
