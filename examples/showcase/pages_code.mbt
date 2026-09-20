// 代码与文档页:code_view 多语言高亮(行号)+ markdown_view 渲染。

///|
fn page_code(_app : App) -> @yue.Node {
  scroll_page([
    section(
      "Code View 代码高亮",
      "逐 token 测宽自绘,全平台一致;lang 关键字集(moonbit/js/ts/python/rust/c/go/bash/sql)+ 行号。",
      [
        @yue.code_view(
          [
            "// MoonBit · 关键字/字符串/数字/注释", "fn main {",
            "  let msg = \"hello 组件库\"", "  println(msg + \"!\" )  // 2026",
            "}",
          ],
          lang="moonbit",
          line_numbers=true,
          width=430.0,
        ),
        @yue.code_view(
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
          width=430.0,
        ),
        @yue.code_view(
          [
            "# Python · 注释与关键字",
            "def greet(name: str) -> str:",
            "    return f'Hello, {name}!'",
            "",
            "print(greet('MoonBit'))",
          ],
          lang="python",
          line_numbers=true,
          width=430.0,
        ),
      ],
    ),
    section(
      "Markdown 渲染",
      "标题/段落/粗斜体/行内代码/链接/列表/引用/分隔线/围栏代码块;区间字体颜色经富文本,三平台一致。",
      [
        @yue.markdown_view(
          ("# MoonBit × libyue\n" +
          "## 富文本渲染的 Markdown 展示\n" +
          "支持 **粗体**、*斜体*、***粗斜体***、`行内代码` 与 [链接文字](https://github.com/lb091188/moonbit-libyue)。\n" +
          "\n" +
          "- 无序列表项一\n" +
          "- 无序列表项二(含 `代码`)\n" +
          "1. 有序列表第一项\n" +
          "2. 有序列表第二项\n" +
          "\n" +
          "> 引用块:主题色竖条 + 缩进排版。\n" +
          "> 引用续行。\n" +
          "\n" +
          "---\n" +
          "\n" +
          "```rust\n" +
          "fn main() {\n" +
          "    println!(\" fenced 代码块 \" );\n" +
          "}\n" +
          "```\n" +
          "\n" +
          "段落文本收尾。"),
          width=480.0,
        ),
      ],
    ),
  ])
}
