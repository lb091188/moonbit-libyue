#!/usr/bin/env python3
"""iconfont SVG 字体 → MoonBit 图标代码生成器(全量替换手写图标集)。

用法:
  python3 scripts/gen_icons.py <iconfont 包目录>
包目录需含 iconfont.json(元数据)与 iconfont.svg(SVG 字体)。

职责:
1. 解析 SVG 字体 glyph(unicode→path d),全指令集:直线/贝塞尔/弧线端点
   参数化展开,Q 升三次,S/T 反射;bbox 归一化到 ±1 并翻转 y(字体 y 向上),
   坐标乘 s*0.88 与旧手写线条图标观感一致;填充型(整 path 一次 p.fill()),
   子路径方向原样保留(镂空靠非零环绕,cairo 默认即非零)。
2. 变体命名:SELECTION 覆盖表优先,其余按 font_class 自动转 PascalCase,
   统一 Yh 前缀,重名追加数字后缀。
3. 重写 yue/icons.mbt 的 icons-gen 标记段,并清除旧手写图标残留:
   枚举变体、draw_icon/icon_name 旧分支、无用绘图助手(icon_dot 被
   splitter 使用,保留)、all_icons 清单。
4. 同步更新文件头与文档注释中的图标计数。
"""

import json
import math
import re
import sys

REPO = __file__.rsplit("/scripts/", 1)[0]
ICONS_MBT = REPO + "/yue/icons.mbt"

# 命名覆盖表:font_class -> MoonBit 变体名(与自动 PascalCase 不一致或需稳定的)
SELECTION = {
    # —— MES 表单控件 ——
    "tree-structure": "YhTreeStructure",
    "tree-table": "YhTreeTable",
    "table": "YhTable",
    "tab": "YhTab",
    "text-field": "YhTextField",
    "textarea-field": "YhTextarea",
    "number-field": "YhNumberField",
    "select-field": "YhSelectField",
    "edit-table": "YhEditTable",
    "script": "YhScript",
    "yunhang": "YhFunction",
    "canshu": "YhParams",
    "tiaojianchaxun": "YhQueryFilter",
    # —— 文本排版 ——
    "font-size": "YhFontSize",
    "font-colors": "YhFontColor",
    "line-height": "YhLineHeight",
    "strikethrough": "YhStrikethrough",
    "indent": "YhIndent",
    "outdent": "YhOutdent",
    # —— 对齐/布局 ——
    "colum-height": "YhColumnHeight",
    "column-width": "YhColumnWidth",
    "vertical-align-botto": "YhVAlignBottom",
    "vertical-align-middl": "YhVAlignMiddle",
    "vertical-align-top": "YhVAlignTop",
    "border-outer": "YhBorderOuter",
    "border-top": "YhBorderTop",
    "border-bottom": "YhBorderBottom",
    "border-left": "YhBorderLeft",
    "border-right": "YhBorderRight",
    "border-inner": "YhBorderInner",
    "border-verticle": "YhBorderVertical",
    "border-horizontal": "YhBorderHorizontal",
    "appstore": "YhAppstore",
    "full-screen": "YhFullscreen",
    # —— 窗口/流程操作 ——
    "fullscreen-exit": "YhFullscreenExit",
    "totop": "YhToTop",
    "swap": "YhSwap",
    "rollback": "YhRollback",
    "enter": "YhEnter",
    "drag": "YhDrag",
    # —— 菜单/排序 ——
    "menu-fold": "YhMenuFold",
    "menu-unfold": "YhMenuUnfold",
    "sort-descending": "YhSortDesc",
    "sort-ascending": "YhSortAsc",
    # —— 文件族 ——
    "file": "YhFile",
    "file-pdf": "YhFilePdf",
    "file-word": "YhFileWord",
    "file-excel": "YhFileExcel",
    "file-ppt": "YhFilePpt",
    "file-zip": "YhFileZip",
    "file-markdown": "YhFileMarkdown",
    "filesearch": "YhFileSearch",
    "snippets": "YhSnippets",
    # —— 云/设备 ——
    "cloud-server": "YhCloudServer",
    "cloud-sync": "YhCloudSync",
    "api": "YhApi",
    "gateway": "YhGateway",
    "qrcode": "YhQrcode",
    "barcode": "YhBarcode",
    "scan1": "YhScan",
    "laptop": "YhLaptop",
    "tablet": "YhTablet",
    "USB": "YhUsb",
    "video1": "YhVideo",
    # —— 图表 ——
    "areachart": "YhAreaChart",
    "linechart": "YhLineChart",
    "radarchart": "YhRadarChart",
    "boxplot": "YhBoxplot",
    "dashboard1": "YhDashboard",
    # —— 用户 ——
    "idcard": "YhIdcard",
    "contacts": "YhContacts",
    # —— 状态/交互 ——
    "stop": "YhStop",
    "export": "YhExport",
    "Import": "YhImport",
    "smile": "YhSmile",
    "frown": "YhFrown",
    "attachment": "YhPaperclip",
    "crop": "YhCrop",
    "magic-stick": "YhMagicStick",
    "wallet": "YhWallet",
    "books": "YhBooks",
}

NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")


# ---------- SVG path 解析 ----------

def tokenize_path(d):
    for m in re.finditer(r"([MmLlHhVvCcSsQqTtAaZz])|(" + NUM.pattern + r")", d):
        if m.group(1):
            yield m.group(1), None
        else:
            yield None, float(m.group(2))


def flush(cmd, nums):
    """按指令参数个数切分重复组。"""
    size = {
        "M": 2, "m": 2, "L": 2, "l": 2, "H": 1, "h": 1, "V": 1, "v": 1,
        "C": 6, "c": 6, "S": 4, "s": 4, "Q": 4, "q": 4, "T": 2, "t": 2,
        "A": 7, "a": 7, "Z": 0, "z": 0,
    }[cmd]
    if size == 0:
        return [(cmd, [])]
    return [(cmd, nums[i : i + size]) for i in range(0, len(nums), size)]


def parse_path(d):
    """解析为绝对坐标指令序列 [(cmd, args)]。"""
    out = []
    cmd = None
    nums = []
    for c, n in tokenize_path(d):
        if c:
            if cmd:
                out.extend(flush(cmd, nums))
            cmd = c
            nums = []
        else:
            nums.append(n)
    if cmd:
        out.extend(flush(cmd, nums))
    abs_cmds = []
    x = y = 0.0
    start = (0.0, 0.0)
    for cmd, args in out:
        rel = cmd.islower()
        C = cmd.upper()
        if C == "M":
            first = True
            j = 0
            while j < len(args):
                px, py = args[j], args[j + 1]
                if first:
                    if rel:
                        px += x
                        py += y
                    first = False
                    start = (px, py)
                    abs_cmds.append(("M", [px, py]))
                else:
                    if rel:
                        px += x
                        py += y
                    abs_cmds.append(("L", [px, py]))
                x, y = px, py
                j += 2
            continue
        if C == "L":
            for j in range(0, len(args), 2):
                px, py = args[j], args[j + 1]
                if rel:
                    px += x
                    py += y
                abs_cmds.append(("L", [px, py]))
                x, y = px, py
            continue
        if C == "H":
            for v in args:
                px = v + x if rel else v
                abs_cmds.append(("L", [px, y]))
                x = px
            continue
        if C == "V":
            for v in args:
                py = v + y if rel else v
                abs_cmds.append(("L", [x, py]))
                y = py
            continue
        if C in ("C", "S"):
            n = 6 if C == "C" else 4
            for j in range(0, len(args), n):
                a = args[j : j + n]
                if rel:
                    for k in range(0, n, 2):
                        a[k] += x
                        a[k + 1] += y
                if C == "C":
                    abs_cmds.append(("C", a))
                else:
                    prev = abs_cmds[-1] if abs_cmds else None
                    if prev and prev[0] == "C":
                        x0, y0 = x, y
                        px1, py1 = prev[1][2], prev[1][3]
                        a = [2 * x0 - px1, 2 * y0 - py1] + a
                    else:
                        a = [x, y] + a
                    abs_cmds.append(("C", a))
                x, y = a[-2], a[-1]
            continue
        if C in ("Q", "T"):
            if C == "Q":
                for j in range(0, len(args), 4):
                    a = args[j : j + 4]
                    if rel:
                        a[0] += x; a[1] += y; a[2] += x; a[3] += y
                    abs_cmds.append(("Q", a))
                    x, y = a[2], a[3]
            else:
                for j in range(0, len(args), 2):
                    px, py = args[j], args[j + 1]
                    if rel:
                        px += x; py += y
                    prev = abs_cmds[-1] if abs_cmds else None
                    if prev and prev[0] == "Q":
                        qx, qy = prev[1][0], prev[1][1]
                    else:
                        qx, qy = x, y
                    a = [2 * x - qx, 2 * y - qy, px, py]
                    abs_cmds.append(("Q", a))
                    x, y = px, py
            continue
        if C == "A":
            for j in range(0, len(args), 7):
                a = args[j : j + 7]
                if rel:
                    a[5] += x
                    a[6] += y
                abs_cmds.append(("A", a))
                x, y = a[5], a[6]
            continue
        if C == "Z":
            abs_cmds.append(("Z", []))
            x, y = start
            continue
        raise ValueError("unknown cmd " + cmd)
    return abs_cmds


# ---------- 弧展开(端点参数 → 采样点) ----------

def arc_points(x1, y1, rx, ry, phi_deg, laf, sf, x2, y2):
    """SVG 弧的端点参数化,返回采样点列表(不含起点)。"""
    if rx == 0 or ry == 0 or (x1 == x2 and y1 == y2):
        return [(x2, y2)]
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg)
    cosp, sinp = math.cos(phi), math.sin(phi)
    dx2, dy2 = (x1 - x2) / 2, (y1 - y2) / 2
    x1s = cosp * dx2 + sinp * dy2
    y1s = -sinp * dx2 + cosp * dy2
    lam = x1s**2 / rx**2 + y1s**2 / ry**2
    if lam > 1:
        s = math.sqrt(lam)
        rx *= s
        ry *= s
    num = rx**2 * ry**2 - rx**2 * y1s**2 - ry**2 * x1s**2
    den = rx**2 * y1s**2 + ry**2 * x1s**2
    co = math.sqrt(max(0.0, num / den)) if den else 0.0
    if laf == sf:
        co = -co
    csx = co * rx * y1s / ry
    csy = -co * ry * x1s / rx
    cx = cosp * csx - sinp * csy + (x1 + x2) / 2
    cy = sinp * csx + cosp * csy + (y1 + y2) / 2
    def ang(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        n = math.hypot(ux, uy) * math.hypot(vx, vy)
        a = math.acos(max(-1.0, min(1.0, dot / n))) if n else 0.0
        if ux * vy - uy * vx < 0:
            a = -a
        return a
    th1 = ang(1, 0, (x1s - csx) / rx, (y1s - csy) / ry)
    dth = ang((x1s - csx) / rx, (y1s - csy) / ry, (-x1s - csx) / rx, (-y1s - csy) / ry)
    if not sf and dth > 0:
        dth -= 2 * math.pi
    elif sf and dth < 0:
        dth += 2 * math.pi
    n = max(2, int(math.ceil(abs(dth) / math.radians(10))))
    pts = []
    for i in range(1, n + 1):
        th = th1 + dth * i / n
        ex = rx * math.cos(th)
        ey = ry * math.sin(th)
        pts.append((cosp * ex - sinp * ey + cx, sinp * ex + cosp * ey + cy))
    return pts


# ---------- 几何收集 ----------

def glyph_geometry(abs_cmds):
    """返回 (subpaths, all_points);弧展开为折线,二次贝塞尔升为三次。"""
    subpaths = []
    cur = []
    x = y = 0.0
    all_pts = []
    for cmd, a in abs_cmds:
        if cmd == "M":
            if cur:
                subpaths.append(cur)
            x, y = a[0], a[1]
            cur = [("L", x, y)]
            all_pts.append((x, y))
        elif cmd == "L":
            x, y = a[0], a[1]
            cur.append(("L", x, y))
            all_pts.append((x, y))
        elif cmd == "C":
            x1, y1, x2, y2, px, py = a
            cur.append(("C", x1, y1, x2, y2, px, py))
            all_pts += [(x1, y1), (x2, y2), (px, py)]
            x, y = px, py
        elif cmd == "Q":
            qx, qy, px, py = a
            c1x = x + 2.0 / 3.0 * (qx - x)
            c1y = y + 2.0 / 3.0 * (qy - y)
            c2x = px + 2.0 / 3.0 * (qx - px)
            c2y = py + 2.0 / 3.0 * (qy - py)
            cur.append(("C", c1x, c1y, c2x, c2y, px, py))
            all_pts += [(qx, qy), (px, py)]
            x, y = px, py
        elif cmd == "A":
            rx, ry, rot, laf, sf, px, py = a
            pts = arc_points(x, y, rx, ry, rot, laf, sf, px, py)
            for p in pts:
                cur.append(("L", p[0], p[1]))
            all_pts += pts
            x, y = px, py
        elif cmd == "Z":
            if cur:
                subpaths.append(cur)
                cur = []
    if cur:
        subpaths.append(cur)
    return subpaths, all_pts


# ---------- 代码生成 ----------

def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def gen_arm(variant, comment, subpaths):
    """生成一个 match 分支。坐标已归一化到 [-1,1],乘 u 后即 s*0.88 范围。"""
    lines = [f"    {variant} => {{ // {comment}"]
    lines.append("      let u = s * 0.88")
    lines.append("      p.begin_path()")
    for sp in subpaths:
        for i, op in enumerate(sp):
            if op[0] == "L":
                x, y = op[1], op[2]
                if i == 0:
                    lines.append(f"      p.move_to(cx + {fmt(x)} * u, cy + {fmt(y)} * u)")
                else:
                    lines.append(f"      p.line_to(cx + {fmt(x)} * u, cy + {fmt(y)} * u)")
            else:
                _, x1, y1, x2, y2, px, py = op
                lines.append(
                    f"      p.bezier_curve_to(cx + {fmt(x1)} * u, cy + {fmt(y1)} * u, "
                    f"cx + {fmt(x2)} * u, cy + {fmt(y2)} * u, cx + {fmt(px)} * u, cy + {fmt(py)} * u)"
                )
        lines.append("      p.close_path()")
    lines.append("      p.fill()")
    lines.append("    }")
    return "\n".join(lines)


def normalize(subpaths, pts):
    """按 bbox 归一化到中心 0、最大半边长 1(y 翻转)。"""
    if not pts:
        return subpaths
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bcx, bcy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    half = max(max(xs) - min(xs), max(ys) - min(ys)) / 2
    if half == 0:
        half = 1
    out = []
    for sp in subpaths:
        nsp = []
        for op in sp:
            if op[0] == "L":
                nsp.append(("L", (op[1] - bcx) / half, -(op[2] - bcy) / half))
            else:
                nsp.append(("C", (op[1] - bcx) / half, -(op[2] - bcy) / half,
                            (op[3] - bcx) / half, -(op[4] - bcy) / half,
                            (op[5] - bcx) / half, -(op[6] - bcy) / half))
        out.append(nsp)
    return out


def pascal(fc):
    parts = [p for p in fc.split("-") if p]
    return "".join(p[:1].upper() + p[1:] for p in parts)


def replace_section(src, begin_marker, end_marker, content):
    pat = re.compile(r"(" + re.escape(begin_marker) + r").*?(" + re.escape(end_marker) + r")", re.S)
    if not pat.search(src):
        raise SystemExit("marker not found: " + begin_marker)
    return pat.sub(lambda m: m.group(1) + "\n" + content + "\n" + m.group(2), src, count=1)


def strip_legacy(src):
    """删除旧手写图标:枚举变体、两个 match 旧分支、无用助手、all_icons 清单。"""
    # 1. 枚举旧变体
    src = re.sub(
        r"(pub\(all\) enum IconKind \{\n).*?(\n  // ---- icons-gen:variants)",
        r"\1\2", src, count=1, flags=re.S)
    # 2. draw_icon 旧分支(match kind { 到 arms 标记)
    src = re.sub(
        r"(  match kind \{\n).*?(\n    // ---- icons-gen:arms)",
        r"\1\2", src, count=1, flags=re.S)
    # 3. icon_name 旧分支
    src = re.sub(
        r"(pub fn icon_name\(kind : IconKind\) -> String \{\n.*?  match kind \{\n).*?(\n    // ---- icons-gen:names)",
        r"\1\2", src, count=1, flags=re.S)
    # 4. 无用绘图助手(icon_dot 被 splitter 使用,保留)
    for name in ("icon_circle", "icon_polyline", "icon_polygon", "icon_outline", "icon_line", "icon_arc"):
        src = re.sub(r"\nfn " + name + r"\(.*?\n\}\n", "\n", src, count=1, flags=re.S)
    # 5. all_icons 清单换成标记段
    src = re.sub(
        r"(pub fn all_icons\(\) -> Array\[IconKind\] \{\n  \[\n).*?(\n  \]\n\})",
        r"\1    // ---- icons-gen:all (scripts/gen_icons.py 维护,勿手改) ----\n    // ---- icons-gen:end ----\2",
        src, count=1, flags=re.S)
    return src


def main():
    pkg = sys.argv[1] if len(sys.argv) > 1 else "."
    meta = json.load(open(f"{pkg}/iconfont.json"))
    zh_names = {g["font_class"]: g["name"] for g in meta["glyphs"]}
    svg = open(f"{pkg}/iconfont.svg").read()

    # unicode codepoint -> path d
    by_cp = {}
    for gm in re.finditer(r'<glyph\s+[^>]*unicode="([^"]*)"[^>]*d="([^"]*)"', svg):
        mcp = re.search(r"&#x([0-9a-fA-F]+);|&#(\d+);", gm.group(1))
        if not mcp:
            continue
        cp = int(mcp.group(1), 16) if mcp.group(1) else int(mcp.group(2))
        by_cp[cp] = gm.group(2)
    for gm in re.finditer(r'<glyph\s+[^>]*?unicode="([^"<&][^"]*)"[^>]*?d="([^"]*)"', svg):
        ch = gm.group(1)
        if len(ch) == 1:
            by_cp.setdefault(ord(ch), gm.group(2))

    # 全量生成:字体顺序 + 命名去重
    used = {}
    arms, variants, names, all_list = [], [], [], []
    skipped = []
    for g in meta["glyphs"]:
        fc = g["font_class"]
        cp = int(g["unicode_decimal"])
        if cp not in by_cp:
            skipped.append(fc)
            continue
        base = SELECTION.get(fc) or ("Yh" + pascal(fc))
        variant = base
        n = 2
        while variant in used:
            variant = f"{base}{n}"
            n += 1
        used[variant] = fc
        d = by_cp[cp]
        abs_cmds = parse_path(d)
        subpaths, pts = glyph_geometry(abs_cmds)
        subpaths = normalize(subpaths, pts)
        zh = zh_names.get(fc, fc)
        arms.append(gen_arm(variant, zh, subpaths))
        variants.append(f"  {variant} // {zh}")
        names.append(f'    {variant} => "yh/{fc}"')
        all_list.append(f"    {variant},")

    # arms 拆块:每块独立顶层函数 + 通配兜底,避免单段超限(0033 警告)
    chunk_size = 110
    n_chunks = (len(arms) + chunk_size - 1) // chunk_size
    dispatch = []
    chunks = []
    for c in range(n_chunks):
        part = arms[c * chunk_size : (c + 1) * chunk_size]
        n = c + 1
        dispatch.append("  draw_icon_chunk_" + str(n) + "(p, kind, cx, cy, s)")
        head = (
            "///|\nfn draw_icon_chunk_" + str(n) + "(\n"
            "    p : Painter,\n"
            "    kind : IconKind,\n"
            "    cx : Double,\n"
            "    cy : Double,\n"
            "    s : Double,\n"
            ") -> Unit {\n"
            "  match kind {\n"
        )
        tail = "\n    _ => ()\n  }\n}\n"
        chunks.append(head + "\n".join(part) + tail)

    src = open(ICONS_MBT).read()
    src = strip_legacy(src)
    src = replace_section(src, "// ---- icons-gen:variants", "// ---- icons-gen:end ----",
                          "\n".join(variants))
    src = replace_section(src, "// ---- icons-gen:dispatch", "// ---- icons-gen:end ----",
                          "\n".join(dispatch))
    src = replace_section(src, "// ---- icons-gen:chunks", "// ---- icons-gen:end ----",
                          "\n\n".join(chunks))
    src = replace_section(src, "// ---- icons-gen:names", "// ---- icons-gen:end ----",
                          "\n".join(names))
    src = replace_section(src, "// ---- icons-gen:all", "// ---- icons-gen:end ----",
                          "\n".join(all_list))
    # 计数注释同步
    total = len(arms)
    src = re.sub(r"\d+ 个内置矢量图标", f"{total} 个内置矢量图标", src)
    src = re.sub(r"\d+ built-in vector icons", f"{total} built-in vector icons", src)
    src = re.sub(r"全部图标种类清单\(\d+ 项", f"全部图标种类清单({total} 项", src)
    open(ICONS_MBT, "w").write(src)

    print(f"生成 {total} 个图标")
    if skipped:
        print("跳过(字体中未找到):", ", ".join(skipped))


if __name__ == "__main__":
    main()
