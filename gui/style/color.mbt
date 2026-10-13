///|
/// 颜色值：`#` 开头按 hex、命名色按 named、其余按 theme token 名（design.md §1.4）。
/// token 存的是**名字**，落色发生在绘制期——主题切换后随重绘生效，样式表不固化快照。
pub(all) enum Color {
  Hex(String)
  Named(String)
  Var(String)
}

///|
/// CSS 命名色（147 个标准名）。命中即 `Named`，未命中的非 hex 字符串按 theme token 名。
let named_color_set : Array[String] = [
  "aliceblue",
  "antiquewhite",
  "aqua",
  "aquamarine",
  "azure",
  "beige",
  "bisque",
  "black",
  "blanchedalmond",
  "blue",
  "blueviolet",
  "brown",
  "burlywood",
  "cadetblue",
  "chartreuse",
  "chocolate",
  "coral",
  "cornflowerblue",
  "cornsilk",
  "crimson",
  "cyan",
  "darkblue",
  "darkcyan",
  "darkgoldenrod",
  "darkgray",
  "darkgreen",
  "darkgrey",
  "darkkhaki",
  "darkmagenta",
  "darkolivegreen",
  "darkorange",
  "darkorchid",
  "darkred",
  "darksalmon",
  "darkseagreen",
  "darkslateblue",
  "darkslategray",
  "darkslategrey",
  "darkturquoise",
  "darkviolet",
  "deeppink",
  "deepskyblue",
  "dimgray",
  "dimgrey",
  "dodgerblue",
  "firebrick",
  "floralwhite",
  "forestgreen",
  "fuchsia",
  "gainsboro",
  "ghostwhite",
  "gold",
  "goldenrod",
  "gray",
  "green",
  "greenyellow",
  "grey",
  "honeydew",
  "hotpink",
  "indianred",
  "indigo",
  "ivory",
  "khaki",
  "lavender",
  "lavenderblush",
  "lawngreen",
  "lemonchiffon",
  "lightblue",
  "lightcoral",
  "lightcyan",
  "lightgoldenrodyellow",
  "lightgray",
  "lightgreen",
  "lightgrey",
  "lightpink",
  "lightsalmon",
  "lightseagreen",
  "lightskyblue",
  "lightslategray",
  "lightslategrey",
  "lightsteelblue",
  "lightyellow",
  "lime",
  "limegreen",
  "linen",
  "magenta",
  "maroon",
  "mediumaquamarine",
  "mediumblue",
  "mediumorchid",
  "mediumpurple",
  "mediumseagreen",
  "mediumslateblue",
  "mediumspringgreen",
  "mediumturquoise",
  "mediumvioletred",
  "midnightblue",
  "mintcream",
  "mistyrose",
  "moccasin",
  "navajowhite",
  "navy",
  "oldlace",
  "olive",
  "olivedrab",
  "orange",
  "orangered",
  "orchid",
  "palegoldenrod",
  "palegreen",
  "paleturquoise",
  "palevioletred",
  "papayawhip",
  "peachpuff",
  "peru",
  "pink",
  "plum",
  "powderblue",
  "purple",
  "rebeccapurple",
  "red",
  "rosybrown",
  "royalblue",
  "saddlebrown",
  "salmon",
  "sandybrown",
  "seagreen",
  "seashell",
  "sienna",
  "silver",
  "skyblue",
  "slateblue",
  "slategray",
  "slategrey",
  "snow",
  "springgreen",
  "steelblue",
  "tan",
  "teal",
  "thistle",
  "tomato",
  "turquoise",
  "violet",
  "wheat",
  "white",
  "whitesmoke",
  "yellow",
  "yellowgreen",
]

///|
/// 颜色字符串判定：`#` 开头 → `Hex`；命中命名色（大小写不敏感）→ `Named`；
/// 其余 → `Var`（theme token 名，认不认识由 [check_color] 在构造期一次性出声）。
pub fn parse_color(s : String) -> Color {
  if s.has_prefix("#") {
    Hex(s)
  } else if named_color_hit(s) {
    Named(s)
  } else {
    Var(s)
  }
}

///|
/// ASCII 小写折叠后逐字符比对（命名色全是 ASCII，非 ASCII 字符原样比较即可）。
fn named_color_hit(s : String) -> Bool {
  let lower = String::from_array(
    s.to_array().map(fn(ch) {
      let c = ch.to_int()
      if c >= 65 && c <= 90 {
        (c + 32).unsafe_to_char()
      } else {
        ch
      }
    }),
  )
  named_color_set.contains(lower)
}

///|
/// theme 的 20 个颜色字段 + `control_height` 之外的颜色 token 名单就是这张表
/// （design.md §1.4：token 名单不另设一套）。顺序与 `Theme` 字段一致。
pub let color_tokens : Array[String] = [
  "primary",
  "primary_light",
  "primary_hover",
  "danger",
  "danger_light",
  "danger_hover",
  "success",
  "success_light",
  "warning",
  "warning_light",
  "info",
  "info_light",
  "text_primary",
  "text_regular",
  "text_secondary",
  "border",
  "fill_hover",
  "fill_zebra",
  "bg_page",
  "bg_panel",
]

///|
/// 可用 token 清单串（报错文本用）。
fn token_list_text() -> String {
  let mut acc = ""
  for t in color_tokens {
    acc = if acc == "" {
      t
    } else {
      acc + ", " + t
    }
  }
  acc
}

///|
/// token 名不认识时的报错文本（含可用 token 清单）。
pub fn unknown_token_message(name : String) -> String {
  "未知颜色 token: \"" + name + "\"，可用 token: " + token_list_text()
}

///|
/// 校验 `Var` token 名：认识返回原值，不认识当场 **abort**（应用启动构造样式表
/// 时一次性出声，不留到绘制期静默回退，design.md §1.5 末条）。
pub fn check_color(c : Color) -> Color {
  match c {
    Var(name) =>
      if color_tokens.contains(name) {
        c
      } else {
        @abort.abort(unknown_token_message(name))
      }
    _ => c
  }
}

///|
/// 绘制期落色：`Var` 现取当前主题的对应字段，`Hex` / `Named` 原样返回
/// （命名色字符串交由绘制层的颜色解析处理，与现状 `TextSource::color` 同口径）。
pub fn resolve_color(c : Color) -> String {
  match c {
    Hex(s) | Named(s) => s
    Var(name) => theme_token_value(name)
  }
}

///|
/// 按 token 名读当前主题的颜色值；名字不认识时返回空串（构造期已拦下，
/// 这里只是不再重复报错）。
pub fn theme_token_value(name : String) -> String {
  let t = @theme.theme_current()
  match name {
    "primary" => t.primary
    "primary_light" => t.primary_light
    "primary_hover" => t.primary_hover
    "danger" => t.danger
    "danger_light" => t.danger_light
    "danger_hover" => t.danger_hover
    "success" => t.success
    "success_light" => t.success_light
    "warning" => t.warning
    "warning_light" => t.warning_light
    "info" => t.info
    "info_light" => t.info_light
    "text_primary" => t.text_primary
    "text_regular" => t.text_regular
    "text_secondary" => t.text_secondary
    "border" => t.border
    "fill_hover" => t.fill_hover
    "fill_zebra" => t.fill_zebra
    "bg_page" => t.bg_page
    "bg_panel" => t.bg_panel
    _ => ""
  }
}
