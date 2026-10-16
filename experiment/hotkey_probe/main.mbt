// W20b/W22 全局快捷键探针：验注册/注销通路与触发抽取（Windows 走
// RegisterHotKey，Linux/X11 走 XGrabKey）。
//
// 分三段：
//   ① **纯解析**（无显示服务也能跑）：加速键串 → (mods, vk, keysym) 的映射
//      逐条打印，与 win/hotkey_wbtest.mbt 的断言同源，这里只是可肉眼对照的读数。
//   ② **真注册**（需后端可用）：注册两个组合键，打印返回的 id（>=1 即成功、
//      None 即失败）；再注销其一、验证幂等注销不崩。**真正的按下触发在 ③**。
//   ③ **门面轮询**：经 core 门面注册，循环 poll 6 秒——真按下或
//      `xdotool key ctrl+alt+h` 注入即打印 HOTKEY-CORE-FIRE。
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
  let m = match @win.parse_accelerator("Ctrl+Alt+H", false) {
    Some(hk) => hk
    None => {
      println("HOTKEY FAIL (解析 Ctrl+Alt+H)")
      return
    }
  }
  let id1 = @win.register_global_shortcut(m)
  println("HOTKEY-REG id1=\{opt_str(id1)} (Some=成功 None=被占用/不支持)")
  let m2 = match @win.parse_accelerator("Ctrl+Alt+J", false) {
    Some(hk) => hk
    None => {
      println("HOTKEY FAIL (解析 Ctrl+Alt+J)")
      return
    }
  }
  let id2 = @win.register_global_shortcut(m2)
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
  let again = @win.register_global_shortcut(m)
  println("HOTKEY-REREG id=\{opt_str(again)} (释放后应可再注册)")
  match again {
    Some(i) => @win.unregister_global_shortcut(i)
    None => ()
  }
  // ③ 门面轮询段：经 core 门面注册同一组合，循环轮询 6 秒——期间真按下
  //    （或 `xdotool key ctrl+alt+h` 注入）即打印命中；无人按键走 TIMEOUT
  //    （不算失败）。自动化验法：后台跑本探针，1 秒后另开终端注入按键，
  //    等 HOTKEY-CORE-FIRE 出现。
  match @shell.hotkey_register("Ctrl+Alt+H") {
    Err(e) => println("HOTKEY-CORE-REG ERR \{e}")
    Ok(h) => {
      println("HOTKEY-CORE-REG id=\{h.id} spec=\{h.spec} poll 6s…")
      let deadline = @win.now_ms() + 6000
      let mut fired : @shell.Hotkey? = None
      let mut done = false
      while !done && @win.now_ms() < deadline {
        ignore(@win.wait(50))
        match @shell.hotkey_poll() {
          Some(f) => {
            fired = Some(f)
            done = true
          }
          None => ()
        }
      }
      match fired {
        Some(f) => println("HOTKEY-CORE-FIRE id=\{f.id} spec=\{f.spec}")
        None => println("HOTKEY-CORE-TIMEOUT (6s 无按键)")
      }
      ignore(@shell.hotkey_unregister(h))
    }
  }
  println("HOTKEY-OK")
}
