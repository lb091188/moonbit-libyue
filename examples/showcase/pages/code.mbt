// 代码与文档页：code_view 多语言高亮（行号）+ markdown_view 渲染。
// Markdown 段演示文本与复制串同源：demo_md_lines 是唯一来源，渲染
// markdown_view(join 为源文)，复制串逐行派生为 MoonBit 字面量拼接——
// 复制所得与页面所见一致。
//
// G7 迁移记档：`code_view` 的 `style=[width]` 在本栈无对应参数（宽度由
// 最长行测宽决定），`markdown_view` 的宽度是命名参数 `width`。

///|
/// Markdown 演示源文（逐行；渲染与复制串共用）。
fn demo_md_lines() -> Array[String] {
  [
    "# MoonBit × native-gui",
    "## GFM 渲染演示",
    "",
    "支持 **粗体**、*斜体*、***粗斜体***、~~删除线~~、`行内代码` 与 [链接](https://github.com/lb091188/moonbit-native-gui),",
    "自动链接 <https://libyue.com>,引用式链接见[主页][home]。",
    "",
    "Emoji 👍 之后的 **样式** 与 `区间` 仍应对齐。",
    "",
    "- 无序列表项一",
    "- 无序列表项二(含 `代码`)",
    "  - 嵌套列表项",
    "1. 有序列表第一项",
    "2. 有序列表第二项",
    "- [x] 任务列表已完成项(点复选框可勾选)",
    "- [ ] 任务列表待办项",
    "",
    "> 引用块:主题色竖条 + 缩进排版。",
    "> 引用续行。",
    "",
    "---",
    "",
    "```rust",
    "fn main() {",
    "    println!(\" fenced 代码块 \" );",
    "}",
    "```",
    "",
    "| 对齐列 | 关键字 | 数值 |",
    "|:-----|:----:|----:|",
    "| 左对齐 | moonbit | 1 |",
    "| 居中 | rust | 20 |",
    "| **加粗** | `代码` | 300 |",
    "",
    "脚注引用在正文里[^1],再来一条[^note]。",
    "",
    "段落文本收尾。",
    "",
    "[home]: https://libyue.com",
    "[^1]: 脚注定义一:在文末分隔线后按引用顺序渲染。",
    "[^note]: 脚注定义支持 **富文本** 与 `代码`。",
  ]
}

///|
/// MoonBit 字符串字面量转义（反斜杠/双引号），供复制串派生。
fn md_demo_escape(s : String) -> String {
  let sb = StringBuilder()
  for ch in s {
    match ch {
      '\\' => sb.write_string("\\\\")
      '"' => sb.write_string("\\\"")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
/// 复制串：由演示源文逐行派生的 markdown_view 调用源码。
fn demo_md_code(width : Double) -> Array[String] {
  let lines = demo_md_lines()
  let code : Array[String] = ["@mdview.markdown_view("]
  let n = lines.length()
  for i, line in lines {
    let tail = if i < n - 1 { " +" } else { "," }
    code.push("  \"\{md_demo_escape(line)}\\n\"\{tail}")
  }
  code.push("  width=\{width},")
  code.push(")")
  code
}

///|
pub fn page_code(_app : @shared.App) -> @widget.Node {
  let md_w = 480.0
  let demo = demo_md_lines().join("\n")
  @shared.page([
    @shared.section(
      "代码高亮",
      "CodeView 代码高亮",
      "逐 token 测宽自绘，全平台一致；lang 关键字集（moonbit/js/ts/python/rust/c/go/bash/sql）+ 行号。",
      [
        @ui.col(
          [
            @ui.code_view(
              [
                "// MoonBit · 关键字/字符串/数字/注释",
                "fn main {",
                "  let msg = \"hello 组件库\"",
                "  println(msg + \"!\" )  // 2026",
                "}",
              ],
              lang="moonbit",
              line_numbers=true,
            ),
            @ui.code_view(
              [
                "use gtk::prelude::*;",
                "",
                "fn main() {",
                "    let app = gtk::Application::new()",
                "        .expect(\"init failed\");",
                "    app.connect_activate(|_| {}); // 回调",
                "    app.run();",
                "}",
              ],
              lang="rust",
              line_numbers=true,
            ),
            @ui.code_view(
              [
                "# Python · 注释与关键字",
                "def greet(name: str) -> str:",
                "    return f'Hello, {name}!'",
                "",
                "print(greet('MoonBit'))",
              ],
              lang="python",
              line_numbers=true,
            ),
          ],
          row_gap=10.0,
          align_items=@yoga.AlignItems::FlexStart,
        ),
      ],
      code=[
        "@ui.code_view([",
        "  \"// MoonBit · 关键字/字符串/数字/注释\",",
        "  \"fn main {\",",
        "  \"  let msg = \\\"hello 组件库\\\"\",",
        "  \"}\",",
        "], lang=\"moonbit\", line_numbers=true)",
      ],
    ),
    @shared.section(
      "Markdown",
      "Markdown 渲染",
      "mdast 解析 + 富文本行自绘：标题/段落/粗斜体/删除线/行内代码/链接（悬浮手型）/自动链接/引用式链接/嵌套列表/任务列表（真复选框）/引用/分隔线/围栏代码块/表格（列对齐）/脚注（正文上标 + 文末定义）；emoji 区间按 UTF-16 计量不错位，演示文本与复制串同源。",
      [
        @mdview.markdown_view(demo, width=md_w),
      ],
      code=demo_md_code(md_w),
    ),
  ])
}
