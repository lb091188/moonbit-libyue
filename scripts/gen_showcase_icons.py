#!/usr/bin/env python3
"""重写 examples/showcase/pages/icons.mbt:按主题组铺全量图标墙。

用法: python3 scripts/gen_showcase_icons.py
读取 yue/icons.mbt 的生成标记区(变体+中文名),按 GROUPS 分组输出,
未分组的落入「其他」。页面结构(icon_grid/icon_group_code/@ui.page)
与原页一致,只换图标清单与分组。
"""

import re

REPO = __file__.rsplit("/scripts/", 1)[0]
ICONS_MBT = REPO + "/yue/icons.mbt"
PAGE = REPO + "/examples/showcase/pages/icons.mbt"

# (组名, 中文标题, 一句描述, [font_class...])
GROUPS = [
    ("form", "表单与表格", "MES 表单控件:输入框/下拉/树形/表格/标签页。", [
        "tree-structure", "tree-table", "table", "tab", "text-field", "textarea-field",
        "number-field", "select-field", "edit-table", "switch", "switch-button",
        "click-button", "static-text", "script", "yunhang", "canshu", "tiaojianchaxun",
        "select", "checkbox",
    ]),
    ("edit", "编辑与排版", "字体样式/对齐/缩进/撤销重做/保存。", [
        "bold", "italic", "underline", "strikethrough", "font-size", "font-colors",
        "line-height", "bg-colors", "indent", "outdent", "align-left", "align-center",
        "align-right", "vertical-align-top", "vertical-align-middl", "vertical-align-botto",
        "colum-height", "column-width", "dash", "small-dash", "number", "scissor",
        "scissors", "copy-document", "document-copy", "edit1", "edit-fill",
        "weibiaoti545", "undo", "redo", "huifu", "save1", "save-fill", "clear",
        "brush", "highlight", "highlight-fill",
    ]),
    ("direction", "方向与翻页", "箭头/折叠三角/回到顶部/交换/拖拽。", [
        "caret-up-small", "caret-down-small", "caret-left-small", "caret-right-small",
        "d-caret", "d-arrow-left", "d-arrow-right", "arrow-left", "arrow-right",
        "arrow-up", "arrow-down", "back", "top", "bottom", "totop", "enter", "enter1",
        "swap", "rollback", "rollfront", "jump", "drag", "move1", "arrawsalt",
        "verticalright", "verticalleft", "up-circle", "down-circle", "left-circle",
        "right-circle", "top-left", "top-right", "bottom-left", "bottom-right",
        "shrink", "full-screen", "fullscreen-exit", "fullscreen",
    ]),
    ("layout", "布局与视图", "网格/边框/圆角/图层/分布/缩放。", [
        "layout", "layout-fill", "appstore", "appstore-fill", "border", "border-outer",
        "border-top", "border-bottom", "border-left", "border-right", "border-inner",
        "border-verticle", "border-horizontal", "radius-upleft", "radius-upright",
        "radius-bottomleft", "radius-bottomright", "radius-setting", "kuaibuju",
        "shuxiangfenbu", "hengxiangfenbu1", "zuoyoujuzhong", "shangxiajuzhong",
        "daxiaoxiangdeng", "dengkuan", "denggao", "format-horizontal-align-top",
        "pic-center", "pic-right", "pic-left", "unorderedlist", "orderedlist",
        "root-list", "layers", "tuceng", "tucengzhizuoyuweihu", "dingceng", "diceng",
        "shangyiyiceng", "xiayiyiceng", "mirror", "rotation", "zoom-in", "zoom-out",
        "suofangdaodengbi", "chicunbiaozhu_",
    ]),
    ("file", "文件与文档", "文件族/文件夹/文档/书籍/证件。", [
        "file", "file1", "file-add", "file-copy", "file-excel", "file-exclamation",
        "file-pdf", "file-image", "file-markdown", "file-unknown", "file-ppt",
        "file-word", "file-zip", "file-text", "filedone", "filesync", "filesearch",
        "file-exception", "fileprotect", "snippets", "audit", "diff", "Batchfolding",
        "reconciliation", "solution", "folder", "folder-open", "folder-add1",
        "folder-remove", "folder-checked", "folder-delete", "document", "document-add",
        "document-checked", "document-delete", "document-remove", "book", "books",
        "read", "notebook-", "notebook-1", "idcard", "contacts",
        "file-excel-fill", "file-pdf-fill", "file-word-fill", "file-ppt-fill",
        "file-zip-fill", "file-text-fill", "file-markdown-fill", "file-image-fill",
        "file-unknown-fill", "file-add-fill", "file-copy-fill", "file-exclamation-fil",
        "folder-fill", "folder-open-fill", "book-fill", "read-fill", "idcard-fill",
        "contacts-fill", "snippets-fill", "diff-fill", "reconciliation-fill",
        "batchfolding-fill",
    ]),
    ("cloud", "云与运维", "云同步/网关/集群/数据库/条码/链接。", [
        "cloud", "cloud-server", "cloud-upload", "cloud-download", "cloud-sync",
        "cloud-fill", "api", "api-fill", "gateway", "sever", "cluster",
        "deploymentunit", "database", "database-fill", "container", "container-fill",
        "disconnect", "USB", "USB-fill", "qrcode", "barcode", "barcode1", "scan1",
        "saomiao", "iconset0254", "link", "link1", "connection",
    ]),
    ("device", "设备与硬件", "笔记本/手机/平板/打印机/相机/外设。", [
        "laptop", "mobile", "mobile1", "mobile-phone", "tablet", "monitor", "monitor1",
        "printer", "camera", "camera-fill", "video", "video1", "video-camera",
        "video-camera-solid", "video-play", "video-pause", "video-fill", "headset",
        "mouse", "microphone", "mic", "xinhao", "printer-fill", "mobile-fill",
        "tablet-fill",
    ]),
    ("chart", "图表与数据", "折线/柱状/饼图/雷达/仪表/统计分析。", [
        "areachart", "linechart", "radarchart", "boxplot", "boxplot-fill", "fund",
        "fund-fill", "stock", "rise", "fall", "heatmap", "pointmap", "dashboard1",
        "dashboard-fill", "chart", "chart-bar", "chart-bubble", "chat-bar", "pie-chart",
        "piechart", "piechart-circle-fil", "data-board", "data-analysis", "data-line",
        "a-precisemonitor", "a-controlplatform", "shebeidianjiantongji",
        "zhushujushenqing-shujufenxi-02", "zhongsuanrenwuliebiao",
    ]),
    ("comm", "通信与消息", "消息/邮件/通知/电话/分享/客服。", [
        "message", "message1", "message-solid", "message-fill", "mail", "mail1",
        "mail-fill", "bell", "bell-fill", "notification", "notification-fill",
        "sound", "sound-fill", "phone", "phone-fill", "phone-outline", "customerservice",
        "customerservice-fill", "share", "share1", "share2", "fuwu-active",
        "lianxiwomen", "guanyuwomen", "user-talk", "wode", "tixing",
    ]),
    ("user", "用户与团队", "用户/团队/增删成员/性别/职业。", [
        "user", "user1", "user-solid", "user-avatar", "team", "addteam", "deleteteam",
        "adduser", "deleteuser", "man", "woman", "mr", "gender-female", "custom-worker",
        "zhiye", "siji", "usergroup-clear",
    ]),
    ("security", "安全与锁定", "锁/钥匙/可见性/证书/扫描。", [
        "lock", "lock1", "lock-fill", "unlock", "unlock1", "unlock-fill", "lock-off",
        "lock-on", "key", "key1", "eye", "eye-fill", "hide", "safetycertificate",
        "safetycertificate-f", "securityscan", "securityscan-fill", "propertysafety",
        "propertysafety-fill", "jiebang",
    ]),
    ("time", "时间与日历", "时钟/计时/日历/加载/同步。", [
        "time", "time-filled", "alarm-clock", "timer", "stopwatch", "reloadtime",
        "hourglass", "hourglass-fill", "calendar", "calendar1", "calendar-check",
        "calendar-fill", "calendar-check-fill", "date", "loading", "loading-step",
        "reload", "sync",
    ]),
    ("status", "状态与反馈", "勾叉/圆环状态/表情/点赞/收藏/电源。", [
        "check", "check-circle", "check-circle-fill", "close", "close2", "circle-close",
        "close-circle-fill", "info", "info-circle", "info-circle-fill", "warning",
        "warning-circle", "warning-circle-fill", "error", "error1", "error-fill",
        "question", "question-circle", "question-circle-fill", "exclaimination", "alert",
        "alert-fill", "minus-circle", "minus-circle-fill", "plus-circle",
        "plus-circle-fill", "minus", "minus1", "plus", "smile", "smile-fill", "frown",
        "frown-fill", "meh", "meh-fill", "stop", "stop-fill", "pause", "play-circle",
        "play-circle-fill", "finished", "fire", "fire-fill", "thunderbolt",
        "thunderbolt-fill", "like", "like-fill", "unlike", "unlike-fill", "star",
        "star-fill", "star-off", "heart", "heart-fill", "thumb", "transaction",
        "poweroff", "poweroff-circle-fill", "weixian", "yichang", "issuesclose",
        "slash", "jingdiananli_wujiaoxing_shoucanghou", "jingdiananli_kongwujiaoxing_shoucang",
    ]),
    ("finance", "金融与商业", "货币/钱包/银行/购物/奖杯/会员。", [
        "money", "coin", "Dollar", "Dollar-circle-fill", "EURO", "EURO-circle-fill",
        "Pound", "Pound-circle-fill", "YUAN", "YUAN-circle-fill", "wallet", "wallet1",
        "wallet-fill", "creditcard", "creditcard-fill", "bank", "bank-fill",
        "bank-card", "moneycollect", "moneycollect-fill", "golden-fill", "gold",
        "accountbook", "accountbook-fill", "calculator", "calculator-fill", "discount",
        "price-tag", "cart", "shopping", "shopping-fill", "shop", "shop-fill", "sell",
        "sold-out", "goods", "shopping-cart-", "redenvelope", "redenvelope-fill",
        "gift", "gift-fill", "present", "trophy", "trophy-fill", "trophy-1", "medal",
        "medal-", "crown", "crown-fill", "percentage", "trademark",
        "trademark-circle-fil", "copyright", "copyright-circle-fil", "CI",
        "CI-circle-fill",
    ]),
    ("system", "系统与工具", "登录登出/导入导出/设置/筛选/构建。", [
        "login", "logout", "export", "Import", "cpu", "windows", "windows-fill",
        "android", "android-fill", "apple", "apple-fill", "apple1", "control",
        "control-fill", "set-up", "setting", "setting1", "setting-fill", "sliders",
        "sliders-fill", "filter", "filter1", "filter-fill", "filter-clear", "tools",
        "wrench", "wrench-fill", "build", "build-fill", "codelibrary", "codelibrary-fill",
        "project", "project-fill", "detail", "detail-fill", "interation",
        "interation-fill", "carryout", "carryout-fill", "box", "experiment",
        "experiment-fill", "medicinebox", "medicinebox-fill", "bulb", "bulb-fill",
        "skin", "skin-fill", "rest", "rest-fill",
        "s-home", "s-open", "s-marketing", "s-management", "s-operation", "s-data",
        "s-cooperation", "s-check", "s-flag", "s-custom", "s-finance", "s-comment",
        "s-shop", "s-ticket", "s-grid", "s-help", "s-claim", "s-goods", "s-promotion",
        "s-release", "s-opportunity", "s-order", "s-tools", "s-platform",
    ]),
    ("weather", "天气与饮食", "晴云雨月/饮品/食物/餐具。", [
        "sunny", "cloudy", "heavy-rain", "light-rain", "lightning", "moon",
        "moon-night", "sunrise-", "sunset", "umbrella", "wind-power", "water-cup",
        "hot-water", "cold-drink", "ice-drink", "ice-tea", "ice-cream", "ice-cream-round",
        "ice-cream-square", "milk-tea", "coffee", "coffee-cup", "orange", "pear",
        "grape", "cherry", "watermelon", "apple", "apple1", "burger", "chicken",
        "food", "dish", "dish-", "dessert", "fork-spoon", "knife-fork", "goblet",
        "goblet-full", "goblet-square-full", "takeaway-box", "tableware", "lollipop",
        "sugar", "potato-strips", "toilet-paper", "refrigerator", "table-lamp",
    ]),
    ("media", "媒体与出行", "图片/影视/球类/交通/定位。", [
        "film", "image", "image1", "image-fill", "picture", "picture-outline",
        "picture-outline-round", "soccer", "basketball", "baseball", "football",
        "bicycle", "no-smoking", "smoking", "car", "car-fill", "truck", "truck-full",
        "ship", "feiji", "receiving", "guide", "location-outline", "location-fill",
        "add-location", "delete-location", "map-location", "position", "aim",
        "coordinate", "compass", "compass-fill", "earth", "school", "office-building",
        "house", "home", "home-fill", "s-home",
    ]),
    ("brand", "品牌与平台", "国内外平台/社交/云厂商标识。", [
        "alibaba", "alibabacloud", "antdesign", "ant-cloud", "behance", "googleplus",
        "medium", "medium-circle-fill", "google", "IE", "amazon", "slack",
        "CodeSandbox", "chrome", "chrome-fill", "dribbble", "dropbox", "facebook",
        "github-fill", "Gitlab", "Gitlab-fill", "HTML", "HTML-fill", "instagram",
        "linkedin", "QQ", "reddit", "sketch", "skype", "skype-fill", "taobao",
        "twitter", "wechat", "weibo", "aliwangwang", "aliwangwang-fill", "alipay",
        "dingtalk", "yuque", "yuque-fill", "Youtube", "Youtube-fill", "yahoo",
        "yahoo-fill", "zhihu", "logo-wecom", "eleme", "platform-eleme",
    ]),
]

# 组内代码样例(每组取前几个已有变体生成)
CODE_SAMPLES = {
    "form": ["tree-table", "text-field", "select-field"],
    "edit": ["bold", "strikethrough", "undo"],
    "direction": ["caret-right-small", "arrow-up", "totop"],
    "layout": ["appstore", "border-inner", "layers"],
    "file": ["file-pdf", "folder-open", "snippets"],
    "cloud": ["cloud-server", "qrcode", "database"],
    "device": ["laptop", "printer", "video-camera"],
    "chart": ["areachart", "pie-chart", "dashboard1"],
    "comm": ["message", "bell", "share2"],
    "user": ["user1", "team", "adduser"],
    "security": ["lock", "eye", "safetycertificate"],
    "time": ["time", "calendar-check", "loading"],
    "status": ["check-circle-fill", "close-circle-fill", "smile"],
    "finance": ["Dollar-circle-fill", "wallet", "creditcard"],
    "system": ["login", "setting-fill", "filter"],
    "weather": ["sunny", "cloudy", "coffee-cup"],
    "media": ["image", "car", "compass"],
    "brand": ["wechat", "github-fill", "chrome"],
}


def load_icons():
    src = open(ICONS_MBT).read()
    zh = {}
    for v, c in re.findall(r'^  (\w+) // (.+)$', src, re.M):
        zh[v] = c
    fc_of = dict(re.findall(r'^    (\w+) => "(.+)"$', src, re.M))
    return fc_of, zh


def main():
    fc_of, zh = load_icons()
    variant_of_fc = {fc: v for v, fc in fc_of.items()}
    assigned = set()
    sections = []
    for key, title, desc, fcs in GROUPS:
        kinds = []
        for fc in fcs:
            if fc in variant_of_fc and fc not in assigned:
                assigned.add(fc)
                kinds.append(variant_of_fc[fc])
        if not kinds:
            continue
        samples = [variant_of_fc[fc] for fc in CODE_SAMPLES.get(key, []) if fc in variant_of_fc]
        sections.append((title, desc, kinds, samples))
    # 未分组
    rest = [v for v, fc in fc_of.items() if fc not in assigned]
    if rest:
        sections.append(("其他", "MES 业务与杂项图标(拼音命名)。", rest,
                         [rest[0], rest[1], rest[2]] if len(rest) >= 3 else rest))

    total = sum(len(s[2]) for s in sections)
    out = []
    out.append("// 图标库页:全量 %d 个矢量图标(iconfont 生成)按分组展示,悬停看名称。" % total)
    out.append("// 本页由 scripts/gen_showcase_icons.py 生成,勿手改;分组定义见该脚本 GROUPS。")
    out.append("// 网格为竖排 vbox 包行(每行 24 个)——外层容器必须 vbox,否则行组被")
    out.append("// 水平排布、超宽截断(图标墙首版即此 bug)。")
    out.append("")
    out.append("///|")
    out.append("/// 一组图标的网格:vbox 包行,每行 per_row 个,悬停 tooltip 显示名称。")
    out.append("fn icon_grid(kinds : Array[@yue.IconKind], per_row : Int) -> @yue.Node {")
    out.append("  let rows : Array[@yue.Node] = []")
    out.append("  for row in 0..<((kinds.length() + per_row - 1) / per_row) {")
    out.append("    let items : Array[@yue.Node] = []")
    out.append("    for col in 0..<per_row {")
    out.append("      let idx = row * per_row + col")
    out.append("      if idx < kinds.length() {")
    out.append("        items.push(")
    out.append("          @yue.tooltip_t(")
    out.append("            @yue.icon(kinds[idx], size=30.0),")
    out.append("            @yue.icon_name(kinds[idx]),")
    out.append("          ),")
    out.append("        )")
    out.append("      }")
    out.append("    }")
    out.append("    rows.push(@yue.hbox(items, style=[(\"gap\", 10.0)]))")
    out.append("  }")
    out.append("  @yue.vbox(rows, style=[(\"gap\", 8.0)])")
    out.append("}")
    out.append("")
    out.append("///|")
    out.append("/// 图标页各分组共用的演示代码形态:icon 画矢量图标,悬停 tooltip 显名。")
    out.append("fn icon_group_code(sample : Array[String]) -> Array[String] {")
    out.append("  let head : Array[String] = [")
    out.append("    \"@yue.hbox([\",")
    out.append("  ]")
    out.append("  for line in sample {")
    out.append("    head.push(line)")
    out.append("  }")
    out.append("  head.push(\"  // …本组其余图标同构\")")
    out.append("  head.push(\"], style=[(\\\"gap\\\", 10.0)])\")")
    out.append("  head")
    out.append("}")
    out.append("")
    out.append("///|")
    out.append("pub fn page_icons(_app : @ui.App) -> @yue.Node {")
    out.append("  @ui.page([")
    for title, desc, kinds, samples in sections:
        out.append("    @ui.section(")
        out.append("      \"%s\"," % title)
        out.append("      \"%s\"," % title)
        out.append("      \"%s\"," % desc)
        out.append("      [")
        out.append("        icon_grid(")
        out.append("          [")
        for i in range(0, len(kinds), 3):
            chunk = kinds[i : i + 3]
            out.append("            " + " ".join("@yue." + k + "," for k in chunk))
        out.append("          ],")
        out.append("          24,")
        out.append("        ),")
        out.append("      ],")
        code_lines = []
        if samples:
            for s in samples[:3]:
                code_lines.append("        \"  @yue.icon(@yue.%s, size=18.0),\"," % s)
            code_lines.append(
                "        \"  @yue.tooltip_t(@yue.icon(@yue.%s, size=18.0), @yue.icon_name(@yue.%s)),\","
                % (samples[0], samples[0]))
        out.append("      code=icon_group_code([")
        out.extend(code_lines)
        out.append("      ]),")
        out.append("    ),")
    out.append("  ])")
    out.append("}")
    out.append("")
    open(PAGE, "w").write("\n".join(out))
    print("showcase icons page: %d sections, %d icons" % (len(sections), total))


if __name__ == "__main__":
    main()
