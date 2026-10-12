// W14c 文件对话框探针（Windows 的 IFileDialog 实装）：点「打开」选一个文件、
// 点「保存」走一遍保存对话框、再试一次文件夹选择；每步把选中的路径打在
// 控制台上，方便对照你在对话框里点的东西。
//
// 跑法：moon run experiment/dialog_probe
// 观感检查项：过滤下拉里的分组与说明、初始目录、多选后只回第一个（当前口径）、
// 取消时程序不崩且回空串。

fn main {
  // 1) 打开对话框：过滤 + 初始目录
  let d1 = @sys.FileDialog::new_open()
  d1.set_filters("文本:txt,md|图片:png,jpg|全部:*")
  d1.set_folder("C:/Users")
  let ok1 = d1.run_for_window(0L)
  println("DIALOG-OPEN ok=\{ok1} path=[\{d1.get_result()}]")
  d1.destroy()
  // 2) 保存对话框：默认文件名 + 过滤
  let d2 = @sys.FileDialog::new_save()
  d2.set_filters("文本:txt|全部:*")
  d2.set_filename("yue-探针.txt")
  let ok2 = d2.run_for_window(0L)
  println("DIALOG-SAVE ok=\{ok2} path=[\{d2.get_result()}]")
  d2.destroy()
  // 3) 文件夹选择 + 多选（多选口径：只回首个）
  let d3 = @sys.FileDialog::new_open()
  d3.set_options(@sys.FILE_OPTION_PICK_FOLDERS)
  let ok3 = d3.run_for_window(0L)
  println("DIALOG-FOLDER ok=\{ok3} path=[\{d3.get_result()}]")
  d3.destroy()
  println("DIALOG-DONE")
}
