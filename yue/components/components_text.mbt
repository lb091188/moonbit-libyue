// 文本与代码:label_t、文本测量、code_view 及多语言词法着色。

///|
/// 代码高亮的着色单元。
pub(all) struct Token {
  text : String
  color : String
}

///|
/// MoonBit 风格着色器:关键字 / 类型(大写开头) / 函数调用(后随 '(')/
/// 数字 / 字符串 / 注释 / 标点与普通文本,One Dark 调色板。
/// 仅供演示;消费方可换成任意词法分析结果后直接用 code_view。

///|
/// ASCII 小写(关键字大小写不敏感比较用)。
fn ascii_lower(s : String) -> String {
  let out = Ref(StringBuilder())
  for ch in s {
    let c = ch.to_int()
    if c >= 65 && c <= 90 {
      out.val.write_char((c + 32).unsafe_to_char())
    } else {
      out.val.write_char(ch)
    }
  }
  out.val.to_string()
}

///|
/// 语言关键字集与行注释前缀(代码高亮通用参数表)。
fn lang_keywords(lang : String) -> (Array[String], String) {
  match lang {
    "js" | "ts" =>
      (
        [
          "function", "const", "let", "var", "if", "else", "return", "class", "extends",
          "import", "export", "new", "typeof", "await", "async", "for", "while",
          "switch", "case", "break", "default", "try", "catch", "throw", "this",
          "super", "null", "undefined", "true", "false", "static", "get", "set",
          "of", "in", "yield", "delete", "void",
        ],
        "//",
      )
    "python" =>
      (
        [
          "def", "class", "import", "from", "if", "elif", "else", "for", "while",
          "in", "not", "and", "or", "lambda", "return", "None", "True", "False",
          "self", "pass", "with", "as", "try", "except", "finally", "raise", "yield",
          "global", "del", "assert", "break", "continue", "is",
        ],
        "#",
      )
    "rust" =>
      (
        [
          "fn", "let", "mut", "pub", "struct", "enum", "impl", "trait", "use", "mod",
          "match", "if", "else", "loop", "while", "for", "in", "return", "Some",
          "None", "Ok", "Err", "self", "crate", "move", "ref", "where", "async",
          "await", "dyn", "as", "break", "const", "continue", "static", "type", "unsafe",
          "true", "false",
        ],
        "//",
      )
    "c" =>
      (
        [
          "include", "define", "typedef", "struct", "union", "enum", "static", "const",
          "int", "void", "char", "float", "double", "return", "if", "else", "for",
          "while", "switch", "case", "break", "default", "sizeof", "long", "short",
          "unsigned", "signed", "extern", "goto", "do",
        ],
        "//",
      )
    "go" =>
      (
        [
          "func", "package", "import", "var", "const", "type", "struct", "interface",
          "map", "chan", "go", "defer", "if", "else", "for", "range", "return", "nil",
          "break", "continue", "switch", "case", "default", "select", "fallthrough",
        ],
        "//",
      )
    "bash" =>
      (
        [
          "echo", "if", "then", "else", "fi", "for", "do", "done", "while", "case",
          "esac", "function", "local", "export", "return", "exit", "read", "shift",
          "in",
        ],
        "#",
      )
    "sql" =>
      (
        [
          "select", "from", "where", "insert", "into", "values", "update", "set",
          "delete", "create", "table", "join", "left", "right", "inner", "outer",
          "on", "group", "order", "by", "limit", "as", "and", "or", "not", "null",
          "distinct", "count", "sum", "avg", "primary", "key", "foreign", "references",
          "alter", "drop", "index", "view",
        ],
        "--",
      )
    _ =>
      // MoonBit 全量关键字(moonc 内置词表对齐):声明/可见性/属性/控制流/
      // 模式与所有权/异步/字面量
      (
        [
          "fn", "let", "mut", "const", "struct", "enum", "trait", "impl", "type",
          "typealias", "derive", "pub", "priv", "open", "override", "readonly", "extern",
          "native", "test", "async", "await", "if", "else", "for", "in", "while",
          "loop", "match", "when", "where", "return", "break", "continue", "as",
          "is", "move", "root", "unsafe", "object", "true", "false",
        ],
        "//",
      )
  }
}

///|
/// 通用语言分词:字符串("…"/'…')、行注释(按语言)、()[]{},;: 标点独立、
/// 运算符连续成词,其余连续非空白为一个词;词再经 classify_word 分为
/// 关键字/类型/函数调用/数字/普通文本。tokenize_moonbit 即 moonbit 特化。
pub fn tokenize_lang(line : String, lang : String) -> Array[Token] {
  let (keywords, comment_prefix) = lang_keywords(lang)
  let out : Array[Token] = []
  let cs : Array[Char] = []
  for ch in line {
    cs.push(ch)
  }
  let n = cs.length()
  let buf = Ref(StringBuilder())
  // 0 未开始,1 词(标识符/限定名/数字),2 运算符串
  let kind = Ref(0)
  // 词着色需要 lookahead:词后紧跟 '(' 视为函数调用
  fn flush(next : Char) -> Unit {
    let s = buf.val.to_string()
    buf.val = StringBuilder()
    let is_word = kind.val == 1
    kind.val = 0
    if s.length() > 0 {
      out.push(classify_word(s, keywords, is_word && next == '('))
    }
  }

  let mut i = 0
  while i < n {
    let ch = cs[i]
    let c = ch.to_int()
    if ch == '"' || ch == '\'' {
      // 字符串字面量:开引号起到闭引号整段
      flush(ch)
      let s = StringBuilder()
      s.write_char(ch)
      i = i + 1
      while i < n {
        s.write_char(cs[i])
        if cs[i] == ch {
          break
        }
        i = i + 1
      }
      out.push({ text: s.to_string(), color: "#98C379", })
    } else if ch == '/' &&
      i + 1 < n &&
      cs[i + 1] == '/' &&
      comment_prefix == "//" {
      flush('/')
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == '#' && comment_prefix == "#" {
      flush('#')
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if ch == '-' &&
      i + 1 < n &&
      cs[i + 1] == '-' &&
      comment_prefix == "--" {
      flush('-')
      let comment = StringBuilder()
      while i < n {
        comment.write_char(cs[i])
        i = i + 1
      }
      out.push({ text: comment.to_string(), color: "#5C6370", })
      break
    } else if c == 32 {
      flush(ch)
      out.push({ text: " ", color: "#ABB2BF", })
    } else {
      let ident = (c >= 65 && c <= 90) ||
        (c >= 97 && c <= 122) ||
        (c >= 48 && c <= 57) ||
        c == 95 ||
        c == 64 ||
        c == 36 ||
        c > 127
      // '.' 在词内续词(小数/限定名),但后随 '.'(区间符 ..)时断开,
      // 让前导数字独立着色;不在词内时归运算符
      let dot_in_word = ch == '.' &&
        kind.val == 1 &&
        !(i + 1 < n && cs[i + 1] == '.')
      if (ident || dot_in_word) && kind.val != 2 {
        buf.val.write_char(ch)
        kind.val = 1
      } else if is_op_char(ch) && kind.val != 1 {
        buf.val.write_char(ch)
        kind.val = 2
      } else {
        // 词与运算符串互切:先冲刷再按新词性开串;()[]{},;: 标点单字符
        flush(ch)
        if !ident && !dot_in_word && !is_op_char(ch) {
          out.push({ text: char_to_string(ch), color: "#ABB2BF", })
        } else if ident || dot_in_word {
          buf.val.write_char(ch)
          kind.val = 1
        } else {
          buf.val.write_char(ch)
          kind.val = 2
        }
      }
    }
    i = i + 1
  }
  flush(' ')
  out
}

///|
/// 运算符字符(连续出现时并成一个词,如 ->、<=、..<、&&、@ 无关的 '.')。
fn is_op_char(ch : Char) -> Bool {
  match ch {
    '+'
    | '-'
    | '*'
    | '/'
    | '%'
    | '<'
    | '>'
    | '='
    | '!'
    | '&'
    | '|'
    | '?'
    | '^'
    | '~'
    | '#'
    | '\\'
    | '`'
    | '.' => true
    _ => false
  }
}

///|
fn char_to_string(ch : Char) -> String {
  let b = StringBuilder()
  b.write_char(ch)
  b.to_string()
}

///|
pub fn tokenize_moonbit(line : String) -> Array[Token] {
  tokenize_lang(line, "moonbit")
}

///|
/// 词分类着色:关键字(大小写不敏感)紫;纯数字橙;@ 限定名按最后一段、
/// 裸标识符按首字符,大写开头视为类型/构造器黄;后随 '(' 的小写标识符
/// 视为函数调用蓝;其余灰。
fn classify_word(
  word : String,
  keywords : Array[String],
  is_call : Bool,
) -> Token {
  let lowered = ascii_lower(word)
  for k in keywords {
    if ascii_lower(k) == lowered {
      return { text: word, color: "#C678DD", }
    }
  }
  // 着色主体:@ 限定名取最后 '.' 段,裸词取整词
  let mut head = word
  if word.unsafe_get(0).to_int() == 64 {
    let segs : Array[StringView] = word.split(".").collect()
    let last = segs[segs.length() - 1]
    if last.length() > 0 {
      head = last.to_owned()
    }
  }
  let c0 = head.unsafe_get(0).to_int()
  if c0 >= 65 && c0 <= 90 {
    return { text: word, color: "#E5C07B", }
  }
  let is_num = word.length() > 0
  for i in 0..<word.length() {
    let c = word.unsafe_get(i).to_int()
    if !((c >= 48 && c <= 57) || c == 46) {
      if is_call && !(c0 >= 48 && c0 <= 57) {
        return { text: word, color: "#61AFEF", }
      }
      return { text: word, color: "#ABB2BF", }
    }
  }
  if is_num {
    return { text: word, color: "#D19A66", }
  }
  { text: word, color: "#ABB2BF", }
}

///|
/// 代码高亮视图:逐 token 建 AttributedText(整段设色)+ 测宽后自绘排版。
/// 等价于「区间设色」的视觉效果,但全平台行为一致——Windows 上
/// AttributedText 区间字体/颜色是上游缺陷(见 docs/adaptation.md),此法绕开。
pub fn code_view(
  lines : Array[String],
  lang? : String = "moonbit",
  font_size? : Double = 13.0,
  line_numbers? : Bool = false,
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Container) -> Unit = fn(_c) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let font = @yue.Font::new("Monospace", font_size)
      fn make_at(text : String, color : String) -> @yue.AttributedText {
        let at = @yue.AttributedText::new(text, wrap=false)
        at.set_font(font)
        at.set_color(color)
        at
      }

      // 挂载时预排版:逐 token 测宽,避免每次重绘重复分词/测量
      let line_h = make_at("Ag", "#FFFFFF").get_bounds_for(10000.0, 100.0).height +
        5.0
      // 行号区:等宽数字位宽 × 最大位数 + 间距
      let digit_probe = make_at("8", "#FFFFFF")
      let digit_w = digit_probe.get_bounds_for(10000.0, 100.0).width
      let digits = lines.length().to_string().length()
      let num_off = if line_numbers {
        digit_w * digits.to_double() + 24.0
      } else {
        0.0
      }
      let laid : Array[(Array[(@yue.AttributedText, Double)], Double)] = []
      let mut max_line_w = 0.0
      for idx, line in lines {
        let segs : Array[(@yue.AttributedText, Double)] = []
        let mut x = num_off
        if line_numbers {
          let num_txt = (idx + 1).to_string()
          let pad = Ref(StringBuilder())
          for _i in 0..<(digits - num_txt.length()) {
            pad.val.write_char(' ')
          }
          let at_num = make_at(pad.val.to_string() + num_txt, "#6B7280")
          segs.push((at_num, 16.0))
        }
        for tok in tokenize_lang(line, lang) {
          let at = make_at(tok.text, tok.color)
          let w = at.get_bounds_for(10000.0, 100.0).width
          segs.push((at, x))
          x = x + w
        }
        if x > max_line_w {
          max_line_w = x
        }
        laid.push((segs, x))
      }
      let content_w = max_line_w + num_off + 32.0
      let view_h = line_h * laid.length().to_double() + 28.0
      let base : Array[(String, &@yue.StyVal)] = [
        ("width", content_w),
        ("height", view_h),
      ]
      for kv in style {
        base.push(kv)
      }
      let c = @yue.themed_container(style=base)
      handle(c)
      @yue.ViewLike::set_background_color(c, "#282C34")
      c.on_draw(fn(p) {
        let mut y = 14.0
        for entry in laid {
          for seg in entry.0 {
            let w = seg.0.get_bounds_for(10000.0, 100.0).width
            p.draw_attributed_text(seg.0, seg.1 + 16.0, y, w + 4.0, line_h)
          }
          y = y + line_h
        }
      })
      @yue.attach(parent, @yue.ViewLike::view(c))
      @yue.ViewLike::view(c)
    },
  }
}

///|
/// 量一段文本在指定宽度下的自然渲染高(同 role 字体,含换行折行;
/// width 传 0 或不传时按不换行量)。供运行期长高的标签显式设定
/// 高度:GTK 标签的自然高交给 yoga 重测会得到错误值(pango 对
/// 未定义高度按一行量、对视口确定高度按裁断量),显式高度可绕开,
/// 定案见 adaptation.md「报告标签自然高」条。
pub fn measure_text_height(
  text : String,
  role? : TextRole = Body,
  width? : Double = 0.0,
) -> Double {
  let probe = @yue.AttributedText::new(text, wrap=width > 0.0)
  probe.set_font(role_font(role))
  probe.get_bounds_for(if width > 0.0 { width } else { 100000.0 }, 100000.0).height
}

///|
/// 主题化标签:文字角色统一字号/颜色,左对齐;可叠加布局样式。
pub fn label_t(
  text : String,
  role? : TextRole = Body,
  color? : String = "",
  style? : Array[(String, &@yue.StyVal)] = [],
  handle? : (@yue.Label) -> Unit = fn(_l) {  },
) -> @yue.Node {
  {
    mount: fn(parent) {
      let l = @yue.Label::new(text)
      @yue.ViewLike::set_font(l, role_font(role))
      fn apply_color() -> Unit {
        // 固定色(如深色遮盖层上的白字)不随主题切换
        @yue.ViewLike::set_color(
          l,
          if color == "" {
            role_color(role)
          } else {
            color
          },
        )
        // 同文重写一次:set_color 改的 Pango 前景属性在部分控件上不被
        // 下次绘制拾取,重排强制生效
        l.set_text(l.get_text())
      }

      apply_color()
      ignore(@yue.on_theme_change(apply_color))
      l.set_align(@yue.Start)
      @yue.apply_style(l, style~)
      handle(l)
      @yue.attach(parent, @yue.ViewLike::view(l))
      @yue.ViewLike::view(l)
    },
  }
}
