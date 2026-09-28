#!/usr/bin/env python3
"""iconfont SVG 字体 → MoonBit 图标代码生成器。

用法:
  python3 scripts/gen_icons.py <iconfont 包目录>
包目录需含 iconfont.json(元数据)与 iconfont.svg(SVG 字体)。

从 SELECTION 挑选图标,把字体轮廓坐标归一化后翻译成 Painter 调用,
替换 yue/icons.mbt 中三处 icons-gen 标记之间的内容。
生成的都是填充型图标(整 path 一次 p.fill()),非零环绕规则由
cairo/Win 后端默认支持,子路径方向原样保留(镂空依赖反向环绕)。
"""

import json
import math
import re
import sys

REPO = __file__.rsplit("/scripts/", 1)[0]
ICONS_MBT = REPO + "/yue/icons.mbt"

# 选型清单: font_class -> MoonBit 变体名(桌面 GUI 场景,品牌/食物/体育等不收)
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
# 归一化半径:图标内容约占 s 的 88%(与手写线条图标观感一致)
FIT = 0.88


# ---------- SVG path 解析:输出 [(cmd, [numbers...])] 绝对化 ----------

def tokenize_path(d):
    for m in re.finditer(r"([MmLlHhVvCcSsQqTtAaZz])|(" + NUM.pattern + r")", d):
        if m.group(1):
            yield m.group(1), None
        else:
            yield None, float(m.group(2))


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
    # 相对转绝对
    abs_cmds = []
    x = y = 0.0
    start = (0.0, 0.0)
    i = 0
    for cmd, args in out:
        rel = cmd.islower()
        C = cmd.upper()
        if C == "M":
            first = True
            j = 0
            while j < len(args):
                px, py = args[j], args[j + 1]
                if first:
                    px += x if rel else 0
                    py += y if rel else 0
                    first = False
                    start = (px, py)
                    abs_cmds.append(("M", [px, py]))
                else:
                    # M 后续坐标按 L 处理(SVG 规范)
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
                    # S: 反射上一控制点
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
            for j in range(0, len(args), 4 if C == "Q" else 2):
                if C == "Q":
                    a = args[j : j + 4]
                    if rel:
                        a[0] += x; a[1] += y; a[2] += x; a[3] += y
                    abs_cmds.append(("Q", a))
                    x, y = a[2], a[3]
                else:
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


# ---------- 几何收集:得到多边形子路径(所有曲线采样/转换后仍按原语保留) ----------

def glyph_geometry(abs_cmds):
    """返回 (subpaths, all_points)。
    subpaths: 每条为 ops 列表, op = ('L', x, y) | ('C', x1,y1,x2,y2,x,y)。
    弧展开为折线,二次贝塞尔升为三次。"""
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
            # 升为三次:c1 = p0 + 2/3(q-p0), c2 = p2 + 2/3(q-p2)
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


def gen_arm(variant, comment, subpaths, cx_expr="cx", cy_expr="cy"):
    """生成一个 match 分支。坐标已归一化到 [-1,1],乘 u 后即 s*0.88 范围。"""
    lines = [f"    {variant} => {{ // {comment}"]
    lines.append("      let u = s * 0.88")
    lines.append("      p.begin_path()")
    for sp in subpaths:
        for i, op in enumerate(sp):
            if op[0] == "L":
                x, y = op[1], op[2]
                if i == 0:
                    lines.append(f"      p.move_to({cx_expr} + {fmt(x)} * u, {cy_expr} + {fmt(y)} * u)")
                else:
                    lines.append(f"      p.line_to({cx_expr} + {fmt(x)} * u, {cy_expr} + {fmt(y)} * u)")
            else:
                _, x1, y1, x2, y2, px, py = op
                lines.append(
                    f"      p.bezier_curve_to({cx_expr} + {fmt(x1)} * u, {cy_expr} + {fmt(y1)} * u, "
                    f"{cx_expr} + {fmt(x2)} * u, {cy_expr} + {fmt(y2)} * u, "
                    f"{cx_expr} + {fmt(px)} * u, {cy_expr} + {fmt(py)} * u)"
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


def replace_section(src, begin_marker, end_marker, content):
    pat = re.compile(r"(" + re.escape(begin_marker) + r").*?(" + re.escape(end_marker) + r")", re.S)
    if not pat.search(src):
        raise SystemExit("marker not found: " + begin_marker)
    return pat.sub(lambda m: m.group(1) + "\n" + content + "\n  " + m.group(2), src, count=1)


def main():
    pkg = sys.argv[1] if len(sys.argv) > 1 else "."
    meta = json.load(open(f"{pkg}/iconfont.json"))
    zh_names = {g["font_class"]: g["name"] for g in meta["glyphs"]}
    svg = open(f"{pkg}/iconfont.svg").read()

    # unicode codepoint -> path d
    by_cp = {}
    for gm in re.finditer(r'<glyph\s+[^>]*unicode="([^"]*)"[^>]*d="([^"]*)"', svg):
        tag = gm.group(0)
        d = gm.group(2)
        uni = gm.group(1)
        mcp = re.search(r"&#x([0-9a-fA-F]+);|&#(\d+);", uni)
        if not mcp:
            continue
        cp = int(mcp.group(1), 16) if mcp.group(1) else int(mcp.group(2))
        by_cp[cp] = d
    # unicode 属性可能不带实体(直接字符)
    for gm in re.finditer(r'<glyph\s+[^>]*?unicode="([^"<&][^"]*)"[^>]*?d="([^"]*)"', svg):
        ch = gm.group(1)
        if len(ch) == 1:
            by_cp.setdefault(ord(ch), gm.group(2))

    class_to_cp = {}
    for g in meta["glyphs"]:
        class_to_cp[g["font_class"]] = int(g["unicode_decimal"])

    arms, variants, names = [], [], []
    skipped = []
    for fc, variant in SELECTION.items():
        if fc not in class_to_cp or class_to_cp[fc] not in by_cp:
            skipped.append(fc)
            continue
        d = by_cp[class_to_cp[fc]]
        abs_cmds = parse_path(d)
        subpaths, pts = glyph_geometry(abs_cmds)
        subpaths = normalize(subpaths, pts)
        zh = zh_names.get(fc, fc)
        arms.append(gen_arm(variant, zh, subpaths))
        variants.append(f"  {variant} // {zh}")
        names.append(f'    {variant} => "yh/{fc}"')

    gen_block = "\n".join(arms)
    var_block = "\n".join(variants)
    name_block = "\n".join(names)

    src = open(ICONS_MBT).read()
    src = replace_section(src, "// ---- icons-gen:variants", "// ---- icons-gen:end ----", var_block)
    src = replace_section(src, "    // ---- icons-gen:arms", "    // ---- icons-gen:end ----", gen_block)
    src = replace_section(src, "    // ---- icons-gen:names", "    // ---- icons-gen:end ----", name_block)
    open(ICONS_MBT, "w").write(src)

    n = len(arms)
    print(f"生成 {n} 个图标")
    if skipped:
        print("跳过(字体中未找到):", ", ".join(skipped))


if __name__ == "__main__":
    main()
