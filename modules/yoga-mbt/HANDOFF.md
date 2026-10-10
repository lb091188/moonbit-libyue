# yoga-mbt 复刻工作交接

> 交接时间：2026-10-10 10:45（GMT+8）· 交接方：本会话（WorkBuddy）· 接收方：同仓库协作方 / 后续会话
> 修订：2026-10-10 11:10 合入 YG2b（baseline + 交叉轴 margin 定位修复）；11:40 合入 YG2b′（容器 auto 尺寸补 padding/border + 多行主轴尺寸）；12:10 合入 YG2c（aspect-ratio，比例语义 border-box）——各批都同步更新了 §0/§3/§4/§5/§6/§7/§8/§9/§10/§11
> 交接范围：`feature/yoga-mbt` 分支上的「纯 MoonBit Flexbox 布局引擎」复刻工作

---

## 0. 三十秒速览

- **在做什么**：用纯 MoonBit 复刻 Yoga 布局引擎（`modules/yoga-mbt` 独立子包），作为 MoonBit 化 libyue 的布局层。
- **当前进度**：YG1（骨架 + 核心算法）、YG2a（absolute 定位）、YG2b（baseline 对齐 + 交叉轴 margin 定位修复）、YG2b′（容器 auto 尺寸补 padding/border + 多行主轴尺寸）、YG2c（aspect-ratio）已完成并推送；全部提交在 `feature/yoga-mbt`（**分支最新提交以 `git log` 为准**）。
- **门控现状**：`moon check` 零警告 + 全仓 `moon test` **708/708** 全绿；yoga-mbt 自身 47 条白盒断言。
- **下一步**：YG2d RTL → YG3 工程化 → YG4 与 libyue 集成（详见 §8；YG2c 留下一小口：绝对定位子项的比例换算未做）。
- **口径已定**：aspect-ratio 比例作用在 **border-box**（用户 2026-10-10 确认），与 CSS 默认的 content-box 不同，动这块代码前先读 §5 第 12 条。
- **三条纪律**（最容易踩）：① 只对齐 **Web Flexbox 标准**，不做 Yoga 双默认值；② 提交前先 `git fetch` 且用 `git add <显式路径>`，**不要 `git add -A`**；③ 每批改动配套回写 `docs/zh/adaptation.md` 与 `TODO.md`，一批一提交一推送。

---

## 1. 工作副本与分支现状（先看这节，否则容易做重复功）

本机现在有**两个副本**，同一仓库、同一个远端，请认准你要在哪个里面干活：

| 路径 | 当前分支 / HEAD | 状态 | 说明 |
|---|---|---|---|
| `/home/lkyh/ownCode/moonbit-libyue` | `master` @ `a656873` | 有未提交改动（README 中英、moon.mod） | **原副本**，另一会话正在此活动（发布/文档线） |
| `/home/lkyh/ownCode/moonbit-libyue-native` | `feature/yoga-mbt`（随 YG2b 持续前移） | 干净，与 origin 一致 | **本次新建副本**，yoga 复刻工作在这里继续 |

- 目录名原按用户口述照录为 `moonbit-libyue-navite`，经用户确认系 `native` 笔误，已 `mv` 为 `moonbit-libyue-native`（若你的 IDE 工作区仍指向旧名，重新打开新路径即可）。
- 新副本的 `.workbuddy/memory/` 是从原副本复制过去的（未跟踪文件，`git clone` 不会带）。
- 远端分支指向（会随提交前移，核对用 `git fetch && git branch -a --format='%(refname) %(objectname:short)'`）：`master` = `a656873`、`win/native-handle` = `45bdd9f`；`feature/yoga-mbt` 为本分支。

**`feature/yoga-mbt` 分支上的提交构成（合并前必读）**

```
105d3c7  【新增】yoga-mbt absolute 定位（YG2a）        ← yoga 工作
f994a15  【构建】yoga-mbt 发布元数据（readme/keywords）
6830867  【构建】发布元数据补全（ffmpeg-mbt/yue-media）  ← 已在 master（b4fddd5）
b01d1dd  【构建】示例拆分（systemprobe → yue-examples）   ← 已在 master（cf43cd9）
ab7c12a  【新增】yoga-mbt 子包首批（YG1）               ← yoga 工作
206dc97  【重构】systemprobe 命令预览页改版             ← 与 master 的分叉点
```

后两个【构建】提交是另一会话在本分支上顺手做的，**内容已 cherry-pick 进 master**。把本分支合回 master 前，建议只保留 yoga 相关提交，例如从 master 起新分支后 cherry-pick 瑜伽提交：

```sh
git checkout -b feature/yoga-mbt-clean origin/master
git cherry-pick ab7c12a 105d3c7 <后续 yoga 提交>
```

（注意：`moon.work` 的成员表在两分支不同——master 无 `modules/yoga-mbt`，cherry-pick 时若冲突，按目标分支实际存在的成员解决。）

---

## 2. 任务背景与目标

- **为什么做**：libyue 复刻（MoonBit 版跨平台原生桌面 GUI）需要自己的布局层，先用手写 Yoga 引擎替换内嵌的 C++ Yoga。
- **形态**：`modules/yoga-mbt` 独立子包，组织方式对齐 `modules/ffmpeg-mbt`（独立 `moon.mod`、自带 README、可单独发 mooncakes），`moon.work` 已注册。
- **铁律（用户明确要求）**：**只对齐 Web Flexbox 标准**（CSS Flexible Box Layout Level 1），不保留 Yoga 的「yoga 默认 / web 默认」双标准。默认值一律 web 语义：`flex-direction: row`、`flex-shrink: 1`、`flex-basis: auto`、`align-items: stretch`、`min-width/height: auto`。
- **与内嵌 C++ Yoga 的边界**：`docs/zh/adaptation.md`「布局几何」节里那条「不开 useWebDefaults、shrink 默认 0」的定案**只管原生控件树里那颗 C++ Yoga**，不要迁移到本引擎；两条线互不冲突（一条管现在的原生控件树，一条管未来 MoonBit 版）。
- **纯 MoonBit、零 FFI**：无 shim、无 prebuild、无链接参数，任何 target 可用（因此不涉及仓库「prebuild 链接托管」那套规则）。

---

## 3. 代码地图（`modules/yoga-mbt`，合计约 2459 行）

| 文件 | 行数 | 职责 |
|---|---|---|
| `src/types.mbt` | 98 | `Value`(Undefined/Fixed/Percent/Auto)、`Edges`、`Display`、`PositionType`、`FlexDirection`、`FlexWrap`、`JustifyContent`、`AlignItems`、`AlignContent` |
| `src/style.mbt` | 111 | `Style`（web 默认值集中在此）+ `edge_value`/`resolve_value`/`definite_size` 三个解析原语 |
| `src/node.mbt` | 97 | `Node` 树、`Layout`（left/top/width/height）、`set_measure`、`set_baseline`、`append_child`、`layout()` |
| `src/api.mbt` | 250 | 全部 setter、`fixed/percent/auto/undefined` 取值辅助、`calculate_layout` 入口 |
| `src/algorithm.mbt` | 1095 | **核心算法**（见下） |
| `src/layout_wbtest.mbt` | 808 | 47 条白盒断言（手算预期值） |
| `src/moon.pkg.json` | 3 | `{"warn_list": "-6"}`，关闭「枚举构造器包内未构造」的误报（仅面向消费方的 API） |
| `README.md` | — | 用法 / 已实现 / 未实现清单（内容类文档，只写怎么用） |

**算法入口**：`fn layout_into(node, avail_w, avail_h, pinned_w, pinned_h) -> (Double, Double)`

- `avail_*` = 父内容盒给出的可用空间；`pinned_*` = 父级弹性解析后**钦定**的最终尺寸（覆盖自身 style/内容推算）；返回 border-box 尺寸。
- 单节点流程（`algorithm.mbt` 内按序）：display 判定 → 自身 padding/border 解析 → **叶子路径**（measure 函数 + 基线函数）→ **flex 项构建**（同时把 `position: absolute` 的子项分流到 `abs_children`）→ **换行**（§9.3）→ 逐行 **§9.7 弹性解析**（§9.2 比例换算基准与 §4.5 自动最小尺寸在 flex 项构建阶段算好） → 主轴 auto margin / justify 定位（§9.5）→ 交叉轴内容测量 + **§9.4 基线分组**与行交叉尺寸（§9.6）→ align-content 整行分布（§9.4/§9.6）→ 逐项定尺寸/定位/递归子树 → **本节点基线定案**（§8.5）→ 自身尺寸定案（内容推算 = 各行最大 + 自身 padding/border，含 min/max 收顶）→ **绝对定位子项**布局。
- 辅助函数：`clamp3`、`first_some`、`justify_leading`、`align_offset`、`resolved_align`（align-self 继承 align-items）、`is_baseline_item`（§9.4 收集条件）、`measure_content`（叶子走 measure，容器递归；两条路径都刷新节点基线）。
- 比例接入点共四处：flex 项构建（换算主轴基准 + 给 `min:auto` 封顶）、交叉轴定尺寸（换算 `final_cross`）、容器自身 `inner_main` / `inner_cross`（换算结果当作确定尺寸）、叶子路径（宽高互推）。绝对定位子项未接。
- 关键内部结构：`Resolved`/`AxisMargin`（四边在主轴/交叉轴视角下的映射，含 auto 标记）、`Item`（单个 flex 项的全部中间量：base / inner_base / hyp_main / min-max / grow / shrink / size_main / final_cross / baseline / frozen / violation / pos）。`Node.baseline`（`Option[Double]`，到本节点边框盒顶部的距离）是节点间上抛基线的通道。

---

## 4. 已完成的工作

| 提交 | 内容 | 测试 |
|---|---|---|
| `ab7c12a` | **YG1** 骨架 + 核心算法：主轴/交叉轴、grow/shrink/basis（规范冻结算法）、justify 全系、align-items/self/content、wrap/wrap-reverse、margin auto 吸收、padding/border/margin、百分比、min/max（主轴 min:auto 内容下限）、gap、叶子 measure | 19 条 |
| `105d3c7` | **YG2a** absolute 定位：包含块 = 父 padding box、同轴两侧 inset 撑尺寸、四向全 auto 落静态位置、内嵌子树继续递归 | 7 条 |
| `f994a15` | 发布元数据（readme/keywords） | — |
| YG2b | **baseline 对齐**：`set_baseline` 回调（基线到内容盒顶部）、§9.4 基线分组决定行交叉尺寸、§9.6 升距最大者贴行起端、§8.5 容器基线上抛；附带修复**交叉轴 margin 从不参与子项定位** | 10 条 |
| YG2b′ | **容器 auto 尺寸**：主轴按各行外沿取最大（原写死 0）、主轴与交叉轴都补自身 padding/border | 4 条 |
| YG2c | **aspect-ratio**：`set_aspect_ratio`（比例 = 边框盒宽/高），§9.2 换算基准、§4.5 换算值封顶 min:auto、§9.4 交叉轴换算、容器自身两轴按比例视作确定尺寸；`align-items: stretch` 覆盖交叉轴比例结果（规范直译）| 7 条 |

门控基线：`moon check` 零警告 + 全仓 `moon test` **708/708**（其中 yoga-mbt 47 条，其余 661 条为仓库既有测试）。

---

## 5. 关键设计决策（**改代码前请先读这节**）

1. **只对齐 web 标准**：默认值同上 §2；不做兼容开关。
2. **宽高 = border-box**（与 Yoga 一致）：`width/height` 含自身 padding 与 border。注意这与 CSS 默认的 content-box 语义不同，`README.md` 已标注。
3. **§9.7 弹性解析按规范逐条实现**（**与 Yoga 有意不同**，Yoga 官方注释自认其两遍法偏离规范）：
   - 目标尺寸从 **flex base** 起步（不是 hypothetical）；
   - 先冻结不弹性项：因子为 0、或（grow 时）base > hypothetical、（shrink 时）base < hypothetical；
   - 循环内按**总违规正负选择性冻结**（正 → 冻结 min 违规项；负 → 冻结 max 违规项；零 → 全冻）；
   - 弹性因子和 < 1 时，以「初始剩余空间 × 因子和」封顶；
   - **shrink 加权用内基准尺寸**（base − 自身 padding/border），Yoga 用 border-box 基准。
4. **§9.6 单行 + 容器交叉轴确定** → 行交叉尺寸直接取容器内交叉尺寸（因此 `align-content` 对单行容器无效，这是规范行为）。
5. **主轴 `min: auto`** → 内容尺寸下限（显式 `Fixed(0)` 才是 0）；**交叉轴** min auto 视同 0（规范只在主轴有自动最小尺寸）。
6. **内容尺寸不额外截断**：可用空间只以「AtMost」形式传给 measure 函数，引擎不再叠一层 `min(avail)`——固定内容尺寸的叶子不会因容器小而被压小（YG2a 踩坑，见 §7 末）。
7. **绝对定位**：包含块 = 父容器 **padding box**（宽高 = border box − 两侧 border，含 padding）；尺寸优先级 = 显式宽高 > 同轴两侧 inset 都设（撑出）> 内容测量；定位 = 该轴有 inset 用它，该轴双 auto → **静态位置**（按父容器 justify-content / align-items 摆一个虚拟项，忽略兄弟，间距类 justify 取 0）。
8. **百分比参照**：自身 padding/border/margin 相对**父的可用宽**；子项的百分比相对**本节点内容盒**（无确定尺寸时退回可用空间）；inset 百分比相对包含块对应轴。
9. **baseline（YG2b）**：`set_baseline` 返回**基线到内容盒顶部**（与 `set_measure` 对称，引擎叠加自身 padding/border）；容器不设回调，基线按 §8.5 由内部项推出（首行有基线对齐项 → 该行共同基线；否则交叉轴起端最靠前的有基线 in-flow 项，逐层上抛）。三条取舍：①主轴为列时不做基线对齐（规范收集条件要求项的 inline 轴平行于主轴）；②**无基线的项不进分组、按 flex-start 摆放**——规范对「合成基线在哪条边」有分歧（css-align-3 说块起边，浏览器对替换元素/空块历史用底边），本引擎选择不合成，与 Yoga 的 dimbound 分支及改前行为一致，需要「图片底边坐落基线」的消费方自己返回基线 = 自身高度；③单行 + 容器交叉轴确定时基线只决定偏移不决定行高（§9.6 短路优先）。
10. **交叉轴 margin 参与定位**（YG2b 修复）：子项位置 = 行偏移 + 对齐偏移 + **margin 起端**；此前只加了行偏移与对齐偏移，而剩余空间 `free_c` 已按含 margin 的外沿算，导致 `margin_top` 被吞（主轴方向一直是对的，`pos_main` 累加了 `m.start`）。
11. **容器 auto 尺寸 = 内容推算 + 自身 padding/border**（YG2b′）：主轴取各行外沿（`size_main` + 两侧 margin + 该行 gap）最大值，交叉轴取各行交叉尺寸之和（+ 行 gap），两者再叠 `pad_border_main / pad_border_cross`——宽高语义是 border-box，不叠就是尺寸小一圈。auto 主轴容器不参与 §9.7 弹性解析（`inner_main` 为 None），`size_main` 恒等于 `hyp_main`，所以「按行取最大」在单行时与旧公式等价，无回归。
12. **aspect-ratio 比例语义 = border-box**（用户定案，与 CSS 默认 content-box 不同）：`ratio = 边框盒宽 / 边框盒高`，换算处不扣 padding；四个接入点见 §3。其中「容器一轴确定 → 另一轴换算结果写进 `inner_main` / `inner_cross` 当作确定尺寸」是必须的，否则换行上限、弹性解析、行交叉尺寸与 stretch 全按内容尺寸走，会出现「`width:320 + ratio:2` 的容器高塌成内容 50、子项也只拉到 50」。另：`align-items: stretch`（本引擎默认）覆盖交叉轴的比例结果——规范 §9.4 algo-stretch 的条件是「computed 交叉尺寸属性为 auto」，并有尾注「本步不影响主轴，即使项有首选比例」，要保持比例需给非 stretch 对齐或显式交叉尺寸（浏览器同款，已入单测）。
13. **未实现的能力不留半成品接口**：宁可没有 API，也不给会静默算错的参数。

---

## 6. MoonBit 工具链/语法坑（照抄能省几小时）

本批实测环境：`moon 0.1.20260920` / `moonc v0.10.14+7d59c7ec9`（`~/.moon/bin/moon`，注意本机 `moon` 不在 PATH，需绝对路径）。

1. **续行运算符必须收在上一行行尾**；行首写 `+`/`-` 会报 `unbound ~+` 之类的怪错。
2. **没有 `+=` / `-=` 复合赋值**（`unexpected token +=`），写 `x = x + 1`。
3. **范围必须带界**：裸 `0..n` 非法，写 `0..<n`（或 `0..=n`）。
4. **科学计数法字面量解析报错**：`1e15` / `1e-6` 不行，写全 `1000000000000000.0` / `0.000001`。
5. **`fold` 要带标签**：`arr.iter().fold(init=0.0, fn(acc, x) {...})`（`Double`/`Int` 同理）。
6. **`guard` 是保留字**（match guard），别当变量名。
7. **泛型参数写在 `fn` 之后**：`fn[T] name(...)`，不是 `fn name[T](...)`。
8. **顶层常量**用 `const NAME : T = ...`；若用 `let` 必须小写（大写 `let` 直接报错）。
9. **`pub priv struct` 的类型在包外仍不可见**：`pub fn` 签名一旦引用它就报 4046（public definition cannot depend on private type）。要「字段私有」目前只能 `pub struct` + 靠约定。
10. **`mut` 字段「从未被赋值」按错误报（0015）**：经引用改**内层结构体的字段**不算外层字段的突变——所以 `Style` 的 `margin/padding/border`、`Node` 的 `style/children` 都不加 `mut`（改了反而报错）。
11. **`moon.pkg`（新 DSL）不认 `warn_list`**（报 Unexpected key）；包级 lint 开关要用旧 JSON 文件名 **`moon.pkg.json`**：`{"warn_list": "-6"}`。
12. **测试断言是 `assert_eq(a, b)`，没有 `!` 后缀**（写 `assert_eq!` 报 `unexpected f!(..)`），且**只能在 `test` 块内调用**——放进普通辅助函数会报 4122。
13. 测试里 `assert_eq` 直接比 `Double` 精确值，预期值尽量手算成整数或二分值（如 150 / 75 / 280），避免浮点尾差；需要容差时自己写比较函数再断言 `Bool`。
14. **写测试预期时先想清 web 默认行为**：本批首轮有 5 条断言写错，全是把「`align-items: stretch` 撑满容器交叉轴」和「`min-width: auto` 内容下限」当成 bug——浏览器同款行为，改预期不是改代码。
15. **YG2b 新增（工具链 0.1.20260920 / moonc 0.10.14）**：字符串插值是 `"..\{expr}.."`，**写 `${expr}` 不报错但原样输出**（探针第一版踩到，白跑一轮）；没有 `print`，只有 `println`。
16. **测试通过时 stdout 不显示**：想看中间数值，要么把探针写成「断言一个不可能的值、读 diff」，要么让测试失败——`moon test` 只回显失败用例的输出。探针文件用完即删（`tmp_*` 别混进提交）。
17. `Option[Double]` 作返回类型的函数字段可以直接放（`mut baseline_fn : Option[(Option[Double], Option[Double]) -> Option[Double]]`），配合 setter 赋值不会触发 0015；枚举值判断本包统一用 `match`（含元组 `match`），未验证 `==` 对所有枚举自动可用。

---

## 7. 构建、验证与仓库纪律

```sh
cd <副本>/modules/yoga-mbt
~/.moon/bin/moon check          # 必须零警告
~/.moon/bin/moon test           # yoga-mbt 47 条
cd <副本> && ~/.moon/bin/moon check && ~/.moon/bin/moon test    # 全仓门控：708/708
```

仓库硬性规则摘要（完整版见根目录 `AGENTS.md`）：

- **提交门槛**：`moon check` 零警告 + 测试全绿，才允许提交。
- **一批一提交**：一个功能/一次修复 = 一次提交并推送 origin；提交信息用「【新增】/【修复】/【文档】/【构建】范围：说明」中文格式，主题行一句改动 + 一句验证结果。
- **经验回写**：真机实测/踩坑按「环境 + 现象 + 根因 + 修复 + 验证」写进 `docs/zh/adaptation.md`，与代码改动**同批**提交；内容类文档（README、docs 使用文档）只写「是什么/怎么用」，原理与取舍只进 adaptation.md。
- **全部交流用中文**（代码、命令、路径除外）。
- **真机 GUI 测试由用户执行**：助手只做代码修复、三类检查（check/test/build）与启动冒烟，涉及其他桌面环境/虚拟机的视觉验证要列清单交给用户。
- 与本次工作**无关**但别忘：任何包的 `moon.pkg` 都不写链接参数（由 `scripts/prebuild.py` 全权托管）；库包（如 `yue/`）不得放 `link` 段。

---

## 8. 未完成工作与建议实现路径

### YG2b′ 容器 auto 尺寸（已完成，留此备案）

探针当时的结论（父容器 `padding-top:10 / padding-left:10`，子项 100×50，容器不给宽高）：row 与 column 两向都得到 100×50，浏览器为 110×60；折行容器（`width:100` + `wrap` + 两行 20 高 + `padding-top:10`）auto 交叉轴高 40（应 50）；多行时 `content_main_sum` 写死 `0.0` 会让折行容器 auto **主轴**尺寸塌成 0。

修复落在 `algorithm.mbt` 末尾「自身尺寸」段：主轴改为按各行外沿（`size_main` + 两侧 margin + 该行 gap）取最大，主轴与交叉轴的内容推算尺寸都再叠 `pad_border_main / pad_border_cross`。YG2b 撤下的 `b.layout().height == 35` 断言已合回，四条探针转正为单测（40 条全绿）。

### YG2c aspect-ratio（已完成，留此备案）

口径：比例作用在 **border-box**（用户 2026-10-10 定案，`ratio = 边框盒宽 / 边框盒高`）。落在四处——§9.2 项的主轴基准换算、§4.5 `min:auto` 用换算值封顶、§9.4 交叉轴假想尺寸换算、容器自身 `inner_main` / `inner_cross` 按比例当作确定尺寸（这一条不做会出现「`width:320 + ratio:2` 的容器高只按内容 50 算、子项也只拉到 50」）。`align-items: stretch` 覆盖交叉轴比例结果为规范直译，已入单测。**留下一口**：绝对定位子项不走比例换算（该路径仍只按显式尺寸 / 同轴两侧 inset / 内容定尺寸），需要时并给 YG2d 之后补。

### YG2d RTL（direction）

- 先做一组「LTR 现有行为快照测试」防回归（含 baseline 与 aspect-ratio 两条新路径），再动映射。
- `Style` 加 `direction`（Ltr/Rtl）+ 逻辑轴的 start/end 映射：主轴/交叉轴起端、margin/inset 的 start/end 语义、`RowReverse` 的组合。
- 只影响「解析与映射」层，不动数据结构。

### YG3 工程化

- **测量缓存**：Yoga 的 16 槽缓存（key = availableWidth/Height + measure mode + owner 尺寸），当前每个节点在 base/交叉轴两次测量里被重复布局，节点数上千时是主要成本；先做性能基线（千节点树布局耗时）再优化。
- **像素网格取整**：root 级开关，最终 left/top/width/height 取整（Yoga 会做绝对位置补偿，注意子项与父项取整后的一致性，避免 1px 缝）。
- **内在尺寸精确语义**（min-content / max-content）：当前容器 content 尺寸用 fit-content 近似（§9.9 未实现）。

### YG4 与 libyue 集成（需先与用户确认整体方案）

- 布局树 ↔ 控件树的映射（哪些控件是叶子 + measure 从哪来：原生控件尺寸、文本测量）、脏区增量重排（改样式只重排受影响子树）、与事件命中测试的坐标对齐。
- 依赖 MoonBit 化 libyue 的**整体范围定案**（是复刻 libyue 全部控件还是分层替换），这块不要自行开工，先对齐。

---

## 9. 已知风险与待决问题

1. **目录名**：原 `moonbit-libyue-navite` 系 `native` 笔误，已由用户确认并 `mv` 为 `moonbit-libyue-native`——若你手中文档还写旧名，以新名为准。
2. **分支混入无关提交**：`feature/yoga-mbt` 上的 `b01d1dd`/`6830867` 内容已在 master（`cf43cd9`/`b4fddd5`），合并前应剔除（见 §1）。
3. **多副本并发**：两个副本、两个会话共用同一远端；`git add -A` 会误提交他人半成品。
4. **近似实现**（已在 README/adaptation 标注，别当 bug 修）：绝对定位静态位置忽略兄弟项与间距类 justify；容器内在尺寸用 fit-content 近似；基线分组**不收无基线的项**（规范对「合成基线在哪条边」本身有分歧，见 §5 第 9 条）。
5. **发布未做**：`yoga-mbt` 尚未发 mooncakes（`license/description/repository/readme/keywords` 已备）。发布前注意仓库已有的教训：主包与 `yue-media` 曾有模块级循环依赖导致发布互等死锁，且 `mooncakes` 同版本不可重发。
6. **基线依赖消费方给回调**：`set_baseline` 未设置的叶子一律不参与基线分组——libyue 集成时文本控件必须同时接 measure 与 baseline，否则文字混排会退化成顶部对齐。
7. **比例项在默认 stretch 容器里交叉轴不按比例**（规范直译，见 §5 第 12 条）：集成方若要「等比方块」语义，得显式给 `align-self` 非 stretch 或直接给交叉尺寸；另外绝对定位子项不吃比例。

---

## 10. 参考资料与重现路径

- **规范**：`https://www.w3.org/TR/css-flexbox-1/`——§9 布局算法在 `li#algo-*` 列表项里（不是 `<section>`，整段抓取会被测试用例表污染，需按 `id` 切段）；§9.7 锚点 `#resolve-flexible-lengths`；baseline 三段可直读：§9.4 `algo-cross-line`（基线分组与行交叉尺寸）、§9.6 `algo-cross-align`（升距最大者贴行起端）、§8.5「Flex Container Baselines」（容器基线上抛，含「无基线则从 border box 合成」这句分歧来源）。
- **Yoga 源码**：`raw.githubusercontent.com` 直连超时（本机实测），用 SSH 稀疏克隆：
  ```sh
  git clone --depth 1 --filter=blob:none --sparse git@github.com:facebook/yoga.git
  cd yoga && git sparse-checkout set yoga/algorithm
  # 重点：yoga/algorithm/CalculateLayout.cpp、FlexLine.cpp
  ```
- **历史本地副本**：`/tmp/yoga-ref/`（规范 HTML 与提取出的 `spec-sec9.txt` / `spec-sec97.txt`；临时目录，可能已被清理，清理后按上两条重现）。
- **项目内记录**：`docs/zh/adaptation.md`「布局几何(Yoga flexbox)」节的 yoga-mbt 三条（首批取舍 + YG2a + YG2b）、`TODO.md`「yoga-mbt」节的 YG1–YG4、`modules/yoga-mbt/README.md`。
- **会话记忆**：`.workbuddy/memory/2026-10-10.md`（两个副本各有一份，内容已同步）。

---

## 11. 接手后 10 分钟动作清单

1. `cd /home/lkyh/ownCode/moonbit-libyue-native && git fetch && git status`——确认在 `feature/yoga-mbt` 且与 origin 一致、工作区干净。
2. `~/.moon/bin/moon check && ~/.moon/bin/moon test`——确认基线 708/708（若数字不同，先查是不是另一会话又推了新提交）。
3. 读 `modules/yoga-mbt/README.md` + 本文 §3 / §5 / §6。
4. 认领 §8 的 YG2d（RTL direction）——按「先补 LTR 快照测试 → 先写测试预期 → 改代码 → 三类检查 → 回写文档 → 提交推送」的节奏推进；顺手评估要不要先把绝对定位项的比例换算补齐。
5. 发现本文与代码/事实不一致 → **以代码为准**，并顺手把本文改成正确的（本文也受「一批一提交」纪律约束）。
