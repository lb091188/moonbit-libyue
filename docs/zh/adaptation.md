# 平台适配经验

各平台实测坑与结论,每条只记「坑 + 修复」;协议互操作结论均来自真总线、真面板验证。Linux 按发行版 → 桌面环境组织,Windows / macOS 按版本;新增结论写进对应小节,英文版 [docs/adaptation.md](/adaptation) 同批同步。

## 图标数据与生成器(803 图标,2026-09-29)

图标数据的形状对比(803 个 iconfont 图标,debug 构建,2026-09-29):「代码形状」(每图标展开为 Painter 调用 match 分支)换「数据形状」(千分定点路径串 + `fill_icon_path` 解释绘制,`scripts/gen_icons.py` 发射)前后——`icons.mbt` 51k 行/3.5MB → 4.3k 行/0.7MB;showcase.exe 23.7MB → 14.9MB(hello 同步 7.9 → 7.5MB);库模块增量编译 6.8s → 0.78s;showcase 窗口 map 41ms → 7~9ms。绘制正确性以 probe-icon 全量网格截图对照旧形态(线条/填充/镂空一致);一帧可见图标 ≤ 百级 × 每图标几百字符解析,微秒级,无需缓存。教训:生成器发射「代码」还是发射「数据」差一个数量级——大量重复几何描述永远选数据形状 + 小解释器。

## 跨平台通用(构建链 / FFI)

### 构建与链接

- 库包不得写 link 段(moon 会生成无 main 的 exe,构建失败);链接参数全部由 `scripts/prebuild.py` 经 `--moonbit-unstable-prebuild` 钩子输出 link_configs,自动传播给所有依赖库模块的 main 包,任何包不手写 `cc-link-flags`。
- prebuild 脚本约束:stdout 只能输出最终 JSON(进度信息走 stderr);全部参数放 link_flags 单一字符串自控顺序(GNU ld 单遍扫描);脚本 cwd 是使用方项目根,库路径必须绝对。
- moon 新版弃用 `moon.mod.json` / `moon.pkg.json`(`moon fmt` 一键迁移);`moon doc` 只认新格式,旧版 moon 不认新格式。
- MSVC 按 cp936 误读无 BOM UTF-8 源码,中文注释会造出假预处理错误(报错行没有那个指令):CMake 对 MSVC 加 `/utf-8`。
- 新版 moon 弃用 trait 方法隐式提升:调用写显式静态形式 `ViewLike::method(obj)`;`impl Trait for X` 声明点须补 `pub extend X with Trait::{...}`(方法清单从 `moon check --no-render` 输出生成,勿手抄);黑盒测试内引用包内符号须限定 `@<包>.xxx`。此类警告增量编译漏报,clean 全量才见全量。
- mooncakes 包页 README 渲染器只显示绝对 URL 外链图片(0.5.3~0.5.5 连发实测:包内相对路径图片无论纯 md 语法还是 HTML 一律不渲染,HTML 块更被整段丢弃,而外链 CI badge 正常显示);门面图改 jsdelivr 绝对 URL(`cdn.jsdelivr.net/gh/<user>/<repo>@master/...`,国内外可达性均衡,@master 引用有数小时缓存延迟),GitHub 侧经 camo 代理显示不受影响。
- 工具链三件套(moon/moonc/core)必须配套同版本(0.5.3 发布实测):非交互终端跑 `moon upgrade` 半途报 `IO error: not a terminal` 时只换了二进制、`~/.moon/lib/core` 未动,落得 moonc 0.10.14 + core 0.10.12 混搭——core 无 `StringView::exact_view`(sysdata 报 4 处 no method),且升号改 moon.mod 触发的全量重查才暴露,之前的增量 `moon check`/`moon test` 全绿是假绿;nightly 版本号当日即滚动下架(CLI 服务器对指名历史版本一律 403),`MOONBIT_INSTALL_VERSION` 钉版本不可行,唯一修复路径是无参重跑 `install/unix.sh` 装 latest 全家桶(二进制与 core 同批换)对齐 CI;验证:`moon version --all` 与 `~/.moon/lib/core/moon.mod` 的版本一致后升号触发全量重查,133 测全绿。
- **mizchi/markdown@0.8.3 引入与传递依赖发布链定案(MD1,2026-10)**:根 moon.mod import 钉 `mizchi/markdown@0.8.3`,独立控制台探针 `examples/probe-markdown` 实证 parse / render_html / serialize 三调用(`moon run examples/probe-markdown --target native` 输出 PROBE-OK:parse 11 块含标题/围栏代码/表格/引用/列表各 1,render_html 出 h1/strong/em/code/a/ul/li/pre/blockquote/table 且链接地址保留,serialize 往返重解析重渲染全过;moon check 零警告 + moon test 576 全绿)。native 支持有据:registry 索引 0.8.0 仅 js+wasm,**0.8.1 起才加 native**,0.8.2 起加 wasm-gc,钉 0.8.3(supported-targets=js+wasm+wasm-gc+native)是支持矩阵的第一个稳妥点;其 src/moon.pkg import 实验性 `moonbitlang/core/v128`(包内注释自述仅 linear-memory 目标可达),native 属 linear-memory,探针编译通过即实证可用,无需任何额外开关。**依赖闭包名义 5 项、实际 21 包**:直接依赖 moonbitlang/async@0.20.3 / moonbitlang/parser@0.3.18 / moonbitlang/x@0.5.1 / mizchi/syntree@0.2.4 / mizchi/moomaid@0.4.0,经各包 moon.mod 二级展开实装 .mooncakes 共 21 外部包(parser→lexer/moon_config/prettyprinter;moomaid→tui/signals/svg/font/css/crater-layout/crater-core 及其下级 tui-terminal-buffer/brotli/zlib/pixelmatch/layout);x 与 syntree 存在上游多版本声明共置(markdown 要 x@0.5.1、parser 要 0.4.39、moomaid 要 0.4.47;syntree 0.2.4/0.2.3),mooncakes 单版本空间取高版本一份实装——上游各自发版漂移时闭包版本由 moon 择高,升级 markdown 须留意级联。**moon add 传递机制实测**:消费方 `moon add mizchi/markdown@0.8.3` 只写入直接依赖一行,传递闭包不进 moon.mod、安装期按 registry 索引递归解析拉取(临时模块实测输出 Using cached mizchi/syntree 等)——即本仓发布后消费方 add 本模块时构建器自动拉全闭包,依赖面成本纯安装/编译期。**定案:接受传递,不拆独立模块**(MD2 起 markdown_view 桥接 mizchi/markdown 随主模块走);依据:闭包全为纯 MoonBit 源码包,无 native stub 无链接面,不碰 prebuild 托管,对消费方零 ABI/平台矩阵/发布物体积风险,与 ffmpeg-mbt 因二进制矩阵+许可+体积拆独立模块的性质不同;降级路径预留——消费方依赖面反馈过重或上游 0.x API 波及时,再下沉独立模块(库模块退回零 markdown 依赖,仿媒体三层拆分)。注意:模块内子包(如旧链的 browser 子包模式)解决不了依赖面——mooncakes deps 是模块级声明,子包 import 一样进发布闭包,browser 模式隔离的是链接 flags 层,两者机理不同勿混用。

### MoonBit cfg(platform=)

- **定案(2026-10-11):平台分派弃用 cfg,即便日后工具链修好也不翻案**——MoonBit 侧跨平台选择一律「运行时探测 + 模式匹配」,探测形态照 render 包既有的降级探针(画一笔验像素、会话句柄非零),已入 AGENTS.md 硬性规则。

### 原生渲染/文本矩阵与文字三层差异(新栈定案,2026-10-11)

- **平台矩阵**:Linux=GTK3 窗口 + cairo 光栅 + Pango 文本(系统库动态链,LGPL 无义务);Windows=纯 MoonBit 软件光栅器 + DirectWrite 文本 + WIC 图片解码(全部系统组件,零第三方依赖);macOS=CoreGraphics + CoreText(**桩占位,后端暂未开发**)。曾评估 vcpkg 静态链 cairo/pango,因依赖重(glib/fontconfig/harfbuzz 全家)+ LGPL 静态链「提供重链接途径」义务,与本库「原生、轻量、无负担」定位相悖而弃。
- **文字三层差异与对策**:①**高度**——行高统一为 `max(引擎自然行高, ceil(size×K))`,K 实测三平台覆盖最肥字体(微软雅黑)后定为常量,行高成为 size 的纯函数,回退字体不再影响行高,多出空间半行距上下居中、取整写死;异字体超地板时行高就地长高(优雅退化不裁字形)。②**宽度**——折行/截断/省略全部是 MoonBit 组件层决策(平台只供测量),textarea 的 wrap_units/layout_lines 纯函数不动;CJK advance≈em 实际无差,拉丁差一个词(折行/省略点边界),内容不丢失。③**像素**——矢量层(矩形/路径/AA/25 混合模式/渐变)由 MoonBit 光栅器三平台同一实现、逐位一致,断言跨平台共用;文字度量/像素分平台固有(旧栈即 Pango/DirectWrite/CoreText 三引擎),断言分「结构性(共用)/数值(平台基线目录)」两档,默认字体按平台显式编码进主题(Windows 钉雅黑系,Linux 跟 fontconfig)。
- **Linux 红利**:cairo 与 MoonBit 光栅器可逐像素对拍,cairo 当标准答案验收自研引擎(渲染批 W4 的验收手段)。
- **平台 C 桩组织**:单一 `stub.c` 多分支 + prebuild 宏(见「Windows 窗口地基 W2」小节的 win/stub.c 先例);render/text 的桩合并照此办理,Windows 侧不引任何 C 渲染/文本库(仅 WIC 属系统组件)。

### MoonBit 原生 GUI 栈 · 纯 MoonBit 光栅器(W4,Windows/mac 渲染后端)

- **架构**:`render` 拆出四个纯 MoonBit 文件——`raster_path.mbt`(路径命令/仿射矩阵/贝塞尔自适应展平/弧→贝塞尔 kappa)、`raster_fill.mbt`(4×4 超采样非零环绕扫描线填充 + miter 上限 10/butt cap 折线偏移描边)、`raster_blend.mbt`(25 混合模式:Porter-Duff 九式预乘闭式 + 16 个 W3C 公式非预乘域 + 渐变求值)、`raster.mbt`(`Raster` 会话,与 `Cairo` 方法面逐条镜像);`Painter` 门面改双后端枚举,**运行时探针**(`Cairo::over` 建不出会话即纯路径)选择,无编译指令(AGENTS 规则 11)。桩合并为 `render/stub.c`:cairo 真实现挂 `WM_STUB_CAIRO` 宏仅 prebuild(Linux)编,非 Linux 全占位保链接、探针探到占位即退纯路径。文本层经 `Painter::cairo_id()` 探测:cairo 后端画在会话上下文,纯后端返回 None(W5 据此走直接往 Bitmap 画的 DirectWrite 形态),`Painter::raster()` 取纯会话。
- **覆盖量化的口径**:4×4 超采样、每像素 16 样本、覆盖 0..256(每样本 16)——与 cairo 解析覆盖的单像素差被「对拍容差带 ≤16(一个采样档)」吸收;满覆盖/零覆盖像素精确。跨点判定用半开区间 `(ay<=ys)!=(by2<=ys)` 防顶点重计;非零环绕扫描「非零区间收样」,开折线 fill 自动闭边(**末边就是环绕边,边数 = n 而非 n+1——写 n+1 会 pts[n] 越界,单测全是闭合路径测不出,真窗口 45 帧当场崩,教训:开放路径要有专项用例**)。
- **预乘取整必须两步,不能合并**:源预乘是 255 域(`(v·a+127)/255`)、覆盖缩放是 256 域(`·cov/256`),合并成 65536 域一步会吞掉 255/256 的比例差(不透明满覆盖实测 254 而非 255,成片差一);合成侧 Normal 的 `s+(d·inv+127)/255` 与 Bitmap::paint 同式,矩形路径逐位一致。
- **与 cairo 的已知口径差(容差带内)**:①AA 覆盖 16 级量化 vs cairo 解析覆盖;②blit 最近邻 vs cairo 双线性(1:1 与不透明像素逐位一致,缩放采样有差——采样域收口语义已镜像:恒落在源子矩形内防串色);③渐变 stop 非预乘插值(CSS/W3C 口径)vs cairo 预乘域(半透明 stop 中间色有差,不透明 stop 无差);④描边设备线宽 = 用户线宽×sqrt(|det|),非均匀缩放的笔帽近似;⑤斜矩阵 clip 取包围盒。25 混合模式的 W3C 公式值双平台同测同过(cairo 算子与手算公式在 8bit 域一致)。
- **MoonBit 写法坑(本批新踩)**:`moonbitlang/core/math` 才有 sin/cos(`@math.sin`,Double 无此方法);`let 大写` 非法要用 `const`;科学计数法 `1e-9` 解析报错须写全 `0.000000001`(旧坑复踩,建议 grep `1e-` 自查);match 臂尾逗号非法;三元组 match 臂 `(a,b,c)` 后不能带 `,`。测试侧:`Cairo::over` 直连的测试改为「后端探测 + 结构档断言」跨平台共用;解码依赖测试加 `decode_available()` 探针守卫(环境缺件只跳过不硬断)。
- **验证**(2026-10-11,Windows 本机):render 43/43(新增「路径/描边/弧两后端对拍(AA 容差)」)、icons 4/4(**803 条图标路径全量出像素**经纯光栅器)、core 62/input 10/mdview 26 复绿、theme 7/8(剩字体实测归 W5);native-window 冒烟 45 帧干净退出(真窗口逐帧全走纯光栅器);全仓 check 287/68 持平。Linux 侧 cairo 路径逐位不动(桩内容原样平移),对拍测试在 Linux 上即「cairo vs 纯实现」验收,待用户侧复跑。

### MoonBit 原生 GUI 栈 · 系统能力桩的 Windows 分支（W14：文件 / 环境变量 / 子进程 / 文件对话框）

- **第三方 `chensuiyi/subproc` 只能弃用,且主分支早就弃了**:该包自述就是「Synchronous **Linux** process management」,靠 pidfd/procfs/poll 这些 Linux 专有机制——本机 `.mooncakes/chensuiyi/subproc/src/native.c:7` 在 MSVC 下 `fatal error C1083: 无法打开包括文件 poll.h`,于是 `sys` 连同下游(chart/ui/examples/native-app)整条链在 Windows 连编译都进不去。注册表另一候选 `trkbt10/subprocess` 只覆盖 Unix/macOS 子进程(Windows 侧仅 IPC socket),同样不够。**改法:平移 master 已验的三平台实现**(master 的实现走自有 C 桩 `proc_spawn/proc_wait/proc_getpid`,零第三方依赖),移植进 `sys/sys_stub.c` 的 C 形态,符号名 `yue_sys_proc_*`,语义逐位对齐:POSIX 分支 Linux/macOS 共用(`fork`→`setsid`/macOS `setpgid`→`dup2` 临时文件→Linux `execvpe`/macOS `execvp`+`*_NSGetEnviron`,失败 `_exit(127)`、`chdir` 失败 `_exit(126)`);Windows 走 `CreateProcessW`+`CREATE_NO_WINDOW`、`STARTF_USESTDHANDLES` 挂可继承句柄、环境块按名排序双宽 NUL 收尾、空块＝继承父环境。**关键设计差别:只回 pid 不回句柄**,Windows 侧 `wait` 用 `OpenProcess(SYNCHRONIZE|TERMINATE|QUERY_LIMITED)` 按 pid 取,句柄用完即关——省掉一张跨调用句柄表和它的泄漏风险(原计划「返 hProcess + `proc_drop`」作废)。
- **`__uuidof` 在 MSVC 的 C 模式里不存在**:`CoCreateInstance(&CLSID_FileOpenDialog, ...)` 若写成 `__uuidof(FileOpenDialog)` 直接 `error C4233: 使用了非标准扩展: 此关键字只在 C++ 中支持`(SDK 头里的 coclass 声明是 C++ 专属)。C 侧只能取头文件里的 `extern const GUID` 常量(`CLSID_FileOpenDialog`/`IID_IFileDialog`/`IID_IShellItem`),这些符号由 **uuid.lib** 提供,故 `scripts/prebuild.py` 的 Windows 分支给 `sys` 下发 `ole32.lib shell32.lib uuid.lib`(MSVC 位置参数口径,`-l` 会报 D9002)。
- **UCRT 没有 `_getwcwd`**:看着像宽字符版 getcwd,实则 SDK 全无声明——MSVC 只给 `warning C4013: 未定义; 默认外部返回 int`,把返回的 `wchar_t*` 截断成 int 再当指针用,是「能编过但必崩」的形态。取工作目录改 Win32 的 `GetCurrentDirectoryW`(两趟:长度 0 问大小,再取串)。
- **环境变量必须宽字符,且 Windows 没有「存在但值为空」这一档**:`getenv`/`_putenv_s` 是 ANSI 版,按进程 ANSI 代码页(本机 936)来回转,UTF-8 中文值写进去读出来是「鍊糀」——`sys/envx_wbtest.mbt` 当场抓到。改 `GetEnvironmentVariableW`/`_wputenv_s`(长度 0 先问大小)。顺带一条语义差:Windows 里 `_wputenv_s(name, L"")` **就是删除**,所以 `envx_get(name)` 空值写入后为 `None` 而非 `Some("")`,测试按平台分档断言。文件同理:路径一律 UTF-8 进、宽字符 API 出(`FindFirstFileW`/`_wfopen`/`_wremove`),A 版在中文用户名目录下直接错位。
- **`ShellExecuteW` 的成功判据是返回值 >32**:它返回 HINSTANCE 语义的旧式状态码(≤32 是 `SE_ERR_*`),`>32 ? 0 : -1` 才对;`open` 动词自带系统关联(URL 走默认浏览器、文档走关联程序),正对应 POSIX 分支 `xdg-open` 的角色。
- **占位分支里「与图形无关」的落盘必须真实现**:`render/stub.c` 的非 Linux 分支原把 `fsw_write_file` 写成 `return 0`(占位保链接),而 PNG 编码本体在纯 MoonBit 的 `png.mbt`,只差这一次写盘——结果 Windows 上图表导出 `ci_save` 恒 `WriteFailed`。判据:占位只该覆盖「该平台还没实装的后端能力」,标准 I/O 这类无后端依赖的不该跟着占位。
- **测试的平台分流(三条)**:①`/tmp` 在 Windows CRT 里是「当前盘根目录下的 tmp」,目录不存在就写失败,临时文件路径要按平台取 `%TEMP%`/`$TMPDIR`(且分隔符随平台);②cmd 系输出行尾是 `\r\n`,断言 `echo` 结果不能写死 `\n`;③**从 Git Bash 起测试时 PATH 里有 `/usr/bin/*.exe`(`echo`/`cat`/`sleep`/`true`),POSIX 命令名「看着能跑」掩盖了实现差异**——从 cmd 起就全灭,故回环一律经平台分流(POSIX `sh -c`,Windows `cmd /c`)。Unix 惯例专属的断言(命令不存在退 127、子进程自发 SIGTERM、固定 `LC_ALL=C`、`/etc/hostname`)只在 POSIX 侧跑,Windows 侧给等价断言(`CreateProcessW` 找不到可执行文件直接 `SpawnFailed`)或打印跳过。
- **没有文字层时自绘控件塌成 0 尺寸**:纯光栅器平台上 `@text.measure` 给 `None`,`attach_text_measure` 的退化值是 `(0.0, 0.0)`,于是「宽度随文本」的按钮/标签/链接既测不出宽也点不中——`ui` 有 20 条断言是这一类。处理口径:测试层加**运行时探针**(`ui_text_guard()` 试测 `"Ag"`、`ui_decode_guard()` 试解一张 GIF),探不到就打印跳过、其余断言照跑,等 W5(DirectWrite)/W9(WIC)落地自动复绿;`theme` 的「控件高度基准」同一处理。不在库里塞估算宽度:那是静默假数据,与「探测 + 语义化降级」的定案相悖。
- **验证方式**(Windows 10 19045 + MSVC 14.44 + SDK 10.0.26100,moon 0.1.20260920):`moon test -p sys` **163/163**(subproc 摘除后该包在 Windows 首次可编可跑)、chart 189/189、ui 110/110(20 条按探针跳过)、theme 8/8、core 70、render 43、input 10、mdview 26、icons 4 全绿;逐包 `moon check --deny-warn` 零警告、`moon check ./examples/native-app --deny-warn` 通过(此前被 subproc 挡在依赖阶段)、全仓红点 287 errors/68 warnings 与基线持平;`text` 在 Windows 仍红,属 W5 范围(断言分「结构性共用/数值平台基线」两档改造随那一批做)。真窗口下的文件对话框观感(IFileDialog 的过滤项/多选/初始目录)留使用者复验。

### MoonBit 原生 GUI 栈 · 批 A 多窗宿主的 Windows 跟进（W15：槽位复用 + wm_init 幂等）

- **批 A 只修了 GTK 分支,同一条缺陷在 Windows 还在**:d1fb1e8 把 `win/stub.c` 的 GTK 分支 `wm_window_new` 改成扫 `area == NULL` 复用槽位,`_WIN32` 分支(同一函数的另一条路)仍是 `wm_next_id++`——附窗反复开合会吃光 32 槽并让 `open_window` 静默返回 `None`。修法照 GTK 逐字对齐,判据换成 `hwnd == NULL`(建窗成功必设、`wm_close` 里 memset 清零,拆过的槽与没用过的槽同样可取)。
- **真正拦住多窗的是 `wm_init` 不幂等**:`app_window()` 每开一扇窗都调一次 `@win.init_backend()`,而 Win32 的 `RegisterClassExW` **同名类重复注册返回 0**(`ERROR_CLASS_ALREADY_EXISTS`)——于是第一次成功、第二次起就返回「后端不可用」,`App::open_window` 在 Windows 上永远给 `None`(主窗反而是第一次调用,所以单窗示例一直正常)。修成「waker 窗口已在则整段直接返回 1」并把 `ERROR_CLASS_ALREADY_EXISTS` 视为成功。GTK 分支用 `gtk_init_check`,它本来就幂等,所以这条只在 Windows 露出来——**「一条路径两次调用」是批 A 引入的新形状,单窗时代的所有冒烟都测不到它**。
- **回证方式(探针包 `experiment/multiwin_probe`)**:①建-拆 40 轮(> 桩的 `WM_MAX_WINDOWS=32` 上限)仍建得出,`opened=40 failed=0`;探针**只建不 show**,于是 40 次建拆不在桌面闪窗。②两轮「开附窗→泵 60ms→关掉它」,打印 `sub_wid/primary/active_is_sub/count` 与 `before/after/main_running`,证明多窗宿主在真有两个 HWND 时派发仍然成立:新窗即当前窗(`active_is_sub=true`)、`primary=false`、关附窗后主窗 `running=true` 且在窗数回落。③收尾 `MULTIWIN-DONE` 行 + 退出码 0。跑法 `moon run experiment/multiwin_probe`;无显示服务打印 `MULTIWIN SKIP`。真窗观感(两窗互相遮挡/拖动重绘、附窗里的 preedit)仍按 AGENTS 规则 6 留使用者复验;`examples/native-app` 在 Windows 的启动冒烟回证 `NATIVE-APP-MW wins=1 ... ` 与退出码 0(按钮点击需要注入,归 W7)。
- **顺带补的口径**:`_WIN32` 分支调用 `snprintf` 却没引 `<stdio.h>`,MSVC 只给 `C4013 隐式声明;假定外部返回 int`——与「UCRT 无 `_getwcwd`」同形的静默坑,补头后本桩单编零警告。

### MoonBit 原生 GUI 栈 · 历史族的三平台数据根（W14e，平移 master 现成分支）

- **不新写,从 master 平移**:浏览器历史/书签/SQLite 侧的 Windows 数据根分支在 `origin/master` 是现成的(`bh_browser_defs_win`/`bh_mac_root`/`bh_root_win`),本分支当年平移时只带了 Linux 的那一份,于是 `bh_supported`/`bm_supported` 被写成「仅 Linux」。做法与 W14b 同:先查主分支有没有,有就搬。
- **三平台只差数据根与目录名,逻辑共用**:Linux=`XDG_CONFIG_HOME` 否则 `$HOME/.config`;Windows=`%LOCALAPPDATA%`,且 Chromium 系的 profile 在其下 `<厂商>/<产品>/User Data` 再下一层(比 Linux 多 `User Data` 这一层,目录名大小写随安装器,如 `Google/Chrome/User Data`、`Microsoft/Edge/User Data`);macOS=`$HOME/Library/Application Support/<厂商>/<产品>`(没有 Windows 那层 User Data)。profile 候选名(`Default` 与 `Profile 1..24`)、目录枚举查 `History`/`Bookmarks` 条目、SQLite/JSON 解析三平台同一条路径,所以只有定义表 `bh_defs()` 与根定位按平台分流。
- **回证方式(Windows 真机,本机装有 Chrome/Edge)**:`bh: profiles=2 items=5` 与 `bh: downloads=3` 是**真读到本机浏览器库**的读数(此前这条在 Windows 上被平台门恒跳过),`bm_bookmarks` 端到端解析同样从「skip」转真跑;`moon test -p sys` 163/163、`moon check ./gui/sys --deny-warn` 与 `./examples/native-sys --deny-warn` 零警告。测试侧一条旧断言 `bm_supported() == (platform=="linux")` 随之改成三平台口径。
- **口径提醒**:`fsx_list_dir`/`sys_read_text_file` 走的是本批刚补的宽字符路由,所以中文用户名目录(`C:\Users\张三\…`)下的浏览器库同样读得到——这条不是巧合,是 W14a 把 A 版 API 换成 W 版之后才成立的。

### MoonBit 原生 GUI 栈 · DirectWrite 文本层（W5，Windows 文字落地）

- **`dwrite.h` 在 C 里编不了，换 C++ TU 解**：`DWRITE_MAKE_OPENTYPE_TAG`/`DWRITE_MAKE_FONT_FEATURE_TAG` 用 `static_cast` 展开进枚举初值，C 模式直接一串 C2275/C2065（实测）；两条路——手工声明 COM 接口（vtable 顺序错一处就崩，弃）或换 C++ 编译单元。**moon 的 native-stub 认 `.cpp`**（探针实测：extern "C" 函数往返成功），于是平台分工定型：`stub.c` 的 Pango 分支（prebuild 带 `-DWM_STUB_PANGO`）+ `stub.c` 的占位分支（macOS 等）+ `dwrite_text.cpp`（Windows，native-stub 编，dwrite.h 直接可见）。链接输入由 prebuild 给 text 包下发 `dwrite.lib d2d1.lib ole32.lib uuid.lib gdi32.lib`。**非 Windows 侧这份 `.cpp` 编出空翻译单元**，故 Linux/mac 的构建链要有 C++ 前端（老链路 shim 就是 C++，本仓环境具备）。
- **行盒取「单字布局的行度量」，不取字体设计度量**：实测 14px 缺省族 DWrite 的布局行高是 19（= 字体 ascent+descent+lineGap 按整像素），按设计度量自己算是 17；更坑的是族名空串时若从集合里取**首族**（不是系统缺省族）会差出两 px——而「行盒要盖得住绘制高度」的混排行高断言吃的就是这个数。修法：`pt_font_line_height` 现搭一份 `"M"` 的布局、读 `DWRITE_LINE_METRICS`（height/baseline），与 `measure()`、绘制三条路自洽（LH14=19 与 M14.h=19、基线 15 对齐）。
- **族名表排序用字节序**：MoonBit 侧断言严格递增走 `lexical_compare`（字节序），而 DWrite 的集合顺序随装载变化——C 侧 qsort 用 `strcmp`（与 Pango 侧 `g_strcmp0` 同口径），相邻**完全相同**才去重；族名取 0 号 locale（en-us），故主题里钉的 Windows 族名用英文（"Microsoft YaHei"）。
- **区间下标要换 UTF-16 码元**：MoonBit（与 Pango 分支）的区间口径是 **UTF-8 字节下标**，DWrite 的 `DWRITE_TEXT_RANGE` 吃宽字符下标——不换的话多字节文本的区间落到界外被静默吞掉（「字节下标：切在字节上」那条断言就是红的）。换算 = `MultiByteToWideChar` 数前缀长度。
- **绘制 = D2D 的 DC 渲染目标 + 32bpp DIB + 预乘 over**：同一份 `IDWriteTextLayout` 先画进 DIB（`Clear` 成透明底、反锯齿固定灰度档——ClearType 是次像素渲染，落在透明底会出彩边），再按 `out = src + dst·(1−srcA)` 逐分量合进 MoonBit 缓冲（ARGB32 小端与 DIB 同布局，无需换序）。区间颜色必须在渲染目标上建画笔（D2D 画笔是设备相关对象）再 `SetDrawingEffect`，所以颜色只在绘制那一趟快照；盒内对齐照 Pango 的 `pt_render_box` 规则：有宽约束时宽与对齐交给布局，单行不省略时自己算 slack 偏移，垂直同理。
- **纯后端没有 cairo 会话：文本走「离屏 + blit」**：`draw_box_at`/`AttributedText::draw_at` 在 `cairo_id()==None` 时把文本先画进自有离屏位图（`pt_draw_box`/`rt_draw` 的缓冲版），再经 `Raster::blit` 落位——平移/裁剪/混合模式都由 blit 现算。
- **顺手修掉 `Raster::blit` 的一个真 bug**：它把 `rect_device` 给的「已是设备坐标」的矩形再乘进 `mt` 又复合 CTM → CTM 被计两次，带 `translate` 的会话里源采样落到源矩形界外，**一个像素都落不下来**（实测 ink=0，且无 transform 时正常所以一直没暴露）。修法：`mt` 建在用户空间（`e/f` 取用户 `dx/dy`），设备矩形只用于扫描窗。修后 render 43/ui 110/chart 189 全绿。
- **行高 K 地板定案落地**：`line_height = max(引擎自然, ceil(size×K))`，**K=1.36** 实测自本机雅黑 12..32px 的自然比上界（1.29..1.36，最肥一档 14px→19）；混排行盒用行内最大字号取地板；升距（基线）不动，地板顶起的余量由绘制的盒内垂直居中吸收（观感即半行距）。两条按「纯自然行高」写的白盒断言（family_wbtest）随口径更新。
- **缺省字族按平台探进主题**：`@theme.default_font_family()` 探到 "Microsoft YaHei" 就用（进程级缓存），探不到交回引擎缺省（Linux fontconfig / macOS CoreText）；`ui` 的 `role_font` 统一走它。
- **验证**（Windows 本机）：text **29/29**（此前 8/29）、render 43、ui 110（20 条文字/解码探针自动转真跑）、chart 189、theme 8、mdview 26、core 70 全绿；native-app 启动冒烟读数行齐、退出码 0；逐包 `--deny-warn` 零警告；全仓红点 287/68 持平。**计划里「text 断言分结构性/数值两档」实测不必要**：29 条都是「与同平台自己的测量比」的自洽断言，两平台各自全绿（记档以免后人再改一遍）。

### MoonBit 原生 GUI 栈 · Windows IME 纯通道（W6）

- **协议面与 GTK 分支逐条对齐**：commit/preedit 都是 UTF-8 字节流（容量 255，超了截断）、`preedit_caret` 也是字节偏移、读完 commit 要 `commit_done` 清零；`WM_IME_COMPOSITION` 里 `GCS_RESULTSTR` → commit（进文本状态），`GCS_COMPSTR` → preedit（只供自绘，绝不进文本状态）。
- **三条平台差异（都是实测/接口事实）**：① `WM_IME_SETCONTEXT` 必须滤掉 `ISC_SHOWUICOMPOSITIONWINDOW`——本栈 preedit 是自绘的，不滤掉系统会在窗口上再叠一份自己的组合窗（重影）；② 组合串光标 `GCS_CURSORPOS` 是**字符偏移**，而 MoonBit 侧口径（与 GTK 一致）是 UTF-8 **字节偏移**，要按前缀 `WideCharToMultiByte` 换算，不换则中文组合串的光标位置全错；③ legacy IMM32 **没有 surrounding-text 接口**（那是 TSF 的），`wm_im_set_surrounding` 只能空操作——GTK 侧喂「已提交文本」是为了让 IM context 推断上下文，Windows 的 IME 从自身组合状态取上下文，两平台语义在此分叉（记档，不在 MoonBit 层做假接口）。
- **光标与候选窗**：`wm_im_set_cursor` 存矩形并在 `WM_IME_STARTCOMPOSITION` 时复喂一次（有些 IME 只在这时读位置）；`ImmSetCompositionWindow(CFS_POINT)` 与 `ImmSetCandidateWindow(CFS_CANDIDATEPOS)` 都贴光标**底边**（`y + h`），候选窗贴组合串末尾的惯例由此成立。`wm_im_reset` 走 `ImmNotifyIME(NI_COMPOSITIONSTR, CPS_CANCEL)` **并清本侧 preedit 缓存**——reset 后 IME 不一定再推组合消息，旧串留在缓存里会被继续画出来（GTK 侧同一条教训）。
- **回证**：探针 `experiment/ime_win_probe`（建窗 → 报插入符矩形 → reset → 读 commit/preedit → 泵 30 轮消息 → 干净退出）读数如预期（commit=none、preedit 空）且零崩溃；`experiment/multiwin_probe` 与 `examples/native-app` 冒烟在 WndProc 加消息分支后仍全绿（退出码 0）。**真实拼音的端到端**（preedit 下划线观感、候选窗位置、commit 落进焦点框）需要注入键入，归 W7 的 SendInput 探针与使用者真机复验——本机已装微软拼音（zh-Hans-CN，唯一 IME），路径可行。

### MoonBit 原生 GUI 栈 · 系统剪贴板（W16）

- **能力落 `sys`（新 `clipboard.mbt` + `sys_stub.c` 的 `_WIN32` 分支）**：Windows 走 `CF_UNICODETEXT`（`OpenClipboard`/`GetClipboardData`/`GlobalLock` 读，`GlobalAlloc(GMEM_MOVEABLE)`+`SetClipboardData` 写——**成功后所有权归系统，绝不能 `GlobalFree`**，这是 Win32 剪贴板的经典坑）；Linux/mac 走命令线（`xclip -selection clipboard` / `pbcopy`·`pbpaste`）。中文内容必须走宽串（`win_utf8_wide`）+ 宽→UTF-8，A 版 API 按 ANSI 代码页会把内容搅乱（同 W14 的环境变量一条）。
- **命令线传文本要绕开引号地狱**：`pr_run` 不做 shell 解析，所以显式 `sh -c 'printf %s "$1" | xclip -selection clipboard' sh <文本>`——文本走 **argv 的第 4 个位置**（脚本里的 `$1`），不拼进脚本体，引号、换行、中文都无需转义。
- **链接面漏过一处**：剪贴板 API 在 **user32.lib**，而 sys 包原先的 Windows 链接参数只有 `ole32.lib shell32.lib uuid.lib`——漏了就是 `LNK2019: __imp_SetClipboardData` 一串，已补（记档：Windows 侧每引一组新 API 都要核对它在哪个 .lib 里）。
- **接线走「内核槽」而不是内核直连平台**：`input` 的 `Editor::set_clipboard(get, set)` 给内核留外部剪贴板槽——`copy`/`cut` 顺手写出去、`Ctrl+V` 现取（取不到回退内置 `clip`），内核本身仍不依赖任何平台层（无头可测）。**默认不装**：`ui` 的 `use_system_clipboard(true)` 由应用显式打开（`examples/native-app` 与 `examples/showcase` 各一行）——测试里的 Ctrl+X 不该动使用者的剪贴板；探测不可用时自动保持内部剪贴板，属语义化降级（Linux 的探测口径见「Linux 剪贴板」那条：GtkClipboard 优先，没跑过 gtk_init 的进程才退回 xclip）。
- **测试**：sys 新增回环用例（中文 + 换行的 `set → get`），**写入前把原内容存档、断言完还原**（探针不在使用者的剪贴板里留痕）；Windows 本机 `moon test -p sys` **165/165**（新增 2 条），ui 110/110、input 10/10 无回归。真跨程序粘贴（复制出去、粘到记事本再粘回来）留使用者复验。

### MoonBit 原生 GUI 栈 · Windows 窗口「黑屏 + 未响应」复盘（W17a，五处根因与性能批）

- **根因一：`wm_wait` 等完不派发**。Win32 分支 `MsgWaitForMultipleObjectsEx` 之后**没调 `wm_pump`**（GTK 分支 poll 完会调）——没人派发消息 → WndProc 永不执行 → 输入、WM_CLOSE、WM_PAINT 全部收不到。判据：窗口被系统标「未响应」、优雅关窗要等自杀计时器（实测 15.9s；修后 **0.9s**）、发 SendKeys 完全没反应。修法：等完即 `wm_pump()`。
- **根因二：`wm_present` 只存指针**。它把 MoonBit 的像素指针记账，等 WM_PAINT 时才去贴——而那是 `paint_frame` 里的**局部** Bitmap，函数一返回就是 GC 的猎物，贴出来是悬垂内存（整窗纯黑）。判据：截图整片黑、而绘制读数与几何行一切正常。修法：桩持帧拷贝（`WmWindow.frame`，按尺寸增长的缓冲），`wm_close` 释放。
- **根因三：键码口径不一致**。Win32 桩把控制字符按 GDK 约定给 `0x01000000|u`，而内核的 `KS_*` 是 X11 口径（Tab=0xFF09、回车=0xFF0D、退格=0xFF08、Esc=0xFF1B、Del=0xFFFF）→ 宿主认不出 Tab/回车（实测 Tab 被当可打印字符插进输入框、回车提交失灵）。修法：控制字符按 X11 keysym 出，可打印（含中文）直接用 Unicode 码点。
- **根因四：抬起事件投给控件**。内核 `Editor::handle_key` 只有 `(keysym, mods)`、分不出按下/抬起，宿主若放行抬起就等于「松手再插一个字符」（现象与根因三叠加）。修法：`App::route` 只把按下投给控件（Tab/焦点栈的宿主处理同样只看按下）。
- **根因五（同批回归自查抓到）**：视口剔除用**绝对矩形**去过 CTM，父原点被计两次 → `oy≠0` 的子树整片误剔（判据：ui 掉到 102/110、控件场景探针「下半屏 0 墨」）。修法：判交用相对当前原点的**本地矩形**（`rect - (ox,oy)`）——CTM 的原点就在父内容原点。
- **根因六（输入真正接通后才暴露的潜伏越界）**：`dispatch_on_path` 的「右键祖先优先」分支写成**取下标前自增**——走完路径末项时 `i` 恰好等于长度，`path[i]` 越界，真机表现为「右键点任何控件即 `PanicError`」。Linux 侧之所以没见过，是那些用例的右键都在更深的层被消费、提前 `handled` 出循环。修法：祖先优先改成「先取后进」（自增挪到循环体末尾）；补回归用例 `widget_wbtest` 的「右键祖先优先：走完路径不越界，顺序根→叶」（含只有根一层的路径）。判据：真机注入左键+右键各两次，进程存活、`clicks=1` 落数、日志无 Panic。
- **根因七（中文输入法打不出字）：消息泵缺 `TranslateMessage`**。Win32 的 `wm_pump` 只做 `PeekMessage + DispatchMessage`——而 legacy IME（IMM32）的组合处理就挂在 `TranslateMessage` 这条路上：缺了它只会收到裸键（字母的按下被 IME 吃掉、只余抬起），`WM_IME_STARTCOMPOSITION`/`WM_IME_COMPOSITION` 一条都收不到，拼音永远组合不起来（实测：只来 `WM_IME_SETCONTEXT`）。补上之后探针立刻拿到 `preedit=[ni'h'ao …]` 与 `commit=[你还奥]` ✓。判据：`experiment/key_probe` 打字看 preedit/commit 行。
- **根因八（Markdown 序号掉到基线下方）：标记格是零高度节点**。`md_marker` 只设了宽度、没有子件也不注册测量 → 高 0；而 `hbox` 默认 `align_items=Center`，0 高的格子被摆到行的中点（实测 `rect=(0,111,18,0)` 而正文在 102..120），序号整体低半个行高、中心正好压在正文基线上。修法：给标记格注册文本测量（行盒高与正文同源），并把它贴首行顶对齐（`valign=Start`）；回归用例 `markdown_wbtest`「有序列表：序号与正文落在同一条基线上」。
- **性能（同批）**：文字路径 **9.4ms → 0.35ms/段**（三件：①D2D 渲染目标从 DC 换 **WIC 位图**——DC 目标逐调用 `BindDC` 就要 0.4ms，总账 1.8ms/段；②画布/画笔进程级缓存，尺寸只增不减；③`Raster::blit` 加「整数平移 + 1:1 全幅 + Normal」快路径，源字节先过 256×256 查表复刻通用路的「解除预乘→乘回」，**逐位一致**才没把像素断言打红）。整树重画 550ms → ~300ms（视口剔除）；示例节拍 100ms → 500ms（真机每个重绘周期阻塞消息泵的时间随之落回安全区）。整窗重绘仍是数百毫秒级（图表页最重），列为后续性能批。
- **WIC 画布两条陷阱**：①**不能**用 `CreateBitmapFromMemory` 包外部缓冲再让 D2D 画——那走 WIC 内部缓存，读不回你的缓冲（现象：ink=0 而返回值成功），要自持位图 + 绘制后 `Lock(WICBitmapLockRead)` 读回；②用「全透明笔 `FillRectangle`」清画布是**空操作**（源覆盖语义），必须 `Clear`——它吃轴对齐裁剪，所以能只清本次区域（缓存画布比本次大时正好用上）。
- **回证方式**：`experiment/key_probe`（建窗→泵→打印键码，配 PowerShell `AppActivate`+`SendKeys`）验键盘通路；`experiment/text_bench` 守文字路径性能；截图核对窗口内容（本机用 PowerShell 抓屏 PNG 看图判色）；`App::step`/`paint_frame` 的临时分段计时（PAINT-PROF/STEP-PROF）定位过瓶颈，已撤。全绿复核：core 70 / input 10 / ui 110 / render 43 / text 29 / chart 189 / theme 8 / mdview 26 / sys 165，全仓红点 287/68 持平。

### MoonBit 原生 GUI 栈 · Windows 基础能力首批（W20a 菜单栏 / W20b 全局快捷键 / W20d 消息框）

- **环境与绕开工具链的验证路径**：Windows 10 19045 + VS BuildTools 2022（MSVC **14.44.35207**，在 `C:\Program Files (x86)\Microsoft Visual Studio\...`；`C:\Program Files\...` 是空目录、会白找）+ SDK 10.0.26100。`vcvars64.bat` 被 reg.exe 策略挡住，手工编纯 C 探针要自己设 `INCLUDE`/`LIB`，且必须用 Windows 风格路径（`/c/...` 会被 cl 当源文件）：
  ```bash
  MSVC='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207'
  SDK='C:\Program Files (x86)\Windows Kits\10'
  export INCLUDE="$MSVC\include;$SDK\Include\10.0.26100.0\ucrt;$SDK\Include\10.0.26100.0\shared;$SDK\Include\10.0.26100.0\um;$SDK\Include\10.0.26100.0\winrt"
  export LIB="$MSVC\lib\x64;$SDK\Lib\10.0.26100.0\ucrt\x64;$SDK\Lib\10.0.26100.0\um\x64"
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$MSVC/bin/Hostx64/x64/cl.exe" \
    /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE <探针>.c \
    /Fe:<探针>.exe user32.lib gdi32.lib imm32.lib advapi32.lib
  ```
  纯 C 探针 `experiment/menu_probe/menu_backend_probe.c` 直接 `#include "../../gui/win/stub.c"`——因为 `wm_menu_bar_new` 返回的是**句柄表下标**（1..31）而非真 `HMENU`，反读菜单结构必须同 TU 拿静态表 `wm_menus[]`（第一版拿下标当 `HMENU` 传给 `GetMenuItemCount`，满屏 `-1`）。
- **纯 C 探针的 include 编译必须显式 `-DUNICODE`/`-D_UNICODE`**：不带时 `IDC_ARROW` 等是 `MAKEINTRESOURCEA` 形态（`LPSTR`），传给 `...W` 形参报 **C4133**（`stub.c:388-396`、`646`）；带上后零新增告警（`stub.c` 自身 `wcsncpy`/`wcsncat` 的 C4996 是既有告警）。`moon` 的 native-stub 本就定义 UNICODE（W2 小节已记），故生产链吃不到这两条 C4133。
- **`AppendMenuW` 单菜单项数上限实测 ≈1168**（本机 bulk 循环第 1169 项起返回 0），**远低于命令 id 池 2048**。由此定两条：①**命令 id 必须「挂载成功后才推进游标」**——原实现先 `cmd = next++` 再 `AppendMenuW`，失败照样吃掉一个 id；反复失败（菜单超限）会让配额提前耗尽，进而与其他菜单在用的 id 相撞（`WM_COMMAND` 只带 id，撞了就把点击派给错项）。修正为 `cmd = next`，`AppendMenuW` 成功后再 `next = cmd + 1`（到池尾归位 `BASE`）。②`WM_MENU_CMD_MAX=2048` 要**刻意大于单菜单上限**：池 ≥ 单菜单上限才保证「只填一个菜单绝不回绕」、菜单自身 id 不自相撞；把池收紧到「实测上限」反而让满菜单撞上回绕。探针据此重写回绕用例——跨菜单填满 2048 个 id 后再在**有空间的新菜单**上加一项，验证它拿到归位后的 1000（单菜单永远耗不尽池子，第一版断言不可达）。
- **`\t` 拼进标签即加速键提示**：`AppendMenuW` 会把 `\t` 之后的部分右对齐显示（探针用 `GetMenuItemInfoW` 读回，校验中文 UTF-8→UTF-16 往返 + `\tCtrl+Alt+Q` 提示串存在）。真正的加速键表（`TranslateAccelerator`）未接，菜单打开后的键盘导航/快捷键暂靠 W20b 全局热键。
- **消息框（W20d）是栈内第二种 FFI 形态——「阻塞式」**：`MessageBoxW` 一次调用即显示并**模态阻塞**到用户点按钮、返回按钮编号，没有回调也没有窗口槽；`uType` 的四段位组合（图标 + 按钮）由 MoonBit 侧纯函数算好传进来（探针真机跑出 `icon=64 btn=0 raw=327744`）。与菜单/热键那种「寄存 + 泵里抽」的异步形态正交。
- **全局快捷键（W20b）挂在**线程**消息队列而非窗口**：`RegisterHotKey` 的 `WM_HOTKEY` 进的是注册线程队列，WndProc 收不到——与菜单同制，桩侧 `wm_hotkey_poll` 在 MoonBit 泵里主动抽。加速键串解析（`"CmdOrCtrl+Shift+M"` → 修饰位 + 虚拟键码）抽成三平台同源纯函数（`CmdOrCtrl` 在 Win 映射 Ctrl、mac 映射 Cmd），10/10。
- **回证**：`experiment/menu_probe/menu_backend_probe.c` 纯 C 探针 `MENU-BACKEND-OK`（菜单条/子菜单/命令 id/分隔线/勾选/嵌套/中文标签/非法父句柄/句柄表用尽/id 回绕全过）；`experiment/menu_probe` 的 MoonBit 侧验模型树 `MENU-OK`；`core/menu_wbtest.mbt` 10/10、`win/hotkey_wbtest.mbt` 10/10、`win/message_box_wbtest.mbt` 8/8 真跑通过。

### MoonBit 原生 GUI 栈 · Windows 图标加载（W20f：.ico 原生 + PNG 走 WIC）

- **三条来源各有各的入口**：`.ico`/`.bmp` 走 `LoadImageW(LR_LOADFROMFILE)`（Win32 原生图标格式，不必解码）；PNG/JPEG/GIF **没有原生入口**，只能 WIC 从内存解码（`CreateStream`→`InitializeFromMemory`→`CreateDecoderFromStream`→`CreateFormatConverter` 到 `GUID_WICPixelFormat32bppBGRA`→`CopyPixels`）；已是像素的走 32bpp 自顶向下 DIB + `CreateIconIndirect`。`wm_icon_load_file` 按扩展名分派，两条都失败给 0。
- **32bpp HICON 的 alpha 必须预乘，而 `render` 的 Bitmap 正是这个口径**（小端 B,G,R,A 预乘）——`CreateIconIndirect` 的颜色位图用 alpha 做混合，预乘才不出光环；两者天然对齐，像素可逐字节 `memcpy` 进 DIB。验证法：`GetObject` 对 DIB section 的 `bmBits` **不保证可读**（实测拿到不可用指针、memcmp 必挂），要反读像素得用 `GetDIBits`（`biHeight` 给负数＝请求自顶向下，与输入行序一致）。
- **`CLSID_WICImagingFactory` 是宏、会指向 Win8 才有的 Factory2**：`wincodec.h` 在 `_WIN32_WINNT >= 0x0602` 时 `#define CLSID_WICImagingFactory CLSID_WICImagingFactory2`；要兼容旧系统就显式取 **`CLSID_WICImagingFactory1`**（vtable 前缀一致，`IID_IWICImagingFactory` 仍用 v1）。
- **GUID 常量全在 `windowscodecs.lib` 里导出**（`dumpbin /linkermember` 实测：`CLSID_WICImagingFactory1`、`IID_IWICImagingFactory`、`GUID_WICPixelFormat32bppBGRA` 都有），故 win 的 Windows 链接行只加 `windowscodecs.lib ole32.lib`，不必再链 `uuid.lib`（C 模式仍用不了 `__uuidof`，与 W14 文件对话框同条坑）。
- **C4013 隐式声明同样会在这条路上出现**：`wm_icon_load_file` 的 WIC 回退要调定义在其后的 `wm_icon_from_png`，独立编 stub.c 时 MSVC 给 `C4013: 未定义；假定外部返回 int`——**能编过但口径不可信**（与主色那节的坑同族），加前置声明即消。教训：内部互相调用的静态/全局函数，先想清定义次序或直接前置声明，别靠隐式声明兜。
- **回证**：纯 C 探针 `experiment/icon_probe/icon_backend_probe.c`（`#include stub.c` 直喂 `wm_icon_*`，再用 `GetIconInfo`/`GetDIBits` 反读）末行 `ICON-BACKEND-OK`：BGRA→HICON 的尺寸/位深/像素往返、`.ico` 磁盘加载、PNG 走 WIC（8×8 RGBA 半透明红解出 32bpp）、句柄表 31 槽用尽归 0、释放幂等全过。PNG 素材由 `experiment/icon_probe/make_png.py` 用标准库 zlib 手写生成（不依赖 Pillow）。`moon test ./gui/win` 24/24（新增 6 条纯函数：扩展名判定/格式分派/句柄 0 语义/尺寸校验）。

### MoonBit 原生 GUI 栈 · Windows 窗口增强（W20e：改标题 / 窗口图标 / 最小尺寸 / 无边框拖拽区）

- **`WM_GETMINMAXINFO` 的 `ptMinTrackSize` 要的是整窗尺寸，不是客户区**：MoonBit 侧传的是**最小客户区**（`set_min_size(w,h)`），C 侧按当前样式 `AdjustWindowRectEx(&r, st, FALSE, ex)` 把非客户区（边框 + 标题栏）外扩后再填 `ptMinTrackSize`。探针实测：客户区最小宽 400、WS_OVERLAPPEDWINDOW 下外框 416（左右各 8px），`AdjustWindowRectEx` 口径与 `WM_GETMINMAXINFO` 一致。
- **某轴为 0 必须显式归零**：`set_min_size` 允许单轴不限（`0` = 该轴不限制）。但**不能**把 `0` 直接塞进 `AdjustWindowRectEx` 的矩形——那会算出「零客户区也占 2×边框宽」的假最小宽。实现写成 `mmi->ptMinTrackSize.x = w->min_w > 0 ? (r.right - r.left) : 0;`，两轴都判一次；`wm_set_min_size` 入口也先把负数夹成 `0`。只设一轴时另一轴必须回落到 0，否则窗口在该轴被卡住。
- **`WM_NCHITTEST` 用 `break` 而非 `return 0`**：自绘标题栏拖拽区命中时 `return HTCAPTION`（把拖窗交给系统），**不在区内必须 `break` 落回默认处理**——`WM_NCHITTEST` 的默认返回值含客户区 `HTCLIENT` / 边框缩放角 `HTBOTTOMRIGHT` 等语义，`return 0` 会把它们一并吞掉：实测表现为边框再也拽不动、客户区鼠标行为异常。命中判定用 `ScreenToClient` 把 `lParam` 的**屏幕坐标**转客户区坐标再比矩形（`lParam` 打包的是屏幕坐标，不是客户区，容易看走眼）；区间取左下闭右上开（`>= x && < x+w`）。注意 `lParam` 的坐标是 **16 位有符号**（`(int16_t)LOWORD/HIWORD`），多显示器负坐标也能还原。
- **`WM_GETICON` 反读校验窗口图标**：`wm_set_icon(id, icon_slot, which)` 的 `which` 0/1/2 分别对应 `ICON_BIG` / `ICON_SMALL` / 两者，直接 `SendMessageW(hwnd, WM_SETICON, …)`。探针用 `WM_GETICON(ICON_BIG)` 反读，拿到同一个 `HICON` 句柄即证明写入生效。**图标句柄表归调用方**（W20f 的槽表），窗口只是「用」这个 `HICON`：C 侧注释与门面文档都写明「调用方须保证图标在窗口显示期间不被 `free`」，否则窗口引用悬空句柄。传入 `icon_slot=0` 即清空图标。
- **无边框 = 改样式后按客户区重算外框 + `SWP_FRAMECHANGED`**：ON 时去掉 `WS_CAPTION|WS_THICKFRAME|WS_MINIMIZEBOX|WS_MAXIMIZEBOX|WS_SYSMENU|WS_BORDER|WS_DLGFRAME`、换 `WS_POPUP`（保留 `WS_MINIMIZEBOX` 以便仍能最小化），OFF 时还原 `WS_OVERLAPPEDWINDOW`。**关键两步**：①先 `GetClientRect` 拿当前客户区尺寸，改完样式后用新样式 `AdjustWindowRectEx` 重算外框，再 `SetWindowPos(..., SWP_NOMOVE|SWP_NOZORDER|SWP_FRAMECHANGED)`——少了 `SWP_FRAMECHANGED` 非客户区不重算，窗口尺寸会跳；②幂等判据用 `w->borderless`，重复设同值直接返回（否则每次调用都 `SetWindowPos`，无谓重排）。探针验：无边框后 `GWL_STYLE` 里没有 `WS_CAPTION`、客户区宽度仍是 640（不变）。
- **运行中改标题走 `SetWindowTextW`**：`wm_set_title` 把 UTF-8 转 UTF-16 后 `SetWindowTextW`；探针用 `GetWindowTextW` 反读中文标题校验 UTF-8→UTF-16 往返。
- **回证**：纯 C 探针 `experiment/window_probe/window_enhance_probe.c`（`#include` stub.c，建真窗口后 `SendMessageW(WM_GETMINMAXINFO/WM_NCHITTEST)` 直读、`GetWindowTextW`/`WM_GETICON`/`GWL_STYLE` 反读）末行 `WIN-ENHANCE-OK`（40 条断言全过）：`SetWindowTextW` 生效（中文）、`ptMinTrackSize.x == 416`（客户区 400 + 边框）、多显示器负坐标命中/边界开区间、区内回 `HTCAPTION` 区外回 `HTCLIENT`、`WM_GETICON(ICON_BIG)` 等于传入图标、无边框后无 `WS_CAPTION` 且客户区宽不变、越界 id 不崩且不写缓冲。示例接线：`examples/native-app` 新增窗口增强区（改标题 / 自绘图标 / 无边框开关 / 拖拽带开关）与退出状态行 `NATIVE-APP-WIN title='…' min=… drag=… bl=… icon=…`，`moon build` 产出 `native-app.exe`。`moon test ./gui/win` 24/24、`moon check ./gui/win ./examples/native-app --deny-warn` 零警告、C 后端 MSVC `/W4` 干净。

### MoonBit 原生 GUI 栈 · Windows 系统托盘（W20c：Shell_NotifyIconW + 复用 W20a 菜单做右键）

- **托盘 = 「一个 HWND + 一个 uID」的 Shell 通知图标**：`Shell_NotifyIconW` 的回调消息投给 `NOTIFYICONDATAW.hWnd` 那扇窗，`wParam` 是 `uID`、`lParam` 是鼠标消息。本侧因此自建一扇**隐藏消息窗**（`yue_wm_tray` 类 + `HWND_MESSAGE`，惰性建、幂等），槽号即 `uID`（1 起，槽 0 不用；`WM_MAX_TRAYS=8`）。
- **`WIN32_LEAN_AND_MEAN` 会把 `shellapi.h` 一并裁掉**：`Shell_NotifyIconW` / `NOTIFYICONDATAW` / `NIM_*` / `NIF_*` 全在它里面，必须显式 `#include <shellapi.h>`（与 `imm.h` 同待遇）。链接面补 **`shell32.lib`**（`user32`/`gdi32` 里没有）——漏了就是 `LNK2019 __imp_Shell_NotifyIconW`。
- **回调消息用 `WM_APP+2`，且同样「C 不回调 MoonBit」**：`WM_APP+1` 已被 `wm_wakeup` 的 waker 窗占用（`stub.c` 里那条 `case WM_APP + 1:`），托盘另取 `WM_APP+2`。命中（`WM_LBUTTONUP`/`WM_LBUTTONDBLCLK` → 左键、`WM_RBUTTONUP` → 右键）压进程级环形队列，宿主每拍 `wm_tray_poll` 抽——与菜单/热键同制，避开蹦床形参错位那一类坑。非点击消息（如 `WM_MOUSEMOVE`）不入队。
- **右键菜单复用 W20a 的 HMENU 句柄表，于是「托盘菜单」与「窗口菜单」共用同一条派发链**：`wm_menu_popup_new()` 建弹出根（与 `wm_menu_bar_new` 只差 `CreatePopupMenu` vs `CreateMenu`），core 的 `menu_translate_into` 照常往里填项；弹出用 `TrackPopupMenuEx(menu, TPM_RIGHTBUTTON|TPM_RETURNCMD|TPM_NONOTIFY, x, y, tray_hwnd, NULL)`——**`TPM_RETURNCMD` 把选中项直接作返回值给出**，压进 `wm_menu_push` 即回到 `dispatch_menu_command()` 的回调表，不必依赖托盘窗的 `WM_COMMAND` 路由。两条微软约定照做：弹前 `SetForegroundWindow(tray_hwnd)`、弹后 `PostMessage(hwnd, WM_NULL, 0, 0)`，否则菜单可能不消失（焦点不还回去）。
- **`szTip` 是 128 宽字符的定长数组，超长必须截断**：写 tooltip 用 `wcsncpy_s(nid.szTip, 128, wtip, _TRUNCATE)`——裸 `wcsncpy` 会吃 **C4996**（与 W20a 菜单标签那两处同族告警）。本次刻意用 `_s` 变体，托盘整段在 MSVC `/W4` 下**零新增告警**。探针实测超长（299 字符）截断在 127 以内、不越界。
- **后端选择：Linux SNI 优先，Windows 走本批桩，皆无给 `Err(Unsupported)`**。SNI 可用性判据是**新增**的 `@dbus.sni_watcher_present()`（连得上总线 **且** `NameHasOwner(org.kde.StatusNotifierWatcher)`），比既有的 `@dbus.sni_available()`（只看「连得上总线」这个候选条件）更强——纯净 GNOME 未装 AppIndicator 扩展时总线通但 watcher 不在线，托盘实际不可用。**GTK 分支刻意返回 0**：Linux 的托盘走 SNI 协议栈，不走 GTK3 的 `GtkStatusIcon`（已弃用且面板不认），与 W20f 图标加载在 GTK 分支返回 0 同一个理由。
- **门面住 `core/tray.mbt`，core 因此新增 `sys` 与 `dbus` 两个依赖**（前者供 `desktop_environment()` 读 `XDG_CURRENT_DESKTOP`，后者供 SNI）。这与 W20a 把菜单模型放 core 同一条分层口径：core 是「跨平台能力门面」层，平台后端只做「模型 → 原生」翻译。旧栈同名 `TrayError` 在待退役的 `yue/error.mbt`，新栈口径住本文件。
- **退出读数的坑（本批顺带修）**：示例的退出状态行在**窗口关闭之后**才打印，那时后端槽已被 `memset` 清空——`NATIVE-APP-WIN title='' min=0x0 …` 一片 0（现场读数读的是一扇已销毁的窗）。改成每拍把现场读数快照进一个 `Ref[String]`、退出时打印最后一份「活着时的」读数，读数才有意义（实测由 `title='' min=0x0` 变为 `title='MoonBit App 宿主 (批次1)' min=900x600`）。口径：**退出时想报「运行中的现场状态」，就得在运行中取样，别指望销毁后还能读到。**
- **回证**：纯 C 探针 `experiment/tray_probe/tray_backend_probe.c`（`#include` stub.c，直喂 `wm_tray_*`）末行 **`TRAY-BACKEND-OK`**，28 条断言全过：`wm_tray_supported()==1`、**真实 `Shell_NotifyIconW(NIM_ADD)` 建成**、tooltip 中文 UTF-8→UTF-16 往返与 299 字符截断在 127 内、`wm_menu_popup_new` 拿到真 `HMENU` 且挂进托盘、**主动给托盘消息窗投 `WM_TRAY_CB` 验左键 kind=0 / 右键 kind=1 / 槽号一致 / 非点击消息不入队**、`wm_tray_popup` 的守卫路径（非法槽、无菜单）立刻返回 0 不阻塞（`TrackPopupMenuEx` 是阻塞调用，真弹出需真人点选，故只验守卫）、槽表用尽（7 槽后给 0）、移除幂等且计数归 0。`moon test ./gui/core` **99/99**（新增 6 条纯函数：`basename_no_ext` 各类路径/空串/尾点/多重点、桌面环境名非空、`TrayError` 三种 Show；**1 条生命周期**：建 → `tray_count()==1` → tooltip 回读一致 → 挂菜单（弹出句柄回填）→ 移除 → `tray_count()==0`，无托盘后端的机器自动跳过而非造假）。示例 `examples/native-app` 新增托盘区块（建/改提示/挂菜单/弹菜单/移除五键 + 状态计数）与退出状态行 `NATIVE-APP-TRAY supported=… backend=… count=… clicks=… note=…`，并在主循环每拍加 `dispatch_tray_event()`。真机冒烟：`exit 0`，`NATIVE-APP-TRAY supported=1 backend=- count=0 clicks=0 note=-`（未点按钮故未建项，supported=1 即 Win32 托盘后端可用）。`moon check` 全仓红点 **287/68** 持平，gui/{core,win,dbus,ui,render,text,theme,icons,input,mdview,chart} 全绿。

### MoonBit 原生 GUI 栈 · Windows 桌面通知（W21a：托盘气泡 NIF_INFO + freedesktop 跨平台门面）

- **Win32 的「通知」没有独立 API，它就是挂在托盘图标上的一张气泡**：先 `NIM_ADD` 建托盘项，再 `NIM_MODIFY` 带 `NIF_INFO` 与 `szInfoTitle`/`szInfo` 弹气泡（Vista 起系统把这类气泡转成 Action Center 的 toast）。因此本段**复用 W20c 的托盘槽表与消息窗**，用新增的 `WmTray.kind` 区分：`kind == 0` = 托盘图标（收点击）、`kind == 1` = 通知气泡（只弹、不收点击）。通知 id 于是天然等于所属托盘槽号（>=1）。
- **通知槽必须显式排除在点击队列外**：`wm_tray_wndproc` 收 `WM_TRAY_CB` 时加了 `wm_trays[slot].kind == 0` 守卫，`kind == 1` 的槽收到点击直接丢弃——气泡的点击语义未定义（Windows 的 toast 点击由系统处理，不经 `uCallbackMessage`），若照旧入队会派发到一个「不是托盘图标」的槽上。探针主动给通知槽投 `WM_LBUTTONUP`/`WM_RBUTTONUP`，验队列仍空。
- **「收气泡」没有独立 API，只能照官方约定再发一次 `NIF_INFO` 且 `szInfo` 置空**：`wm_notify_close` 先发这条空正文的 `NIM_MODIFY`（系统据此撤下气泡），再 `NIM_DELETE` 摘掉托盘项——两步都要，只 `NIM_DELETE` 不保证气泡立刻消失。幂等：重复关闭走「槽已空」的守卫直接返回。
- **两条平台差异显式降级、不假装对齐**（写进 `core/notify.mbt` 的文档头与本节）：① **`uTimeout` 自 Vista 起被系统忽略**，气泡驻留时长由系统的辅助功能设置定，故 `timeout_ms` 只用于与 Linux 侧同签名、本侧不生效；② **Win32 气泡没有「进度 hint」**，Linux 的 freedesktop `value` hint 能让桌面端画进度条，Win32 无对应物，门面把百分比拼进正文（`notify_body_with_progress`，可见降级而非静默丢弃）。
- **`kind` 三态映射 `NIIF_*`**：0 信息 / 1 警告 / 2 错误 → `NIIF_ERROR` / `NIIF_WARNING` / `NIIF_INFO`（气泡左侧的系统状态图标）。这是写死的一行三元式，**Win32 没有读回 `dwInfoFlags` 的接口**，故探针只能验三个 kind 下发都返回成功，映射本身由代码评审兜底（探针头注释如实写明这一限制）。
- **`szInfoTitle` 是 64 宽字符、`szInfo` 是 256 宽字符的定长数组**：写入一律 `wcsncpy_s(..., _TRUNCATE)`（裸 `wcsncpy` 吃 C4996，与 W20a/W20c 同族）。探针实测 399 字符标题截断在 63 以内、不越界。`WmTray.ntitle[64]` 存一份标题副本供反读（`wm_notify_title`，UTF-8 输出）。
- **托盘图标槽与通知槽共用同一张 `WM_MAX_TRAYS=8` 表，但计数完全解耦**：`wm_tray_count()` 只数 `kind == 0`、`wm_notify_count()` 只数 `kind == 1`。探针验「托盘 1 + 通知 3 = 占用 4 槽」「表满后再发只成 3 张」「摘掉托盘图标不影响通知数」。分配入口统一走 `wm_tray_alloc(kind, icon_slot, tip)`，`wm_tray_new` 转调 `kind=0`。
- **门面分层**：`win/notify.mbt` 是 Windows 侧薄封装（`notify_supported`/`notify_send`/`notify_update`/`notify_close`/`notify_count`/`notify_title` + `NOTIFY_INFO/WARNING/ERROR` 三常量）；`core/notify.mbt` 是**跨平台门面**——后端选择 Linux freedesktop D-Bus（`dbus/notify.mbt`）优先 → Win32 托盘气泡 → 皆无给 `Err(NotifyError::Unsupported)`。跨平台 API 形如 `notify_send(app_name, summary, body, icon?, timeout_ms?, replaces_id?, progress?, kind?, icon_handle?)`，其中 `icon` 是 Linux 主题图标名、`icon_handle` 是 Win32 的 W20f 图标句柄（0 = 用系统状态图标）。`replaces_id > 0` 时 Win32 侧先试 `notify_update`（同槽重发即替换）。
- **回证**：纯 C 探针 `experiment/notify_probe/notify_backend_probe.c`（`#include` stub.c，直喂 `wm_notify_*`）末行 **`NOTIFY-BACKEND-OK`**，**37 条断言全过**：`wm_notify_supported()==1`、**真实 `Shell_NotifyIconW(NIM_MODIFY)` 弹气泡**、标题中文 UTF-8→UTF-16 往返与 399 字符截断在 63 内、**通知槽点击不入托盘队列**、三个 kind 下发皆成功、**托盘 1 + 通知 3 共表且计数解耦**、表满（7 槽）后新发给 0、关闭减一且幂等、非法槽/托盘槽调用通知 API 全给 0 或无效。`moon test ./gui/core` **108/108**（新增 9 条：`notify_clamp_kind` 夹 0..2、`notify_clamp_pct` 夹 0..100、`notify_body_with_progress` 负值不改/拼进正文/百分比夹取、`NotifyError` 两种 Show、后端名与枚举一致、`notify_caps` 有/无后端两态；**1 条生命周期**：发 → 改进度 → 关 → 幂等重关，无通知后端的机器自动跳过）。示例 `examples/native-app` 新增通知区块（发信息/发警告/发错误/进度 60%/关闭五键 + 状态计数）与退出状态行 `NATIVE-APP-NOTIFY supported=… backend=… sends=… id=… count=… note=…`（`count=` 同样每拍快照，理由同 W20c 的退出读数坑）。真机冒烟：`exit 0`，`NATIVE-APP-NOTIFY supported=1 backend=win-balloon sends=0 id=0 count=0 note=-`（未点按钮故未发，`backend=win-balloon` 即后端选择正确）。`moon check` 全仓红点 **287/68** 持平，gui/{core,win,dbus,ui,render,text,theme,icons,input,mdview,chart} 全绿。

### MoonBit 原生 GUI 栈 · 自绘消息框（W21b：`@ui.message_box_t`，与 W20d 原生档并存）

- **自绘档与原生档是两条路、互补而非替代**：`@win.show_message_box`（W20d）走 `MessageBoxW`——系统外观、系统模态、**阻塞**返回编号，但**只有 Win32 有**（macOS 留桩）；`@ui.message_box_t`（本批）纯自绘、吃主题、**非阻塞**（点按钮回调编号），三平台同一份代码。调用方按需选，两者语义面对齐（标题 / 正文 / informative 副行 / 多按钮 / 响应回调）。
- **响应编号由调用方给，不借用 Win32 的 1..7**：`buttons` 是 `(文案, 响应编号)` 列表，组件原样回传。原生档的 `Ok(1)/Cancel(2)/…/No(7)` 是 `MessageBoxW` 的返回值口径，自绘档不该被它绑住——**两套编号刻意不互通**，状态行里也就分成 `NATIVE-APP-MSGBOX`（原生）与 `NATIVE-APP-MSGBOX2`（自绘）两行。
- **✕ / Esc / 点遮罩 = 收起但不给编号**（走 `on_dismiss`）：原生 `MessageBoxW` 的 ✕ 归 `IDCANCEL`，自绘档不这么借（见上条）；要「取消也算一个结果」，调用方自己放一个取消按钮即可。`close_on_mask` 默认 **false**——消息框通常要求显式作答，点空白处就关掉容易误操作。
- **Enter = 第一个按钮**（与原生档 `default_index=0` 同义）。Esc/Enter 要能收到，就得**接管焦点**：开层时 `msgbox_alloc_focus_id()` 取一个 700000 起的 id、`@core.host_active()` 上 `focus.register` + `focus.focus`，面板自己当焦点控件（层级上比遮罩深，键先到它）；收层时 `unregister` 并把**开框前那个焦点还回去**。取号从 700000 起是为了避开调用方常用的低号段（示例里用 1..25）——**焦点 id 是全局命名空间，组件内部取号必须留余地**。
- **枚举变体名不许叫 `None`（本批踩到的编译期连带伤）**：`MsgBoxKind` 最初写 `None`，结果**同包其它文件**里所有 `Store::new(None)` 都开始按 `MsgBoxKind::None` 推断，`datetime_wbtest` 当场 6 条类型错。原因：`Store::new(None)` 这类**没有期望类型**的位置，同名构造器会被抢去解析。改叫 `Default` 即消。教训：往包里加枚举时，**变体名要先看包内有没有同名的无期望类型用法**（`None` 首当其冲，其次是 `Warning` 这类与 `SemanticType` 撞名的）。
- **与 `dialog_t` 的关系**：两者共用 `core/overlay.mbt` 的同一套浮层机制（铺满遮罩 / 居中 / 点外收起 / 开层即重排），差在语义面——`dialog_t` 是「内容对话框」（任意内容树 + 确定/取消两个出口），`message_box_t` 是「消息框」（按种类取图标 + informative 副行 + 任意多按钮各带编号）。要做纯内容对话框仍走 `dialog_t`，本批**没有**把两者合并。
- **回证**：`ui/message_box_wbtest.mbt` 新增 **8 条**（3 条纯函数：五种种类的图标名/取色互异/默认钮编号；5 条运行时：Store 驱动弹收 + 面板居中 + 四区结构 + 按钮回调编号与收起 + ✕/Esc 走 dismiss 而 Enter 走默认钮 + `close_on_mask` 两态 + informative 空则不留副行 + 空文案按钮跳过），用无头控件树 + 手动装的浮层宿主（同 `overlay_wbtest`），**不需要真窗口**。`moon test ./gui/ui` **118/118**（原 110）。示例 `examples/native-app` 新增自绘消息框区块（信息/警告/错误三个按钮各驱动一个消息框）与退出状态行 `NATIVE-APP-MSGBOX2 shots=… last=… ovl=…`（`ovl=` 是运行中浮层数的末次快照，理由同 W20c 的退出读数坑）；真机冒烟 `exit 0`、`NATIVE-APP-MSGBOX2 shots=0 last=- ovl=0 native_ovl=0`（未点按钮故未弹）。`moon check ./gui/ui ./examples/native-app --deny-warn` 零警告，全仓红点 **287/68** 持平。

### MoonBit 原生 GUI 栈 · 拖放门面（W21c：`core/drag.mbt` 会话模型 + `@ui.drag_source`/`drop_target`）

- **应用内拖放全自绘、三平台同构**：旧链路的拖源/投放是**平台回调**（GTK `gtk_drag_*` / Win32 `IDropTarget`），还要分别注册 enter/update/leave 三件；本栈的**应用内**拖放不碰任何平台接口——会话模型在 `core/drag.mbt`（进程级），声明式两个钩子在 `ui/drag.mbt`。**跨应用**的系统级拖放（拖出窗口 / 接系统文件）仍随平台批，门面接口形状已定，后端接上后 UI 侧不用改。
- **载荷是自有类型，不是平台图像类型**：`DragData{Text,Html,Paths,Img}`；`Img` 存**原始 PNG 字节**而非平台图像句柄——模型层不带平台类型，才能跨后端/跨进程传。`DataKind{Text,Html,Image,FilePaths}` 各给一个稳定编号（1/2/3/4），`drag_encode`/`drag_decode` 编成 `[kind:i32 LE][payload]`（`Paths` 用 `\n` 连接）——这是将来跨进程/跨后端传载荷的稳定 ABI。
- **会话是进程级单例，落点按窗口坐标算**：同一时刻只允许一个拖拽在跑（`drag_current`）。落点由 `Widget::drop_target_at` 从后往前找**最深**带 `on_drop` 的可见控件；悬停高亮由绘制方读 `@core.drag_hover()` 自判——**省掉 enter/update/leave 三个回调**，也就没有「离开回调漏发」的态同步问题（旧链路的老毛病）。
- **按下捕获的语义差异（本批踩到，务必分清）**：`route_pointer` 在 `Down` 记下的 captured id 是命中链上**最深**的控件（与 Web `pointerdown` 的 target 同义）；拖源包装层的 `on_pointer` 是靠**冒泡**收到事件的（内容件自己不处理指针，就往上传）。因此 `@core.drag_source()` 记的是**包装层** id，而捕获 id 是**内容控件** id——测试断言要按这个区分（曾误写成断言等于包装层 id）。
- **拖源内容里别放按钮**：指针事件**最深优先**，内容里的交互控件会先把按下吃掉，那样就拖不动它。拖源里放展示件（文本/图标/缩略图）即可。**这是使用约束，不是 bug**。
- **`payload()` 惰性求值**：只有**过了阈值**（默认 4px）才调 `payload()` 取数据开拖；没过阈值按普通点击放行——内容里的选择/点击不受影响。`payload()` 返回 `None` 时这一拖不成立，也退回普通按下。
- **给值类型 `derive(Eq)` 会触发 `implicit_impl_as_method` 告警**（本批的编译期坑）：正确形态是手写 `pub impl Eq for DataKind with fn equal(self, other) -> Bool` + `pub extend DataKind with Eq::{not_equal, equal}`。注意实现函数名是 **`fn equal`**（首次写成 `op_equal` 编译器报 `no method op_equal in trait Eq`）。`DragData` 因含 `Bytes`/`Array` 没有走 `Eq`（也没实现 `Debug`），测试观测一律走字符串/编号。
- 另一个实现坑（记档）：`Bytes` 没有 `op_set`，`raw[4:...]` 给的是 `BytesView` 不能直接切——拼字节用 `FixedArray::make` + `Bytes::from_array`；`split("\n")` 得 `Iter[StringView]`，要 `.map(fn(s){ s.to_owned() })` 才是 `Array[String]`。
- **回证**：`core/drag_wbtest.mbt` **6 条**（编号往返、`DragData::kind`/`as_text`、编解码往返与坏输入、`drop_target_at` 最深命中、会话 `begin→move→drop`、无落点/拒绝/`cancel`、无根时落点恒无）；`ui/drag_wbtest.mbt` **4 条**（按下→过阈值开拖→移到目标→松手投递、没过阈值当普通点击/投空白处不投递、`accept` 拒绝时回调不跑、`payload` 给 `None` 不产生会话），全走宿主的 `@core.route_pointer`（含按下捕获），**不需要真窗口**。`moon test ./gui/core` **115/115**、`moon test ./gui/ui` **122/122**。示例 `examples/native-app` 新增拖放区块（两个拖源「文本载荷 / 路径载荷」+ 两个落点「全收 / 只收路径」）与退出状态行 `NATIVE-APP-DRAG drags=… drops=… active=… last=…`；真机冒烟 `exit 0`、`NATIVE-APP-DRAG drags=0 drops=0 active=0 last=-`（未拖故计数为 0）。`moon check ./gui/core ./gui/ui ./examples/native-app --deny-warn` 零警告，全仓红点 **287/68** 持平。
- **本批未做且不假装完成**：跨应用系统级拖放（拖出窗口/接系统文件，随平台批）、拖拽视觉反馈（跟随指针的 ghost 缩略图——现在只描落点高亮）、macOS 后端、拖拽的真机观感（归 `_人工测试清单.md`）。

### MoonBit 原生 GUI 栈 · 开机自启动（W21d：`sys/autostart.mbt`，面在 MoonBit、只有 Windows 要 C）

- **分工**：**跨平台的面在 MoonBit**——Linux（及各 XDG 桌面）拼 `$XDG_CONFIG_HOME/autostart/<app_id>.desktop` 并写盘（纯字符串 + `fsx.mbt` 既有的文本文件读写入口，不需要任何平台接口）；**只有 Windows 需要 C**——HKCU 的 Run 键只能走注册表 API（`RegOpenKeyExW` / `RegQueryValueExW` / `RegSetValueExW` / `RegDeleteValueW`），见 `sys/sys_stub.c` 的自启动节。macOS 本批显式 `Unsupported`（要走 LaunchAgents plist，留待真机）。
- **值的形态是平台惯例，不是随便一个字符串**：Linux 的 `.desktop` Exec 要按桌面项规范**整体双引号包裹**（引号内 `\` 与 `"` 反斜杠转义、`%` 写 `%%`）；Windows 的 REG_SZ 值同样要**整串引号包裹**——路径含空格而未加引号时，登录拉起会被截断成第一个词（等于自启动了一个不存在的程序）。两侧的引号都由 MoonBit 侧拼（`autostart_escape_exec` / `autostart_run_value`），C 桩**原样写、原样读**，不做二次加工。
- **幂等是契约的一部分**：重复 `enable` 是覆盖写（Linux 覆盖 `.desktop` / Windows 覆盖同值名的 Run 值）；`disable` 对「本就不在」也返回成功（Linux 靠 `yue_sys_remove_file` 的「先探存在再删」、Windows 对 `RegDeleteValueW` 的 `ERROR_FILE_NOT_FOUND` 与「键都不在」两档都算成功）。
- **app_id 校验是两个落点的公共前提**：app_id 同时要当 `.desktop` 文件名与 Windows 的 Run 值名，所以沿用 DBus 知名名字符集（≥2 个点分元素、每元素以字母/下划线开头、只含 `[A-Za-z0-9_-]`、总长 ≤255）。**`sys` 不反向依赖 `dbus`**，故这条规则在 `sys/autostart.mbt` 里本地实现了一份（`autostart_valid_app_id`）。**踩到的认知坑**：元素**不能以 `-` 或以数字开头**，但**可以包含**它们——`com.example.my-app2` 合法、`com.2app` 与 `com.-app` 非法。写测试时曾把「含 `-`」当成非法（断言 `com.ap-p` 为 false 而它其实是合法的），实测纠正。
- **链接面**：`Reg*` 一族在 **advapi32.lib**，而 `sys` 的 Windows 链接行原本只有 `ole32/shell32/uuid/user32`（那些是给文件对话框的 COM 用的）——本批给 sys 条目补上 `advapi32.lib`（`scripts/prebuild.py` 托管，包内仍不写链接参数）。
- **纯 C 探针的两个自带件**（`experiment/autostart_probe/autostart_backend_probe.c`）：①**探针自带 `moonbit_make_bytes`**——纯 C 探针不链 moon 运行时，而 `yue_sys_*` 返回的是 moon 字节串；自带一份只要**布局自洽**即可（长度存数据指针**前 4 字节**，与真 `moonbit_object` 头同构），真 ABI 交互由白盒测试覆盖。②**`stub.c` 的 include 顺序会让 `_CRT_SECURE_NO_WARNINGS` 失效**——探针先 `#include <windows.h>`（它已带入 `string.h`），UCRT 在那一刻就定下了弃用名要不要告警，于是桩里那两处 `wcscpy`/`wcscat` 在探针编译里出 2 条 C4996。这是**探针 include 顺序的产物，不是代码问题**：真构建由 moon 的 native-stub 先含 `sys_stub.c`，宏先生效，无此告警。
- **回证**：纯 C 探针末行 **`AUTOSTART-BACKEND-OK`**，**36 条断言全过**：`yue_sys_exe_path` 与独立调用 `GetModuleFileNameW` 逐字符一致（含 `.exe` 后缀与反斜杠）、未写时 ok=0、写入后**探针自己直读** `RegQueryValueExW` 确认落在 `Software\Microsoft\Windows\CurrentVersion\Run` 且类型 `REG_SZ`、值与写入逐字符一致、覆盖写/中文路径往返/空值（长度 0 但存在）/1207 字符长值往返、`NULL` 参数三入口回 -1、删除后独立直读 `ERROR_FILE_NOT_FOUND`、幂等再删仍成功。**探针会真写用户注册表**（这正是它的意义），起手与收尾都删自己的专属值 `com.moonbit.native-gui.autostart_cprobe`，无论成败都清场（跑完 `reg query` 复核无残留）。`sys/autostart_wbtest.mbt` **8 条**：6 条纯函数（目录解析三态 / Exec 转义 / `.desktop` 内容与解析两态 / Run 值形态与反解 / app_id 校验 / 错误 `Show`）+ 1 条「非法 app_id 在任何平台先被拒」+ **1 条真实生命周期**（清场 → 未启用 → enable → 启用 → 落点可读回（Linux 读 `.desktop` 正文、Windows 读 Run 值并反解比对 exe）→ 重复 enable 幂等 → disable → 未启用 → 幂等再 disable），`autostart_supported()` 为假时跳过而非造假。`moon test ./gui/sys` **174 条、173 过、1 红**——那 1 条是**既有**的 `fsx_wbtest.mbt:109`（`sys_make_dirs` 用例当时在 Windows 上本就红：`pr_available()` 在 Windows 为真，但用例走的是 POSIX 的 `/tmp` + `pr_run("rm"/"mkdir")`；已用 `git stash` 在纯净态复核同一条红，与本批无关）。**现已修复**——`sys_make_dirs` 改为 C 薄 FFI `yue_sys_make_dirs`、用例本身也做成平台可移植，`sys` 178/178。示例 `examples/native-sys` 新增「启用自启 / 取消自启」两键与状态行，退出读数行 `NATIVE-SYS-AUTOSTART supported=1 enabled=0 id=… exe=… on_hits=0 note=…`（`is_enabled` 是即时读盘/读注册表，关窗后照读，与窗口读数不同）；真机冒烟 `exit 0`（未点按钮故 `enabled=0`、注册表无残留）。`moon check ./gui/sys ./examples/native-sys --deny-warn` 零警告；C 侧 MSVC `/W4` 仅剩 2 条 C4996（探针 include 顺序所致，见上）；全仓红点 **287/68** 持平。
- **本批未做且不假装完成**：macOS（LaunchAgents plist，留 Unsupported）、「启动参数」与「延迟启动」（Windows 可写 `**` 前缀/`schtasks` 延时，Linux 可加 `X-GNOME-Autostart-Delay`——本批不写）、`is_supported` 之外的能力探测、自启动真机观感（归 `_人工测试清单.md`）。

### MoonBit 原生 GUI 栈 · 用户空闲检测（W21e：`sys/idle.mbt`，只给读数不给二值）

- **接口只给「秒数」，不设 active/idle 二值**：`idle_seconds() -> Result[Double, IdleError]` 返回**自最后一次输入起的秒数**，阈值判定（「多久算空闲」）交给调用方自己比较——屏幕常亮/锁屏/省电各自的阈值差别很大，库替调用方拍一个数只会被绕开。换算与夹取（负数归零）在 MoonBit 纯函数 `idle_clamp_ms` / `idle_ms_to_seconds` 里，桩只回毫秒原始值。
- **平台取数分三档（都在 `sys/sys_stub.c` 的空闲节）**：Windows `GetLastInputInfo` + `GetTickCount`；Linux 走 X11 的 **XScreenSaver 扩展（XSS）**；macOS 本批不做（恒 false / `Unsupported`）。
- **Windows：差值必须用无符号模减，不能用 int64 相减**（本批的关键口径）。`GetTickCount()` 是 32 位、约 **49.7 天**回绕一次。正确的写法是 `DWORD elapsed = GetTickCount() - li.dwTime;`——无符号减法天然按模 2³² 求值，跨回绕点结果仍对；若先各转 int64 再相减，回绕点会得到一个巨大的负数（换算成秒是负的时间）。纯 C 探针用合成值（`0x10 - 0xFFFFFFF0 == 0x20`）把这条语义钉死。
- **Linux：运行期 dlopen，不引入 X 链接依赖**。`sys` 的 Linux 链接行只有 pthread/dl/m/stdc++——**headless 消费者不该被 X 库绑住**，所以 XSS 一律走 `dlopen("libX11.so.6"/".so")` + `dlopen("libXss.so.1"/".so")`，`dlsym` 取 `XOpenDisplay` / `XDefaultRootWindow` / `XScreenSaverAllocInfo` / `XScreenSaverQueryInfo` / `XFree` / `XCloseDisplay`。`XScreenSaverInfo` 结构体**在桩里本地声明**（不引 `X11/extensions/scrnsaver.h`，避免链进 X 头）；取符号经 `void*` 中转（`memcpy`）避开 `-Wcast-function-type`。结果缓存在静态 `g_idle_x11`（`tried` 位防重复探测）。
- **Wayland 会话给「不支持」而不是给错数**：没有 X 服务端（`DISPLAY` 为空）时 `idle_supported()` 直接 false。XWayland 下输入事件不进 X 服务端，XSS 读数只会**虚高**——宁可不报，也不给会误导调用方误判的错值（这正是「只给读数」要配 `Result` 的原因：失败当 0 秒会被误读成「刚动过」）。
- **支持性与这次成败分两档**：`idle_supported()` 是运行期能力探测（Windows 恒真；Linux 要 `DISPLAY` 非空且两个库都 dlopen 成功；macOS false）；`idle_seconds()` 里 `ok=1` 给 `Ok`，否则**看 `idle_supported()`**：真则 `Err(Failed("空闲查询失败"))`（如 X 连接中途断），假则 `Err(Unsupported)`。二者分开，调用方才能区别「这台机器没这能力」和「这次查询挂了」。
- **回证**：纯 C 探针 `experiment/idle_probe/idle_backend_probe.c` 末行 **`IDLE-BACKEND-OK`**、**13 条断言全过**——支持性恒 1、读数非负且在 int32 区间（无误截断）、与**独立重算**的 `GetTickCount() - li.dwTime` 一致（±2000ms，容忍调用间隙与 GetTickCount 粒度）、连续读单调不减、模减语义合成值（含回绕）、连续 5 次读全成功、`ok` 出参每次被写。探针只读系统状态、不写任何东西（较 W21d 少一处自带件：空闲接口不返回 moon 字节串，故不需要自带 `moonbit_make_bytes`）。编法见探针头注释（补 `user32.lib`——`GetLastInputInfo` 在 user32；同时因 `#include sys_stub.c` 带进注册表函数，需一并链 `advapi32.lib`）。`sys/idle_wbtest.mbt` **4 条**：3 条纯函数（毫秒夹取 / 毫秒换秒 / 错误 `Show`）+ 1 条「支持性探测」（Windows 断言真、余平台只打印）+ 1 条「读数非负 + 连续两次单调（变小只可能是期间有输入把它清零，此时新值必然 <0.05s）」。`moon test ./gui/sys` **178 条、177 过、1 红**——那 1 条是**既有**的 `fsx_wbtest.mbt:109`（与本批无关，已在前批用纯净态复核）。**现已修复**，见上面「C 桩按需且 minimal」那条的回访。示例 `examples/native-sys` 新增「读空闲」键与状态行，退出读数行 `NATIVE-SYS-IDLE supported=1 seconds=2486.141 hits=0 note=…`；真机冒烟 `exit 0`、`NATIVE-SYS-GEO` 含 `idle=1786,368,110x32`（按钮已排版）。`moon check ./examples/native-sys` 零警告；全仓红点 **287/68** 持平。

### MoonBit 原生 GUI 栈 · 全局快捷键跨平台门面（W22：`core/hotkey.mbt`，三族门面统一的最后一族）

- **W22 的范围收敛**：「托盘 / 通知 / 热键三族门面统一」里，托盘（`core/tray.mbt`）与通知（`core/notify.mbt`的门面在 W20c/W21a 已各自落成，本批**不重构它们的既有 API**（改错误类型与探测命名是纯破坏性改动，调用方零收益）；真正缺的一面是**热键根本没有跨平台门面**——W20b 只落在 win 包（`register_global_shortcut` 等自由函数 + `parse_accelerator` 纯函数），Linux/macOS 调用方无从写同构代码。故 W22 = 补 `core/hotkey.mbt`，形态对齐另两族：**探测 `hotkey_supported()` + 结构化错误 `HotkeyError{Unsupported, Failed(String)}` + 泵钩子 `hotkey_poll()`**。
- **后端现状与降级口径**：Windows 真实现（`RegisterHotKey` + 线程队列，W20b 已验）；Linux 的 X11 `XGrabKey` 与 macOS 的 Carbon/AppKit 热键**未接**，一律 `Err(Unsupported)`——「没做」与「失败」分两档，调用方据此藏 UI，与 tray 的 SNI watcher 不在线、notify 的无后端同口径。
- **加速串进出，id 回查在门面**：注册收字符串（`"Ctrl+Alt+F9"` / `"CmdOrCtrl+Shift+M"`，`CmdOrCtrl` 按平台映射 Ctrl/Cmd——解析委托 win 的纯函数，不在 core 重写一份）；轮询 `hotkey_poll()` 命中给 `Hotkey{id, spec}`——Win32 的 `poll` 只回 id，**加速串回查表由门面自己持**（进程级、与 win 注册表同生命周期；表外 id 的 `spec` 给空串，表示不是经本门面注册的）。
- **平台探测走运行期 `@sys.sys_platform()`**（C 桩 `ffi_sys_platform` 回 1/2/3 → "windows"/"macos"/"linux"），与 AGENTS 规则 11「运行时探测 + 模式匹配、禁用 `#cfg`」一致；`is_mac` 判据同源（决定 `CmdOrCtrl` 映射）。
- **两个本工具链小坑（都已在代码里踩过）**：① `Array` **没有 `find`**——回查表线性扫用手写循环（`for h in arr { if … return Some(h) }`）；数组追加用 `arr.push(x)`，**不要写 `arr + [x]`**（解析器把 `+` 当 infix，报 `unexpected token infix 1`，错误信息离根因很远）。② `inspect(value, content="…")` 的 `content` 是**与 value 字符串化结果比较**的字符串——布尔值要传 `"true"`/`"false"`，传 "supported" 这类描述词必失败（本批与 taskbar 批各踩一次，记此一处）。
- **回证**：`gui/core/hotkey_wbtest.mbt` 2 条（未注册 id 回查给空串；「连上了才硬断言」——后端可用时空加速串必须走 `Err(Failed)` 而不是崩或静默成功，其余平台只打印 skip）；`moon test ./gui/core` **118/118**（原 116 + 新增 2）。`examples/native-app` 的热键区块从直调 `@win.*` 切到 `@core.hotkey_*`（注册 / 轮询两处，轮询命中直接拿 spec 回显），`--deny-warn` 零警告、冒烟 100 秒无 panic 无 CRITICAL。
- **本批未做且不假装完成**：Linux `XGrabKey` 与 macOS 热键后端（门面已就位，后端落地不改调用方）；tray/notify 两族既有 API 的统一重构（明确不做，理由见第一条）。

### MoonBit 原生 GUI 栈 · 任务栏进度（W20g：`win/taskbar.mbt`，§6.3 接缝项「任务栏进度 / dock 徽标」的 Windows 半边）

- **只写不读**：Win32 的 `ITaskbarList3` **没有 getter**，`TBPF_*` 进度状态不可反读（与 W21a 通知的 kind→`NIIF_*` 映射同款「映射不可反读，由代码评审兜底」）。所以对外只有写入口（`set_taskbar_progress` / `set_taskbar_state` / `clear_taskbar_progress`），探测（`taskbar_supported`）只报「COM 实例起没起来」，不回任何当前进度值。调用方要显示当前进度，自己持有那份数（与 `notify_title` 反读是刻意不同的两档：那个有 `NIF_INFO` 的 szInfoTitle 可反读，这个没有）。
- **COM 实例进程级单例，目标窗口按 hwnd 区分**：`ITaskbarList3` 接口本身与窗口无关（`SetProgressValue(hwnd, …)` 的 hwnd 才是目标），所以桩侧一个静态单例（`wm_taskbar` + `wm_taskbar_tried` 防重复探测），窗口句柄从窗口槽拿（`id` 越界或 `hwnd` 为空一律返回 0，与其它 `wm_*` 入口同口径）。初始化细节：`CoInitializeEx(COINIT_APARTMENTTHREADED)` 遇 `RPC_E_CHANGED_MODE` 退回 `CoInitialize` 再试一次；`S_FALSE`（本线程已初始化过）当成功；`HrInit` 失败要 `Release` 再报不可用；退出时不 `CoUninitialize`——COM 对象随进程收尾，而应用退出路径上还有别的 COM 用户（W14 文件对话框、W20f WIC）。
- **GUID 符号走 `uuid.lib`，不是 ole32**：C 模式用不了 `__uuidof`，`CLSID_TaskbarList` / `IID_ITaskbarList3` 两个常量要在链接期取符号——**ole32.lib 只导 COM 基础 GUID，这两个在 uuid.lib**（与 W20f 图标加载的 `CLSID_WICImagingFactory` 一族在 windowscodecs.lib 是同一条坑：GUID 常量落在哪个库要逐个确认）。故 `gui/scripts/prebuild.py` 的 Windows 分支 win 条目补 `uuid.lib`（探针手工编法同）。
- **进度值走 `Int64`**：下载字节数一类的进度值会超 32 位，MoonBit 侧 `value`/`total` 用 `Int64`、C 侧透传 `ULONGLONG`；`total <= 0` 时 `SetProgressValue` 语义无意义，文档口径是「不确定进度改用 `Indeterminate` 状态」。
- **回证**：纯 C 探针 `experiment/taskbar_probe/taskbar_backend_probe.c` 末行 **`TASKBAR-BACKEND-OK`**、**20 条断言全过**——`wm_init` 成功、`supported == 1` 且单例非空（这两条同时验证 uuid.lib 的 GUID 符号解析与 `CoCreateInstance` + `HrInit` 两步）、建真窗口（`wm_window_new` + `wm_show`，测完 `wm_close`）、五种 state 编号与 `value/total` 写路径全成功、`4GB-1 / 8GB` 大值成功、守卫路径（越界 `id=0` / `id=9999`、槽在但 `hwnd` 空的未建窗口、非法 `state=5` / `state=-1`）全给 0 不崩不写、收尾清回 `NoProgress` 后关窗、关窗后同 id 给 0（`hwnd` 已置空）。`gui/win/taskbar_wbtest.mbt` **4 条**：编号与 `TBPF_*` 对齐、编号往返、未知编号归 `NoProgress`（与 C 侧 default 分支一致）、「连上了才硬断言」——后端可用时不存在的窗口句柄必须给 `false` 而非静默成功（其余平台只打印 skip）。`moon test ./gui/win` **28/28**（原 24 + 新增 4）。
- **示例接线**：`examples/native-app` 加「任务栏进度（§6.3）」区块——七个写入口按钮（10% / 50% / 100% / 错误 / 暂停 / 不确定 / 清除）+ `live_counter` 每帧现读最近一次操作的结果标签（写失败会写进标签，不静默）；退出状态行 `NATIVE-APP-TASKBAR supported=… last=…`。`moon check ./examples/native-app --deny-warn` 零警告；冒烟进程存活（110 秒无 panic、无 CRITICAL——注意 native-app 的自杀点是 **10 分钟**，无人值守跑法一律带超时，见 `_人工测试清单.md` 头部）。
- **本批未做且不假装完成**：Linux 的任务栏进度另有 Unity LauncherEntry（DBus `com.canonical.Unity.LauncherEntry`）路径、macOS 是 dock 徽标（`NSDockTile`），都归后续跨平台门面批——GTK 分支与占位分支只给「supported 恒 0」的可编译失败桩；任务栏按钮的**真观感**（绿条 / 红条 / 黄条、 indeterminate 滚动）只能人看，归 `_人工测试清单.md` O 节。
- **探针侧两条 C4996 是既有现象**：`wm_im_*` 段的 `wcsncpy` / `wcsncat`——探针自己 `#include <windows.h>` 会让桩内的 `_CRT_SECURE_NO_WARNINGS` 失效（W21d 记过同一条），真构建（moon 的 native-stub）无此告警。

### 媒体回到独立模块：模块级可选恢复（2026-10-12，架构边界批）

- **引子**：`TODO.md` 里「旧链 `modules/gui-media` 下线」那句话被读成「不要 ffmpeg 了」。查证后确认 ffmpeg 一点没退场（新栈 `yue/media` 照旧 import `NoahLiu/ffmpeg-mbt/src`，是**解码后端**），但**带出一个真问题**：`yue/media` 住在主模块里，为让它 import 得动 ffmpeg-mbt，根 `moon.mod` 必须声明 `NoahLiu/ffmpeg-mbt@0.1.0`——于是**所有消费主模块的人都把 ffmpeg 拉进依赖闭包**，当初「媒体拆成独立模块＝可选依赖」的设计被抵消了。
- **机制（moon 的硬约束）**：`moon.pkg` 的 import 必须先由 `moon.mod` 声明模块依赖（否则报 `containing module is not imported`）。因此「媒体包住在主模块内」与「模块级可选」**互斥**：想要可选，媒体只能整个挪出主模块。**要把两层分开**——**包级可选**（`moon.pkg` 的 import 决定编译/链接边界）一直在，不 import `yue/media` 就不会链 `-lav*`；丢的是**依赖闭包/构建期**那一层，两者不是同一件事。
- **一处实测纠偏**：本仓是 moon workspace（`moon.work` 成员含 `modules/ffmpeg-mbt`），所以**仓内构建任何包都会跑 ffmpeg-mbt 的 prebuild**——实测 `moon build ./gui/core`、`moon build ./modules/yoga-mbt/src` 都打印 `ffmpeg(prebuild):` 那行，而这两者与媒体毫无关系。这条**不是**根 `moon.mod` 造成的，workspace 成员身份单独就能触发（`moon.work` 改不改都跑；`.mooncakes` 里没有 `NoahLiu/`，说明 `NoahLiu/*` 全从 workspace 本地成员解析）。**本批收益因此限定在「外部消费者」**：消费者不在这个 workspace 里，只按 `moon.mod` 解析依赖，摘掉那行后 ffmpeg-mbt 不再进他们的闭包。仓内/CI 仍会跑（CI 本就安装 ffmpeg 开发包，无新增负担）。
- **做法**：①`git mv yue/media modules/gui-media/media`——媒体包迁进既有独立模块 `NoahLiu/gui-media`（该模块本就是为可选媒体而拆的）；②媒体包要的 miniaudio 系统库链接参数（`-lpthread -ldl -lm -lstdc++ -latomic`）从主仓 `scripts/prebuild.py` 搬到**新模块自己的** `modules/gui-media/prebuild.py`，按包名 `NoahLiu/gui-media/media` 下发（非 Linux 优雅降级为空 link_configs，与 ffmpeg-mbt／主 prebuild 同口径）；③`modules/gui-media/moon.mod` 补 `NoahLiu/yoga-mbt@0.1.0`（媒体包经 `@yoga` 取节点）与 prebuild 选项；④根 `moon.mod` 摘掉 `NoahLiu/ffmpeg-mbt@0.1.0`。
- **示例必须跟着走（`b01d1dd` 的教训）**：`examples/native-web` 是主模块里**唯一** import `yue/media` 的包。它若留在主模块，主模块就得反向依赖媒体模块 → 重现「主 ↔ 媒体」的发布环（当年正是这个环让两边都发不了版，才把示例拆去 `modules/gui-examples`）。故整包迁到 `modules/gui-examples/native-web`（该模块本就是「需要媒体的独立示例模块」），其 `moon.pkg` 的 `NoahLiu/native-gui/yue/media` 改为 `NoahLiu/gui-media/media`（别名仍派生为 `@media`，**源码零改**），`modules/gui-examples/moon.mod` 补 `NoahLiu/yoga-mbt@0.1.0`。**不拆页**：`native-web` 头部写明它「webview 与媒体的累积验证示例，同族不另开页」，拆出去另开页违背该口径。
- **归口政策随之更新**：`TODO.md` 的「验证示例归口」把 webview + 媒体侧的落点从 `examples/native-web` 改为 `modules/gui-examples/native-web`（历史回证行的原文保留，那是当年的记录）。
- **回证**：①`moon tree` 根模块闭包**不再列 `NoahLiu/ffmpeg-mbt`**（改前明确列着；改后首行只剩 yoga-mbt / subproc / markdown 三支）；②全仓 `moon check` 红点 **287/68 未变**，错误仍全在旧链包（`events.mbt`/`splitter.mbt`/`types.mbt`/`props.mbt`/`video_view.mbt`…），证明搬迁没碰那批；③两个迁出的包强制重查（`touch` 源码后 `moon check`）全绿；④新模块 prebuild 直跑 `echo '{}' | python modules/gui-media/prebuild.py` → `{"link_configs": []}`（非 Linux 降级）；⑤主模块 `grep` 无任何包引用 `yue/media`、主 prebuild 无 `MEDIA_PACKAGE` 残留。**一条 Windows 侧收获（改前就是坏的）**：根模块在 Windows 上根本构建不了——`native-web` → `yue/media` 的 C 桩要 `libavformat/avformat.h`、`audio_stub.c` 又用了 `CLOCK_MONOTONIC`，实测 `moon build ./examples/native-web` 直接失败；改后根模块不再含任何「在 Windows 编不过的包」。
- **本批未做且不假装完成**：miniaudio 单头文件**仍是两份拷贝**（`modules/gui-media/src/miniaudio.h` 与 `modules/gui-media/media/miniaudio.h`，同 md5 `8d5bf2a0b46efa835bde4d0eac5a0cd8`）——归一仍卡在旧链 `modules/gui-media/src` 下线，前置是 `systemprobe` 媒体页迁移；媒体包在 Windows/macOS 仍不可用（POSIX 时钟 + ffmpeg 后端未接）；媒体在 Linux 的真机行为（是否真出声、seek 手感）本机无法回证，归人工清单。
- **本批未做且不假装完成**：macOS（要走 `CGEventSourceSecondsSinceLastEventType` / IOKit HID，留 Unsupported）、Wayland 原生会话的 idle（要走 `org.freedesktop.ScreenSaver` 或 `ext-idle-notify-v1`，本批只给「不支持」）、「屏幕常亮」的置位侧（`XScreenSaverSuspend` / `SetThreadExecutionState`——本批只做**读**空闲，不拦休眠）、空闲阈值变化的通知机制、真机观感（归 `_人工测试清单.md`）。

### 媒体音频后端跨平台化：单调时钟三平台（2026-10-12）

- **引子**：上一批把媒体包挪进独立模块时，把「媒体在 Windows 上构建不了」的根因概括成「POSIX 时钟 + ffmpeg 未接」。本批把其中**属于我们自己的那一半**做掉——`audio_stub.c` 是媒体的音频后端（miniaudio 设备层 + PCM 队列），**零 ffmpeg 依赖**，它能不能编、编出来能不能跑，可以单独钉死，不必等 ffmpeg 那条线。
- **现象（MSVC 实测）**：`audio_stub.c` 报 `error C2065: "CLOCK_MONOTONIC": 未声明的标识符`，并附一条 `warning C4013: "clock_gettime" 未定义`——`CLOCK_MONOTONIC` 是 POSIX 专有常量，MSVC 的 `<time.h>` 不提供（`clock_gettime` 也只在 UCRT 的部分版本里有）。
- **修复（单一 stub.c 多分支 + 平台宏，先例 `win/stub.c`；AGENTS 规则 11）**：`mbt_now_ms` 按平台三分支——`_WIN32` 走 `QueryPerformanceCounter` / `QueryPerformanceFrequency`（QPC 是 Windows 的单调高精度计数器；**不用 `GetTickCount`**：粒度粗 ~15.6ms，且会被系统时间调整带偏）；`__APPLE__` 走 `mach_absolute_time` + `mach_timebase_info`（不用 `clock_gettime`：`CLOCK_MONOTONIC` 在 macOS 要 10.12+，mach 更保守且同为单调计数）；其余 POSIX 保持 `clock_gettime(CLOCK_MONOTONIC)` **原样不变**。三支都返回「自任意固定起点的毫秒数」，只用于差分（`elapsed = now - wall0`），绝对值无意义——所以起点因平台而异不影响播放时钟。
- **两处溢出防线**：①Windows 分支拆成 `(ticks / freq) * 1000 + ((ticks % freq) * 1000) / freq`，避免 `ticks * 1000` 在 64 位溢出（QPC 计数自开机起累计，10MHz 下一年 ≈ 3.15e14，乘 1000 后仍有量级余量，但拆开更稳）；②macOS 分支用 `__uint128_t` 过渡 `t * numer / denom`，防 Apple Silicon 上 numer/denom 非 1:1 时中间乘积溢出。
- **两份拷贝同步改**：`media/audio_stub.c` 与 `src/audio_stub.c` 此前逐字节相同（md5 `2b807752…`）。改时一度只在 `src/` 多写一句注释，结果两份**不再**逐字节相同——当场回退那行，两份恢复一致（改后 md5 均为 `856a4c98e3879e77aa5108f7bb4dcfd8`）。理由：旧链下线时的「归一」要能直接取一份，两份静默漂移会让这件事没法机械判断。
- **回证（纯 C 探针 `experiment/media_probe/audio_backend_probe.c`，直接 `#include` 平台后端）**：末行 **`AUDIO-BACKEND-OK`**、**48 条断言全过**、0 失败——①**时钟**：连续/五连读单调非减、为正、`Sleep(60)` 后推进 61ms（落在 [40,400] 区间）；②**设备开参数**：`channels ∈ [1,8]` 且 `rate > 0` 才收，`0`/`9`/`-1`/`rate=0`/负 rate 一律回 NULL；③**队列与音量语义**（与设备是否存在无关）：push 追加、`queued_bytes` 累计 400→600、非法 push 不改队列、`clear` 清零且二次幂等、`played_bytes` 非负、volume 钳到 [0,1]（0.5/1/0.25 读回一致、-1→0、2→1）；④**设备生命周期两分支都跑**（不假设环境）：本机有真设备 → `start=0`/`is_started=1`/二次 start=-1/`played_bytes` 真的推进（实测 35280 字节）/pause=0/二次 pause=-1；无设备（CI/headless）→ start=-1 且状态恒 0；⑤**NULL 参数防御全档**（该给失败档给失败档、不该崩的不崩）。探针另**直读 `QueryPerformanceFrequency` 报出 10000000 Hz**，证明走的是 QPC 高精度分支而非粗粒度回退。编法见探针头注释（`-I <moon>/include` 供 `moonbit.h`；补 `ole32.lib uuid.lib` 供 miniaudio 的 WASAPI 后端；`#pragma warning(disable:4244)` 只压 miniaudio 单头内部那一处赋值窄化，不压自家告警——探针本体 /W4 零告警）。
- **一手实测补记**：`miniaudio.h`（4.2MB 单头）**在 MSVC 下能编**——除其自身第 80532 行一处 `ma_uint64 → ma_uint32`（C4244）外无告警。这说明音频后端在 Windows 上是有落地路径的，缺的只是时钟这一处。
- **一条必须说清的边界**：改后 `audio_stub.c` 在 Windows 上**编得过、跑得起来**（探针即为证），但 `moon test ./modules/gui-media/media` **仍跑不起来**——测试可执行文件会把 `ffmpeg_stub.c` 一并链进来，而它要 `libavformat/avformat.h`（`ffmpeg-mbt` 那条线在非 Linux 上未接）。所以本批的 Windows 收益是**音频后端可编译可运行**，不是「媒体包能在 Windows 上用了」。Linux 分支代码逐字节未动，行为不变（本机跑不了 Linux，此为代码级判断而非实测）。
- **本批未做且不假装完成**：`ffmpeg-mbt` 的 Windows/macOS 后端（要接系统解码器或自带 DLL，是另一条独立的线）；媒体包在非 Linux 上因此仍不能整体构建与整体测试；macOS 分支（`mach_absolute_time`）无法在本机回证，只做了代码级正确性论证；真机听得见的声音与 seek 手感仍归 `_人工测试清单.md`。
- **顺带一条实测结论（免得后人「修」错地方）**：媒体 prebuild 的「非 Linux → 空 link_configs」是**对的**，不要往里加 `ole32.lib`/`uuid.lib`，也不要加 macOS 的 framework。①**Windows**：把 `audio_stub.c`（`#include` 了 miniaudio）拿去做实验——**不加任何额外库**直接链接即可通过（实测 `/Fe:probe_nolibs.exe` 零库链接成功且运行照样过 48 条断言），因为 miniaudio 默认走**运行期 `LoadLibrary`**（`MA_NO_RUNTIME_LINKING` 未定义），不产生链接期符号（此前那批探针带 `ole32.lib uuid.lib` 能过，是它们**不必要**而非必要）。②**macOS**：miniaudio 自述「the macOS build should compile cleanly without the need to download any dependencies nor link to any libraries or frameworks」——默认同为运行期框架链接（只有显式 `-DMA_NO_RUNTIME_LINKING` 才要求 `-framework CoreFoundation -framework CoreAudio -framework AudioToolbox`，且该宏的自动置位出现在 **DOS** 分支、不在 Apple 分支），命令行只需 `-lpthread -lm`，而这两者在 macOS 上由 libSystem 默认带上。所以三平台里**只有 Linux 需要显式系统库**（`-lpthread -ldl -lm -lstdc++ -latomic`）。

### 示例迁移首批：showcase 骨架 + 基础/反馈两页（G7，2026-10-12）

- **本批范围**：`examples/showcase` 从旧链路（`@yue` 根包 + `@declarative` + `@components`）改到新栈（`core` 的 `Node` 层 + `ui` + `theme`），先落**骨架 + 基础组件页 + 反馈组件页**。旧链路的 15 页里其余 13 页（图标库/表单/事件与布局/导航/数据展示/图表/代码与文档/Store 对照/系统集成/窗口/浏览器/画布与富文本）**已从工作区删除**（`git rm`，源码在 `91204ca` 之前的历史里可随时取回），按「先基础、后重控件」逐批迁入——浏览器页含 WebKit 重控件、图标墙页要建 803 个图标控件，都不适合先动。
- **四处机械差（旧链路 → 本栈，写在这里免得每页重踩）**：
  ① **`style=[...]` 不存在**。新栈组件只接显式参数（`padding`/`row_gap`/`width`…），间距是**布局容器的属性**而不是控件自己的；旧代码里成片的 `style=[("marginTop", 8.0)]` 一律删，改由父容器 `row_gap` 表达。
  ② **显隐与惰性挂载换层**：`View::set_visible` → `Widget::set_visible`（内部落 `display:none` 的 yoga 安全路径），`Node::mount_into(View)` → `Node::mount_into(Widget)`；`Node.mount` 的闭包签名也从「返回 View」变成「返回 Widget」，语义不变。
  ③ **「撑满剩余高度」不能写在控件上**：旧链路写 `style=[("flexgrow", 1.0)]`；新栈滚动容器（`scroll_v`）**不接** `grow` 参数，要在 `handle` 回调里对**视口控件**置 `node.set_flex_grow(1.0)`（`handle` 拿到的就是视口本身）。
  ④ **导航页要自己写**：旧链路 `nav_page` 本就是示例本地件（`examples/showcase/ui/section.mbt`），本栈同样没有对应物，照原机理重写成 `shared/section.mbt` 的 `nav_page`——`set_visible` 切显隐、**首次选中才 `mount_into`**（15 页全量挂载的启动开销不可行，这条机制必须保留）。
- **坑一：本地共享层不能叫 `ui/`**。旧链路里组件库叫 `@components`、示例自己的共享层叫 `@ui`，所以不冲；新栈组件库**就是** `ui`，两个包都派生成 `@ui` 直接歧义。改法：目录 `examples/showcase/ui/` → `examples/showcase/shared/`（包名派生成 `@shared`），顺带把 `@ui.App`/`@ui.page`/`@ui.section` 的调用点一并改准。**不要靠 `moon.pkg` 里给组件库另起别名绕过**——那样示例读起来会长期名实不符。
- **坑二：`popover_t` 的宽高是命名参数**。旧链路 `popover_t(trigger, content, 180.0, 60.0)` 位置传参；新栈签名是 `popover_t(trigger, content, width?, height?, handle?)`，位置传两个 `Double` 直接编译报 **4080**（`which requires 2 positional arguments, but is given 4`）。凡新栈签名多出可选参数，都要先确认它是命名参数——照旧调用点抄最容易踩这一类。
- **坑三：旧链路的 `@yue.VERSION` 不可用**。它在**主包**（旧链路根包，正是全仓 287 个红点的所在地），示例 import 它会把整个红包拖进依赖闭包。示例本地留一份 `SHOWCASE_VERSION` 常量，并注明权威值仍是 `moon.mod` + `yue/version.mbt`（后者的构建期一致性校验由 `scripts/prebuild.py` 负责）。
- **两条组件层收并（迁移时按新形状写，别找旧函数）**：`alert_closeable` 已并入 `alert(closable=true, on_close=)`；`result` 只吃 `(标题, 副标题, 语义类型)`，**不再**吃操作区数组——操作区由调用方在旁边摆（「组件只给形状、内容是调用方的」是本栈组件层的通用取向）。
- **一条顺带的接口澄清**：`toast_layer` 在本栈**只返回推送函数**，不再返回「层节点 + 推送函数」——提示带子开在**浮层图层**上（第一条推送才开、撤完就收），所以页面里不必再常驻一棵空树，提示也永远压在对话框与其它浮层之上。迁移时旧代码里那个 `@components.toast_layer()` 解出来的 `toast_node` 要**整条删掉**，别往树里挂。
- **验证**：`moon check ./examples/showcase ./examples/showcase/shared ./examples/showcase/pages --deny-warn` **零警告**；全仓 `moon check` 红点 **287/68 未变**（删掉的 14 个旧页本就在红点里）；真机冒烟 `exit 0`，控制台 `SHOWCASE-READY title=组件库演示板 pages=2 follow=1` 与 `SHOWCASE-DONE page=基础组件`，窗口标题正确、响应正常、`CloseMainWindow` 干净退出。退出时那条 `libpng warning: iCCP: cHRM chunk does not match sRGB` 是**既有**的（`examples/native-app` 同样打），与本批无关。
- **本批未做且不假装完成**：其余 13 页；菜单栏 / 托盘 / 单实例的接线（两个 `dialog_t` 已挂窗口根并可由反馈页打开，菜单栏、托盘、单实例按「各自随系统集成页/窗口页进来」处理，`examples/native-app` 已有对照演示）；真机观感（侧栏悬停、切段后滚动位置保留、跟随/手动主题切换的手感）归 `_人工测试清单.md`。

### 声明式层与自绘组件

- mouse 回调内禁止 `set_background_color`:运行期 CSS 改写会吞掉紧随的首次 press(「点两次才生效」)。交互态(hover / 按下)一律 on_draw 表达;set_background_color 只用于挂载期与主题订阅回调。
- flex 容器的挂载序同时是排列序与 z 序:夹层件(把手 / 分隔线)必须严格按排列位置挂入,且视觉常显——用户靠「看」找它,不靠 hover。
- **markdown_view 样式区间计量与 mdast 实测语义(MD2,2026-10)**:旧自写解析器(md_parse_inline / md_parse_blocks)已删,`yue/markdown.mbt` 改吃 mizchi/markdown(mdast)。①**富文本区间端点必须按渲染文本逐段累计 UTF-16 code unit(`md_utf16_len`),不能按码点数累计,也不能直接用 mdast Span 定位**——MoonBit `for ch in str` 按码点迭代而 `str.length()` 是 UTF-16 code unit 数(实测 "a👍b" 迭代 3 次、length 4),AttributedText 区间是 UTF-16 语义,emoji(非 BMP,1 码点 = 2 code unit)之后的样式按码点累计会整体前移;Span 定位则根本不可行:渲染文本 ≠ 源文(标记剥离、软换行空格化、链接地址丢弃),区间只能对渲染后文本计量。展平用显式栈携带样式集递归展平行内嵌套树(`md_flatten_inline`),相邻同样式段合并减区间数;渲染与测试共用同一计量 `md_span_ranges`(wbtest 断言 emoji 后粗体区间为 [4,6) 而非码点错位的 [3,5))。②mizchi/markdown 0.8.3 解析语义三则:`FencedCode.code` 尾带 `\n`(切行须丢末尾空行);`parse_code_block_info` 只认 `lang:file {meta}` 格式,**不认空格分隔 info 串**("rust title=x" 整串进 lang),语言须自取首词;段落间空白行会产出 `BlankLines` 块,AST 遍历不能按「块下标=文档序直觉」取块(测试曾因此踩 children[2] 实为空行块)。渲染面决策:HtmlBlock / 脚注默认不渲染,表格行式降级(单元格两空格分隔 + 表头加粗),任务列表吃 `ListItem.checked`(☑/☐),Blockquote 子块整体递归进竖条,有序列表带 `start`。验证:`moon check` 零警告 + `moon test` 595 全绿(19 条新 wbtest 覆盖换算 / 展平 / 区间 / info / 切行,及 CommonMark 偏差五项前后对比:setext 标题 / ~~~ 围栏 / info 串 / 缩进代码块 / 嵌套列表)。
- **markdown_view GFM 渲染面补齐(MD3,2026-10)**:①**删除线不上原生属性,MoonBit 层自绘**——上游 AttributedText 仅有 SetFontFor / SetColorFor(vendor libyue `attributed_text.h`,GTK Pango 底层有删除线但封装未暴露,shim 同样无入口),走 fork 补丁需重建三平台预构建库不在本批边界;`md_rich_label` 由 Label 改为挂载时自绘(themed_container + draw_attributed_text),**逐段用同字体独立测宽(get_bounds_for)得区间像素坐标表**,删除线段按坐标补画横线(行高中线,前景色),**链接命中与悬浮光标同用此坐标表**——跨层契约即「富文本行的区间语义是 UTF-16 端点 + 像素 x 区间并存:样式区间给 AttributedText,命中区间给鼠标事件」;单行(wrap=false)场景逐段测宽累计与整体拼排在亚像素级一致,点击命中天然容忍小偏差(多行 wrap 下该坐标表失效,本组件富文本行不换行故不涉及,若未来引入 wrap 须改为逐行布局)。②**链接点击**:MDSpan 携 url(Link 直接取、RefLink/RefImage 查 ParseResult.definitions 按 label 精确匹配,查不到降级为无地址的链接样式),on_mouse_down 的 view_x 落在 [xs, xs+ws) 即 open_url(复用系统能力,Linux 走 xdg-open);on_mouse_move 换手型光标,add_tooltip_for_rect 按 url 区间挂地址提示(挂载时一次性注册,主题切换不改几何无需重挂)。③**脚注两遍法**:预扫描正文(嵌套列表 / 引用 / 表格单元格 / 定义列表全递归)按出现顺序编号,FootnoteDefinition 自身跳过(定义内引用不进编号,防文末内容污染顺序);FootnoteReference 展平为上标 "[n]"(区间小四号字体,AttributedText 行内混排字号 Pango / CoreText / DirectWrite 均支持),markdown_view 主内容后分隔线 + 只渲染被引用的定义(未被引用不渲染,符合 GFM 语义)。④**图片**:块级「段落恰为单图」才显示(行内混排图降级 alt——富文本行不支持行内嵌图),Image::new_from_file 吃本地路径 / file:// 前缀(剥前缀),is_empty 即降级 alt;无网络图加载能力,网络 url 一律 alt 降级;等比缩放宽度上限 560(与 markdown_view 默认宽一致,外层更窄时溢出,同现状单行文本溢出行为)。⑤**表格等分网格**:格子宽用百分比字符串通道("33.33%",实测可用,showcase events 页 width "50%" 先例),列对齐经格子容器 alignItems(center 有先例;flex-end 未实测,值不被识别时 yoga 忽略退左对齐,无崩溃面),单元格富文本复用 md_rich_label;不与 table_t 混用——table_t 是 Store 驱动的数据面板(列宽固定 / 纯文本单元格),文档流表格列数不定、单元格富文本,自绘网格更贴。⑥任务列表 checkbox_t 空 title(固有宽 30 固定宽覆盖)+ 内容并排,勾选态即 ListItem.checked,点击切换纯视觉(文档源不变)。⑦showcase 演示文本与复制串同源:`demo_md_lines()` 单一来源,渲染吃 join("\n"),复制串逐行派生 MoonBit 字面量(反斜杠 / 双引号转义),复制所得与页面所见一致。验证:`moon check` 零警告 + `moon test` 600 全绿(markdown_wbtest 24 条,新增删除线标志 / 链接携址 / 引用式链接取定义 / 无定义退化字面文本 / 脚注编号与上标 / 块级忽略定义 / 图片路径换算 / 表格单元格与列对齐映射断言);真机视觉项(删除线横线位置 / 链接点击与悬浮 / 表格对齐与网格 / 图片显示 / 任务列表勾选 / 脚注上标与文末)由用户按 showcase「代码与文档」页 Markdown 段验证。
- **订阅必须可退订,否则重建式组件的死订阅无界累积(CORE2)**:Store/Signal 订阅闭包由信号内核持有、主题订阅由 theme_box.subs 持有,都没有退订入口——任何「重建行 / 重挂子树」的组件每次重建都漏下一整代死订阅:transfer 移动 N 次漏 N 套;table_t 每次 rows Store set 漏「行容器 + 每单元格 themed_container + bind_fg」一整套(千行表格一次刷新即上千条);snackbar 每次 push 漏两条;bind_node 每次重挂漏旧子树里 bind_label 的 Store 订阅。死订阅内存占用不大,但每次 set / theme_apply 都会对已销毁视图空跑(set_color / schedule_paint 打到已移除控件),且闭包捕获的视图子树永不回收。修复分内核与用法两侧:①订阅带 id——`Signal::subscribe` 返回句柄、`Signal::remove(id)`;Store 侧 `subscribe_id(f)` 取句柄、`remove(句柄)`(`Store::subscribe` 保持 Unit 不变:MoonBit 非 Unit 值不能隐式丢弃,改它的返回类型要动全仓上百个调用点)。②主题订阅同款:`on_theme_change` 返回句柄、`off_theme_change(句柄)`。③深层 / 成片订阅用**订阅回收袋** `sub_bag_begin() / sub_bag_end() / sub_bag_discard(闭包表)`:重建前开袋,重建期间注册的全部订阅(Store + 主题,含任意深度子树里的 themed_container / bind_fg / bind_label)把退订闭包压进袋,旧代整袋退订后再重建——transfer 的 render_all、table_t 的 rebuild、bind_node 的 rebuild、snackbar 的撤下定时器都走这条;袋是栈(嵌套安全),与 signals.mbt 既有 sig_collector 的「收集期全局上下文」同模式。验证:moon check 零警告 + moon test 657 全绿(新增 store 退订与幂等、Signal 句柄退订、回收袋三代与嵌套、主题 off 与回收袋、空栈收袋、组件重建走主题回收袋、carousel_stop 共 8 条)。
- **挂载即常驻的定时器要有回收通道,两条定时器 API 契约不同(CORE2)**:组件挂载时起的定时器没有「视图已移除」通知,不回收就继续对已销毁子树空转。libyue 侧两种定时器契约不同:`set_timeout` 返回 id、可 `clear_timeout(id)` 立即取消(自排链式轮播走这条);`set_timer` 是周期回调、**无取消 id,只能让回调返回 false 停**(shim yue_mbt.cpp 的 SetTimer 不回传 id)。因此 carousel_t 新增 `rotation? : CarouselHandle` 句柄与 `carousel_stop(handle)`(停自动轮播并取消已排下的那次超时,手动箭头 / 指示点不受影响);video_view_t 的帧推进定时器走文档契约——`vid_stop(handle)` 置 running=false,下一拍回调返 false 自停,**卸载前必须调用**(至多多转一拍)。两处的「卸载前必须 stop」都写进使用文档(components-ui / system-capabilities,中英同步)。

### 自绘画布与图表渲染

- 8 位 hex 颜色的 alpha 在**前**(`#AARRGGBB`,libyue `ParseHexColor` 源码级约定,与 CSS 的 `#RRGGBBAA` 相反;`yue/color.mbt` 的 `parse_hex` 亦然)。拼在尾部不会报错也不会改透明度——两位 hex 落到**蓝分量**,表现为颜色漂移。实例一:悬浮滚动条渐隐把 alpha 串从 "d9" 改 "73",实际蓝分量 0xd9→0x73、红绿不动,渐隐中的 thumb 变黄。实例二:图表面积填充 `color + "26"`,主题色 `#009688` 拼成 `#00968826` 按 AARRGGBB 解析 = alpha 0x00(全透明)+ RGB(150,136,38)——**面积填充从未显示过**。统一走 `with_alpha(hex, aa)`(拼头部)修复;凡 set_fill_color/set_stroke_color 需要透明度一律用它,禁手拼后缀。
- 离屏 `Canvas::new + get_painter` 在未 `initialize()` 时可做全部几何绘制(fill / stroke / arc / clip 均正常,无 DISPLAY 的 CI 也能跑绘制基准);但文本路径(`draw_text` / `AttributedText::get_bounds_for`)直接段错误——GTK 文本栈要 initialize 起过才在。测试基准因此分两级:无显示跑「纯函数管线 + 几何调用镜像」,有 DISPLAY 才 `initialize` 后跑真实全帧(含文本标注),两级数值都记入 `charts_wbtest.mbt` 的输出。
- painter 默认描边色下 `stroke()` 是空操作(不画任何东西):基准里忘记 `set_stroke_color` 会让描边成本显示为 ~0,虚假通过。所有描边基准必须显式设色后再测。
- 软件光栅化(GTK/X11 无 GPU 路径)下路径描边每段约 1.8µs,近垂直段(斜率 >30)约 13µs/段;`fill_rect` 每约 1µs(轴对齐快路径),`draw_text` 每次约 0.11ms,`line_to` 本身约 12ns(纯建路径)。折线图 1000 点 × 4 序列若全走路径描边,单帧 45~60ms,远超 5ms 验收线。
- 修复(图表族统一策略,见 `yue/charts.mbt`):密集态(点数 > 绘制区像素列数)按列抽稀(min/max 保极值)后改矩形路径——面积模式每列一个填到锚线的矩形(填充顶边即折线),折线模式每列画 min..max 竖条;稀疏态(点数 <= 列数)才走真实折线 + 多边形面积。绘制成本与窗口大小脱钩,只随绘制区宽度增长。
- libyue 的 Arc 无法表达逆时针弧:GTK 侧 `PainterGtk::Arc` 就是 `cairo_arc`,而 cairo 会把 `ea < sa` 规范化成「加 2π 的顺时针长弧」;Win 侧公开 API 也写死顺时针(底层 ArcPixel 有 anticlockwise 形参但没有暴露)。shim 里「ccw 用负角跨度表达」的换算因此两层都不生效——圆环内弧硬用 ccw 会把内孔包进长弧,填充出实心饼(真机截图实测:环形图/仪表盘中心不镂空,"总计"/百分比压在实心面上)。修复:内弧回程改折线近似(整圆 32 段,弦误差 <0.4px,三平台一致);纯描边场景(图标弧)直接交换起止角等价。fork 层若要把 `PainterGtk::Arc` 改成 `cairo_arc_negative` 才是根治,需走 vendor-* 出包,暂未做。
- 图表验收基准(release,Ubuntu 24.04 XFCE X11,离屏 Canvas + initialize,真实全帧含文本):折线 1000 点 × 4 序列(陡锯齿对抗数据)3.08ms / 平滑数据 1.81ms;柱状 200 类目 0.38ms;环形 50 扇区 0.70ms;仪表盘 0.15ms;散点 10000 点 3.03ms。纯函数管线(值域/刻度/抽稀/坐标换算)折线 0.028ms。推点长跑:4800 次(10 分钟 @2Hz × 4 序列)共 2.89ms,窗口长度恒定 1000 不增长——活数据 4 × 1000 × 8B = 32KB 有界,内存增量来自 GC 回收的换窗垃圾,连续推点不积累。
- 折线面积锚点:0 在值域内取零线,全正值取绘制区底,全负值取绘制区顶(跨零时一列上下两段矩形)。
- `Painter::DrawText`(画布 draw_text)默认 `wrap=true`:定高行 / 窄盒里的长文本被平台排版换行,溢出行界。实测三类症状:进程表命令行(动辄上百字符)换行穿透行高压到下一行;图表 y 轴大数值直出("21414.7")竖排成多行互相叠压;折线多序列末端值标签接近时叠字。修复:shim 增 `yue_mbt_painter_draw_text_ex` 透出 TextAttributes 的 wrap/ellipsis(纯 ABI 翻译),MoonBit 侧 draw_text 加可选参数,表格单元格统一 `wrap=false + ellipsis=true` 单行省略(截断由平台排版完成,免逐格测宽);`fmt_axis` 在 |v| ≥ 1e4 起按 k/M/G 换挡(一位小数去尾零),标签保持 5 字符内不触发换行;末端标签改为收集后按 y 排位(最小间距 14px,越界整体压回)再绘制。
- 图表 / 虚拟表格自适应(fill 开关):不设固定宽度,靠列容器默认 stretch 横向铺满,随窗口伸缩。表格 fill 模式下每次绘制按实际宽度重排列几何:固定列保留拖宽结果、弹性列分摊剩余宽度(拖宽两列此消彼长守恒,与弹性列重排不冲突);行内自适应固定坐标(w − 偏移)的自绘行容器本就跟随。
- 表格表头自绘装饰必须画在表头容器(head)的 `on_draw`,不能画在单元格容器(head_cell)上:GTK 上 libyue Painter 的路径填充(`begin_path` + `fill`)在单个表头单元格(约一列宽 × 32px、内有 Label 子 widget)里完全不渲染——代码跑了、无报错、就是不出像素;同一段代码画在整行表头容器或表格大画布容器上正常。`fill_rect` 与路径描边(`stroke`)在所有尺寸容器都正常,症状极易误判成「坐标算错」。复现方式:同窗口并排画 fill_rect / 路径填充 / 路径描边三块即可定位。修复:table_t / table_v_t 的排序箭头、列边界线、悬停高亮统一收敛到 head 容器单一 `on_draw`,head_cell 只留交互。根因待 fork 层深究(疑似与小容器 GTK draw 区域 / 裁剪有关)。
- 表头列边界的鼠标事件落点:列边界竖线右侧像素归属下一单元格,对准可见边界按下会落进下一格左缘(触发排序而非拖动)。修复:拖动热区认双向边界(右缘 4px → 边界 (j, j+1),左缘 4px → 边界 (j-1, j)),末列右缘不设把手。
- Painter 无 dash API:markLine 等虚线一律自绘段模拟(ci_dash_line,6px 实 4px 空),三平台观感一致,不依赖平台 dash 支持。
- 图表 hover 浮层自绘而不复用基础件(选型依据):Popover 是点击触发、相对视图定位、独立裸窗口,hover 跟随会闪;原生 tooltip 是单行系统样式,不满足多行 + 主题化。故浮层画在图表容器自身 on_draw 内(图表之后绘制即在最上层,无 z-order 问题),位置经 ci_tooltip_pos 钳制在画布内不出界;mouse 可达性经 bar_chart_t/donut_chart_t 同款路径验证。
- 地图与飞线的投影方案(geo_map_t,选型与实现口径):**等距圆柱投影(equirectangular)**——lon [-180,180] 线性映射到绘制区横向、lat [-90,90] 线性映射到纵向(上北下南),输入先钳制经纬度再算,输出不越过绘制区(geo_project)。没有选墨卡托 / Lambert:墨卡托的 85° 截断与纬度间距放大对中国纬度带不利、纬度外推会发散,Lambert 的双标准纬线又要为每个数据集挑参数,等距圆柱的全部几何都能被单测定点断言(北美 / 中国 / 全球三种典型数据集均可验证)。投影矩形 = 区域环与飞线端点的**合并包围盒**按自身长宽比居中缩进(geo_fit_rect,保形不变形),不用固定矩形:局部地图才不缩成一角,飞线两端落区域外也完整可见;退化轴(同经 / 同纬)给 1° 最小跨度,w/h 非正退化为 0 尺寸。质心用 shoelace 有向面积(|A| 为轴)加面积加权环内点平均(geo_ring_centroid / geo_region_centroid):环可能是 MultiPolygon 拼接的多环,取有向面积绝对值最大的环为主环,凹形(如山东半岛 / 辽宁)比 bbox 中心或首点都稳;angle-free 实现避免椭圆积分近似在细长环上跑偏。区域填充色用主题主色按**区域名 FNV-1a 哈希**做 ±0.06 明度微调(geo_name_hash,哈希取模 13 / 12 归一),同名同色、换主题或缩放不变——不用表格序号:序号随数据顺序变,深浅对比会闪。飞线弧线在**投影后的画布坐标**上算控制点(geo_flight_ctrl 取起终中点 + 方向法向偏移 bend × 起终距),弧的视觉凸量才均匀;直接在经纬度上算控制点,高纬弧会因经度权重而畸变(1° 经度在高纬比低纬短)。贝塞尔采样 geo_flight_points 默认 48 段,首点 from 末点 to(含端点保证箭头方向正确)。地图数据不内置:geojson_parse 复用 vscode_history 的手写 JSON 解析器(vsc_json,纯 MoonBit),只收 FeatureCollection / Feature / 裸 Polygon / MultiPolygon,几何不合规(缺 coordinates、环点数 < 3、坐标含非数值)给 GeoError::BadGeometry;geometry 为 null 的 Feature 合法跳过。

### 布局几何(Yoga flexbox)

- 布局断言 16/16 通过(±1px);叠加规律:内容区 = 容器 − 2×padding;gap 不与 margin 叠加;百分比基准为父内容区宽。
- 复合控件(Tab / Scroll / Group)在 yoga 树里是无 measure 的叶节点,外框尺寸必须显式给出(如 `flex:1`),否则塌缩(Tab 构造时固化最小尺寸,页区域归零)。
- tabs_t 曾把 outer 宽度写死 360px、内容页无 flex:放进页里的 Scroll / Table 因此塌缩归零(实测 sysmonitor 概览页整个空白,只有页签头)。修复:outer 去掉固定宽改 `flex:1`(列容器默认 stretch 拿宽度,父有确定高度时填充),内容页同样 `flex:1`。父容器无确定高度时 flex 不增长,内嵌场景(showcase 的分段演示)布局不变。
- 运行时改样式(set_style)后调 `update_layout`,GTK 上对「根容器」调用子树完全不刷新(yoga 状态已改,bounds 纹丝不动),对单个节点调用也只重排「该节点及其父下的兄弟」——跨子树(如表格 body 的行)不受影响。探针同构四组对照实证(挂载后立即 / 500ms 后、update 根 / 叶子、width / flexbasis):唯一可靠形态是「被改样式的容器逐个调用」。table_t 拖列宽曾因对根调用而「手柄在动(bounds 走的 col_w)、列宽纹丝不动(样式没生效)」;splitter 恰好只有一个包装容器要改,对 outer 调用看似通用,实则同坑未爆。修复:apply_col_widths 对表头两个单元格 + 每行两个单元格逐个调用。
- GUI 自动化:键盘驱动(Tab 聚焦 + Space 激活)首选;`xdotool key --window` 走 XSendEvent 会被 GTK 丢弃,必须 XTEST(不带 --window);坐标点击受 WM 装饰偏移影响不可靠。
- **Linux/macOS tabs_t 切页塌陷已根治(native ≥ v0.15.6-mbt.19)**:病灶在 yoga 本体与 display:none 的交互,三层机制——①`flex` 简写(flex:1)在这版 yoga 解析为 grow=1 且派生 basis=0(`resolveFlexBasisPtr`);②切页隐藏走 display:none,`YGZeroOutLayoutRecursively` 把布局整体 `= {}` 清零,`computedFlexBasis` 一并打回 undefined;③重显后的 flex basis 计算(Yoga.cpp `YGNodeComputeFlexBasisForChild`)只要解析值有定义且 `computedFlexBasis` 为 undefined 就把派生 basis=0 写回,**之后每轮都命中「已计算」分支永不再走内容测量**——auto 高父链(scroll 内容列)无剩余空间可分,页容器永久 0 高(探针实测新显页 1px、outer 65→36 塌成 head 高)。从未隐藏的页不塌是「内容测量曾进过 basis 缓存」的巧合而非稳定保证。修复(fork 补丁 lb091188/yue 93078300,display 清零时置 `zeroedByDisplayNone` 标记、basis 计算对标记节点该轮改走内容测量,显式 flexBasis 样式行为不变)只治简写路径;**显式 flexbasis 0 的塌陷是固有语义**(每轮按解析值重写 0,内容测量分支永不执行),tabs_t 因此平台分化——Windows 保显式 basis 0(治其显隐中间态压缩),Linux/macOS 回纯 flex 简写。回归工具:`moon run examples/probe-collapse`(四轮切换采样,简写页应恒稳 22 高)。坑位:CI 的 clang 命令行带 `-Wshadow -Werror`(本机 `-Wall -Wextra` 组合不含 shadow 补丁代码本机全绿 CI 全红,首查 shadow);fork 补丁落在 `patches/`(prebuilt 工作流 Bootstrap 后 `git -C third_party/yoga apply`),yoga 是子模块不进 fork 提交。
- **mbt.19 补丁的边界:showcase 复塌与 outer 简写禁用(次日真机复验闭环)**:mbt.19 上线后真机复验 showcase 仍塌——补丁只治「被 display:none 清零后重显的节点自身」,治不了「从未隐藏、被兄弟显隐 dirty 连坐重算的 flex 简写祖先」:tabs_t 的 outer 自身也写 flex:1 简写,切页把它 dirty 后,auto 高父(scroll 内容列)的内容测量轮里,outer 的派生 basis 0 按可用尺寸解析成 0(非 undefined),被父当成 0 高内容贡献——outer 塌成 margin 高、子树全 0(液位计实测 1px);初始一切正常只因首轮 natural 测量 owner 尺寸为 nan,basis 0 解析回 undefined 走内容测量。纯 yoga 最小复现(先 availableHeight=undefined 一轮,再固定 300 轮+切换)完整复刻两形态,Yoga.cpp 加打印追踪出三级塌链:`outer mainOwnerSize 300→10→0`(10 即 margin 高)。修复不动 native:tabs_t 的 outer 改 **flexgrow+flexshrink 单写**——grow/shrink 不参与内容测量,basis 走 auto 语义(CSS flex:1 1 auto):auto 父下按内容高、确定高父下照常填充压缩,与简写唯一差别即 basis auto。**规则:凡「确定高父填满、auto 父按内容」两栖的容器禁用 flex 简写,一律 grow/shrink 单写;简写仅适合父恒确定高、或节点自身就是显隐切换对象(mbt.19 补丁保护)的场景。**回归工具追加 `moon run examples/probe-collapse2`(showcase 主结构全复刻:sidebar+兄弟 page 互切+scroll 链+双形态 tabs,液位计组应恒 18)。探针侧栏摆设勿用 button_t:窗口销毁期 GTK focus-out 回调会踩已析构资源偶发段错误(gdb 栈 `OnFocusOut → Store<Responder>::get`),与塌陷无关,探针改 label 规避,button_t 焦点链生命周期已修(yue_mbt_quit 统一断信号,见「GTK 相关」退出段错误条目)。
- **超宽容器 flexWrap 不生效:Yoga 的 flexShrink 默认是 0(CSS 是 1)**。segmented 19 段一行 2400px 被窗口截断,内层 hbox 写了 flexWrap 仍不断行——换行的前提是容器宽度被约束,而该 hbox 作为外层子项 shrink 默认 0,拿到内容全宽,约束传不进去 wrap 永不触发。修复:内层显式 `flexShrink 1` + `flexWrap wrap` + `rowGap`(换行行距);段少页面不触发换行外观不变。通用规则:期望「超宽折行」的容器,若它同时是别人的子项,shrink 必须显式给。
- **yoga Web 语义对齐的最终定案:不开 useWebDefaults,shrink 默认维持 0、需要收缩显式给 1**。yoga 四处内核默认偏离 CSS(flexShrink 0 / flexBasis 隐式 0 / flexDirection column / alignContent flex-start),官方开关 `YGConfigSetUseWebDefaults` 可一次对齐(fork 接入点在 nu `State::State()` 全局 config 处一行),但它是**全局 config:原生控件内部的 yoga 布局同样翻面**,原生组件无封装无从逐个豁免——弃用。随后试过「声明式层默认化」(container_node 统一默认 flexshrink 1,只影响声明式 hbox/vbox),真机实测仍回归面过大:图标墙固定 50px 自绘画布被行挤压变形、一图多行错乱——声明式层内同样遍布「固定宽自绘控件 + 富余空间」布局,全局翻转的收益(超宽折行免显式)远小于代价(固定宽控件全要补锁)。**回退,最终定案:shrink 默认维持 yoga 原语义 0;需要收缩/折行的容器(segmented 等)显式给 1。**回归证据:probe-collapse 系液位计恒稳、showcase 基础/图标库/图表三页截图与改前一致、hello-themed/sysmonitor 冒烟存活。组件默认值抽查(control_height 32、字阶 12-18、语义色系)贴近 AntD/Element 与桌面 GUI 惯例,无需对齐动作。方法论沉淀:默认值翻转类变更,先在真实页面巡检一圈再定——showcase 本身就是最好的回归器。
- **惰性挂载 × flex 简写的新病理(tabs 初始 0 高,切换一轮才恢复)**:页/段改「首次选中才挂载」后,tabs_t 内容页的 Linux 分支(`flex 1.0` 简写)在新的挂载时序下暴雷——全量挂载时代整树首轮 natural 测量 owner=nan、派生 basis 0 解析回 undefined 走内容测量所以一直正常;惰性挂载让 tabs 在**父链布局稳定后**才挂入,子节点加入触发的首轮 basis 求值 owner 尺寸已定,简写派生的 basis 0 直接解析成 0 并进「已计算」缓存,而初始可见页从未隐藏、不落 mbt.19 的「display 清零重显」保护——初始页 0 高,切一轮页签(触发重显保护)才恢复。修复:Linux 分支内容页改 grow/shrink 单写(basis 走 auto 内容测量,与 outer 同款两栖语义),Windows 显式 basis 0 分支保留。教训:**mbt.19 的重显保护只覆盖「hidden→显示」路径,「布局稳定后新挂载即可见」是它的盲区;两栖容器禁 flex 简写的规则对「延迟挂载」场景同样成立**。回归:showcase 页签段初始即有高度、切换正常,probe-collapse2 液位计恒稳,sysmonitor(启动即挂载场景)概览完整。同族全库排查:yue 内 19 处 `flex 1.0` 简写里,column 主轴 + auto 高父链组合的 4 处(progress_line、divider 水平分支、slider 自适应宽分支、轮播面板)同样必塌,统一改 grow/shrink 单写;其余在 row 主轴(行宽确定)或启动挂载确定尺寸语境,不塌保留。验证:统计进度段首挂 25% 填充、分隔线 1px 横线、轮播面板高度均截图实证。测试方法学教训:xdotool 驱动验证时注意单实例合并(新实例会向首实例发唤醒后退出,截图打到旧代码窗口)与 X 窗口 id 复用,必须按「exe 路径过滤的 PID ↔ wmctrl 窗口」配对确认,且首次挂载类 bug 要在全新实例上验。


- **yoga-mbt 纯 MoonBit Flexbox 引擎首批(feature/yoga-mbt 分支,与内嵌 C++ Yoga 是两条线)**:为 MoonBit 化 libyue 预置布局层,独立子包(modules/yoga-mbt,零 FFI 无 prebuild)。定位差异先说清:本节此前「shrink 默认 0 / 不开 useWebDefaults」的定案管的是原生控件树里那颗 C++ Yoga,不可迁移;yoga-mbt 按用户要求只对齐 CSS Flexbox L1 单标准,默认值全 web 语义(row / shrink 1 / basis auto / align stretch / min:auto)。对照材料:W3C css-flexbox-1 §9 全文(w3.org/TR/css-flexbox-1,§9 算法在 li#algo-* 列表项里)+ Yoga 官方源码(github facebook/yoga,yoga/algorithm/CalculateLayout.cpp 与 FlexLine.cpp;raw.githubusercontent 直连超时,走 `git clone --depth 1 --filter=blob:none --sparse git@github.com:...` SSH 可达)。三点实质差异按规范取舍:①§9.7 冻结算法——规范是「目标尺寸从 flex base 起步、不弹性项(因子 0 / 被 min-max 截断)预冻结、循环按总违规正负选择性冻结(正冻结 min 违规、负冻结 max 违规、零全冻)」,Yoga 官方注释自认用两遍法偏离规范,本引擎按规范;②shrink 加权用内基准尺寸(base − 自身 padding/border,规范原文),Yoga 用 border-box 基准;③单行 + 容器交叉轴确定时行交叉尺寸直接取容器内交叉尺寸(§9.6),align-content 对单行无效——此前靠 align-content:stretch 补齐的实现会让非 stretch 的 align_content 在单行容器上错位。实测踩坑(纯 MoonBit 侧,moon 0.1.20260904 + moonc 0.10.x):续行运算符必须收在行尾(行首 `+`/`-` 报 unbound `~+`);无 `+=`/`-=` 复合赋值;裸 `0..n` 非法必须 `0..<n`;`1e15` 科学计数法字面量解析报错须写全 `1000000000000.0` 形态;`fold` 要求带标签 `fold(init=0.0, ...)`,`guard` 是保留字;泛型写 `fn[T] f(...)` 不是 `fn f[T]`;顶层常量用 `const NAME` 或小写 `let`;`pub priv struct` 的类型在外部不可见(pub fn 签名引用即报 4046「public definition cannot depend on private type」),字段私有需求实际只能 `pub struct`;mut 字段「从未赋值」按错误报(0015),经引用改内层字段不算外层字段突变;moon.pkg 新 DSL 不认 warn_list(报 Unexpected key),关包级 lint 要用旧 JSON 文件名 `moon.pkg.json` 写 `{"warn_list": "-6"}`(unused_constructor 对「构造器全给消费方」的枚举库是误报,此法显式关闭);测试断言是 `assert_eq(a, b)` 无 `!` 后缀,且只能在带错误类型的上下文用(test 块内)。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 19/19 全绿(预期值按规范手算;首版 5 条断言错在把 stretch 撑满与 min:auto 下限当 bug,浏览器同款行为,预期修正而非代码回退)。

- **yoga-mbt absolute 定位(YG2a)**:包含块取父容器 padding box(宽高 = border box − 两侧 border,含 padding),inset 与 margin 百分比相对包含块对应轴;尺寸规则:显式宽高 > 同轴两侧 inset 都设(撑出 = 包含块 − 两侧 inset − 两侧 margin,内容盒下限 0)> 内容测量;定位规则:该轴有 inset 用它(右侧取包含块 − right − margin − 尺寸),该轴双 auto 落静态位置——按父容器 justify-content(主轴)/align-items(交叉轴)摆放一个虚拟项(忽略兄弟,间距类 justify 取 0)。踩坑一条:内容测量得到的尺寸**不额外按可用空间截断**(可用空间只以 AtMost 形式传给 measure 函数,与 Yoga 同款),先做了 `min(avail)` 截断导致「auto 尺寸父容器 + 固定内容尺寸叶子」场景被压成 0(auto 父容器 padding box 为 0 时尤甚);验证:`moon check` 零警告 + 全仓 `moon test` 687/687(新增 7 条:脱流与 left/top 定位、同轴两侧 inset 撑尺寸、四向全 auto 静态位置居中、right/bottom 定位、不撑开容器内容尺寸、内嵌子树递归、百分比 inset 相对 padding box)。

- **yoga-mbt baseline 对齐(YG2b)+ 交叉轴 margin 定位缺陷**:API 取 `set_baseline(f : (可用宽, 可用高) -> Option[Double])`,返回值语义为**基线到内容盒顶部**(与 `set_measure` 对称,引擎叠加自身 padding/border);容器不设回调,基线由引擎按规范 §8.5 推出:首行有基线对齐项 → 取该行共同基线(升距最大值),否则取交叉轴起端最靠前的有基线 in-flow 项(嵌套容器逐层上抛)。行交叉尺寸按 §9.4 补齐前半:收集「inline 轴平行主轴 + align-self 为 baseline + 交叉轴两侧 margin 均非 auto + 有真实基线」的项,取 max(基线到外沿交叉起端) + max(基线到外沿交叉末端),与既有「最大外沿交叉尺寸」取大;定位按 §9.6「升距最大者贴行交叉起端」= maxAscent − margin 起端 − 基线。三条定案:①单行 + 容器交叉轴确定时行交叉尺寸仍直接取容器内交叉尺寸(§9.6 短路优先),基线只决定项的偏移不决定行高;②主轴为列时不做基线对齐(规范收集条件要求项的 inline 轴平行于主轴,列容器交叉轴是水平向),按起端摆放 = 浏览器行为;③**无基线的项排除在基线分组外并按 flex-start 定位**——规范只说「无基线则从 border box 合成」,未写明合成在哪条边(css-align-3 首基线合成于块起边,浏览器对替换元素/空块历史用底边,存在分歧),本引擎取「不合成」,与 Yoga 的 dimbound 分支一致,也让「无基线项」与改前「Baseline 当 FlexStart」行为完全兼容;想要浏览器那种「图片底边坐落基线上」的消费方,自行把基线回调返回自身高度即可。实测缺陷(实现本批时由新增断言打出,与 baseline 数学同源):**交叉轴 margin 从未参与子项定位**——`pos_cross` 只等于「行偏移 + 对齐偏移」,而 `free_c` 已按含 margin 的外沿算,于是 `margin_top: 30` 的项贴到行首(实测 `0 != 30`),`align-items: flex-end` + `margin_top: 20` 时 margin 被整体吞掉(实测 `130 != 150`);主轴方向无此问题(`pos_main` 累加了 `m.start`)。修复:定位改为「行偏移 + 对齐偏移 + margin 起端」(auto margin 解析值为 0,故 auto 分支不受影响)。另暴露一条**待修**缺陷:容器 auto 主轴尺寸按内容推算时 `content_main_sum` 只累加子项,漏加自身 padding/border(`padding_top: 5` + 30 高子项 → 容器高 30 而非 35),且多行分支把 `content_main_sum` 直接写死 0(折行容器 auto 主轴尺寸会塌成 0),留作下一批,本批相应断言暂不合入。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 36/36 + 全仓 `moon test` 697/697(新增 10 条:交叉轴 margin 定位与拉伸、margin 与 flex-end、两项按基线对齐、基线决定行交叉尺寸(容器交叉轴不定)、stretch 项不参与基线分组、无基线项按 flex-start、margin-top 计入升距、多行时基线只在行内生效、嵌套容器基线上抛、column 容器不做基线对齐);对照材料:W3C css-flexbox-1 §9.4(algo-cross-line)/§9.6(algo-cross-align)/§8.5(Flex Container Baselines)原文。

- **yoga-mbt 容器 auto 尺寸漏算自身 padding/border + 多行主轴尺寸塌 0(YG2b′)**:YG2b 期间探针实测(父容器 `padding-top:10 / padding-left:10` + 100×50 子项,容器不给宽高)row 与 column 两种方向的 auto 尺寸都得到 100×50,浏览器为 110×60——根因在「自身尺寸」段用 `content_main_sum`(只累加子项 size_main + margin)与 `own_cross_content`(只累加行交叉尺寸)直接当容器的 border-box 尺寸,而宽高语义明确是 border-box,自身 padding/border 从没叠加;子项**定位**侧一直是对的(`layout_left = own_border.left + own_pad.left + x`),所以现象是「尺寸小一圈、子项位置正确」,容易被误判成测量函数报错。第二个洞在同一处:多行分支把 `content_main_sum` 写死 `0.0`,折行容器不给主轴尺寸时整条主轴塌成 0。修复:主轴按各行外沿(size_main + 两侧 margin + 该行 column/row gap)取最大值,交叉轴沿用各行交叉尺寸之和,两者统一再补 `pad_border_main / pad_border_cross`;`nlines == 1` 分支与旧值等价(auto 主轴容器不参与弹性解析,`size_main` 恒等于 `hyp_main`,故改用「按行取最大」不改变单行结果)。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 40/40 + 全仓 `moon test` 701/701(新增 4 条:行容器 auto 尺寸含 padding、列容器同款、含 border 的 47×23、折行容器「主轴取最宽行 + 交叉轴累加行高」= 90×50 且两行子项 top 10/30;并把 YG2b 撤下的嵌套容器 `b.height == 35` 断言合回)。

- **yoga-mbt aspect-ratio(YG2c)——比例语义定案为 border-box**:用户定的口径是「比例 = 边框盒宽 / 边框盒高」,与引擎既有的 width/height = border-box 一致,和 CSS 默认的 content-box 比例不同(README 已标注;换算处一律不做 padding 扣减)。四处接入点:①§9.2 flex base——项有比例 + 基准为 content + 交叉轴确定 → 主轴基准 = 交叉轴按比例换算(列容器则反过来除);②§4.5 自动最小尺寸——主轴 `min:auto` 取「内容尺寸」与「换算尺寸(transferred size suggestion)」的**较小者**,否则比例会被内容下限顶回去(实测例:内容宽 200 + 高 10 + 比例 2 → 应为 20,写成 `min:auto = 内容` 得 200);③§9.4 交叉轴假想尺寸——主轴已定(含 §9.7 弹性解析结果)→ 交叉轴 = 主轴按比例换算,再走 min/max 收顶;④容器自身尺寸——一轴确定(显式或由父级钦定)而另一轴 auto 时,按比例换算出的那一轴**当作确定尺寸**参与后续计算(即写进 `inner_main` / `inner_cross`),于是换行上限、弹性解析、行交叉尺寸与 stretch 全部按该尺寸走;不做这一步会出现「`width:320 + aspect-ratio:2` 的容器高按内容 50 塌着、子项也拉伸到 50」的错果。一条规范直译的行为要写清:`align-items: stretch`(本引擎默认)会覆盖交叉轴的比例换算结果——规范 §9.4 algo-stretch 的条件看的是「computed 交叉尺寸属性为 auto」,并有尾注「本步不影响项的主轴尺寸,即使它有首选比例」,所以比例项在 stretch 容器里按行交叉尺寸取高,要保持比例需给非 stretch 对齐或显式交叉尺寸(浏览器同款行为,已入单测)。绝对定位子项这一批**不做**比例换算(该路径仍只按显式尺寸 / 同轴两侧 inset / 内容定尺寸),记在 README 未实现清单。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 47/47 + 全仓 `moon test` 708/708(新增 7 条:宽推高、高推宽、列容器由高推宽、容器自身按比例定尺寸并让子项撑满、stretch 覆盖比例(含改 align_self 后恢复)、比例值给 min:auto 封顶、非正比例视同未设);对照材料:W3C css-flexbox-1 §9.2 / §4.5 / §9.4 与 css-sizing-4 的 preferred aspect ratio 定义。

- **yoga-mbt RTL(direction,YG2d)+ 翻转定位两处既有缺陷**:方向语义定为**按节点独立、不做 CSS 的 direction 继承**——引擎的 `layout_into` 只拿得到父给的可用尺寸、没有父链样式上下文,而 libyue 侧主题/控件自己知道该给哪个容器设 rtl,继承链交给上层封装。实现只动「解析与映射」层:两个派生标志 `rev_main = is_reverse(flex_direction) != (rtl && 主轴为行)`(行容器 direction 与 row-reverse 各翻一次,列容器主轴是块轴不受 direction 影响)与 `rev_cross = rtl && 主轴为列`(交叉轴即 inline 轴才翻);`axis_margin` 增 `cross_reverse` 参数决定交叉轴起端取 margin-left 还是 margin-right——**物理边始终是 margin-left/right,只是「起端/末端」的含义随方向换算**,auto margin 的分配跟随所属边(Yoga 同款语义)。行容器交叉轴是块轴,所以 baseline 分组、align-items 的垂直摆放与 rtl 完全无关;rtl 列容器折行时 `pos_cross` 含行偏移后整体翻转,首列自然落在右侧、次列在其左(单测实证)。本批由 RTL 的翻转参照打出两条既有缺陷:①**row-reverse / column-reverse 在容器 auto 主轴尺寸下算出负偏移**——翻转参照用 `inner_main_dim.unwrap_or(0.0)`,容器主轴靠内容推算时该项为 None,于是 100 宽的项落到 -100、第二项 -200(探针实测),修复为「容器内主轴确定尺寸优先,否则取内容推算的行主轴尺寸最大值(`line_main_max`,顺带从自身尺寸段上提到定位段之前)」;②**绝对定位四向全 auto 的静态位置恒按左/上落**——YG2a 的静态位置只按 justify/align 算偏移、没跟着主轴翻转,`column-reverse` 容器里应当贴底部却贴了顶部,修复为静态位置的起端随所属轴的翻转标志走(margin 也取所属起端的物理边)。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 60/60 + 全仓 `moon test` 721/721(新增 13 条:3 条 LTR 快照锁住翻转参照与静态位置的新行为 + 10 条 rtl:行容器右起端、rtl×row-reverse 回左起端、列容器交叉轴起端在右、起端取右边距、justify flex-end 落物理左端、margin 物理边参与主轴、margin auto 吸收、行/列容器的绝对定位静态位置靠右、rtl 列容器折行行序);改前 47 条 LTR 断言全部保持原值,即方向层未回归既有行为。对照材料:W3C css-flexbox-1 「主轴起端由 direction 与 flex-direction 共同决定」的定义(flex-direction 与 Writing Modes 的 inline/block 轴关系)+ css-position-3 的 static position 定义。

- **yoga-mbt 绝对定位子项吃 aspect-ratio(YG2e,YG2 标准面收尾)**:abspos 段的尺寸优先级原为「显式宽高 > 同轴两侧 inset 撑出 > 内容测量」,比例换算插在中间一步——先按老规则解出「已确定的一轴」(显式给出或由左右/上下两侧 inset 撑出),另一轴仍 auto 时按比例换算并以自身 padding/border 兜底,再走 min/max 收顶;两轴都 auto 时**仍按内容测量**(与 in-flow 项一致,比例不凭空造尺寸)。左右(上下)inset 全 auto 的落位沿用 YG2d 的方向翻转标志,不受本批影响。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 63/63 + 全仓 `moon test` 724/724(新增 3 条:由宽推高、由高推宽、两侧 inset 撑出宽后按比例推高)。

- **yoga-mbt 枚举跨包不可构造(E4036)+ 性能基线(YG3a 工程化首批)**:先报阻断级坑——本工具链(moon 0.1.20260920 / moonc 0.10.14)里 `pub enum` 只把**类型**与「匹配可读」开放给包外,**变体构造对外是只读的**:外部包写 `@lib.Green` 或 `@lib.Color::Red` 都报 `E4036 Cannot create values of the read-only type`;`pub(readonly) enum` 语法不被支持,变体上单独加 `pub` 报「No individual visibility for enum constructor」。正确形态是 **`pub(all) enum`**(依据:`moon check --explain` 输出的 E4036/E0006 官方解释 + 双包最小复现)。对 yoga-mbt 意味着:引擎的 `FlexDirection / AlignItems / AlignContent / JustifyContent / FlexWrap / PositionType / Display / Direction / Value` 九个枚举全是消费方要往 setter 里塞的值,原写法下**外部包一行样式都设不了**;这条在单测里永远不暴露(测试与实现同包),是新增 bench 这个**外部包**跑 `moon check` 时才炸出来的——YG4 集成前必踩。修复:九个枚举统一改 `pub(all) enum`,`Value` 已有的 `fixed/percent/auto/undefined` 辅助函数保留(消费方两种写法都通)。同批建立性能基线,工具 `modules/yoga-mbt/bench`(`moon run bench` / `moon run --release bench`;树 = 根 + 20 组 ×（1 组头 + 10 行）× 每行 5 节点 = 1121 节点,行带 `align-items: baseline` + grow + gap + padding,叶子带 measure、文本带 baseline 回调;把 `rounds` 改 0 即得「进程 + 建树」基线):本机 Ubuntu 24.04 x86_64 实测 500 轮 `calculate_layout` debug 4.57s / release 2.21s,0 轮基线 ≈0.106s,折得**每轮 debug ≈ 8.9ms(8.0µs/节点)、release ≈ 4.2ms(3.8µs/节点)**。下一个优化对象由代码结构直接指出:同一节点在「base 测量」与「交叉轴重测」两轮里被重复 `layout_into`,Yoga 用 16 槽测量缓存解决;yoga-mbt 做缓存要先解决失效时机(引擎无脏标记,样式可能在两次布局之间被改),暂定形态「`calculate_layout` 入口做一次前序遍历清缓存,缓存在单次布局内有效」。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 63/63 + 全仓 `moon test` 724/724,且 bench 包作为外部消费者参与 `moon check`,等于「枚举可跨包构造」有了常驻回归。

- **yoga-mbt 测量缓存(YG3b)**:`measure_content` 在同一次布局里会对同一节点重复调用两遍(§9.2 base 测量、§9.4 交叉轴重测),容器还会被父链逐层重复,是基线里的主要冗余。形态:**缓存挂在 `Node` 上**(`measure_cache : Array[((可用宽, 可用高), (宽, 高, 基线))]`,键值全用元组与基础类型——`pub struct Node` 的字段不能引 priv 类型,否则重犯 E4046「public definition cannot depend on private type」),命中时**连基线一起回灌**(基线是容器上抛给父容器做 §9.4 分组的中间量,与尺寸同源,漏回灌会让 rtl/baseline 场景读到上一次的旧值)。**失效时机定案:缓存在单次 `calculate_layout` 内有效,入口整树前序遍历清一次**——理由是本引擎没有脏标记,消费方可以在两次布局之间随意改样式(实测例:padding-left 10→50、baseline 10→18),按 Yoga 那种「版本号/dirty」方案要引入变更通知面,而清缓存的一次 O(n) 遍历相对单次布局成本可忽略,换来零失效漏洞。收益(bench 同机同树,500 轮):**debug 每轮 8.9ms → 5.1ms、release 4.2ms → 2.6ms(1121 节点)**,即约 1.7 倍;剩余成本主要在「带 pinned 尺寸的最终定位轮」——那一轮必须真跑(子项坐标要落地),要进一步就是 YG4 的脏区增量重排,不在工程化批次内做。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 65/65 + 全仓 `moon test` 726/726(新增 2 条失效回归:改 padding 后重排不走旧缓存、改基线后重排不走旧缓存;63 条既有断言零回归即缓存语义未改变布局结果)。

- **yoga-mbt 像素网格取整(YG3c)**:根节点开关 `set_pixel_grid(interval)`(`0.0` / 负数关闭,只在节点作为布局根时生效),`calculate_layout` 末尾追加一趟后处理,把 `left/top/width/height` 落到网格上;关掉开关时全程保留小数值,65 条既有断言必须零回归。取整口径定为**按绝对边框取整再回推相对坐标**:同一物理边被相邻两项共用时两侧读到的是同一个绝对坐标,取整结果自然一致,等分 `100/3` 得到 `33 / 34 / 33`(和恰为总宽,相邻项之间不留 1px 缝)——若按「相对坐标 + 自身尺寸」各自取整,三项都记 33 就少 1px。**踩坑一条**:递归下传父项起端时**只能传「取整后的父起端」不够**,必须同时传「取整前的父绝对起端」:子项的 `layout_left` 是相对父**原始**坐标的,用取整后的父起端去还原子项绝对边,会把父项自己那半格误差算进子项——实测中间容器绝对起端 33.33→取整 33,内部两项原始宽 16.67,于是第二项绝对起端算成 `33 + 16.67 = 49.67`、绝对末端 `66.33`,取整得 50/66 → 宽 16(应为 17,`16 != 17` 断言炸出)。修复后参数分为四元 `raw_*`(还原子项真实绝对边)与 `snap_*`(换算子项相对坐标),误差只出现在各条边自身、不被父项误差转嫁。**未做**:Yoga 的贴父末端回推补偿(`pixelGridSnapError` 一类)——容器有尾部 padding/border 时,贴到内缘尽头的项其取整后末端与父内缘可差一个网格单位以内,记在 README 作为已知限制,真机出现可见缝隙再补。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 69/69 + 全仓 `moon test` 730/730(新增 4 条:整像素等分 `33/34/33`、半像素网格 `33.5/33/33.5`、不设网格保留 `100.0/3.0`、嵌套项按绝对坐标补偿 `mid.left 33 / width 34` 与 `inner 0/17 + 17/17`)。

- **yoga-mbt 内在尺寸 min/max/fit-content(YG3d,YG3 收尾)**:先记口径来源(Yoga 与规范都要核对,不能凭记忆)。**规范侧**:css-flexbox-1 §9.9「Intrinsic Sizes」只有三句话,把定义整体推给 css-sizing-3(§2.1 auto box sizes 给 stretch-fit / max-content / min-content / fit-content 四个尺寸,§5.2 intrinsic contributions 说「贡献 = 只含该项的 auto 浮动在零宽/无限宽包含块里的内容盒尺寸」并声明具体算法留给对应 display 的规范);**flex 容器自身的内在尺寸细则不在 L1**(w3.org/TR 与 drafts 两版都查过,`collected … contribution` 在 L1 里只出现在 §9.3 分行),只在 css-flexbox-2 草案(§9.10.1 还分 ideal / web-compatible 两套)。故本引擎按 css-sizing-3 的通用规则单套实现,不追 L2 的双算法(README 已记)。**Yoga 侧**(SSH 稀疏克隆 `facebook/yoga` 的 `yoga/algorithm`+`yoga/style`+`yoga/enums` 核对):①`Unit` 只有 `MaxContent / FitContent / Stretch`,**没有 min-content 关键词**,`SizingMode` 注释自认「Missing min-content」;②min-content 只作为 §4.5 内部量存在——`computeMinContentMainSize` 对叶子用「请求轴 `AtMost 0` + 另一轴 `Undefined`」调测量函数(文本回最长词宽),对容器直接递归且**只看容器自身主轴**(子项主轴求和、交叉轴取最大),忽略 flex-wrap、忽略 gap;③`MaxContent` 尺寸模式下测量函数的可用空间被改成 `YGUndefined`。本引擎取「Yoga 的探询约定 + 规范的合成规则」:叶子探询沿用 `Some(0.0)` / `None`(与既有 `set_measure` 签名兼容,不改 API),容器合成做换行感知(可换行容器的 min-content 主轴 = 最宽单项,并按该宽度贪心分行求交叉轴;不换行取单项之和)。**语义修正两处**:①§4.5 `min:auto` 的 content size suggestion 此前用「当前可用空间下的测量值」近似 → 改为真 min-content;②§9.2 `flex-basis: auto` 且主轴尺寸也 auto 时的基准此前同为该近似 → 改为 **max-content**(否则折行项的基准随可用空间漂移,收缩算不到溢出量;实测:100 宽容器里放 wrap 子容器(单项 60/50/40),改前基准 90 不收缩,改后基准 150 收缩到可用 100,可用 55 时被 min:auto=60 顶住)。新增取值 `min_content() / max_content() / fit_content()`,可进 width / height / min-* / max-* / flex-basis,绝对定位子项同样吃(`axis_size` 一处收口)。踩到两条:①**内在探询不能刷新节点基线**——第一版叶子探询走 `measure_content`,探询(不受约束那次)覆盖了真实布局的 `Node.baseline`,基线分组会读到「单行基线」,改为直接调测量函数的专用探询路径;②**热路径要为缓存键的分配买单**——`measure_content` 每次调用先构造键元组再线性比对,新增的内在递归把每节点探询从 2 次抬到 4~6 次,`release` 每轮从 1.30s(500 轮)涨到 2.54s,逐步止损(`release` 500 轮实测 2.54 → 2.07 容器只求主轴就不算交叉贡献 → 1.93 命中改逐项比较、只在写入时构造键 → 1.81 叶子探询绕开 `measure_content` 另加「显式尺寸已定就不探对应内在值」的短路,探到也要丢弃的值不再探)。bench 口径(直接计时构建出的可执行文件,0 轮基线 0.106s,与 YG3a/YG3b 的 `moon run` 口径不同批比较需谨慎,本批 A/B 是同机同法实测):每轮 debug 4.9→7.3ms、release 2.4→3.4ms(1121 节点),即真内在尺寸的成本约 +40%;进一步要靠「缓存跨布局驻留 + 脏区增量重排」,那属于集成层(YG4),本批不做。验证:`moon check` 零警告 + `moon test -p NoahLiu/yoga-mbt/src` 79/79 + 全仓 `moon test` 740/740(新增 10 条:max-content 不被可用空间压窄、min-content = 最长词、fit-content 三段夹取、min-width: max-content 顶住收缩、flex-basis: max-content 参与 grow、列容器 min/max-content 宽取最宽子项加 padding、折行容器基准 max-content 与下限 min-content、nowrap 容器 min-content 为子项之和、绝对定位项的 max-content、改子项后内在缓存不复用旧值;69 条既有断言零回归)。对照材料:css-flexbox-1 §9.9 / §4.5、css-sizing-3 §2.1 / §5.2、`facebook/yoga` 的 `yoga/algorithm/CalculateLayout.cpp`(`computeMinContentMainSize` / `measureNodeWithMeasureFunc`)与 `yoga/style/StyleSizeLength.h`。

### MoonBit 原生 GUI 栈(G0 输入法探针)

- **环境**:Ubuntu 24.04 + X11(XDG_SESSION_TYPE=x11)+ XFCE,moon 0.1.20260920;系统库 gtk+-3.0 3.24.41 / pangocairo 1.52.1 / cairo 1.18.0 / x11 1.8.7;fcitx5 与 ibus 的守护进程均已安装,`GTK_IM_MODULE=fcitx`。探针在 `experiment/ime_probe`,两形态同二进制:模式 B = `GtkIMContext` 纯通道(文本状态只在 MoonBit 一份)、模式 C = 可见 `GtkEntry` + CSS 主题化。**构建链四条坑**:①**moon 的 `link_configs` 只有链接期字段**——给条目加 `c_flags` 被静默忽略,`native-stub` 编译不带系统头文件搜索路径,`#include <gtk/gtk.h>` 直接 fatal error;修复是与 shim 同构,由 `scripts/prebuild.py` 的 `build_ime_probe_stub()` 用 `pkg-config --cflags` 编成 `build/libime_probe_stub.a`,再仅经 `link_flags` 传入。②该库必须按 ld 命名叫 `libime_probe_stub.a`,`-lime_probe_stub` 才找得到。③**moon 不重链改过的原生库**:改 stub 后 `moon run` 仍跑旧 exe(SIGSEGV 现场一模一样),与「改 shim 后须删 `_build` 下产物强制重链」是同一条坑,此处复现于 `-l` 静态库路径——删 `build/libime_probe_stub.a` 与该包 exe 后再跑。④CI 三平台都跑 `moon build --target native` 的**全包链接**,Linux 专属探针会让 Windows/macOS 断 `ip_*` 符号;修复:加 `ime_probe_stub_portable.c`,在 `#if !defined(__linux__)` 下把所有入口给空实现(`ip_init` 返回 0,MoonBit 侧据此打印"本平台无探针"后退出),该文件走 moon 自己的 native-stub,Linux 上整体为空。**自己的一个坑**:`ip_report_im_module` 在模式 C 对 `pr.im == NULL` 调 `G_OBJECT_TYPE_NAME` → SIGSEGV(退出码 139);模式 C 本就没有自建上下文(输入法挂在 GtkEntry 上)——冒烟只跑模式 B 完全看不出来,再次印证「每条分支真实触发过才算验证」。**已实测到的三条**(供 G5 取舍):①`g_main_context_iteration(NULL, TRUE)` 单步就能驱动 GTK 窗口与信号,**不需要 `gtk_main`**,主循环全在 MoonBit 手里,Esc 与 1500ms 自动退出都干净、无退出期崩溃;②**GtkEntry 的尺寸协商确实顶回去**——给它 22px 的盒子,主题默认把控件撑到 32~33px(`requested_h=22 allocated_h=33`),CSS 加 `min-height: 0px` 后落到 24px(22 + 上下各 1px 边框),即"能压但压不回请求值";③Pango 口径可直接用——14px 字面行高量得 17px,前缀宽度量出 59px,插入点矩形 `83,22 1x17` 已推给输入法通道(候选窗定位的输入口)。**待真机项**:commit / preedit 内联 / 候选窗贴合 / 快捷键穿透 / 中文实际可打性,按 `experiment/ime_probe/README.md` 清单在 fcitx5 与 ibus 两种 `GTK_IM_MODULE` 下执行,结论回填本节。验证:`moon check` 零警告 + 全仓 `moon test` 740/740 + `moon build --target native` 68 任务全过 + 本机两模式冒烟进程存活并干净退出。

### MoonBit ↔ C ABI

- 蹦床与 C 函数指针原型逐位对齐,含参数个数:C 以 `(closure, args...)` 调用,蹦床首参收 closure。错位后行数正常、部分回调能跑,极具掩盖性;每个回调都真实触发过才算验证。
- `extern "c"` 返回可空类型:旧版工具链直接段错误(成败经 `Ref[Int]` 出参报告);moon 0.1.20260904 + moonc v0.10.12 实测 `-> Bytes?` 已可用——C 侧返回 NULL 正确映射 None,debug / release 双模式、真实缺失文件与目录(EISDIR)路径均验证(sysmonitor 的 read_text_file)。其余可空类型(句柄等)未复测,仍按出参模式兜底。
- FFI 指针参数标 `#borrow`(编译器强制);控件参数写句柄类型 `View`,不写 MoonBit 包装 struct(否则运行时句柄全部无效且静默丢弃)。
- 闭包跨 ABI:无捕获顶层函数字面量即 C 函数指针;带捕获走「函数指针 + 闭包指针」双参模式。
- 回调闭包由注册表进程级保活,不随窗口回收(单窗口工具场景泄漏可忽略,已定案)。
- Toolbar / Vibrant 的 Linux 静态库无符号,链接必败,不暴露;Browser 空 Cookie 列表崩溃已在 fork mbt.7 修复。
- 改 shim 签名必须 `.cpp` / `yue_mbt.h` / ffi.mbt 三处同批;漏同步或整段漏声明的断链形态都是 mangle 分裂(`_Z` 前缀符号对纯 C 名引用),nm 对比定位;出包前跑「.cpp 全量定义 × 头文件声明」对照扫描。
- **独立翻译单元(如 `yue_accent_mac.mm`)不 include `yue_mbt.h` 时,函数定义必须显式 `extern "C"`**:缺了按 C++ mangling 导出(`__Z25yue_mbt_system_accent_macv`),`yue_mbt.cpp` 按头文件的 C 名引用即链接 undefined。此病三平台只有 macOS 暴露(Linux/Windows 不编 .mm),vendor/CI 的 prepare 阶段也不暴露(静态库不查 undefined),唯 macOS 真链接(moon test/build)必现;本机无 mac 时唯一防线是 CI。0.5.0 发布前实修一轮(符号经 vendor Actions 重出后 strings 复验为 `_yue_mbt_system_accent_mac`)。
- XFCE 面板 IconPixmap 优先于 IconName:set_icon_name 与 set_pixmap 互斥,设一方须清空另一方。
- **自定义协议拒绝编码与 C 端载荷预验(CORE1,高危)**:`Browser::register_protocol` 的 None 拒绝路径曾把载荷编成 `[1,0,0,0]`——C 端按首 4 字节小端读出的 `ok=1` 当成功,继续在 4 字节缓冲之外读 mime_len/content_len(原生堆越界读),再按垃圾长度 `std::string(p+8, mime_len)` 构造字符串,未定义行为;且拒绝从未真正生效(libyue WebKitGTK 侧只在 handler 返回 nullptr 时 `finish_error` 拒绝请求,见 yue fork 的 `nativeui/gtk/browser_gtk.cc` OnProtocolRequest)。修复:MoonBit 侧拒绝载荷改 `[0,0,0,0]`(ok=0,C 端直接返回 nullptr、不读后续字节),编码抽成包内纯函数 `encode_protocol_payload` 供白盒测试;C 侧先按 MoonBit Bytes 长度预验再逐段解码——ok==0 或载荷不足 12 字节即拒,mime_len/content_len 为负或越出载荷同样按拒(长度比较走 int64 防 `8+mime_len+4` 溢出),nullptr 载荷也兜底拒。Bytes 长度取数据指针前 4 字节(moonbit_object 头的 meta,VAL_ARRAY 即长度;布局照 moonbit.h 的 `Moonbit_array_length`,不引入 moonbit.h 以避免其 extern "C" memcpy 声明与 glibc 冲突),该假设用直链 libmoonbitrun.o + libruntime 归档的最小 C 探针实证(make_bytes(23/4/0) 三态读回长度全对)。教训:**带长度字段的自编码 ABI 载荷,C 端必须自己拿得到总长度并先预验**,不能信任对端"声称成功"后的字段;跨 ABI 的契约测试要与 C 端解码逻辑同构(先长度预验再逐段取值),而不是只验编码侧形状。验证:`moon check` 零警告 + `moon test` 636 全绿(新增 yue/browser/browser_wbtest.mbt 8 条:None 载荷逐字节为 `[0,0,0,0]`、Some 逐字节对齐 ok/mime_len/mime/content_len/content、UTF-8 多字节按字节计长、空 mime/content 的 12 字节最小载荷、旧版 `[1,0,0,0]` 形态与 ok=1 的 8 字节短载荷均按拒、mime_len/content_len 越界按拒、长内容含引号换行往返);shim 改动经 prebuild 增量重编,删 `_build` 下 showcase exe 后 `moon build examples/showcase` 重链零警告(nm 确认 exe 引用 yue_mbt_browser_register_protocol);showcase 补 demo-deny 拒绝路径按钮与代码片段,加载失败的真机表现由用户在 Linux WebKitGTK 下确认(Windows WebView2 自定义协议本就静默无效)。

### 统一 style 值模型(StyVal trait)与 MoonBit trait object 限制(0.5.2)

- 统一 style 值模型:`StyVal` 开放 trait(`yue/style.mbt`)给 builtin `Double`/`String` 实现 `apply_to(Self, View, String)`,混型数组 `Array[(String, &StyVal)]` 单参数收像素与字符串值,内部派发 `ffi_view_set_style_prop_float/_str` 两条 C 通道(C ABI 无重载,拆分消化在 yue 内)。期望类型已知时数组字面量自动装箱(tuple 内亦传播),存量纯数值调用点零改动迁移。
- **trait object 对 builtin 类型的 impl 判定限制**(moonc v0.10.12 实测,/tmp 探针):①一个 impl 块只能写一个方法,`impl T for X with fn a.. fn b..` 换行连排与同行连写都不存在;②impl 块必须一次写全 trait 全部方法——trait 两方法而某类型只 impl 其一时,报 "does not implement trait, although an impl is defined: method X is missing",且 `&Trait` 引用直接报 "trait not found";③「声明 `= _` + 包级默认 impl + 类型分块覆盖」对 builtin 类型不生效(对 struct 类型是官方文档形态,见 moonbit-docs trait 示例的 J),覆盖块写全两方法也判定失败;④结论:给 builtin 类型实现自有 trait,每类型一个 impl 块写全全部方法(core 的 Show/Hash 同此形态);因此 StyVal 只能单方法,「从 trait object 取回数值」(as_num 通道)不可行。
- **core 库版本敏感 API**:`StringView::exact_view` 在 moon 0.1.20260904 的 core 中不存在(报 no method)、0.1.20260920 中存在且 `sub` 反被标 deprecated——同类 API 随 nightly core 演化互斥存在,代码跟随当前 nightly 的正名,新旧版本切换时以 moon check 输出为准。
- **CI 挂排查路径与 nightly 特性**(实测):CI 三平台整排红时,匿名 API 拉不到日志(job logs 接口 403),但 `GET /repos/:repo/check-runs/:job_id/annotations` 可读错误注解;注解为空且"Process completed with exit code 1"时按 job 的 steps 列表(`.../actions/runs/:id/jobs`)看哪步红。moon nightly 滚动极快(0.1.20260918 数日内 404、0.1.20260920 当天傍晚即 403 下架),install 脚本按具体版本号下载会被滚动清掉——**CI 不能钉 nightly 版本号,只能跟随 latest 别名**。
- **bind_node 运行期重挂后 Windows 鼠标 hit-test 错乱**(真机实测,演进三版结论):bind_node 信号变化 remove+add 重挂子树,Windows 上点击链路触发重挂后,**后续全窗点击都被路由给重挂过的控件**(探针 v3 事件流实证:点行1/空白均触发行2 回调、根容器收不到任何事件),推迟一拍重挂也躲不开——有害的是 remove+add 本身,不是同步栈时机。hit-test 走 ContainerImpl::FindChildFromPoint 的 GetClippedRect(=size_allocation_ 布局分配 rect),remove 后 add 的新子树该值异常扩张,libyue 层根因待 fork 侧修。**规避**:点击链路会重挂自身落点的场景改「预建双份 + set_visible 显隐切换」——显隐走 is_visible_ 标志 + display:none(fork 的 yoga-display-none-flex-basis.patch 专门维护),不销毁不重建 view,探针行5 验证;bind_node 的 doc 已加警示。Linux 的 GTK 布局同步无此病,bind_node 照常。
- **swap_node:bind_node 的 Windows 安全替代**(0.5.2,真机验证通过):两态切换场景(换图标按钮/换整块视图)用 `swap_node(sig, a, b)`——预建两棵节点、信号选显隐,不销毁不重建 view,零 hit-test 风险;showcase 明暗切换改用后 Windows 真机多轮切换+后续操作全正常(此前 bind_node 版全窗点击失效连标题栏都关不掉)。代价:两棵子树常驻(低频场景可忽略)。fork 根修后 bind_node 恢复全平台,swap_node 保留(零重建低开销)。
- **theme_apply 的 Windows 分支勿改推迟**(教训入档):曾按「点击栈内同步重绘扰动消息状态」假设改与 Linux 同款 post_task/post_delayed_task 推迟——黑盒测试(components_wbtest 调 theme_apply)进程退出时 60ms 延迟任务对已销毁窗口执行 EnumWindows/RedrawWindow 直接崩,Windows CI exit -1 两连挂;且该假设已被探针否定(真凶是 bind_node 重挂)。Windows 保持同步 ffi_repaint_all,Linux 保持原有两拍推迟。
- **bind_node 运行期重挂后 Windows 鼠标 hit-test 错乱**(真机实测):bind_node 信号变化走 remove+add 重挂子树,Windows 上 yoga 根不重算(native v0.15.6-mbt.19 只修被清零节点自身,树结构变化不在修复面),新挂子树 bounds 停在脏值→鼠标命中测试恒命中它——表现为「点了深浅切换按钮后,全窗口的点击都触发明暗切换,其余操作全部失效」,键盘走焦点不受影响。修复:bind_node 的 rebuild 尾部在 Windows 上对挂载容器调 refresh_layout(整窗布局重算+根级重绘,与 tabs 切页同款兜底);Linux 的 GTK size request 自动覆盖新子树无需此步。同族面:toast 层动态移除条目属纯删(在 mbt.19 修复面),暂无恙。
- **仓库整体移动后 CMake 缓存拒绝配置**(真机实测):build/ 里的 CMakeCache.txt 记录配置期绝对目录,仓库从旧路径整体拷到新路径后 cmake 报 "current CMakeCache.txt directory is different than..." 且拒绝配置,prepare.py 中断。修复:prepare 的 cmake_build 前检测 CMakeCache 记录的 CMAKE_CACHEFILE_DIR/CMAKE_HOME_DIRECTORY 与当前路径不一致即清空 build/ 重新配置(顺带重编 shim),无需手动删目录。
- **Windows 用户名含撇号/空格的 LNK1104**(真机实测):moon 在 Windows 上拼 cl/link 命令行时对含单引号的绝对路径 quoting 失败——用户目录 `C:\Users\noah'liu\...` 的库路径被剥掉撇号,且 `yue_mbt.lib` 与 `yue_prebuilt.lib` 两个空格分隔的路径被黏成**一个**链接输入,LNK1104「无法打开文件 …lib …lib」;prepare.py/cmake 均不受影响(路径原样传递),只有 moon 的 link_flags 拼接炸。修复:prebuild 的 Windows 分支库/manifest 一律用**相对模块根**路径(`build/yue_mbt.lib`、`lib/windows-x64/…`),moon 链接子进程 cwd 即模块根(从模块根执行 `moon build` 为前提),相对路径只含安全字符天然绕开;Linux/macOS 走参数数组不经命令行拼接,无此问题仍用绝对路径。
- **vendored 库级联误链(浅克隆)——CI 整排红的根因**(实测闭环):prebuild 的 `_native_dir()` 级联「lib/<平台>/ vendored 优先、build/ 回退」,其新鲜度判定 `_sources_newer` 依赖 git pathspec 提交时间;**actions/checkout 默认 fetch-depth=1 浅克隆下 pathspec 限定的 log 退化成 HEAD 时间,t_shim==t_lib 恒等 → 判定 shim 不比库新 → 恒走 vendored**,而 `ensure_native_lib` 对 vendored 就位直接零编译返回——shim 领先 vendored 出包的新符号(如 view_set_bounds/scroll_refresh_content_size)在 CI 链接全部 undefined,本机完整 clone 走 git 时间比较用 build/ 故不复现。修复:`_native_dir()` 改「**build/ 有 prepare 产物(stamp+库)即最高优先**」(开发/CI 链路的产物按当前 shim 全新编译,恒不旧于 vendored;vendored 只服务无 build/ 的 mooncakes 分发用户),`_sources_newer` 浅克隆恒等/mtime 竞态一律保守回退 build/。教训:**vendored 与 shim 的领先关系是常态**,级联判定宁可重编不可误链旧库。
- 布局参数收编后 Windows 单行输入垂直居中不再读数值:改纯布局方案——Entry 控件收窄到行高(`entry_ctrl_height`,文字在控件内天然居中),外壳 `justifyContent=center` 垂直居中,任意高度值(含百分比)自动适配;原 entry_vcenter 的「收窄+均分 margin」路径已删。
- select_t/dropdown_menu 弹层宽度在点击时 `get_bounds(field)` 现取(用户 style 覆盖字段宽后弹层自动跟随);弹层根容器宽高仍须创建期给定(事后 set_style 会被弹层分配时序吞掉,见 GTK 节)。

### 目录枚举与进程内环境变量(shim 的 POSIX / Win32 分支)

- 目录枚举(`yue_mbt_list_dir`,服务 fsx_list_dir;shim 由 prebuild.py 托管编译):POSIX 走 `opendir`/`readdir`(跳过 `.` 与 `..`),Windows 走 `FindFirstFileW`。**不能用 FindFirstFileA**——A 版是 ANSI 代码页,非 ASCII 路径(中文用户目录)全乱码;路径用 `base::SysUTF8ToWide` 转宽字符、拼 `L"\\*"` 模式,子项经 `SysWideToUTF8` 回转。返回扁平 UTF-8 文本、子项名以 '\n' 分行(与本包多字符串返回惯例一致:browser cookie / clipboard get_data 同编码);**子项名本身含 '\n' 的极端文件名会被拆开**,扁平文本编码的已知边界,文档须写明。`ok` 出参区分「空文本是失败」与「空目录」(空目录 ok=1 空文本,合法成功态)。
- 进程内环境变量(`yue_mbt_setenv` / `yue_mbt_unsetenv`,服务 fsx/envx):POSIX 直接 `setenv`/`unsetenv`;Windows 用 `_putenv_s`,它**恒覆盖**——`overwrite=0` 分支须先 `std::getenv` 探测再决定,否则「已是既有值则保持原值」语义会被静默改掉。删环境变量在 Windows 是 `_putenv_s(name, "")`(卸下该变量,不是置为空串),与 POSIX `unsetenv` 语义对齐;本就不存在也记 ok=1(幂等)。作用范围都是**当前进程**(之后 spawn 的子进程可见),不触碰系统持久配置、不影响父进程。
- fsx 把这两类薄原语收进一个模块(appfind / browser_history / envx 共用):要点是「只列条目名、不读内容」,修 appfind 的「大体积可执行文件全量读入仅判存在」取舍——之前 appfind 用 read_binary_file 判存在,现在走 fsx_list_dir 查目录条目。

### 按包拆分:yue 单包 → 核心 + 六个子包(0.5.11)

- 环境:moon 0.1.20260920 / moonc v0.10.14,模块 NoahLiu/native-gui;原生层预构建库就绪。
- 现象:拆包前 yue 单包容纳约 6 万行——FFI、原生控件、主题组件库、20+ 图表、markdown、声明式层、30 个系统能力文件混在一个包。MoonBit 按包编译、包内无树摇,webview 方案或只用核心的消费者也被迫把整套工具箱编进二进制。
- 根因(机制):MoonBit 跨包引用必须 `@别名.` 限定——实证两条:官方 moonbitlang/async 的 src/fs 子包用 `@async.xxx` 引用根包;本仓 yue/media.mbt 用 `@traybus.xxx` 引用 traybus 包。拆包因此=每子包独立 moon.pkg + 包内全部核心引用加 `@yue.` 限定(codemod 词边界替换,须跳过 `.字段`/`::方法`/字符串字面量)+ 外部依赖声明随包下沉(mizchi/markdown → yue/markdown,subproc 与 moonsqlitefile → yue/system)。链接参数无需改 prebuild:link_configs 按依赖闭包逐包拼 flags,新包只 import 核心即自动拿到 `-lyue_mbt`;webkit 仍只进 yue/browser 条目,按需化不被破坏。
- 修复(批次顺序即循环依赖规避):①markdown 先搬——它调 components 的 code_view,晚搬则核心→components→核心成环;②components——前置手术是把 `hand()` 光标助手从 components.mbt 提入核心并 pub(charts_interactive 跨包引用它,charts 后搬),主题块约 17 个私有 getter 及 bind_fg/bind_entry_theme/entry_ctrl_height 被 20+ 文件跨包引用,按需 pub 化;③icons;④charts(charts_wbtest.mbt 自带 extern "C",moon.pkg 须 targets 声明 native-only);⑤declarative——前置手术两步:Node 协议(struct Node + attach)从 declarative.mbt 抽留核心 yue/node.mbt(否则 components/icons/markdown/charts 四包对 Node 的无前缀引用全要改),signals.mbt 末尾的 `bind()`(内部调 bind_label)随 bind_label 迁入 declarative 包;⑥system——打开外部 `open_url`(system.mbt)与托盘 tray.mbt 留核心(markdown 的链接点击依赖 open_url,procrun 随系统层走);⑦版本收口 0.5.11:moon.mod、yue/version.mbt、modules/gui-media 钉版三处同步(prebuild 构建期校验一致,不一致 moon build 直接失败)。
- 验证方式与教训:每批 moon check 零警告 + moon test 全量 + moon build examples/showcase 与 sysmonitor;独立验收员只读审 git diff(符号逐位等价、moon.pkg 卫生、无夹带)。**教训:门控漏了 systemprobe**——批处理提交后,已推送的树 systemprobe 构建 15 处断链(导入适配留在工作区未随批提交),hello/hello-themed 不受影响故双示例门控无感;用 `git stash` 在已提交态实测才发现。拆包类改动的门控必须覆盖全部示例,提交范围须以 git status 逐批核对(并行工作流的未提交文件极易被整文件提交扫入)。

### MoonBit 原生 GUI 栈 G1（绘制契约）· 本工具链的 MoonBit 语法形态与缓冲选型

环境：Ubuntu 24.04 + X11 + XFCE，moon 0.1.20260920 / moonc v0.10.14。新增 `render`（纯 MoonBit，零 FFI）。

- **坑**：`pub method name(self : T, ...)` 直接解析失败——`method` 是保留字（Warning 0035 提示 reserved keyword）。**修复**：一律写 `pub fn T::name(self : T, ...)`。
- **坑**：`match expr with { }` 报 `unexpected token with`（仓库现有代码里 `match ... with {` 出现 0 次）。**修复**：写 `match expr { }`；注意**记录更新** `{ s with tx: 1.0 }` 里的 `with` 仍合法，两处不同构。
- **坑**：`Bytes` **只读**（无 `op_set`），且本版本**没有** `ByteArray` 类型（`The type/trait ByteArray is not found`）。**修复**：可变字节缓冲用 `FixedArray[Byte]`（`yue/png_rgba.mbt:12-19` 已在用），就地写入还不需要 `mut` 绑定。像素位图字段因此定为 `FixedArray[Byte]`，G2/G3 交给 Cairo/X11 时再取数据地址。
- **坑**：`self.field[i] = v`（经字段下标赋值）会把整个方法提成要求 `T &mut`，调用点就得写 `mut p`；对要承接组件层一万行既有调用点的绘制器不可接受。**修复**：写像素前先取局部句柄 `let d = self.data` 再 `d[i] = v`；而状态重绑（`self.state = {...}`）同样要求 mut，故把可变字段放到**内层** `PainterState` 的 `mut` 字段上、外层 `state` 字段从不重绑（与 `yue/signals.mbt:247` 的 `self.node.dirty = false` 同构），`p.fill_rect(..)` 因此在不可变句柄上可用。
- **坑**：结构体是引用语义，`save()` 把 `self.state` 直接入栈，`restore()` 拿回的是同一个对象，状态根本不会回退。**修复**：入栈逐字段拷贝快照（`snapshot`），出栈逐字段写回（`load_state`）；此行为已有单测覆盖（translate + restore 后两处像素分别断言）。
- **坑**：带类型名的构造 `Color { r: ... }` 解析失败。**修复**：按上下文写裸 `{ r: .., g: .. }`（参照 `yue/view.mbt:513-521`）。
- **坑**：跨 `moon.work` 成员的测试依赖只在 `moon.pkg.json` 的 `wbtest.import` 里声明会报 `Package ... not found`，且条目中的 `alias` 字段被静默忽略（默认别名取路径末段，故 bench 里是 `@src`）。**修复/取舍**：要让 `render` 的测试用 yoga-mbt，得在根 `moon.mod` 声明该模块依赖，会改动发布依赖图；本批不动它，「布局树→像素」的定位断言顺延到真正接线 yoga 的批次（G2/G7）。
- **口径分岔（记档待定夺）**：hex 8 位写法本栈按 CSS 的 `#RRGGBBAA`（透明度在尾）解析，而 libyue 的 `Color` 约定是 `#AARRGGBB`（`yue/color.mbt` 的 parse_hex 注释里写明混用表现为颜色漂移而非透明度变化）。新栈不沿用前者。
- **坑（工具链副作用，勿再踩）**：仓库级 `moon fmt` 在当前版本会重排约 80 个与本批无关的文件（本仓并非 fmt-clean），并把 `moon.pkg.json` **迁移**为 `moon.pkg`——而新 DSL 不认 `warn_list`（见 `modules/yoga-mbt/HANDOFF.md` §6.11），`yoga-mbt/src` 里那条 `warn_list: -6` 会被静默搬走。**修复**：`moon fmt` 只点名本批新文件；跑后以 `git status` 核对，误改的一律 `git checkout -- <显式路径>` 回滚。

- **验证**：`moon check` 零警告 + 全仓 `moon test` 748/748（`render` 新增 8 条像素级断言：半开区间覆盖、source-over 混合、translate+restore、clip 只收紧、内侧描边一圈、窄矩形整块填满、100/3 等分共用边不留缝、非法 hex 与零尺寸位图保持原状）。

### MoonBit 原生 GUI 栈 G2（GTK3 窗口地基）· 循环泵与上屏的五条实测坑

环境：Ubuntu 24.04 + X11 + XFCE，moon 0.1.20260920 / moonc v0.10.14，GTK3 3.24.x。新增 `win`（GTK3 后端）、`examples/native-window`。

- **坑 ①（窗口不画、frames=0）**：`gtk_widget_show_all` 之后 GDK 的 map 请求还压在输出缓冲里，X 服务端收不到 map，poll 等的是一个永远不会来的事件。**修复**：show 后 `gdk_display_flush(...)` 并跑一轮 `gtk_main_iteration_do(FALSE)`（不要用已弃用的 `gdk_flush`）。
- **坑 ②（忙轮询占满 CPU，dt=0）**：在 `poll` 之前调 `g_main_context_wakeup` 会把 GLib 内部唤醒管道置为可读，poll 立刻返回，外层退化成空转。**修复**：等待内部绝不调 wakeup，跨线程唤醒只由外部 `wm_wakeup()` 触发（效果正是让本次 poll 提前返回）。
- **坑 ③（GLib 加固签名）**：本机 `g_main_context_query/check` 比网上示例多一个 `n_fds` 参数（query 第 5 位传缓冲容量；check 第 4 位是 n_fds，不是 n_ready）。**做法**：按 `/usr/include/glib-2.0/glib/gmain.h` 核对，不照抄文档示例。
- **坑 ④（相对延时的时基）**：`CLOCK_MONOTONIC` 是开机起算的大数（本机实测 21405569ms）。`Loop` 的 last_now 若从 0 起算，首次 advance 前排的定时器会**全部立刻到期**——骨架动画只跑一拍、5 秒退出定时器当拍就停循环。**修复**：`Loop::start(now_ms)` 显式建立时基，未 start 时基准取 0（已入单测）。
- **坑 ⑤（已知坑复现：moon 不因原生静态库变化重链）**：改 `win/gtk_stub.c` 后 `moon build` 报 `no work to do`，跑的还是旧 exe（与「改 shim 后须删产物」同一条）。**修复**：删 `build/libyue_win_stub.a` 与该示例的 `_build` 输出再来。
- **另记（口径）**：上屏路径把调用方的 RGBA 缓冲拷进后端暂存再换序（BGRx），**绝不就地改调用方缓冲**——离屏快照与窗口同源，就地换序会让下一次快照通道错位、重复上屏还会来回颠倒。
- **验证**：`moon check gui/{core,win,render}` 零警告；`moon test -p NoahLiu/native-gui/core` 9/9；`examples/native-window` 本机冒烟 52 帧、退出码 0、无退出期崩溃；yoga-mbt 79/79 未掉。

### MoonBit 原生 GUI 栈 G3 首批（Cairo 光栅器）· 位图格式与两侧口径对齐

- **格式定案（关键）**：`render` 的 Bitmap 内部布局改为与 `CAIRO_FORMAT_ARGB32` 一致（小端 = B,G,R,A 且**预乘** alpha）。收益：Cairo 可以直接画进我们自己的缓冲（`cairo_image_surface_create_for_data`）、上屏直拷，全链路单一格式零转换。代价与对策：自写的 `Bitmap::paint` 改在预乘域做 source-over（与 Cairo 同一套算术），`Bitmap::pixel` 负责**反预乘**，所以对外语义（独立 RGBA 分量）与 G1 的断言完全不变。
- **上屏简化**：`wm_present` 去掉 RGBA→BGRx 换序与暂存拷贝，直接用调用方缓冲建 ARGB32 surface 贴上（会话期间由 `#borrow` 持有，缓冲不会动）。
- **`stroke_rect` 两侧同口径**：Cairo 的 `stroke` 是**居中**描边，与布局层 border-box 口径不符，故 C 端用「四条内边带填充」复现内侧语义；界面上要与 Cairo 居中描边区分时另开方法，不改本契约。
- **不变量（已入单测）**：同一矩形、同一颜色（含 alpha）经「纯 MoonBit 矩形绘制器」与「Cairo」两条路径，**逐像素完全相等**（含 `#00000080` 叠白底 = 127,127,127,255 的情形）；斜边填充出现中间 alpha，证明确实走了抗锯齿。
- **验证**：`moon test -p NoahLiu/native-gui/render` 14/14（新增 6 条 Cairo 断言：逐像素一致、三角形填充、抗锯齿中间 alpha、clip+translate、内侧描边两侧同语义、半透明混合一致）；`moon check gui/{core,win,render}` 零警告；`examples/native-window` 冒烟 52 帧、退出码 0（示例已加 Cairo 画的圆与贝塞尔弧，整条链路过一遍）。

### MoonBit 原生 GUI 栈 G3 次批（Pango 文本层）· FFI 出参与跨包字段可见性

- **坑（SIGSEGV，无测试输出）**：把 `Array[Int]` 当 C 的出参数组用（C 侧 `int32_t *out` 写 `out[0..2]`）会段错误——MoonBit 传给 C 的是**数组对象**，按 `out[0]` 写会踩坏它的长度头，之后任何一次使用都崩。仓库既有形态是逐个 `Ref[Int]` 出参（`yue/ffi.mbt:452` 的 `ok : Ref[Int]`），改成三个 `Ref[Int]` 后 7/7 通过。**规则**：C 回传多值一律用多个 `Ref[Int]`，不要用 `Array[Int]` 借指针。
- **坑**：跨包构造/读取结构体字段要 `pub(all) struct`（`yue/geometry.mbt:20` 的 `RectF` 形态）。只写 `pub struct` 时报 `Cannot create values of the read-only type`，同一条也适用于 `pub(all) enum`。
- **坑**：带默认值的参数必须是标签参数（`family? : String = ""`），写成 `family : String = ""` 报 `Only labelled arguments can have default value`。
- **口径**：字号按**逻辑像素**取绝对尺寸（`pango_font_description_set_absolute_size(desc, px * PANGO_SCALE)`，不是磅）；`baseline` 是首行基线到布局盒顶部，与 yoga-mbt `set_baseline` 的定义一致，接线时不需要换算；ellipsize/wrap 语义照老师 `attributed_text_gtk.cc:82/128-132`。
- **测试取向**：不断言具体像素宽/高（随机器字体配置变，G0 探针记的「14px 行高 17px」是本机值），只断单调性（文本更长更宽、字号更大更高）、约束性（`max_width` 下宽受钳、换行后高增长）与「确实落像素」的计数，保证换机不假红。
- **验证**：`moon test -p NoahLiu/native-gui/text` 7/7；`moon check gui/{core,win,render,text}` 零警告；`examples/native-window` 冒烟 52 帧退出码 0（窗口内画中英混排文本）；全仓红点仍 290 errors 未增。

### MoonBit 原生 GUI 栈 G3b 补充 · 行高口径定案与「测试可执行文件不重链」

- **口径定案**：`line_height` 取**字体 metrics 的 ascent+descent**（`pango_context_get_metrics`），`line_ascent` 取 ascent（= 首行基线）。不能用样例文本的盒高当行高——那会把「有无下伸部」当成行高差，布局盒高随内容抖。
- **与 G0 探针对账**：探针记的「14px 字面行高量得 17」其实是**首行基线**（本层 `line_ascent(14) = 17` 与之一致），本层 `line_height(14) = 22`（ascent+descent）。两个数都对，名字用错了；G5 定文本盒高时按 22 这一路走。
- **坑**：`PangoFontMetrics` 不是 GObject，必须 `pango_font_metrics_unref`；误用 `g_object_unref` 直接 SIGSEGV（且崩在测试驱动里、无任何测试输出，极易误判成 FFI 参数问题）。
- **坑（既有坑的新面）**：改原生静态库后 `moon test` 的可执行文件**同样不重链**——此前记录只针对 `moon build` 的 exe，本次复现于 `_build/native/debug/test/<pkg>`：修好 SIGSEGV 之后测试仍崩，因为跑的是旧链接产物。排查时先用一个普通 main 目标复现（它是新目标、必然新链接），一致地「main 正常、测试崩」即指向产物过期；修复要连 `_build/native/debug/test/<pkg>` 一起删。
- **验证**：删产物后 `moon test -p NoahLiu/native-gui/text` 7/7；`moon check gui/{core,win,render,text}` 零警告；render 14/14、core 9/9、yoga-mbt 79/79 未掉。

### MoonBit 原生 GUI 栈 G4 首批（编辑内核与键码）· 内核语义与工具链写法

- **内核语义定案**：文本状态唯一权威在 `input`，输入法只是它的客户端之一（不做「通道持有文本」那份双状态）。坐标一律 **UTF-8 字节下标**，caret/anchor 只落码点边界（续字节 0xC0..0xBF 回退），与 G0 探针同源；改成码点下标会同时断掉 Pango 量宽与 IME preedit 偏移口径。`get_text_in_range` 的对齐方向是**起点回退、终点前进**（宁可多含一个码点，也不返回半字）。内核不碰系统剪贴板：`cut/copy` 返回文本、`paste_text` 接收文本，故整块逻辑可在无显示环境下测。`Tab`/`Shift+Tab` 返回「未消费」交上层焦点栈；可打印键由 `keysym_to_text` 落地（Latin-1 与 UCS keysym 两条路），其余功能键留给 G5 的 IME 通道。
- **坑（本工具链写法，均实测）**：① `fn helper(self : Editor, ..)` 这种隐式方法形式**不被识别**（报 unbound），私有辅助也要写 `fn Editor::helper(self : Editor, ..)`；② 顶层常量 `pub name : Int = v` 解析失败，要 `pub const NAME : Int = v`（大写）；③ `move` 是保留字（Warning 0035），方法改名 `move_caret`；④ `Int.to_char()` 返回 **`Char?`**，直接插值会报「Option does not have a meaningful string representation」，必须先 match 出 Char；⑤ `pub enum X derive(Eq, Show) { A B }` 的变体在别处不可构造，无载荷枚举要 `pub(all) enum`，本批进一步把二值枚举（Consumed/NotConsumed）直接换成 `Bool` 少一层语法面；⑥ `} else match ... {` 不合法，match 作分支体要裹 `{ }`。
- **坑（越界）**：`floor_boundary` 允许 k == 缓冲长度（末尾是合法边界），循环里必须 `k < n` 短路后再取字符，否则 `Array::at` panic（实测 SIGABRT）。
- **验证**：`moon test -p NoahLiu/native-gui/input` 10/10（中英混排 roundtrip、退格删整字不残留、选区替换、词跳转三个方向、shift 延长/折叠、copy 不动状态而 cut 删、undo/redo 往返、handle_key 路由与 Tab 归属、Ctrl+A/Ctrl+Z/Ctrl+左、区间对齐）；`moon check gui/{core,input}` 零警告；render 14/14、text 7/7、yoga-mbt 79/79 未掉。

### MoonBit 原生 GUI 栈 G4 次批（键/指针事件与焦点接入）· GTK 侧四条口径

- **坑**：`gdk_keyval_to_lower(ev->keyval)` 会把 Shift 后的大写抹成小写——X11 的 keyval **本身已含 shift 语义**（'a' 与 'A' 是不同 keysym），内核的 `keysym_to_text` 因此能直接得到正确字符。事件里保留原 keyval，不做小写化。
- **坑**：修饰位不能直接透传 GDK 的位值（Shift=1、Control=4、Mod1=8、Mod2=64、Meta=16），必须显式重映射到本栈的 `MOD_SHIFT=1 / MOD_CTRL=2 / MOD_ALT=4 / MOD_META=8`，否则 `Ctrl+Left`、`Shift+Tab` 一类组合全判错。
- **收键前提**：`gtk_widget_set_can_focus(area, TRUE)` + `gtk_widget_add_events(area, GDK_KEY_PRESS_MASK | ... | GDK_SCROLL_MASK)`，并在 `show_all` 之后 `gtk_widget_grab_focus`；少任一步窗口存在但一个键事件都不回（与 G2 的「不 flush 就等空事件」同类：现象是「没反应」而不是「报错」）。
- **口径**：事件队列是每窗口 64 槽 FIFO，满了**丢弃而不是覆盖**（宁可丢一个事件也不能把顺序打乱）；取事件用「`wm_take_event` 返回 code + `wm_ev_*` 逐字段读最后一条」而不是多个出参——MoonBit 不能给 C 传可写数组（见 G3b 那条 SIGSEGV）。
- **焦点栈在 MoonBit 侧**：`core/focus.mbt` 只管次序与环绕（Tab 到末尾回第一个、Shift+Tab 到首位回最后一个、注销当前项焦点交给后继），平台侧只有一个动作 `Window::request_focus`。逻辑焦点归 MoonBit 与 libyue 的 `FocusManager` 同构（容器不持有系统焦点）。
- **caret 定位口径**：点击定位逐码点量前缀宽，取「不超过点击点的最右边界」；`Editor::boundary_after` 由私有提升为公开，供上层做同一种推进。
- **验证**：五包 `moon check` 零警告；测试 core 14/14、input 10/10、render 14/14、text 7/7、yoga-mbt 79/79；`examples/native-window` 本机冒烟 49 帧、退出码 0、两个框文本状态完好。**真机项待协作方**：英文/数字可打字、退格与方向键、Tab/Shift+Tab 在两框间环绕、点击定位光标、caret 500ms 闪烁、中文标点与组合键（IME 属 G5）。

### MoonBit 原生 GUI 栈 G0 · 真机回证：`im_focus` 是纯通道成立的前提，preedit 缺口定位在探针挂法

环境：Ubuntu 24.04 + X11 + XFCE，`GTK_IM_MODULE=fcitx`（fcitx5）。执行人：协作方真机（AGENTS 规则 6）。

- **现象**：探针模式 B 下每按一键都直接落成一次 commit、preedit 恒 0，输入法像根本没接管——不是 fcitx5 不工作，而是 `GtkIMMulticontext` 在上下文**未激活**时落回内建的 `GtkIMContextSimple`（只处理 Latin-1，组合串与候选都不走）。
- **根因**：只调了 `gtk_im_context_set_client_window` 就够了让上下文可用，但**没调 `gtk_im_context_focus_in`**，它一直处于失活态，`filter_keypress` 因此从不消费按键。
- **修复**：realize 时 `gtk_im_context_focus_in(pr.im)`；顶层窗口 focus-in/out 事件里同步 in/out（失焦必须 `focus_out`，否则输入法侧残留未完成的组合串——即清单第 5 项）。补上后**中文 commit 路径真机可用**。
- **闭环（同日追加）**：preedit 内联已达成，纯通道**四条件**齐备——①`focus_in`/`focus_out` 随焦点同步；②按键处理挂**焦点控件**层（挂窗口层时事件顺序与消费都不对，这正是与 `GtkEntry` 行为的差别所在）；③每拍 `gtk_im_context_set_surrounding`（只喂已提交文本、光标按 UTF-8 字节）；④`use_preedit=TRUE`——它的语义是「用 preedit 串做内联反馈」，不是「输入法自绘」，一度读反，代价是两轮假阴性。
- **另一处真机坑（与输入法无关）**：组合串**只能在一处拼接**。探针原先 MoonBit 侧把 preedit 拼进显示串、C 侧绘制时又拼一次，同一段文字显示两份；修法是把拼接与下划线统一收到绘制侧（正文不带线、组合串带线，与 `GtkEntry` 同观感），MoonBit 只推已提交文本。
- **一处误判要记**：曾按「前端版本错配」怀疑依赖，被模式 C 对照否证（同环境下 `GtkEntry` 预览正常）——真机症状先用参照实现对照，再谈归因。
- **ibus 未装**：清单中 ibus 两轮标「环境未装 ibus daemon，未测」。
- **验证方式**：`moon build experiment/ime_probe` + 两模式冒烟退出码 0（助手侧）；真机（fcitx5）由协作方回证：preedit 内联一份带下划线、流水有 `[preedit] changed`、`[commit] 中文` 正常、候选窗贴组合串末尾。

### MoonBit 原生 GUI 栈 G4 · 真机反馈「无法输入/点击与 Tab 不切焦点」的第一处根因：事件码 4 未映射

- **现象**（协作方真机）：自绘框打不进字、点击不切焦点、Tab/Shift+Tab 无反应，但窗口动画与重绘正常。
- **根因**：后端 `wm_event` 用返回值 **4** 表示「有输入事件待取」，而 MoonBit 侧 `Window::poll_event` 的映射只写了 1/2/3，4 落进 `_ => NoEvent` 分支——于是主循环认为「没有事件」直接退出排空，`take_input` 永不被调用。渲染走定时器所以照常动，症状正是「只有输入全失灵」，且**没有任何报错**。
- **教训（口径级）**：事件码是两端之间的隐式契约，新增一类事件必须同时改 C 端返回值与 MoonBit 端映射，且**默认分支不能吞掉未知码**——今后新增事件类型时，先把未识别码打出来（或断言），别让 `_ =>` 静默吸收。
- **仍未闭环**：修完映射后示例的 5 秒自动退出没触发（进程 0% CPU 阻塞在等待里）。已排除 `Loop::advance`「只看队首就 break」饿死后序定时器这一猜想——新增无头用例「自重排的短周期节拍不应饿死长周期定时器」通过（core 15/15）。下一步用 `xdotool` 向示例窗口注入按键与点击做客观验证（这条路本机已跑通，可替代肉眼来回）。
- **验证**：`moon check win` 零警告；五包测试 core 15/15、input 10/10、render 14/14、text 7/7 全绿。

### MoonBit 原生 GUI 栈 G4 · 「完全打不进字」的两处真因：按键挂错层 与 NumLock 被当成 Meta

现象：G4 接入后自绘框一个字符都进不去，但 Tab 看着"像在动"（焦点其实切了）、窗口动画与重绘正常、全程无报错。用 `xdotool key` 向示例窗口注入按键做客观验证（本机宿主、不依赖肉眼），逐条打印 `code/keysym/mods/focus/len` 后定位到两处：

- **① 按键挂到了顶层窗口而不是焦点控件**：原 `g_signal_connect(w->window, "key-press-event", ...)`。G0 探针（`ec2849d`）已用真机定下挂法——按键处理要挂在**焦点控件**上，挂窗口层会让事件顺序与"消费后能否真正吃掉"都不对（接 IME 后尤其致命）。改为挂 `w->area`（drawing area），与 GtkEntry 的挂法同构。
- **② `GDK_MOD2_MASK` 被当成 Meta 用（致命且极易误判）**：`wm_mods()` 里写了 `state & (GDK_META_MASK | GDK_MOD2_MASK)` 就置 MOD_META。MOD2 在 X11 上是 **NumLock**，正常桌面恒为亮，于是**每个**按键事件都带 mods=8；内核 `handle_key` 见 `alt/meta` 非零即判定为组合键、不插字符，于是所有可打印键被静默丢弃。修法：Meta 只认 `GDK_META_MASK | GDK_SUPER_MASK`，NumLock/CapsLock 这类锁定位不参与本栈修饰位。
- **定位手法（值得复用）**：「事件到没到 C」在 C 回调里 `fprintf(stderr, "[c] key ...")`；「到了 MoonBit 之后丢在哪」在派发点打印 `code/keysym/mods/focus/编辑器字节数`。这次就是靠 `mods=8` 一个字段直接锁定第 ② 条的——只看现象会一路往"事件没送到"方向猜。
- **反证的一条**：修完映射后示例一度不自动退出，我先怀疑 `Loop::advance`「只看队首就 break」会饿死后序定时器，写成无头用例后**通过**（core 15/15），猜想去掉；实际卡住是第 ③ 条（draw 之外画 GdkWindow 撞死窗口，见 G2/G4 时序条）与测试等待时长不够叠加造成，不是调度器问题。
- **验证（客观）**：注入 `a b c Tab d e f` 后 `NATIVE-WINDOW-OK ... a='helloabc' b='第二个框def'`——前三键进第一框、Tab 切焦点、后三键进第二框；`mods=0`。五包 `moon check` 零警告，core 15/15、input 10/10、render 14/14、text 7/7、yoga-mbt 79/79，全仓红点仍 290 errors。**仍需肉眼确认**：点击定位光标与 caret 500ms 闪烁的观感（xdotool 能注入点击、但看不到画出来的 caret）。

### MoonBit 原生 GUI 栈 G5 首批（Linux 纯通道输入法接入）· 四条件落到 win 上的四条坑

配方来自 G0 探针（`ec2849d` 四条件），本批把它实现进新栈自己的窗口层：`win` 建 `GtkIMMulticontext`（`use_preedit=TRUE`）、收键先 `filter_keypress`（消费即吃掉、不推给内核）、提交文本与组合串以「取一条 + 逐字段读」回 MoonBit、每拍喂 surrounding 与插入符矩形；`input` 增加 `set_preedit`/`preedit_text`（组合串只作显示，**绝不并入文本状态**，文本仍只有一份）；示例把组合串画在已提交文本之后并加下划线，候选窗矩形算上组合串宽。

- **坑①（拼音原样进文本、输入法像没工作）**：`set_client_window` 在 `show` 之前调，那时 drawing area 还没 realize、`gtk_widget_get_window` 返回 NULL，multicontext 于是没挂上任何输入法模块，`filter_keypress` 恒返回不消费。**必须挂在 `realize` 信号里**（探针同此），并配 `focus-in/out-event` 做 `focus_in`/`focus_out`。
- **坑②（core dump：`free(): double free detected in tcache 2`）**：`commit` 信号给的 UTF-8 串所有权在 GTK，回调返回后它自己释放，处理器里 `g_free(text)` 即双释放。探针的处理函数也确实不 free。
- **坑③（永远出不来中文）**：每拍喂 surrounding 时顺手调 `gtk_im_context_reset` 会**打断组合**——reset 的语义是「当前组合串作废」。喂 surrounding 只调 `gtk_im_context_set_surrounding(im, text, len, caret_bytes)`（四参旧接口，探针同此，不走带 SelectionData 的新接口）。
- **坑④**：`preedit-changed` 的信号签名是 `(GtkIMContext*, gpointer)`，串要用 `gtk_im_context_get_preedit_string(ctx, &str, &attrs, &caret)` 取（按 `(ctx, text, data)` 接会拿到错的指针）；`caret` 是组合串内的**字节**偏移，与我们 UTF-8 字节光标同口径。
- **工具链补充**：`FixedArray[Byte]` → `String` 的现行路子是 `@utf8.decode_lossy(FixedArray::unsafe_reinterpret_as_bytes(buf))`（`@utf8.decode_utf8`/`buf.to_bytes()` 在本版本都不存在）；`Double → Int` 用 `x.floor().to_int()`（无 `Int.floor_of_double`，也没有 `+.` 运算符，且**续行运算符必须收在上一行行尾**）。
- **验证（客观，`xdotool` 注入，`GTK_IM_MODULE=fcitx`）**：输入 `nihao` + 空格 → 退出行 `a='hello你哈哦'`，拼音字母零残留、`seen=6` 只剩未被消费的键，说明过滤与「消费即吃掉」都按预期工作；进程干净退出。五包 `moon check` 零警告，core 15/15、input 10/10、render 14/14、text 7/7、yoga-mbt 79/79，全仓红点仍 290 errors。
- **待肉眼/待补**：preedit 下划线的观感、候选窗是否贴组合串末尾（本机只能证明矩形已推送）、ibus 一套（探针侧结论：ibus 无内联预览疑为 libpinyin display-style 设置，与本层无关，另记）、Windows `ImmAssociateContext` 与 macOS。

### MoonBit 原生 GUI 栈 · Painter 契约补齐首批（门面化 + 混合模式 + 渐变）

- **门面化定案**：`Painter` 从「纯矩形子集」升为**完整契约门面**——`new(bitmap)` 即开一个 Cairo 会话，矩形/路径/变换/裁剪/混合/渐变都走 Cairo；Cairo 不可用（非 Linux 占位 stub、或 16 个会话槽耗尽）时退回纯矩形实现（路径类调用为无操作）。矩形类绘制在**两条路径上逐像素一致**（新增矩阵等价用例：取整、内侧描边、裁剪求交、平移、半透明叠色一段序列跑两遍比对）。
- **会话纪律**：Cairo 会话槽 16 个（`CR_MAX`），每帧一个会话的用法要求 `Painter::end()` 回收；泄漏会让后续 Painter 静默退回降级实现。新增「连续开合 20 个 Painter 仍持有会话」的回收用例；旧测试有 9 处没回收（累计 14 个泄漏），补 `end()` 后余量才回到安全区。
- **混合模式**：25 个 `BlendMode` 与 Cairo 算子 **1:1 映射**（前 16 个 W3C 混合 + 后 9 个 Porter-Duff）。独立 C 探针实测本机（cairo 1.18 + pixman）**25 个算子全部真实生效**（pigment 系与 HSL 系含），无需自实现混合算法；半透明源按 W3C 公式（`(1-α)·底 + α·Blend(底,源)`，实测 0.5 α 乘算 = 0.5·底 + 0.5·底×源），透明底上 Multiply 退化为源色。25 模式实测表落成断言行（混合/HSL 行留 ±2 容差防跨 pixman 定标差异，Porter-Duff 行精确值）。
- **坑（取整必须在设备空间）**：矩形取整若发生在**用户空间**，经 CTM 平移（如 `translate(1.3, 0.6)`）后的设备坐标是分数像素 → Cairo 抗锯齿出灰边，与纯实现分岔——「门面 vs 降级」矩阵等价用例正是靠这一条先红后绿。修法：`cairo_user_to_device` 换算后在**设备空间** `floor(v + 0.5)`，再临时换单位矩阵按整数矩形填充；矩阵含旋转/斜切（off-diagonal 非零）时不做取整，原样交给抗锯齿。
- **坑（裁剪区是图形状态）**：临时单位矩阵 + `cairo_rectangle` + `cairo_clip` **不能**用 `cairo_save`/`cairo_restore` 包住——裁剪属于被保存的状态，`restore` 会把刚设的裁剪一起回退；必须手动 `cairo_get_matrix`/`cairo_set_matrix` 还原（裁剪终值存设备空间，之后 CTM 再变不影响已设的裁剪区）。
- **坑（默认线宽不同源）**：Cairo 会话默认线宽 **2.0**、契约默认 **1.0**，`Painter::new` 里不同步会让不调 `set_line_width` 的描边（如 `stroke_rect` 的内侧带）粗一圈——「描内侧一圈」用例给出定位。
- **坑（不存在的函数）**：`cairo_pattern_get_status` 不存在（正确的是 `cairo_pattern_status`），写错报在**链接期** undefined reference 而非编译期。
- **坑（产物路径大小写，G3b 那条的补充）**：本仓测试产物路径是 `_build/native/debug/test/NoahLiu`（**首字母大写**），删小写路径静默不生效、测试继续跑旧二进制——本批一度在修好设备空间取整后仍见 20 像素差异，实为旧产物。改原生库后删产物的正确路径：`_build/native/debug/test/NoahLiu/native-gui/<pkg>`。
- **渐变**：`Gradient::linear`/`radial` + `add_stop`，offset 钳到 [0,1]、hex 非法忽略、无 stop 的渐变整体忽略、`set_fill_color` 覆盖渐变；实现为一次性 pattern（建 → 逐 stop 加色 → 设为 source 即释放句柄）。实测口径：线性在像素中心采样（`(x+0.5)/轴长`）、超端点 pad 复现端点色；径向同心、四角对称。
- **验证**：`moon test -p NoahLiu/native-gui/render` 25/25（新增 11 条：Porter-Duff 精确值、25 模式实测表、半透明公式、透明底退化、模式与设色顺序无关、线性渐变采样与 pad、径向对称、空渐变忽略与纯色覆盖、门面路径与抗锯齿、save/restore 变换与样式同退、会话槽回收）；五包 `moon check` 零警告、core 15/15、input 10/10、text 7/7、yoga-mbt 80/80；`examples/native-window` 冒烟 49 帧、退出码 0（示例改为走门面，并用上渐变辉光、乘算方块与路径圆）；全仓红点仍 290 errors / 68 warnings 未增。

### MoonBit 原生 GUI 栈 · Painter 次批（离屏 Canvas 与图片）· 采样域与归档重建

- **图片解码**：走 **GdkPixbuf**（GTK3 既有依赖，零新增运行期依赖；`GdkPixbufLoader` 按内容嗅探格式），像素统一转成本栈 `Bitmap` 布局（ARGB32 预乘、小端 B,G,R,A），预乘取整与 `Bitmap::paint` 同口径 `(c*a+127)/255`，因此「编码 → 解码 → 再编码」字节稳定（`#12345680` 这类半透明色也精确往返）。解码器只取**静态首帧**——旧链路的 `Image` 是 `GdkPixbufAnimation`（GIF 会动），动画属已知缺口，不假装支持。
- **尺寸口径照老师**：`get_width`/`get_height` 返回**逻辑尺寸**（像素 / scale），`get_scale_factor` 返回记录比例——与 libyue `image_gtk.cc:75-77` 的 `ScaleSize(.., 1.f / scale_factor_)` 一致。
- **坑（blit 的采样域必须收在源子矩形内）**：直接给「整张源位图」建图案、只把源矩形写进图案矩阵，双线性会从子矩形**外**取色——精灵图/图标拼接会串色（测试里「取左上象限铺到 4x4」先红：右缘采到了隔壁绿块）。修法：`cairo_surface_create_for_rectangle(s, sx, sy, ssw, ssh)` 建**子表面**，采样空间随子矩形原点平移，再叠 `PAD` 扩展让边缘不越界成透明缝。
- **坑（`ar rcs` 对改名成员是追加）**：源文件从单个拆成 `cairo_stub.c` + `image_stub.c` 后，旧归档里残留的 `librender_cairo_stub.o` 与新对象**同时**进库 → 链接期 `multiple definition`。prebuild 的 `compile_stub` 改为「先删旧归档再 `ar rcs`」，并把「任一源更新即整体重编」写进缓存判据（原来是单源 mtime 比较）。
- **资产搬家的连带**：PNG 编码器从根包 `yue/png_rgba.mbt` 搬进 `render/png.mbt`（公共入口改名 `png_encode_rgba`，内部 `pngr_*` 保留），随包带走 6 条既有用例；根包私有 helper `utf8_bytes` 在外包不存在，要改用 `@utf8.encode` 并在 `moon.pkg` 加 `moonbitlang/core/encoding/utf8`。搬完红点从 290 降到 **287**（根包少了一个文件与一份测试）。
- **文件写入**：`Canvas`/`Image` 的 `write_to_file` 目前只支持 "png"，落盘经 C 端 `fsw_write_file` 兜底（系统层落地前的临时通道，路径按 UTF-8 字节收）。
- **验证**：`moon test -p NoahLiu/native-gui/render` 40/40（新增 9 条：PNG 往返不透明/半透明、空图语义与空图上不落像素、逻辑尺寸随 scale、`resize` 放大实心色保持、`draw_canvas` 2 倍放大四象限、`draw_canvas_from_rect` 子矩形无串色、blit 尊重混合模式乘算、PNG 落盘读回逐像素；另有 6 条 PNG 编码器用例随搬家并入）；五包 `moon check` 零警告、core 15/15、input 10/10、text 7/7、yoga-mbt 80/80；`examples/native-window` 冒烟 49 帧、退出码 0（新增离屏画布精灵 4× 放大上屏）；全仓红点 **287 errors / 68 warnings**（较 290 减少，未增）。

### MoonBit 原生 GUI 栈 · 图标绘制面平移（803 条千分定点路径）

- **平移范围与保真**：master `icons/icons.mbt` 前 4197 行（`IconKind` 803 变体、`path_num`/`fill_icon_path` 解释器、`draw_icon`、`icon_path_data` 数据块、`kind_index`/`all_icons`/`icon_name` 三张表）整段搬入新包 `icons`；改动只有两处类型引用 `@yue.Painter → @render.Painter` 与头部说明，**数据块与本尊逐行零差异**（`diff` 只报头部 7 行与 2 行类型引用）。声明式包装 `icon`/`icon_button_t` 依赖声明式层，留给组件接线那批（G7）。
- **语义照搬不重造**：坐标为归一化值 ×1000 的整数定点、命令集 M/L/C/Z、每子路径 M…Z 闭合、整体一次 `fill`（iconfont 轮廓型）、安全边距 0.88（`v × s × 0.88 / 1000 + 中心`）、单命令即读即调不缓存（解析微秒级）。
- **测试口径**：①清单/名字/路径数据三表一一对应——用「计数数组每格恰为 1」代替哈希集合（不为此引入容器），名字唯一用平方比对（803 项规模够用）；②路径串字符集封闭**全量扫描**（只允许 M/L/C/Z、数字、`-`、`,`，且首 M 尾 Z）；③`draw_icon` 落像素且已画像素包围盒中心 ±2px（验居中语义，不锁具体形状）；④803 图标 24px **全量扫描无空图**（含解析 + 光栅化，0.7s 内跑完）。
- **环境观察（避免误判）**：示例退出行的 `seen` 计数含**指针移动**事件（motion 的 code 4 同样走输入队列），冒烟时鼠标停在窗口上会看到 `seen` 非 0 而文本不变，属预期，不是「按键乱入」。
- **验证**：`moon test -p NoahLiu/native-gui/icons` 4/4；`moon check icons` 零警告；`examples/native-window` 冒烟 49 帧、退出码 0（示例新增一排五个矢量图标）。

### MoonBit 原生 GUI 栈 · 字体与富文本子系统（Font / TextFormat / AttributedText）

- **面**：`Font`（族名 + 逻辑像素字号 + 9 档字重 + 斜体；字重数值就是 CSS 的 100..900，直传 Pango 的 `PangoWeight`）、`TextAlign`/`TextFormat`/`TextAttributes`/`SizeF`/`AttributedText`（本批为**整体属性**面：字体、颜色、对齐、换行、省略、`get_bounds_for`、`set_text`/`get_text`/`clear`）。区间属性（`set_font_for`/`set_color_for`）要把范围挂进 Pango attribute list，留次批。
- **绘制入口按包边界放 `text`**（`draw_in_box`/`draw_font`），不做 `Painter::draw_text` 方法：MoonBit 不能给外包类型加方法（render 也不能反向依赖 text）。组件层接线时调用点从旧契约的 `p.draw_text(..)` 改 `@text.draw_in_box(p.bitmap, ..)` 形态，属 G7 的定点改写。
- **坑（语义级，探针实测抓出）**：`wrap=false` 此前**根本未生效**——Pango 只要 `pango_layout_set_width` 就按默认 `WRAP_WORD` 折行（实测：120px 宽 + 不带换行标志，长文本仍折成 4 行 88px）。修法：宽度只在「要换行或要省略」时才交给 Pango；单行不省略时按自然宽绘制（可溢出盒界），盒内对齐改为自己算偏移（与垂直对齐同一套写法）。这也纠正了旧文档「定高行内长文本会溢出行界」的说法——它其实是折行。
- **坑（FFI 原型要三处同批改）**：给 `pt_font_line_height` 加 weight/italic 时只改了 MoonBit extern 与 portable 占位，**真实现**（`text/stub.c` 的 Pango 分支）还是 4 参——多传的实参按调用约定落进 `out_h` 指针位，症状不是崩而是「行高断言莫名变假」。规则：改 FFI 签名 = moon extern + 真实现 + 占位分支三处一起。
- **坑（本工具链派生 trait 是弃用路径）**：`pub(all) enum X { .. } derive(Eq)` 触发 `implicit_impl_as_method` 弃用警告（`equal`/`not_equal` 被隐式提升为普通方法）；把 `derive(Eq)` 写在枚举名之后更是直接编译错（正确位置是 `}` 之后）。为守住零警告，本批不派生 trait，测试用包内 id 映射比较枚举（`align_id`/`weight_value`）。
- **验证**：`moon test -p NoahLiu/native-gui/text` 14/14（新增 7 条：`wrap=false` 单行自然宽与 `wrap=true` 的高度对照、省略宽度受钳、粗体不窄于常规、盒内水平/垂直对齐落点与居中、`AttributedText` 属性面与包围盒、`new_with`/`format` 往返）；`moon check text` 零警告；`examples/native-window` 冒烟 49 帧、退出码 0（示例新增居中粗体标题，把 Font/TextAlign/AttributedText 跑了一遍）。

### yoga-mbt · 语料派生项结案：子项 flex-basis 被容器属性遮蔽（Chrome 对照）

- **来源**：语料 `93078300` 派生待查——显式 `flex-basis: 0` + `min-height: 0` 在 auto 高列容器下引擎给 60，按 CSS 推导应为 0。
- **Chrome 对照手法（可复用）**：本地 HTML + 浏览器 MCP 的 `getBoundingClientRect()` 读实高；规范正文用 drafts.csswg.org 页面内 DOM 抽取（`document.querySelector('#anchor')`）比 WebFetch 可靠（后者只拿到目录）。
- **结论一（Blink 口径）**：auto 主轴尺寸 = **各子项假想主轴尺寸之和**（flex base 被 min/max 钳制），growth 完全不参与。证据行：`basis 100 / 内容 300 / grow 1` → **100**（规范 §9.9.1 的 Ideal 算法会按弹性因子放大、Web-compatible 取 max-content contribution 给 300，两者都不符，实现以 Blink 为准）；`basis 0 + min 0` → 0；`basis 0 + min:auto` → 60（内容下限）；`basis auto + max-height 30` → 30；`basis 40%`（容器主轴不定、无参照）→ 60（退回内容）。
- **结论二（根因，一处笔误）**：弹性项构建时基准读成了**容器**的 `s.flex_basis`（应为 `c.style.flex_basis`），子项 flex-basis 于是在整条布局链路上从未生效——这也解释了为什么 basis 怎么设结果都一样。容器 auto 主轴尺寸同样不看子项基准，改由新的 `main_contribution` 承担：确定基准优先并按其确定的 min/max 钳制，auto / 无参照百分比退回内在尺寸；`min: auto` 的内容下限只在 §4.5 弹性解析里生效，不在容器推算里重复探内在尺寸（否则每次容器测宽/测高都多算一遍内在尺寸）。
- **验证**：Chrome 矩阵 7 行（A/C/D/F/G/I/L）逐行一致，落成 `patches_regression_wbtest.mbt` 的常驻用例；yoga-mbt 81/81（含 `display:none` 语料用例与全部既有断言）；bench 无变化（1121 节点 × 500 轮 release：修复前 1.93s、修复后 1.95s，A/B 实测）。

### MoonBit 原生 GUI 栈 · 主题系统首批（色板派生公式 + 变更订阅）

- **面**：`Theme`（20 字段色板）+ `default_theme`/`dark_theme` 预设 + `theme_from_accent`（EP 主题工作台公式：主色保色相、饱和度保底 0.45、明度按模式钳制（浅 0.34..0.52 / 深 0.55..0.72）、hover 浅 -0.09 深 +0.08、`*_light` 浅混白 12%/14%、深混面板底 30%/28%、语义色取固定色相轮 142/36/4/210 且饱和度假借主色（≥0.4）明度随模式、中性色不随主色偏移）+ `theme_current`/`on_theme_change`/`off_theme_change`/`theme_apply` + 20 个 getter + `control_height`（32）+ `entry_ctrl_height`。
- **三处刻意不做（与旧链路的差）**：①原生控件 CSS 下发（旧 `apply_native_theme_css`）——新栈控件全自绘，色板是绘制时唯一来源，没有「原生观感跟系统主题」这回事；②`ffi_repaint_all` 整体重绘兜底——重绘责任随组件批次落到各控件的订阅路径；③`theme_from_system`（跟随系统深浅与主色）依赖系统集成层读取，未接。`sub_bag_begin/end` 批量退订随 relink 层接。
- **色彩数学落点**：`theme/palette.mbt`（hex 解析 / `rgb_to_hsl` / `hsl_to_rgb` / `mix_hex` / `lighten_hex` / `darken_hex`），其中 hex 解析复用 `@render.Color::parse`——即 CSS 口径「8 位透明度在尾」，与 libyue 的 `#AARRGGBB` 分岔已在 G1 条记档；主题串只用 6 位写法，不受影响。
- **从 master 继承的一条实测坑**：`mix_hex(a, b, t)` 的 `t` 是取**前者**的比例，且端点（t=0/1）与非法输入要**原样返回输入串**，不经 `hex6` 往返——`hex6` 输出小写十六进制，会把主题里的 `#2D68C4` 改写成 `#2d68c4`，与原串比较不等。断言按小写写（`theme_from_accent("#FF0000").primary == "#ff0000"`）。
- **测试取向**：不断言派生出的具体色值（换基准盘就整片红），只断**公式不变量**——灰 accent 饱和度被抬到保底、白 accent 明度被钳上限、深模式把暗 accent 抬到下限、hover 的明度方向、语义色色相轮 ±1°、浅底变体的混色方向、非法 accent 回落基准盘；订阅面断「通知走快照」（回调里新注册的不进本轮）、退订幂等、未知句柄空操作、`theme_apply` 后 getter 跟随。
- **验证**：`moon test -p NoahLiu/native-gui/theme` 7/7；`moon check theme --deny-warn` 零警告；全仓红点仍 287 errors / 68 warnings；其余包与 yoga-mbt 未动。

### MoonBit 原生 GUI 栈 · 控件宿主首批（布局树 ↔ 控件树、命中与事件路由）

- **落点**：按计划 §2 的包表放在 `core`（循环/焦点栈同在本包，平台后端在 `win`，绘制契约在 `render`），本层不认识任何平台句柄。这也是 yoga-mbt 第一次成为主包的依赖——`moon.mod` 的 `import` 加了 `"NoahLiu/yoga-mbt@0.1.0"`（工作区里已有该模块，缺这句会报「containing module is not imported」）。
- **坐标口径（只在一处换算）**：yoga 的 `left/top` 是「相对父节点边框盒」的偏移；`relayout`/`relayout_at` 在布局后一次遍历（`collect_abs`）把它折算成窗口坐标的绝对矩形写回控件。命中测试与绘制遍历都只吃绝对矩形；事件交给处理器前再平移为控件本地坐标（本地 (0,0) = 该控件边框盒左上角）。绘制逐层 `translate + clip_rect`，所以控件的 `on_draw` 只写本地坐标、不需要自己裁剪。
- **传播规则**：从命中控件起沿祖先链向上，第一个返回 `true` 的处理器消费掉事件（指针/滚轮/按键同一条规则）。宿主**不存父指针**，冒泡靠命中路径（`hit_path` / 按焦点 id 寻路），因此重挂子树不会留下悬垂的父引用。
- **坑①（控件本体不能比 `==`）**：`Widget` 带闭包字段 → 派生不出 `Eq`，`Option[Widget] == None` 直接编译错（报在 `impl Eq for Option` 的约束上）。做法：控件自增 `id`，本体比较与测试断言一律走 id（命中不到给 -1 的辅助函数）。
- **坑②（隐藏子树留着旧矩形）**：布局引擎碰到 `display:none` 就**不再往下递归**，其后代的 `layout_*` 保留上一轮数值。若 `collect_abs` 不跳过隐藏子树，被隐藏的后代仍可能拿陈旧矩形被命中/绘制。修法：控件不可见时把**整棵子树**的矩形清零后再返回。
- **坑③（`local` 是保留字）**：`let local = ...` 触发 `Warning [0035] reserved_keyword`（本工具链把 `local` 留给未来），零警告门禁下必须改名。
- **真窗口回证（坐标对齐不是纸面结论）**：示例加了一条 200×28 的演示带（四个 50×28 单元格，各自 `on_draw` 画色块、`on_pointer` 只数按下）。`xdotool mousemove --window <id> X 250` + `click 1` 在窗口坐标 200/250/300/360 各点一次 → 退出行 `NATIVE-WINDOW-OK band_h=1/1/1/1`（每格恰一次、无错格无重计），同轮 `frames=49`、`queue=0`、退出码 0。
- **本批未做（G6 余项）**：脏区增量重排 + 测量/内在缓存跨布局驻留；`App` 宿主（把 `win` 的原始事件翻成本层 `PointerEvent`/`KeyEvent`、以及 present 循环的收包方）随声明式层 G7 一起落。
- **验证**：`moon test -p NoahLiu/native-gui/core` 22/22（新增 7 条：绝对矩形折算含父 padding、命中取最深/后画优先/出界与零尺寸与隐藏不命中、指针本地化与三级冒泡与消费即停、带偏移树的本地坐标 (12,45)→(12,15)、滚轮冒泡到容器且出界不路由、按键按焦点 id 定位并冒泡且隐藏后不可达、绘制遍历的平移与裁剪（子控件越界部分不留色）+ 隐藏子树不绘制）；`moon check gui/{core,input,render,text,win}` 与示例 `--deny-warn` 零警告；yoga-mbt 81/81；全仓红点仍 287 errors / 68 warnings。

### MoonBit 原生 GUI 栈 · `sys` 起包（JSON 解析器平移 + 本包自建测试）

- **落点**：新栈的系统能力包按方案 §2 命名 `sys`。第一个资产是零依赖 JSON 解析器——master 线 `yue/vscjson.mbt` 整段搬入（公共名 `VscJson`/`vsc_json_parse`/`vsc_json_get`/`vsc_json_str`/`vsc_json_int64`/`vsc_hex_val`/`vsc_codepoint_at` 一律不改，消费方只把包前缀从 `@yue.` 换成 `@sys.`），搬完根包少一个文件，红点数不变（该文件本就无错）。
- **覆盖补齐**：旧链路里这个解析器**没有独立测试**（覆盖散在 `vscode_history`/`browser_bookmarks` 的用例中），按「新栈每包自建 wbtest」的基线补 7 条：标量与类型门、Int64 毫秒时间戳精度、嵌套结构链式取值、字符串转义（常规 / `\u` / 代理对 / 孤立代理→U+FFFD / 未闭合 / 坏 `\u`）、9 条语法错误全拒 + 松散空白对照、GeoJSON 取点路径、十六进制与码点助手。
- **两条实测口径（写测试时踩出来的）**：① 本工具链的 `String.unsafe_get(i)` 返回的是 **UTF-16 码元**而不是码点——`vsc_codepoint_at("😀", 0)` 给 `(0x1F600, 2)`，这个「代理对合并」助手存在的意义正在于此；② 整值浮点转 Int64 的 2^53 门是拿**取整后的 double 值**判定的，`9007199254740993.0` 这个字面量本身在二进制里就落到 2^53，所以照样放行；要断「超范围拒绝」得用 `1e20` 这一类量级。
- **验证**：`moon test -p NoahLiu/native-gui/sys` 7/7；`moon check sys --deny-warn` 零警告；全仓红点仍 287 errors / 68 warnings。

### MoonBit 原生 GUI 栈 · 富文本区间属性（`rt_*` 会话）· Pango 属性侧三条实测

- **实现形态**：`AttributedText` 只存数据（文本 + 格式 + 基准字体/颜色 + `Array[TextRange]`），每次测量或绘制把会话建到 C 端的 `rt_*` 槽表（`RT_MAX 16`）、用完立刻 `rt_free`——不留长驻句柄，也就不存在「MoonBit 对象被回收而 C 侧还握着指针」。文本与字体名在入口处拷进自有内存（MoonBit 交来的 `Bytes` 指针只在调用期内有效）。
- **区间口径**：**UTF-8 字节下标** `[start, end)`（与编辑内核同源；libyue 的区间是字符区间，属记档的分岔）。越界在建树时钳掉、起点不小于终点的空区间直接跳过、非法 hex 不入表；`set_text` 按旧语义保留区间表。公共面加 `range_count()`（组件层判断「要不要走富文本路径」用）。
- **Pango 侧三条实测**：① `pango_layout_insert_attr` 要 Pango 1.52+，本机头文件里没有它的声明——C 侧按**隐式声明返回 int** 编译通过、把指针截断，症状会是莫名其妙的段错误，改用 `PangoAttrList` + `pango_layout_set_attributes`（1.44 起可用）；② 前景色与前景 alpha 是**两条属性**——`pango_attr_foreground_alpha_new` 只收一个 `guint16`（不是 RGBA 四参），半透明区间要 `foreground_new` + `foreground_alpha_new` 一起插；③ `pango_attr_font_desc_new` 会自己复制描述，本地那份建完即 `pango_font_description_free`。
- **覆盖顺序**：同类型属性按插入顺序生效（后设覆盖先设），用「整段染红 + 首字符改回黑」的像素包围盒验，而不是靠读 Pango 文档。
- **验证**：`moon test -p NoahLiu/native-gui/text` 20/20（新增 6 条：颜色区间落在正确的字形上且其余保持基准色、多字节文本证明切的是**字节**不是字符、字号区间抬高包围盒、后设覆盖先设、越界/空区间/非法色不落像素也不炸、空文本与 `set_text` 后的区间保留）；`moon check text --deny-warn` 零警告；示例标题把开头 `MoonBit` 7 字节换色上屏，冒烟 49 帧、退出码 0；全仓红点仍 287 errors / 68 warnings、yoga-mbt 81/81。

### MoonBit 原生 GUI 栈 · App 宿主与 `TextEditorHost` 收口（`core/app.mbt`）

- **分层落点**：宿主放 `core`（方案 §2 把 App/Window、脏区重绘划给 core），一处收齐「窗口 + `Loop` + 控件树 + 输入法通道 + 上屏」，示例与组件不再各自抄一遍循环。编辑器接缝做成**焦点控件上的五个回调**（`on_key` / `on_commit` / `on_preedit` / `im_context` / `im_cursor`）而不是一个 host 对象——因为 `input` 已经依赖 `core`，core 反向 import input 会成环；G5b 记档的四签名（`process_key`/`commit`/`preedit`/`set_cursor_rect`）逐一对应，只是宿主从「持有一个 host」换成「按焦点投回调」。
- **原始事件口径**（`win` 的 `code` 来自 C 侧 `WmEv`）：`0/1` = 键按下/抬起，`2/3` = 按钮按下/抬起，`4` = 指针移动，`5` = 滚轮。两个数据槽按 C 的 `dx/dy` 命名传到 MoonBit：按钮号走 `button`（dx），滚轮纵向走 `axis`（dy，正=上滚）；`dx` 在滚轮事件里是横向。翻译单独成 `raw_to_event` 是为了无头可测（宿主其余部分要真窗口）。
- **点击接管焦点做成控件树函数**：`Widget::focusable_at(x,y)` 取命中链上从最深向上第一个声明了 `focus_id` 的控件，宿主在 `Down` 时据此改焦点栈（与 Web 同源：点表单控件即聚焦它），控件不必自己碰焦点栈；已在该控件上时**不做任何输入法动作**，否则在同一个框里点一下就把正在拼的字打断了。
- **输入法两条实测（本批真机踩到，都是「串框」）**：① 一个窗口只有一个 `GtkIMContext`，逻辑焦点换控件时必须 `gtk_im_context_reset`，否则前一个框攒下的组合串会在后一个框 commit 出来（注入 `a b Tab c` 实测 `t2='第二个框岸边'`，`岸`/`边` 明明是在第一个框打的）。新增 `Window::im_reset()`（extern + 真实 stub + portable stub 三处同批）；只在**焦点真的换了**那一瞬调，每拍调等于一直打断组合（G5 那条「绝不调 reset」说的是每拍）。② 光 reset 不够：提交文本是在按键事件处理当期就落进 C 侧缓冲的，脚本连发键时 Tab 事件排在若干 commit 之后，晚一拍排空就会把旧控件的提交投给新控件。所以切换点必须先按**旧** id 排空 commit、清旧组合串、再 reset（`App::flush_ime_for_switch(prev)` 在改焦点栈**之前**调用）。修复后同一注入序列 → `t1='hello岸边' c1=11 t2='第二个框曾'`，各归各框。
- **工具链四条**：① `loop` 是保留字（App 的调度字段叫 `sched`，`local` 上一批已记）；② `PointerKind` 带闭包字段派生不出 `Eq`，判定用 `match`；③ `FocusStack::focus(id)` 是**改**焦点的 setter，绘制里判高亮必须用新增的只读 `is_focused(id)`——示例原先在 `on_draw` 里调 `focus(id)`，每帧重绘都把焦点抢给最后画它的那个控件，退出行 `focus=3` 而第一个框永远收不到键，这类「查询/赋值歧义」靠命名与只读助手挡；④ 用脚本改文件时 `str.replace(...,1)` 不命中是**静默失败**（本批开工时那 8 个 `Widget has no field` 错误就是这么来的），必须断言命中次数。
- **注入手法（沿用并补两条）**：键盘必须走 XTEST，即 `xdotool key` **不带** `--window`（带 `--window` 是 XSendEvent，GTK 直接丢弃，见本文「GUI 自动化」条）；鼠标则要写成一条原子命令 `xdotool mousemove --window <id> X Y click 1`——拆成 `mousemove --window` 后单独 `click 1` 本轮实测 `clicks=0`（与既有的「XFCE click-to-focus 拦合成点击」同源）。另：测「字母必须原样进框」的链路时要把 IM 桥摘掉（`env -u GTK_IM_MODULE -u XMODIFIERS`），否则本机 fcitx5 双拼会把 `a b` 变成中文；反过来验输入法串框问题时**保留**默认环境才是有效对照。
- **坐标判据要与被点的布局同帧取（2026-10-12 靠这条撤掉一条假缺陷）**：一条「命中区与渲染错位」的缺陷记录（点某按钮的渲染中心却触发邻居、越靠右偏得越多）复测时不成立——按同一次运行的截图逐盒量出边界再取中心，七个中心全部命中自己。错在**取坐标的那一刻**：截图来自另一轮布局（同一示例在宿主提供整页滚动前后，按钮行整体位移过几十像素），拿旧截图的坐标点新布局当然会「偏」，而偏移量正比于横向位置，看着就像越靠右越歪。口径：注入点击的坐标必须与判据截图取自**同一次运行、同一次布局**（先 `xwininfo` 取窗口原点、再截同一窗口的图量盒边界，然后才点）；命中与绘制在本栈同源（都读 `Widget::rect`，滚动只是让 yoga 布局带上位移），所以「两者错开帧」在代码侧没有通路，出现这种症状先怀疑测量。
- **验证**：`moon test -p NoahLiu/native-gui/core` 28/28（新增 6 条：原始事件翻译表、commit 沿祖先链冒泡且消费即停、preedit 只投焦点控件不冒泡、`im_context`/`im_cursor` 可达性与隐藏后不可达、无 `im_context` 声明的控件不参与输入法轮次、`focusable_at` 取命中链上最近可聚焦者且隐藏不可达）；八包（core/input/render/text/win/icons/theme/sys）`--deny-warn` 全零警告；yoga-mbt 81/81；全仓红点仍 287 errors / 68 warnings。新示例 `examples/native-app`（GUI 侧同类测试的累积页）：冒烟退出码 0、`frames=49`；注入回证 `a b Tab c` → `t1='helloab' c1=7 t2='第二个框c' focus=2`（打字 + Tab 环绕），点按钮中心 (116,128) → `clicks=1` 且焦点接管，持焦点回车 → `clicks=2`，点文本框最左端（窗口 x=17 → 控件本地 x=1）→ caret 归 0、再打 `z` 得 `t1='zhelloab' c1=1`——**「点击定位」这条此前只能靠肉眼的链路首次客观验通**。仍需用户目视：caret 闪烁观感、preedit 下划线、候选窗是否贴组合串末尾。

### yoga-mbt · 脏区增量重排 + 缓存跨布局驻留（YG3e，解 YG3d 留下的 40% 成本）

- **三条判据，缺一不可**：① **变更通知面**——39 个样式 setter 加 `append_child`/`clear_children`/`set_measure`/`set_baseline`/`set_pixel_grid`，第一件事都是 `mark_changed(self)`（全局时钟 +1 并记进本节点 `rev`）；漏标不会报错，只会**安静地拿旧结果**，是最难查的一类 bug。② **子树版本**——`calculate_layout` 入口 `scan_subtree_rev(root)` 自顶向下给每个节点写「子树内最大 rev」，这是 O(节点数) 的整数比较、不做任何测量与数学；有了它「这棵子树自上次布局以来没变」= `subtree_rev == laid_rev`，**不需要父指针**（父指针与 `children` 成引用环，本工具链回收处理不了环，长驻 GUI 里就是稳定泄漏）。③ **入参指纹**——`layout_into` 记上次的 `(avail_w, avail_h, pinned_w, pinned_h)`，跳过要求版本与指纹**都**对上：父容器重排后给子项的可用空间/钦定尺寸可能变，这时子树自身没变也得重算。
- **两条实现坑**：① 复用值必须记 `layout_into_impl` 的**返回值**（像素网格取整前），不能记 `layout_width/height`——后者被 `round_to_grid` 后处理改写，拿它复用会让带网格的树每轮往下漂（`round_to_grid` 仍无条件遍历整树，取整是幂等的）。② 缓存作废从「入口整树清」改成按版本门：`cache_fresh(node)` 见 `cache_rev != subtree_rev` 才清该节点两份缓存——深叶变更会连带祖先的**内在尺寸**缓存失效，靠子树版本而不是回溯清理；另加 `cache_slots = 16` 上限，连续改可用宽时「丢复用不丢正确」，否则每个宽度一条缓存就是无限增长。
- **bench 拆成三场景**（同一份程序，`git archive HEAD` 取改前引擎对照，同机 release，µs/轮 @1121 节点）：`steady` 同参数重复 **3652 → 4**、`one_leaf` 每轮改一个叶子 **3656 → 78**、`resize` 每轮换根宽（全树重排）**3664 → 3602**（全量路径无回归）。debug 同步量 7622→14 / 7570→176 / 7572→5940。**三场景校验值（探针布局结果之和）改前改后逐位相同**——这是跨引擎的独立正确性信号，比任何自说自话的断言都硬。计时用 `moonbitlang/core/env` 的毫秒时钟，只进 bench 包，引擎本体保持零依赖。
- **对宿主的意义**：`App::paint_frame` 每帧 `root.relayout(w, h)` 走的就是 `steady` 那条路（干净整树 4µs/千节点），「每帧重排」因此在 GUI 里成立；G7 把文本 `set_measure`/`set_baseline` 接上后，`one_leaf`（改一行文本）就是实际形态。
- **测试取向与四条工具链写法**：增量布局的唯一正确性标准是**「与同状态从零全量布局逐节点相等」**，10 条用例一律按这个断言（参考树按同一状态新建、只布局一次），不比对中间状态。踩到的：① 同包内顶层标识符必须唯一——测试里的 `snap` 与 `algorithm.mbt` 已有的取整 `snap` 撞名，报的是 `toplevel identifier declared twice`（不是普通重名提示）；② C 式三段循环的第三段只接受 `i = i + 3`，写 `i += 3` 直接语法错；③ `let a = []` 的空数组在零警告门禁下会报 `unresolved_type_variable`，要写全 `let a : Array[(Double, Double, Double, Double)] = []`；④ `UInt64` 的时长再 `.to_double()` 传给收 `UInt64` 的函数会类型门住，单位换算放进被调函数里做。另有一条写法规矩：reparent 用例先按「新父左边距 50」断言 `left == 50`，实际是 **150**（行内 `box_a` 宽 100 + 50 边距）——改成与最终结构直接新建的参考树比对，而不是猜数。
- **验证**：`moon test -p NoahLiu/yoga-mbt` **91/91**（81 条既有零回归 + 10 条增量：同参数复用不改结果、单点变更与全量一致、兄弟子树不重测、根宽变化与参考一致、像素网格 + 跳过仍贴格、隐藏重显不留旧坐标、自身样式变更作废本节点内在缓存、结构变更不被藏、子树跨父搬移、越过缓存槽位上限每轮都等于全量）；`moon check src --deny-warn` 与 `moon check bench --deny-warn` 零警告；主包八包不受影响（core 28/28 等全绿、`--deny-warn` 零警告）、全仓红点仍 287 errors / 68 warnings。

### MoonBit 原生 GUI 栈 · 字体族枚举与回退 + 多字体混排行高（`text` 第三批）

- **枚举的实现形态**：C 侧一次性把族表建进进程内缓存（`pango_font_map_list_families` → **排序 + 相邻去重** → `\n` 拼接的 `GString`，`g_string_free(out, FALSE)` 交出所有权），MoonBit 按「读长度 + 逐字节读」取回（本工具链不能把可写缓冲交给 C）。排序不是洁癖：fontconfig 的枚举次序随装载顺序变、同一族还会带多个 locale 名出现多次，不排就无法写任何稳定断言（本机 682 条）。
- **可用性判定放 C**：`pt_family_available` 在缓存里逐行 `g_ascii_strncasecmp`——族名比较不区分大小写是 fontconfig/Pango 的口径，放 MoonBit 侧就得自己实现同一套 ASCII 折叠，容易与后端不一致。
- **回退口径三条**：① 通用族 `serif`/`sans-serif`/`monospace` 一律算可用（它们不在枚举表里，由 Pango 解析到具体字面族）；② `resolve_family(candidates)` 按 CSS `font-family` 列表取第一个可用者，全不可用退 `""`（空族名就是「跟随系统默认」，测量/绘制都按它走）；③ `Font::resolve` 只在族名**不可用**时才退空族名，可用名与通用族原样保留——保留请求名才量得到那一族的度量。
- **一条实测纠正了预期**：不可用的族名并不会让测量失败，Pango 直接退默认族照样给数（`line_height_multi([base, Font::new("不存在的族", 13.0)])` 与给 `""` 的结果一致）。所以「回退」的价值在**行高口径确定 + 族名可诊断**，不是防崩溃；写测试时按「会 None/会炸」去假设反而会写出假绿断言。
- **混排行高定案**：行盒 = 逐字体上抛的 **max ascent + max descent**（每个 inline 盒按自己的字体贡献，两侧最大值可以来自不同字体），**不是**「取字号最大的那一份的行高」。实现上把 `pt_font_line_height` 已有的 ascent/descent 拆成 `FontMetrics`，`line_height_font`/`line_ascent_font` 改成它的投影（顺手去掉两处重复的 C 调用拼装），`line_height_multi(fonts)` 做聚合，`AttributedText::line_height()` 把基准字体与每条区间字体一起喂进去。断言取两条硬性质：行高**盖得住** `get_bounds_for` 的绘制高度；基准字体的行高**装不下**区间里 28px 的内容（盒矮了会裁字，这正是组件层最需要的判据）。
- **工具链六条**（都是本批写测试时踩的）：① **MoonBit 的 `String` 序是 shortlex——先比长度、再比码元**，`<` 与 `compare` 都**不是**字典序（`"Agency FB" < "Aharoni"` 为假、`"b" < "aa"` 为真）；要字典序用 `String::lexical_compare`，要忽略大小写用 `compare_ignore_ascii_case`。族表断言就是踩在这上面：C 侧明明已按字典序排好，`list[i-1] < list[i]` 大面积假红。② `Int::to_char()` 返回 `Char?`（要 `unsafe_to_char`），拼进字符串会得到 `"Some('x')"` 这种静默错值（编译期只有一条 deprecated 警告）。③ 本工具链的 `Buffer` 没有 `push`/`push_char` 可用名（写字符是 `write_char_utf8`），短串直接 `+=` 更省事。④ `Array[Byte]` 没有 `freeze`/`to_fixed_array` 通往 `FixedArray[Byte]`，要递给 C 当 `Bytes` 读就一开始用 `FixedArray::make(n, b'\x00')` 按下标写。⑤ `@utf8` 的包路径是 `moonbitlang/core/encoding/utf8`，写成 `moonbitlang/core/utf8` 报 `Cannot find import`。⑥ MoonBit 没有单引号字符串（`''` 是 lexer 错）。
- **验证**：`moon test -p NoahLiu/native-gui/text` 28/28（新增 8 条：族表非空/有序/去重/无分隔符、可用性含大小写翻转与通用族与空名、`resolve_family` 取第一个可用与全不可用退空、`Font::resolve` 与 `resolve_fonts` 保留字号字重样式、`font_metrics` 与既有两个口径同源且 28px 升距大于 13px、`line_height_multi` 的聚合规则与顺序无关且幂等、`AttributedText::line_height` 里颜色区间不掺和而字号区间掺和、行高盖得住绘制高度）；`moon check text --deny-warn` 零警告，八包全零警告；core 28/input 10/render 40/icons 4/theme 7/sys 7/yoga-mbt 91 全绿；全仓红点仍 287 errors / 68 warnings。`examples/native-app` 加字体行（同段文字两个盒子，盒高分别取基准与混排 `line_height()`，右盒 visibly 更高）：冒烟退出码 0，状态行 `fam=682 use='monospace' lhm=42`；同轮 xdotool 注入序列结果与上一批逐字段相同（`clicks=2 t1='zhelloab' c1=1 t2='第二个框c' focus=1`）。**待用户目视**：新增字体行里右盒是否把 28px 的字完整包住、左盒没有多余空白。

### MoonBit 原生 GUI 栈 · 声明式地基（`Node`/`mount`/Store/signals/relink 跑在 Widget 上）

- **换的只有一件事**：master 的 `Node { mount : (View) -> View }` 变成 `Node { mount : (Widget) -> Widget }`——「构造器只建树、mount 才实例化控件并挂到父控件」的语义与「children 天然异构」的存在类型形态一字不改。地基件：`node_of`（已有控件包成节点）、`node_of_new`（新建 + 配置回调，回调**返回控件**，方便链式再建子树）、`mount_children`、`App::mount(children)`（内容入口，挂完标一次脏）。
- **relink（重挂）三条定案**：① **原位替换**——新一代先挂到 parent 尾部，再 `move_child` 挪回旧一代原先的下标，兄弟项顺序与坐标不受被换掉的这项影响；为此给布局引擎补了 `Node::insert_child(index)` / `Node::remove_child_at(index)`（越界钳制 / 越界返回 None 且不改树），控件层补了 `Widget::insert_child` / `remove_child` / `index_of` / `move_child`（控件表与节点表两层同步，摘除按 `Widget.id` 认身份——带闭包字段的控件比不了 `==`）。② **旧链路 Windows 的两条规避不需要**：master 的 `bind_node` 要 `post_task` 推迟一拍 + 重挂后 `refresh_layout` 整窗重算，防的是 native 侧 remove+add 之后 yoga 根不重算、hit-test 恒命中旧矩形（真机实证「点一次后全窗点击失效且不可逆」）。本栈的命中矩形每帧从布局结果重取（`App::paint_frame` → `relayout` → `collect_abs`），没有那个洞——注入回证：连点三次声明式行之后再点按钮，计数照常 +1。③ **每一代订阅进回收袋**：重建前 `sub_bag_discard(gen)`、挂载期 `sub_bag_begin/end` 收本代，死订阅不随重建次数累积；顺带的性质是**嵌套 `bind_node` 也正确**——内层在自己的 `mount` 里注册的 `sig.subscribe` 落在外层袋内，外层换一代时整袋退场。
- **重绘回路**：`set_repaint_hook` / `invalidate()` 是**进程级单槽**，`App::new` 装自己的 `schedule_paint`（置脏 + `@win.wake()`）；没装钩子（无头测试）时 `invalidate()` 空操作，组件层因此可以无条件调。已知限制：一进程一宿主，多窗口要等宿主层能「按控件找所属 App」再升级——当前没有多窗口消费者，不写猜测性实现。
- **平移纪律**：信号内核与 `Store` 自 master `yue/signals.mbt` / `yue/store.mbt` 逐行搬进 `core/signal.mbt` / `store.mbt`（本就零平台依赖，公共名 `Signal`/`Store`/`batch`/`sub_bag_*` 一律不改），19 条既有测试整段带过来（自动依赖收集、条件分支只依赖实际读到的信号、钻石依赖收敛、batch 合并、订阅句柄精确退订、袋内整代退订 + 无袋退化）。
- **两条写法坑**：① 同包多个 `_wbtest.mbt` **共享顶层助手名**，重复定义不报 `declared twice` 而是让**先定义的那个变成 unused**（我在 `node_wbtest.mbt` 里重写了 `sized`，`widget_wbtest.mbt` 那份立刻报 `Unused function 'sized'`）——写测试前先 grep 同包已有助手，别造第二个。② `node_of_new` 的配置回调若声明成返回 `Unit`，闭包体里用 `sized(w, ..)` 这类返回控件的助手会直接类型不匹配；返回 `Widget` 既省掉 `let _ =`，又允许回调里再建子树。
- **验证**：`moon test -p NoahLiu/native-gui/core` **53/53**（28 既有 + 19 平移信号/Store + 6 条声明式：`mount_children` 顺序与坐标、`bind_node` 原位换棵且兄弟项坐标跟随、旧代订阅整袋退订（重建 5 次源上仍只有 1 条）、重挂后 parent 里始终只有一棵不留半棵、`swap_node` 预建两棵只改显隐且隐藏那棵矩形清零、无钩子时 `invalidate` 空操作）；yoga-mbt **92/92**（新增原位增删：摘中间项再插回与参考树逐节点一致、越界不改动树）；八包 `--deny-warn` 全零警告，全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-app` 新增声明式行，点击即 `Store.update` → 原位重挂）：`decl=3 kids=6/6`（根子项数恒定，说明没有泄漏也没有重复挂），同轮 `clicks=1`（重挂三次后按钮命中照常）、`t1='hellox' c1=6`（Tab 环绕与打字照常），退出码 0。**待用户目视**：声明式行底色随点击奇偶切换（证明确实换了一棵新树，而不是只改文本）。

### MoonBit 原生 GUI 栈 · 控件交互地基（悬停/按下归属、指针捕获、回调不得自捕获）

- **状态归宿主，控件只读**：`Widget` 加 `hovered`/`pressed` 两个字段，由宿主在每次指针事件里按命中与捕获统一维护（`set_hover(id)` / `set_press(id)`，只在归属**变化**时各走一趟树），控件在 `on_draw` 里直接读。旧链路的 `hover_group` 是轮询式（libyue 不给 move 事件，只能定时问鼠标在哪），本栈有完整路由，所以进入与离开都是事件：悬停者换了就给上一个补发 `Leave`——「只有进入没有退出」的悬浮提示形态在这里不成立。
- **按下即进入捕获期**：分发决策做成纯函数 `route_pointer(root, ev, hover_id, capture) -> (新悬停, 新捕获, 是否消费, 是否变了)`，`App` 只保存并写回两个状态。规则：`Down` 的命中者标 pressed 并成为捕获者，之后 `Move`/`Up` 一律投给捕获者（沿它到根的路径投递，本地坐标照常折算）；`Up` 清按下态、解除捕获，并**按抬起位置**重判悬停；捕获期悬停不动。为什么必须做：不做捕获，指针一离开控件就再也收不到 `Up`——按下态卡死只是 mild 症状（实测表现是控件常驻高亮），拖选与「拖动插入点」这两条输入框语义直接没有依据。等价于 Web 的 `setPointerCapture`。
- **回调不得捕获控件自身（引用环纪律）**：`on_draw` 首参改成 `Widget`、`im_cursor` 改成收 `Widget`，控件读自己的 `rect`/`hovered`/`pressed` 由参数拿，句柄不再进闭包。原因是本栈控件**持有**自己的回调表，闭包再捕获控件就是引用环，计数式回收断不掉环；一次性示例看不出来，`bind_node` 每重挂一次漏一棵树就是稳定泄漏。示例与测试的全部绘制回调随签名改完。
- **一条被实测纠正的预期**：`display:none` 的兄弟项会**上顶**（列容器 auto 高按可见项算），所以「隐藏项原来占的那片区域」命中的是顶上来的兄弟而不是父容器——我第一版按「命中父控件」下断言，`route_pointer` 直接给了兄弟的 id。含义是组件层不必为隐藏项额外清理悬停态，位置自然被活着的那一项拿走。
- **注入手法补一条**：拖动序列写成 `xdotool mousemove --window <id> X Y mousedown 1` 原子按下，随后 `xdotool mousemove --window <id> X2 Y2` 移动、`xdotool mouseup 1` 松开（不带 `--window`，XTEST 在当前点位松开）。实测带内按下、带外松开，捕获带仍收到抬起。
- **验证**：`moon test -p NoahLiu/native-gui/core` **59/59**（新增 6 条：悬停跟随与 `Leave` 补发、捕获期移动与抬起都投给按下者且悬停不动、点在空白处不进捕获也不炸、隐藏控件不参与悬停且兄弟上顶后命中跟着变、`by_id` 与 `dispatch_pointer_to` 按身份投递（坐标不参与判定）、滚轮沿用同一冒泡规则）；八包 `--deny-warn` 全零警告，yoga-mbt 92/92，全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-app` 新增「捕获带」，绘制态直接读 `w.pressed`/`w.hovered`）：带内按下 → 拖到 (200,245) → 拖到 (300,100) 松手 → `band=d1/u1/m3`（**在带外松手仍收到抬起**），同轮按钮 `clicks=1`、声明式行 `decl=2 kids=7/7` 照常，退出码 0。**待用户目视**：拖动过程中带子保持按下色（橙）、离开后恢复常态而悬停色不再跟着指针跑。

### MoonBit 原生 GUI 栈 · 组件层首批（新包 `ui`：文本测量回灌布局 + 容器/标签/分隔线/图像/图标/按钮）

- **为什么不写进 `yue/components`**：那个目录是旧链路的组件实现（引用 `@yue` 根包与 `@declarative`，属全仓 287 个红点的主要来源）。新栈每批只把**要保留的语义**重做，若与旧文件同包，`moon check <包> --deny-warn` 这条分包门禁就永远无从执行（旧文件的错会一起报）。故新组件层另起 `ui`，旧包按批替换/删除，G7 收口时一并结算。
- **文本测量回灌布局引擎**（G7 欠的那块）：`attach_text_measure(w, src)` 给节点同时设 `set_measure`（尺寸来自 `measure_font`）与 `set_baseline`（`line_ascent_font`），于是文本第一次能参与 `align-items: baseline` 的真实排布，`label` 的宽高也就是 Pango 给的真尺寸。两条被实测纠正的断言：① **列容器默认 `align-items: stretch` 会把标签宽度拉到整行**——要看出测量给的真宽度，父项必须 `FlexStart` 或标签自带显式宽（我第一次直接断言测量宽，拿到的是 240 而不是 70）；② 基线对齐时**顶边差 = 两个 ascent 之差**（大字号更靠上），我把差写反过一次。min-content 探询（请求轴 `Some(0.0)`）暂按「不受约束」处理，属记档近似（等接进省略号自适应再细化）。
- **指针回调也要收控件本身**：`on_pointer` 首参改成 `Widget`（与 `on_draw` 同一条引用环纪律）。按钮需要 `self.rect` 才能判「松开是否仍落在自己范围内」——捕获期保证按钮一定收得到在别处松手的那次 `Up`，但只有拿到自己的矩形才分得清内/外。
- **两处与 master 的命名分岔**（记档，不做兼容层）：① `button(type="text")` 的 `type` 是 MoonBit **保留字**，作参数名直接语法错，换成 `kind : ButtonKind`（`Primary`/`Border`/`Text`）；② 禁用态配色暂用 `fill_hover` 底 + `text_secondary` 字，真正的 disabled 色板随主题批补进 `Theme`（现在 20 个字段里没有它）。
- **主题跟随做成进程级单订阅**：组件挂载时调 `watch_theme()`（幂等），主题变化 → 一次 `invalidate()`。不做按控件订阅：`invalidate` 本就是全局的，逐控件订阅会让每次重挂都留下一条死订阅，换不来任何精度。颜色一律在 `on_draw` 里现取（不在建树时固化），主题切了下一帧就是新色。
- **文本绑定的对应物**：`label_dyn(sig : Signal[String], ...)` 就是旧链路 `bind_label` 的位置——就地改文本 + 重设测量回调（节点标脏）+ 请求重绘，不重建子树；订阅退订经 `@core.sub_bag_register` 进本代回收袋（该函数为此从包内提到公开，组件层的清理都走它）。
- **验证**：新包 `moon test -p NoahLiu/native-gui/ui` 7/7（标签尺寸来自测量且随信号重测、两字号基线对齐的顶边差、按钮松开在内/在外两种结果、禁用态不消费也不回调、悬停态换色且文本仍落在盒内、容器/分组/分隔线几何与横线撑满、图标按尺寸占位并真出像素 + 图像缺文件不崩）；**九包**（core/input/render/text/win/icons/theme/sys/ui）`--deny-warn` 全零警告，core 59/input 10/render 40/text 28/icons 4/theme 7/sys 7/yoga-mbt 92 全绿，全仓红点仍 287 errors / 68 warnings。真窗口回证：`examples/native-app` 底部新增一行全用 `@ui` 构造器（label + 竖分隔线 + icon + `加一` 按钮 + `禁用` 按钮），窗口加高到 420×372；xdotool 注入 `mousemove --window 135 278 click 1` 两次 → `comp=2`，再点禁用按钮那一段 → 计数不涨且 `decl=0`（禁用态确实不消费事件），`kids=8/8` 根子项数在多次重挂后仍恒定，退出码 0；同轮既有回证（打字/Tab/点击定位/捕获带）未退化。**待用户目视**：组件行的悬停/按下色、竖分隔线是否真的撑满行高、图标与文本在同一行的基线观感。

### MoonBit 原生 GUI 栈 · 表单控件首批，以及两处「只有截图才看得见」的渲染缺陷

- **缺陷一：文本无视控件原点**。文本层（`pt_draw*`/`rt_draw`）一直是「拿 `Bitmap.data` 自建 surface 画字」，那条路径**不经过 Painter 的 CTM 与 clip**——于是宿主每层 `translate + clip_rect` 对文字完全无效，真窗口上所有控件的文字都挤在窗口左上角（截图见 `控件首批` 前后对照）。修法是把 Cairo 会话交出去：render 桩新增 `void *cr_session_context(int64_t id)`（返回该会话的 `cairo_t*`），text 桩新增 `pt_draw_box_cr` 与 `rt_draw_cr`，在**调用方的上下文**上 `cairo_save → set_source_rgba → move_to → pango_cairo_show_layout → cairo_restore`（save/restore 保住调用方的 source 与裁剪，画完不污染）。MoonBit 侧对应 `Painter::cairo_id()`、`@text.draw_box_at / draw_at / draw_text_at`、`AttributedText::draw_at`。旧的 `draw_to/draw_in_box/draw(target,…)` 保留（离屏自绘、图表缓冲还要用）。
- **缺陷二：嵌套绘制重复累加偏移**。`Widget::paint` 逐层 `p.translate(self.rect.x, self.rect.y)`，而 `rect` 是**绝对**矩形——于是第二层起把祖先的偏移又加了一遍（第二行的文字直接掉到窗口外）。改成 `paint_at(p, ox, oy)`：只平移「自己相对已平移原点」的差值，并把本控件的绝对原点传给子层。
- **为什么前面几批没发现**：批次1 的绘制用例里中间那层控件正好在 `(0,0)`，绝对=相对，测试自然通过；示例的状态行只报计数与文本，不报像素。**结论：GUI 的「退出码 0 + 状态对」不等于画面对**——累积验证页从此留两条机器可查的路：`NATIVE-APP-RECTS` 几何行（每个根子项的 `x,y,wxh`，注入坐标按它取，不再靠猜截图）+ 需要看画面时 `import -window <id> x.png` 截图核对。
- **跨静态库的链接**：text 桩引用了 render 桩的符号，`moon test -p .../gui/text` 在**链接期**报 `undefined reference to cr_session_context`（编译期无感）。按 AGENTS 规则 1，链接参数只在 `scripts/prebuild.py` 改：text 的 `link_flags` 追加 `-lrender_cairo_stub`（消费者在前的顺序即可）。
- **禁用态必须是单元而不是布尔**：测试抓到步进器的真 bug——`disabled` 若在建树时固化进闭包，值走到边界后 `-`/`+` 的禁用态仍停在挂载那一刻。改为 `Enabled { mut off : Bool }`，绘制与事件每次现取；组合控件（复选行、开关、步进器两侧）共用同一个单元，`set_disabled(cell, v)` 随时改。
- **拖动状态由组件自持**：滑块用 `dragging : Ref[Bool]` 而不是读宿主的 `pressed`——宿主的 `pressed` 只在真实事件流里置位，组件在**任何**投递路径下都要能把拖动做完（否则无头用例根本测不到拖动）。
- **两条坐标口径（本批 4 条用例一起踩的）**：① `dispatch_pointer` / `dispatch_pointer_to` 收的是**窗口坐标**，投递时才折算本地——测试里传局部坐标会静默不命中（表现为「点了没反应」）；② 按坐标命中的 `dispatch_pointer` **投不进来自控件外**的拖动，出界移动必须走 `root.dispatch_pointer_to(w.id, ev)`（等价宿主的捕获期投递）。
- **工具链写法七条**：`match` 多主语必须写成元组 `match (a, b) { (Some(x), y) => ... }`；`Double::clamp` 要 labelled `min=/max=`；`Int::to_char()` 返回 `Char?`（要 `unsafe_to_char`，否则静默拼出 `"Some('x')"`）；`String.split` 给的是 `Iter[StringView]`、`StringView::to_string` 已弃用改 `to_owned`；`Array[Byte]` 没有 `freeze`/`to_fixed_array`，要递给 C 当 `Bytes` 就一开始用 `FixedArray::make`；`Option[(A, B) -> R]` 结尾的 `]` 丢了会报「unexpected token infix」这种莫名错；跨行续写不能把 `+`/`&&` 放行首（MoonBit 按行尾断句），`type` 是保留字不能作参数名。
- **验证**：`moon test -p .../gui/ui` 15/15（新增 7 条：复选点击/再点/出界不触发/禁用不消费、单选组按项写值且点已选不改、开关尺寸固定且绘制跟随 Store 现值、滑块按下取值+出界拖动+步长吸附+禁用不消费、进度条按值填充、步进器夹取且边界自动禁用、Store 订阅随回收袋退订（重挂 5 次后 `sub_count=0`，不套袋则常驻 1 条）；另加两条渲染回归：文本随控件原点落位并被裁剪、富文本经会话绘制落位在平移后的盒内）、`text` 29/29；九包 `--deny-warn` 全零警告，core 59/render 40/icons 4/theme 7/sys 7/yoga-mbt 92 全绿，全仓红点仍 287 errors / 68 warnings。真窗口注入（坐标取自 `NATIVE-APP-RECTS`）：`form=true/false/90/1`（复选切真、开关切假、滑块拖到 90 且按步长 5 吸附、步进 +1），`decl=3 kids=9/9`（声明式原位重挂未退化），`band=d3/u3/m3`（三次带外松手都收到抬起），`clicks=2 t1='zhelloab' c1=1`（打字/Tab/点击定位），退出码 0；截图复核：标题、两个输入框、计数按钮、混排行高盒、组件行与表单行全部落位正确。

### MoonBit 原生 GUI 栈 · 输入框全语义（`ui/entry.mbt`）

- **形态**：文本状态的唯一权威仍是 `@input.Editor`，组件不另存一份；`Store[String]` 只是它的对外投影——编辑后回写 Store，Store 被外部 `set` 时经订阅回灌内核（`subscribe_id` + 回收袋退订，重挂不留死订阅）。与宿主的接缝就是地基那五个回调，输入法四条件由 `App::pump_ime` 统一满足，组件只提供 `im_context`（已提交文本 + 字节 caret）与 `im_cursor`（候选窗定位矩形）。
- **焦点高亮改由宿主同步**：新增 `Widget.focused` 与 `Widget::set_focused_by_focus(focus_id)`，`App::paint_frame` 每帧画之前同步一次。原因与 `hovered`/`pressed` 同理——焦点栈只记 id，组件要的是「那个 id 是不是我」，让每个组件自己去问焦点栈既拿不到栈、又会把 `core` 的焦点结构漏进组件层。
- **只读白名单要按 keysym 族来写**：第一版按「65288..65300 是导航」放行，结果**退格（65288）被当成导航放过**，只读框照旧删字（测试抓到）。真实口径：方向键/Home/End/PageUp-Down 在 **65360..65367**，退格 65288、删除 65535 属编辑键。定案为「带 Ctrl/Shift 的组合、65360..65367、Tab 放行；退格/删除/可打印字符一律不吃」。
- **双击判定**：两次 `Down` 间隔 < 400ms 且位移 < 4px（时钟用 `@core.now_ms()`，是 `@win.now_ms()` 的转派）。**副作用要记档**：连续快速点击会被判成双击——无头用例里「按下-松开-再按下」验证拖动时，第二次按下实际走了选词分支，断言要按这个语义写。
- **CJK 选词是当前近似的点**：`is_word_byte` 把 `>= 0x80` 全算词内（与内核同口径），所以中文里双击会把**连续的整段中文**选中（真窗口实测：`组件框ab` 末尾双击选中 `组件框ab` 整段，替换后剩 `Q`）。ASCII 侧正常（空格分词，`组件框ab c` 双击只选 `c`）。要不要按 Blink 的词典分词收敛，等布局那套 Blink 对照手法排到文本时一并测，先记档不猜。
- **拖动选区**：按下记锚点，捕获期的 `Move` 用 `select_range(anchor, byte_at_x(x))` 扩选——指针拖出框外也连续（这是宿主捕获期的第二个消费者）；`Up` 结束拖动，之后再 `Move` 不跟手（用例断言 caret 不变）。
- **观测通道的取巧处**：内核句柄不外露（文本权威在组件里），无头用例改从两条公开面观测——`w.im_context()` 给「文本 + caret」，以及「打字会替换选区」这一行为本身（选区对不对，看替换后的文本）。比为了测试开一堆 getter 干净。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **25/25**（新增 10 条输入框用例：键入回写 Store 与退格/undo、commit 落文本而 preedit 只进绘制、点击最左/最右定位、双击选词、拖动全选与松手不跟手、Shift+箭头扩选 + Ctrl+A/C/V 内部剪贴板、只读放行导航与复制、密码遮罩 Store 存原文、placeholder 有像素且 Store 为空、Store 外部改动回灌内核 + `focused` 由宿主同步）；九包 `--deny-warn` 全零警告，全仓红点回到 287 errors / **68** warnings（中途一度 69，是测试里一个未用变量）。真窗口注入（`examples/native-app` 新增 `@ui.entry` 行，`focus_id=4`）：点进框 → 打 `ab c` → 末尾双击 → 打 `Q` → `Home`+`Shift+End`+`Delete`+`Ctrl+Z` → 状态行 `t3='组件框ab Q'`、`focus=4`，退出码 0；截图复核组件框落位与描边正常。**待用户目视**：caret 闪烁（组件的 `caret_on?` 由调用方时钟驱动）、preedit 下划线、候选窗是否贴组合串末尾。

### MoonBit 原生 GUI 栈 · 显示族首批（`ui/display.mbt`：标签 / 徽标 / 头像 / 分隔线 / 提示条 / 卡片 / 描述列表 / 空状态 / 结果页 / 折线进度）

- **与 master 的差一条（记档）**：CSS 风格的 `style=[("marginRight", 8.0)]` 通道还没接（随主题批的 style 通道一起做），这批只留**类型化**参数；语义色枚举 `SemanticType`（Primary/Success/Warning/Danger/Info）与 `type_color`/`type_light_color` 保留同名，色值现取 `theme` 的五档主色 + 五档浅色（主题首批已就位，不必新增字段）。
- **两条自绘组件的通用规矩（本批踩到并写进代码注释）**：① **绘制回调不改布局**——`statistic` 第一版在 `on_draw` 里 `set_width(按测量宽)`，等于让 paint 变成布局的写入方（同一帧内布局与绘制互相触发，且脏区增量重排的指纹判定会被自己搅乱）；宽度必须在挂载时按测量算定。② **控件高度要装得下自己的字**——折线进度的百分比列先按「和条同高 8px」占位，11px 的字被裁成半截（截图才看得出来）；文字类节点的高度至少给到字高，容器按最高子项撑开即可。
- **可关闭提示条的热区口径**：整条 alert 都消费按下（避免点击穿透到下层），但只在**右上角 24×24** 触发 `on_close`——热区判定用本地坐标（`ev.x >= rect.w - 24 && ev.y <= 24`），这条在捕获期下依然成立（松开一定回到本控件）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **33/33**（新增 8 条显示族：五档语义色互不相同且都是合法 hex、标签与徽标按内容定宽且超上限显示「99+」、头像首字符出像素、带文字分隔线整宽且两侧有线、提示条有描述时更高且关闭只在热区生效（非热区点击不计数）、卡片带标题多占两行（标题+分隔线）、描述列表行数按条目算、空状态/结果页真出像素、折线进度两列且填充随 Store 变化）；九包 `--deny-warn` 全零警告，全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-app` 新增显示族区块，几何行给出坐标）：点提示条非热区 → `closed=0`，点右上角两次 → `closed=2`，同轮组件按钮 `comp=1`、`kids=11/11`，退出码 0；截图复核标签三色、徽标 7/99+/圆点、头像「刘」、「或」分隔线、提示条左侧色条与描述、进度条与百分比全部正常。

### MoonBit 原生 GUI 栈 · 显示族收尾（时间线 + 轮播，自转走宿主延时通道）

- **新增通道：进程级延时（`core/loop.mbt` 的 `set_timer_hooks`/`set_timeout`/`clear_timeout`）**。组件要的是「过一会儿跑一次」，不该知道自己属于哪个宿主，所以与 `set_repaint_hook` 同款进程级单槽：`App::new` 把两个函数转派给自己的 `Loop`（`timer`/`cancel`），组件只调 `@core.set_timeout(ms, f)`。**没有宿主时 `set_timeout` 返回 0 且不执行**——组件照常工作，只是不自动推进；无头测试于是可以自己装一条通道把回调拿到手手动派发，轮播的自排链因此能被确定性地测到（不必等真实时钟）。
- **轮播三条形态定案**：① 面板**全部预建**、切页只翻 `Widget::set_visible`（与 `swap_node` 同一理由：不销毁子树就不留悬垂回调，也不必重挂）；② 箭头悬停底色直接读**宿主维护的** `Widget.hovered`，master 那两条 `on_mouse_enter/on_mouse_leave` 在本栈省掉——交互态归宿主统一置位，组件只读；③ 悬停暂停靠本控件在**父链**上收到的 `Move`/`Leave`（事件从最深命中控件往上冒泡、第一个返回 true 者消费），因此若页面内容把移动与离开都吃掉，暂停就收不到信号——这条不是猜测而是路由规则的必然结果，故另开 `carousel_pause(handle, v)` 让调用方自己接管。
- **自排链的回收口径**：一次性延时 + 回调里排下一拍，句柄存进 `CarouselHandle.timer`；`carousel_stop` 既置 `running=false` 又 `clear_timeout` 取消待触发那次。测试实测到边界语义：stop 之后**已经在队里的那一拍仍会被跑一次**，但 `running` 兜底让它既不切页也不再排下一拍——所以「取消句柄」不能当唯一保险，`running` 标志必须同时存在。
- **时间线的竖线口径**（EP 原样）：首行从点心起、末行到点心止，中间行整条贯通；行高固定，绘制只写本地坐标（宿主逐层 `translate + clip_rect`，控件不必自己裁剪）。
- **两条工具链/测试实测**：① 无载荷枚举的同名构造器在跨类型字面量里会 `The constructor Primary is ambiguous`（本仓库 `ButtonKind` 与 `SemanticType` 都有 `Primary`），给数组字面量标注元素类型即可，别改成全限定名污染断言；② 指示点只有 8×8，注入点位按「行高一半」取到 `y+12` 就落到热区外，症状是「点了没反应」而**没有任何报错**——按坐标注入前必须回读该控件自己的 `rect`（本例几何行因此补了 `NATIVE-APP-CAR`/`NATIVE-APP-AUTO` 两行，直接给箭头、末指示点与自转面板的矩形）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **37/37**（新增 4 条显示族收尾：时间线逐行等高 + 首行点上方无线/末行点下方无线/点与线不同色、轮播预建三页只显当前页 + 箭头与指示点切页 + 越界回绕、自转走宿主通道（暂停不前进但链不断、stop 取消待触发）、空条目不崩）；`moon test -p NoahLiu/native-gui/core` **60/60**（新增 1 条：未装通道时 `set_timeout` 返回 0 且不执行、装完后 `set_timeout`/`clear_timeout` 成对转派、句柄 0 不转派取消）。九包 `--deny-warn` 全零警告、`yoga-mbt` 92/92、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「显示族收尾」区块，窗口加高到 560×900）：注入「右箭头 → 末指示点 → 左箭头」得 `car=2`（这条下标唯一，能同时证明两处箭头与指示点各自生效），基线自转 `auto=6`，把指针停在自转轮播上不动 → `auto=2`（悬停暂停实测）；截图复核时间线三色点与贯通线、两条轮播的箭头/指示点高亮均正常。

### MoonBit 原生 GUI 栈 · 日期族首批（值模型 + 自绘日历面板，「今天」走平台日历时间）

- **新增平台读数 `wm_local_date`（`win` 两个 C 桩 + `ffi.mbt` extern + `window.mbt` 公共 API，`core` 转派成 `local_ymd()`）**：日历要的是**日历时间**，而本栈已有的 `now_ms()` 是 `CLOCK_MONOTONIC`（单调钟，只给循环做时基），拿它推日期会得到一个稳定但错误的数字。C 侧用 `time()` + `localtime_r` 走系统时区，打包成 `年*10000 + 月*100 + 日`；**失败/便携桩返回 0**，`core` 翻成 `(0,0,0)`，组件层 `today_date()` 才退到 1970-01-01——分层上「平台给读数、上层决定退路」，本层不猜日期。
- **`today` 做成可显式传入的参数**（`calendar_t(today? : DateYMD = today_date())`）：默认走平台，测试传确定日期。否则「10 月 1 日落在第几格」这类断言会随运行当天漂移，等于没有断言。
- **42 格网格数学外置成纯函数 `month_grid(y, m) -> Array[(DateYMD, Bool)]`**（比 master 多一份）：面板只负责画与点，网格规则（首格前的上月尾巴、月末后的下月头部、本月格数=月长）脱离控件就能测，日期选择器与区间选择器后面共用同一份，不必各自再推一遍。
- **42 格一次建好、切月只改数据**：面板结构恒定，命中矩形不会因增删子控件而错位（`Widget::hit_path` 每帧从布局结果取矩形，但重建子树仍会让「按下-松开」跨代的控件对不上）；`rebuild_grid` 只写每格的 `Ref[DateYMD]`/`Ref[Bool]` 再 `invalidate()`。
- **选中语义走 Store 现取，不缓存副本**：`state_of` 每次画都读 `value.get()`（无 Store 才读自持的 `sel`），所以外部 `v.set(...)` 立刻换掉实心方块，不需要「订阅后手动刷新」这一步——master 的 `refresh()` 回调链在本栈被「画法现取」替掉，订阅只负责请求重绘（`follow_store`）。
- **松开才选中 + 跨月格不可选**：格子的 `Down` 只在 `in_month` 时消费（跨月格连按下都不吃，事件继续往上冒），`Up` 还要判松开仍落在本格内（捕获期把松开投回被按下的格，出界即不算一次）。
- **两条工具链实测（本批写测试时踩到）**：① `(x) -> Bool { ... }` **不是**闭包字面量（那是函数类型注解），`Array::filter` 要写 `fn(x) { x.1 }`，写错时症状是一串莫名的「cannot infer / unbound / Parse error」连锁报错；② 给值类型 `derive(Eq, Show)` 在本工具链里 `Show` 已弃用（提示改用 `Debug`），而 `derive(Eq)`/`derive(Debug)` 又会报 `implicit_impl_as_method` 弃用告警——零警告门禁下不划算，**断言一律走字符串观测**（`format()`、格子状态名），既不给组件加派生、也让失败输出更好读。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **44/44**（新增 7 条日期族：闰年/月长/星期（Sakamoto 三个锚点：2026-10-11 周日、2000-01-01 周六）/月份进退含 ±12 与 15 个月、格式化补零与时间钳制与区间端点顺序不限、42 格网格（10 月首格 2026-09-27、第 5 格 10-01、末格 11-07、本月格数=31；闰年 2 月 29 格；1 月跨年头格落到上一年 12 月）、本地今天必须是真实年份（证明走的是日历时间而非单调钟）、面板点格写 Store + 跨月格不可选 + 格外松开不算一次、切月后可选日期跟着换 + 选中格画实心方块（比对该处是否仍是面板底色，因为面板底不透明）、外部改 Store 即换选中格、区间格子映射端点/中间/半开区）；九包 `--deny-warn` 全零警告、`yoga-mbt` 92/92、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 把 6b/6c 排成三列并把窗口改成 900×700，几何行补 `NATIVE-APP-CAL`）：注入「右箭头→末指示点→左箭头」+「点第 14 格→右箭头切到 11 月→再点同一格」→ 状态行 `car=2 auto=6 date='2026-11-15'`、`kids=12/12`、退出码 0；截图复核三列并排、日历头部「2026 年 10 月」、9 月尾巴灰显、10 月 11 日（今天）主题色、指示点高亮全部正常。

### MoonBit 原生 GUI 栈 · 导航族首批（分段 / 面包屑 / 分页 / 步骤条 / 折叠面板）

- **master 的 `stateful_item` 在本栈换成「画法现取 + 宿主交互态」**：旧那套是每项自持 `hover`/`focused` 两个 Ref 并在 enter/leave/focus 回调里置位+重绘；本栈的悬停与按下归属由宿主按命中统一维护（`Widget.hovered`/`pressed`/`focused`），所以底色/文字色回调只收本控件、现读现画，组件不再自己处理 enter/leave。收益有二：重建子树不会有「鼠标已离开但 hover 仍为真」的残留态；订阅面从「每项两条」降到「整组一条」（`follow_store` 只为请求重绘）。
- **选中态一律走 Store 且画法现取**：`segmented`/`breadcrumb`/`pagination` 都是「点即 `set`、画时 `get`」，所以同一 Store 挂在多处时全部同步高亮，不需要「改完再通知各控件」的登记表。
- **分页箭头的夹取写在宿主回调里而不是禁用按钮**：`‹`/`›` 在首/末页仍可点，值夹在 `[1, pages]`——与 Web 的 disabled 形态不同，但少一份状态（`pages` 可变时不用重算禁用），且无头测试能直接断言「连点 8 次左箭头仍停在 1」。
- **折叠面板收起即 `set_visible(false)`（display:none），不销毁内容**：内容子树预建常驻，开合只翻显隐 + `invalidate()`；测试用「整块高度回落」证明收起真的不占位（只断可见性会漏掉「隐藏但仍占高」这一类错）。各面板独立开合由每块自持的 `Ref[Bool]` 承担，互不影响。
- **一条自己写错的断言（记下来防再犯）**：步骤条是「连线插在方块前」的交错排布，子项顺序是 `方块0 文字0 连线1 方块1 文字1 …`，按「方块在 0/2/4」猜下标会拿到文字节点——文字处没有底色，两处取样同色，断言 `l1 != l3` 就以 `false` 失败。**自绘组件的像素断言必须先回读实际子项顺序**，别按视觉顺序猜结构。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **49/49**（新增 5 条导航族：分段点即写 Store 且段宽随文本、选中段底色与未选段不同；面包屑分隔符占位、点非末项改值、末项不改值；分页点页码直落 + 箭头步进 + 两端各连点仍夹在 1/5；步骤条三态底色互不相同 + 连线随当前步着色 + 改 Store 后待办块换色；折叠面板默认只开第一块、各块独立开合、收起后整块高度回落）；九包 `--deny-warn` 全零警告、`yoga-mbt` 92/92、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 把该批排成第四列、窗口 1240×840，几何行补 `NATIVE-APP-NAV` 直接给四个注入点矩形）：注入「分段第二段 → 面包屑第二段 → 第 3 页 → 第二块标题行」得 `seg='分段乙' crumb='列表' page=3 step=1 fold='11'`（`fold='11'` 同时证明第二块开、第一块未被带跑），同轮 `kids=12/12`、`car`/`date` 等旧读数不变、退出码 0；截图复核分段高亮、面包屑分隔符、页码实底、步骤条三态与连线、折叠箭头方向全部正常。
- **一条验证手法上的坑（差点误判成组件不工作）**：把三批交互合到一轮注入（10 击）时，后三击全部无效——不是导航族没接上，而是示例的 5 秒自动退出赶在了注入之前。判据是「同一组坐标分批注入全中、合批注入只中前若干击」。累积验证页的存活窗口因此从 5 秒延到 9 秒；以后再加区块都要按「注入次数 × 每击间隔」核对存活时间，别拿退出码 0 当「交互全通过」的证据。

### MoonBit 原生 GUI 栈 · 导航族次批（侧边菜单 / 分组菜单 / 树 / 页签）

- **圆角落在组件层而不是等 Painter 补**：Painter 门面没有圆角矩形，`fill_round_rect` 用「四段直线 + 四个 90° 弧」在 `ui` 里拼路径（弧角一律递增——`Painter::arc` 的 `ccw` 参数在两层后端都不可用，逆时针需求要靠递增起止角表达）。菜单 4px 圆角与选中强调条因此和 EP 观感一致，不必给 render 层加新契约。
- **树与折叠面板同一形态：子层预建 + `set_visible` 切换**，收起即 `display:none`（不测量、不占位、不绘制、不命中），展开只翻标志；节点行按「行 + 子层容器」成对追加，测试因此能按 `children()[2i]` 取行、`children()[2i+1]` 取子层。叶子行连 `Down` 都不消费（`has_kids` 为假），事件继续往上冒，不会出现「点了没反应但把父容器的悬停吃掉」。
- **页签的显隐切换由 Store 订阅驱动，且先显示新页再隐藏旧页**：这条顺序在 master 是 Windows 专属规避（反序会让 yoga 在中间态把外层按 0 内容分配）；本栈每帧从根重排、没有那个洞，但「先显后隐」保留下来无害，且和 `swap_node` 的预建形态一致。页签头行**先**入树再挂页区，视觉顺序即子项顺序（测试用 `head.rect.y < page.rect.y` 钉住）。
- **两条测试写错的地方（都是「按坐标注入」这一类，值得记死）**：
  1. 取样像素必须**按各自控件的 y**取。侧边菜单三项同宽同 x，用第一行的 y 去取第二行，实际取到的还是第一行（选中行），于是「未选项应与容器底色相同」这条以「两处都是浅蓝」失败——症状像组件坏了，其实是断言取错了点。
  2. **隐藏的控件 rect 会被清零**（不可见子树整棵清零是 G6 定的口径），所以「点一个已收起的组内项」这种写法不会命中它自己，而是命中落在原点附近的另一个控件——本例里点到了组一标题行，把组一又展开，表现成「我什么都没做它却变了」。要验「收起即点不到」，得按窗口坐标显式判 `hit_path`/`hit_test`，不能拿控件自己的 rect 加偏移。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **53/53**（新增 4 条导航族次批：侧边菜单项宽跟随容器 + 点项写 Store + 选中项底色与未选项不同（按各自行取样）；分组菜单标题行只影响本组、收起后整列上移需重取坐标、再展开后组内项可选；树子层预建即收起、点父行展开、点叶子行不动作、再点收起；页签预建三页只显当前页、点页签与外部改 Store 都换页、头行在页区之上）；九包 `--deny-warn` 全零警告、`yoga-mbt` 92/92、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加第五列、窗口 1620×840，几何行补 `NATIVE-APP-NAV2` 给菜单第二项/树父行/页签第二页矩形）：合批 13 击（轮播三击 + 日历三击 + 导航首批四击 + 本批三击，注意页签要在树展开**之前**点，因为展开会把页签推下去）得 `car=2 auto=11 date='2026-11-15' seg='分段乙' crumb='列表' page=3 step=1 fold='11' menu='报表' tab=1 tree=1`、`kids=12/12`、退出码 0；截图复核菜单选中浅蓝圆角底 + 左缘强调条 + 「报表」图标、树折叠三角方向、页签指示条与页区内容全部正常。

### MoonBit 原生 GUI 栈 · 穿梭框收尾（导航族 10/10）与「重建式列表」的两条坐标纪律

- **选中集合改成组件自持的两张表，行不持订阅**：master 的穿梭框每建一行就订阅一次数据 Store，靠 `sub_bag_begin/end/discard` 在每次重建前整袋退订，防止死订阅随移动次数累积。本栈的行只读自持的 `Ref[Array[String]]`（选中集合按值存），重建就是「清子控件 + 按 Store 现值再挂」，行级根本没有订阅可漏——回收袋只留给列 Store 那两条（整列各一条）。少一层机制的代价是「选中集合不参与 Store」，换来的是重建次数与订阅数量解耦。
- **`Store.set` 不看值是否真的变了**：空搬运（选中集为空）也会 `from.set(remain)` + `to.set(merged)`，两个 Store 都发通知 → 整列又重建一次。这是 `Store` 的既有语义（不去重，见 `core/store.mbt`），组件不额外加「值相等就不 set」的判断——加了就把「同值也要刷新视图」的用法一起堵掉。测试因此必须按这条语义写：每次可能触发 `set` 的点击之后都要重取坐标。
- **两条「按坐标注入 + 重建式列表」的纪律（本批实测踩到）**：① 重建出来的行**没有矩形**，要等下一次布局才有——无头测试里每次可能引起重建的操作后必须手动 `root.relayout(...)`（真窗口由宿主每帧重排，无感）；漏掉时症状是「点了没反应」，因为零矩形加偏移会命中到别处。② 合批注入时，**任何会改变布局的点击都必须排在同列下方控件之后**：本例先点树父行（展开 +64px）再点穿梭框，穿梭框的两击就全打空（`xfer=3/1` 不变）；把树那一击挪到最后即 `xfer=2/2`。几何行给的是「最后一帧」的矩形，注入顺序必须与它一致，否则等于拿过期坐标点新位置。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **54/54**（新增 1 条穿梭框：点行选中 + 箭头搬运 + 搬完清空选中（再点箭头不继续搬）+ 反向搬回 + 外部改数据整列重建，含上面两条 relayout 纪律）；九包 `--deny-warn` 全零警告、`examples/native-app` 零警告、`yoga-mbt` 92/92、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 第五列加穿梭框、窗口 1620×900，`NATIVE-APP-NAV2` 补 `xrow`/`xbtn` 两个注入点）：合批 15 击按「先点后移」顺序重排后得 `car=2 auto=11 date='2026-11-15' seg='分段乙' crumb='列表' page=3 step=1 fold='11' menu='报表' tab=1 tree=1 xfer=2/2`、退出码 0；截图复核左右两列描边、行首方块、`›`/`‹` 两键方向正常。

### MoonBit 原生 GUI 栈 · 滚动容器（yoga 补相对定位偏移 + `ui/scroll.mbt`）

- **滚动平移落在布局层而不是控件层**：`position: relative` + `top: -offset` 让内容整块上移，相对偏移**只改落位、不改常规流占位**——容器按内容自然高度撑开、后续兄弟不受影响，正是滚动要的语义；命中与绘制都吃布局结果（宿主每帧从 `collect_abs` 取绝对矩形），组件层不需要第二套坐标换算。为此给 yoga-mbt 补上了相对定位偏移：`top`/`left` 优先、同轴两端都给值时另一端忽略、`auto` 不偏移、百分比按父内容盒解；**绝对定位项不吃这套偏移**（它的 `top` 是 inset，从 padding 盒量起）。三条都在 `relative_wbtest.mbt` 里钉住。
- **内容必须 `flex-shrink: 0`**：CSS 里弹性项默认可收缩，内容是唯一子项时会被压成视口高、永远滚不动——这类「能滚的容器里内容却不变形也滚不了」的坑只有真滚一遍才看得出，所以配了「20 行 × 20 高 = 内容 400 / 视口 100 / 上限 300」的用例先钉住几何。
- **滚动条是视口的绝对定位子控件，不是画在视口上的一层色**：它贴在右缘、覆盖在内容之上，于是命中路径上它是最深的那个控件——内容行里的按钮抢不走条的按下与拖动（画在视口 `on_draw` 里的形态会被内容子控件的命中吃掉，这类「看得见点不着」只有真点才暴露）。条的绘制按「视口/内容」比例给拇指长（下限 16px 便于抓），拖动是「拇指中心跟随指针」的映射：`offset = clamp((y - 拇指/2) / (条高-拇指)) * 上限`，实测拖动到条中点得 `scr=171/320`、与手算逐位一致。
- **几何抄进状态放在第一帧绘制时**：视口高与内容高都来自布局结果，只能在绘制回调里读到（`self.rect.h` 与内容子控件的 `rect.h`），所以 `ScrollState.view_h/content_h` 由视口 `on_draw` 每帧刷新，滚动条比例与越界夹取都吃它。代价是**挂载后第一帧之前 `max()` 还是 0**（此时滚轮不动），实现上真窗口每帧都画所以无感；无头测试必须先 `paint` 一次再断言滚动行为，这条写进了用例注释。
- **一条诊断口诀（本批花了十分钟找）**：类型里少一个右括号——`children : Array[@core.Node>`——会报成 `Inline wasm syntax error: unknown operator ?STRING` + `The type alias Array expects 1 argument(s), but is here given 5`，报错位置横跨整个函数签名、离现场很远。看到「Array 参数个数不对 / Inline wasm」这类**语义完全不搭**的报错，先回读签名里的括号配对，别去猜语言特性（对照实验：把函数体换成空体仍报同样错 → 病灶在签名）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **58/58**（新增 4 条滚动容器：视口/内容几何来自布局且滚轮改偏移两端夹取、内容随偏移整体上移且滚动条在内容之上（命中求证）、点轨道跳转与拖动拇指且松手后不再跟手、内容不足一屏时不滚也不画条（按像素求证该处露的是行底色））；`moon test -p NoahLiu/yoga-mbt` **96/96**（新增 4 条相对定位：top 只平移不改兄弟与容器尺寸、left 可负且 auto 不偏移、同轴两端 top/left 胜且只给 bottom/right 反向量、百分比按父内容盒解且绝对项不吃偏移）；九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加第六列「滚动容器」：190×120 视口装 20 行 22 高、几何行补 `NATIVE-APP-SCR`）：注入滚轮下滚三格 → `scr=90/320` 且几何行 `row0=1182,437`（内容首行上移 90 = 527-90）、注入拖动条从顶到中 → `scr=171/320`（与手算逐位一致）、退出码 0；截图复核滚到第 7~11 行、行在视口边缘被裁、右缘滚动条拇指位置随偏移变化。

### MoonBit 原生 GUI 栈 · 浮层基座（`core/overlay.mbt`）与首批三件（气泡/下拉/悬浮提示）

- **宿主的浮层图层三条定案**：① **空图层不可见**——`display:none` 的控件不在任何命中路径上，所以没有浮层时点击原样落到内容；一旦开第一层就置可见并**立刻重排一次**（图层此前不可见、矩形还是清零的，不换算不出它自己的原点），浮层才能按「窗口坐标 − 图层原点」摆位。② **点浮层外收起放在抬起**——按下与抬起都由图层消费（不让这一击漏到内容里），但收起只在抬起做：若放在按下，同一击的抬起会重新命中触发件、把刚关掉的浮层又打开（实测：第二击把菜单关了又开，状态看上去「点不动」）。③ **浮层内容临开临建、关掉即摘**——不进内容树、不占位、没有隐藏态要同步；这与「预建 + 显隐」的切换式组件是两条路，浮层是瞬时的。
- **`popover_t`/`dropdown_menu` 包在触发件外层监听抬起**：触发件内部控件的事件先跑（按钮会消费按下），抬起冒泡上来才切换开合，所以包按钮、包标签都成立；「开着时再点触发件」的正常路径其实是被图层消费掉的，组件里的 `overlay_alive` 分支是兜底（程序化投递或图层被撤掉的形态）。
- **`tooltip_t` 走宿主维护的悬停态而非冒泡的移动事件**：子控件可能自己消费移动（本仓按钮就是 `Move => !is_off()`），包在外面的组件再也收不到通知——真窗口实测「悬停 300ms 后没出气泡」就是这个原因。为此把 `Widget::set_hover` 改成**父链语义**（指针在子项上时父项也算悬停，与 CSS `:hover` 同义）并新增 `on_hover_change` 回调（只在悬停归属翻转时由宿主触发），提示组件挂在这个回调上起停定时器，包住谁都成立。核心用例把「命中链三层都算悬停、兄弟不算、重复设置不重复回调」钉住。
- **一条与 master 的差（记档）**：旧链路的 `tooltip_t` 是 GTK 原生 tooltip（`ffi_view_set_tooltip`），自绘栈没有原生 tooltip 通道，改成「悬停延时后开一层自绘气泡」——观感可控（吃主题与圆角），代价是自己管延时与收起（走 `@core.set_timeout`，无宿主时空操作）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **62/62**（新增 4 条浮层：空图层不挡内容 + 点触发件开层再点收起 + 浮层落在触发件下方 2px；点浮层外收起且这一击不漏给内容；下拉菜单 4 项含 1px 分隔线、选中回调序号并收起；悬浮提示延时到点才出现、离开即收、延时未到就离开则不出现）；`moon test -p NoahLiu/native-gui/core` **61/61**（新增 1 条：悬停父链语义 + `on_hover_change` 翻转触发、重复设置不重复回调）；九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「浮层首批」列，几何行补 `NATIVE-APP-OV`）：注入「点下拉 → 点第 2 项 → 点气泡 → 点浮层外 → 悬停在提示件上」得 `pick=2 ov=1`（`ov=1` 即退出时提示气泡还开着），同轮旧读数不变（`car=2 auto=14 date='2026-11-15' … xfer=2/2`）、退出码 0；截图复核下拉箭头朝上、面板四行含一条分隔线、浮层压在内容之上。
- **一条环境口径记档**：本机显示器中途变成竖屏（1440×2560），示例页七列并排（约 1800px）会超出屏幕、右缘列点不到——已把累积验证页拆成两排（4 列 + 3 列，窗口 1400×1260）。**窗口请求尺寸大于屏幕时 WM 会静默钳制**，只按几何行取坐标会在「看不见的区域」注入，症状是「某些列完全没反应」。

### MoonBit 原生 GUI 栈 · 浮层族收尾（对话框 / 轻提示 / 右键菜单）与三条实测口径

- **对话框开在浮层图层上**（与 master 的差，记档）：旧链路把遮罩做成**页面内绝对定位层**（同一份 `Node` 常驻页面树、靠 `set_visible` 弹收）；本栈改开在图层上——对话框天然要压过所有内容与其它浮层，图层正是这个语义，而且不必常驻一棵隐藏树。遮罩用 `overlay_show_full`（insets 全 0 的包裹层）+ **显式 `width/height: 100%`**：靠内部 `align-items: center` 撑满不可靠（内容比窗口宽时遮罩尺寸会跟着内容走，实测面板 420 > 窗口 400 时遮罩只有 420 宽、盖不住整窗）。
- **`node_of_new` 的 finish 是构造期执行的**——「按 Store 立刻开层」这类需要宿主已就位的初始化必须改用**显式 `mount`** 形态（`{ mount: fn(parent) { ... } }`）：测试里把 `dialog_t(visible=true)` 先在装好宿主之前构造，开层调用就落在一个空槽上、无声失败（`overlay_count == 0`）。真窗口里 App 建窗时先装宿主，所以只有测试会撞上；但组件把「构造期依赖进程级单槽」当常态是脆的，已按挂载期做。
- **右键改「祖先优先」派发**（`dispatch_on_path` 里 `button == 3` 时从根往最深走）：上下文菜单是容器级能力，包在内层控件外面要能先拿到它——否则包住按钮时按钮先把按下吃掉（本仓按钮的 `Down` 不分按键一律消费），菜单永远弹不出来。其余按键维持「最深优先」不变。
- **轻提示开在图层上、第一条才开层**（与 master 的差，记档）：旧链路返回「层节点 + 推送函数」，由调用方把层挂进页面树；本栈把顶部带子做成图层的一层（推送时开、最后一条撤下时收），于是**提示永远压在对话框之上**，页面里也不必常驻一棵空树；入口只剩一个推送函数，没有宿主时是空操作。叠放顺序「后开者在上」由图层条目顺序保证，用例直接断言两个条目的句柄先后。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **67/67**（新增 5 条：对话框按下即弹、确定/取消都先收起再回调、Store 归假；✕ 收起且遮罩点击按 `close_on_mask` 决定收不收；轻提示推送后挂一条、宽度随文本、到点自动撤、撤完收层；右键在指针处弹出并回调选中项；轻提示开在对话框之上）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 第二排加「浮层次批」列，几何行补 `NATIVE-APP-OV2`）：注入「点弹窗 → 点确定 → 点提示 → 右键 → 点菜单项」得 `dlg=1 ctx=1 toast=1`、退出时 `ov=0`（提示已按 2 秒自动撤）、退出码 0；截图复核对话框半透明遮罩 + 居中面板（标题 / ✕ / 正文 / 取消+确定两键）、顶部居中的绿勾提示条。

### MoonBit 原生 GUI 栈 · 日期选择器四只（`ui/datepicker.mbt`，日期族 5/5）

- **弹层一律开在浮层图层上**（浮层基座刚落地就用上了）：日历面板与时间面板都是 `overlay_show_at` 的一层，点浮层外收起、再点字段收起都由图层与字段各自处理，组件不自己管「外面点掉了」。
- **日历面板与网格直接复用 `datetime.mbt`**：`build_calendar`（42 格一次建好、切月只改数据）与 `range_state_of`（端点实心、区间浅底）被四只选择器共用，`date_range_picker` 因此只是「两段式点击 + 写 Store」十几行；这也是把网格数学外置成纯函数的回报。
- **字段交互定案**：整字段吃下按下（进捕获期），抬起按**本地 x** 区分三件事——点 ✕ 清空（只在 `clearable`、悬停且有值时给热区，`width-40..width-20`）、开着则收起、否则开层。清空不触发 `on_change`（与 master 同：回调签名收的是非空值）。
- **与 master 的两条差（记档）**：① 旧链路弹层是原生 Popover，本栈用浮层图层上的自绘面板；② 旧链路时间是「时/分两个 `input_number` 输入框」，本栈改成**步进器**（时 ±1、分 ±5、循环进位），因为自绘栈没有原生输入框语义，键盘编辑要另配一套焦点与输入法通道（要键盘输入的多行文本用 `entry`/即将做的 `textarea_t`）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **71/71**（新增 4 条：日期选择器显示占位、点开日历、点选回填并收起、再点字段收起、悬停后点 ✕ 清空且清空不回调；日期区间两段式点击写回整段并收起；时间区间步进器改值 + 确定写回 + 取消不改；日期时间区间四字段各写各的、日期走日历时间走步进）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 第二排加「日期族选择器」列，几何行补 `NATIVE-APP-DP`）：注入「点日期字段 → 点 10 月 1 日格子」得 `dpk='2026-10-01'`、「点区间字段 → 点 10 月 3 日 → 点 10 月 7 日」得 `drg='2026-10-03~2026-10-07'`、「点时间字段 → 点 + → 点确定」得 `trg='10:00'`，退出码 0；截图复核日历弹层落在字段下方、时间弹层的时/分步进与取消/确定两键。
- **一条注入坐标的纪律（本批又踩一次）**：时间弹层的两步（点 + 与点确定）第一遍全打空，原因是我按「容器高度推中心」算坐标时把行高算错了一行（点进了「分」行、确定键点到了按钮右侧空白）——**浮层里的坐标不能靠推算，要用截图回读或把该控件的 rect 打出来**；本例改用「面板内边距 + 行序 × 行高 + 半高」重算后一次命中。

### MoonBit 原生 GUI 栈 · 表格首批（`ui/table.mbt`：模型 + `table_t`）

- **排序状态归组件、排序口径归使用方**：组件在表头点击时切换 `Store[TableSort]` 并画箭头（新列升序 → 同列翻转 → 同列第三次取消、`column = -1`），**不替调用方排序数据**——数字列要数值序、字典序、还是自定义比较都是业务口径，组件替它排反而会错（master 的注释里也是这条；本批沿用）。排序箭头分「当前排序列的实心三角（升/降）」与「可排序列悬停时的灰色 ↕ 提示」两种画法。
- **列宽分配外置成纯函数 `table_widths`**：固定列按声明宽、弹性列（`<= 0`）均分剩余宽、总宽不够时弹性列取 0（溢出而不压缩固定列）——这条单测直接钉住，不必真画一遍表。
- **行是重建式列表**（与 `transfer` 同款）：数据 Store 一变就清空子控件按新值重挂，行级不持订阅；选择与排序只影响**绘制**（`on_draw` 里现取），所以点选与排序切换都不会触发重建。选择存的是**源数据下标**（不是显示序），因此重排后选中行跟着数据走——比 master 的「显示位置 Ref」稳。
- **单元格四型**：纯文本（按列对齐）/ 语义标签（浅底 + 主色字，与显示族 `tag_of_type` 同口径）/ 颜色块（色块 + 文字）/ 多行（行高内最多两行）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **75/75**（新增 4 条：列宽分配三种情形；表头列数/斑马纹/点选行写选择 Store 且左缘出强调条/再点取消/行回调带源下标；表头排序状态机四步含不可排序列点了不动；标签与色块单元格出像素 + 数据变更整表重建）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「表格」区块，几何行补 `NATIVE-APP-TB`）：注入「点表头两次（升→降）→ 点第 2 行」得 `tsort=0/false tsel=1`、退出码 0；截图复核表头排序三角朝下、斑马纹、选中行浅蓝底 + 左缘强调条。
- **一条纪律（本批连踩三次同类笔误）**：嵌套泛型少写一个右括号（`@core.Store[Array[TableRow]>`，正确的是 `]]`）会报成 `The type constructor Store expects 1 argument(s), but is here given N` + `Expected upper case identifier for type name`，报错位置横跨签名、与真实病灶（少一个 `]`）无关。已把「写完嵌套泛型先 grep `]>`」当成本批后的固定自检——三次里有两次是通过「函数体换成空体仍报同样错 → 病灶在签名」这条对照实验定位的。

### MoonBit 原生 GUI 栈 · 虚拟列表与虚拟表格（万行级形态）

- **只挂可见区间**：视口固定、行高固定，滚动偏移一变就按「首行 = 偏移/行高 − overscan」重挂窗口，上下各放一个占位控件把内层总高撑到「行数 × 行高」。命中与绘制只跟挂载的行有关，200 行实测只挂 10~13 个行控件。
- **占位不等于平移，两者要同时在场**（真机缺陷：`examples/native-app` 的虚拟表格滚动后「从上往下一路白屏」）：初版只在 `first > 0` 时插一个 `first × 行高` 的上占位、内层不做相对定位，理由写成「占位同时把可见行摆到正确的滚动位置」。**这条理由是错的**：没有平移时第 `i` 行永远落在内层原点下方 `i × 行高` 处，也就是**比正确位置低整整一个 `offset`**，而宿主按控件矩形裁剪（`widget.mbt` 的 `clip_rect`），于是偏移越大可见行被推出视口下沿、视口上沿越空——正是「慢慢从上面开始往下白屏」。占位只补「窗口第一行 → 内容原点」这段差额，真偏移量必须由内容块的 `position: relative` + `top: -offset` 承担（与 `scroll_view`/`sticky_list` 同一套）。原来的写法只在 `offset` 恰为行高整数倍且极小时看不出问题。
- **钉桩要钉几何，不能只钉挂载数**：本缺陷能长期存活，是因为既有 3 条单测只断言「挂了哪几行、内层总高对不对」，没有一条断言「行的绝对矩形落在视口内」。补的回归钉桩滚 **1.5 行**（非整数倍偏移最容易暴露），断言内容块上移量 = 偏移、第一行顶部 = 视口顶 − 半行，再深滚到底断言「视口内仍有 5 行可见」。几何类组件的判据一律写成 `rect` 比较。
- **滚动条从 `scroll_v` 抽出来共用**（`scroll_bar(state)`）：轨道/拇指比例、点轨道跳转、按住拖动、松手即止这套只写一份，`scroll_v` 与 `virt_list` 都拼它。抽的时候踩到一个「脚本式抽取」的坑：按行号切片把设置代码复制了两遍（`let bar` 到 `append` 之间本来就含设置段），`--deny-warn` 立刻报 `unused dragging` ——**抽取后要重跑门禁**，重复段与未用变量都躲不过。
- **不在 `on_draw` 里重建窗口**：绘制遍历正在读 `kids`，改动子控件会踩迭代器；所以视口高只在 `on_draw` 里**抄进状态**，窗口重建一律发生在事件回调（`ScrollState.apply`）与数据订阅里。首帧还没有真实视口高时用声明的 `height` 兜底（否则首帧只按 overscan 挂几行、看上去空）。
- **数据变短要先夹偏移再重挂**：订阅里先把 `content_h` 按新行数写好、把越界偏移拉回上界，再重建窗口；少了这步，删数据后视图会停在一片空白上。
- **虚拟表格 = 固定表头 + `virt_list`**：表头不参与滚动，行控件与 `table_t` 共用同一份构造（把 `table_t` 里的表头与行各自抽成 `table_header`/`table_row_widget`，两者共用；抽取后 `table_t` 自身也只剩「拼表头 + 重建式行表」）。表头宽度扣掉滚动条 8px 与左右边框，列宽才与数据行一致。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **78/78**（新增 3 条：千行只挂可见区间且滚动 4 格后窗口首行 = 偏移/行高 − overscan = 4、内层总高 = 行数×行高；拖滚动条改偏移、数据变短偏移夹回上界；虚拟表格表头固定不滚、行只挂可见区间、表头排序与行点选与 `table_t` 同口径）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「虚拟表格」区块，几何行补 `NATIVE-APP-VT`）：注入「滚轮下滚三格 → 点列表中部」得 `vt=1/1`、`NATIVE-APP-VT mounted=13 total=200`（**挂载数远小于总数**即虚拟化生效的机器可查证据）、退出码 0；截图复核滚到第 1~6 行、选中行浅蓝底 + 左缘强调条、右缘拇指位置随偏移变化。
- **修复批验证**：`moon test ui` **133/133**（含新钉桩）、`moon test core ui render text theme icons sys input win dbus chart mdview web` **865/865**、`cd gui && moon check --deny-warn` 零警告。真机复核项（待用户回证）：`moon run examples/native-app` 与 `moon run examples/sysmonitor` 的进程页——滚轮连滚十几格后行内容要始终跟着滚动条走、不出现上沿空白；点行选中与滚动条拖动落位一致。

### MoonBit 原生 GUI 栈 · 表格列宽拖动与粘性列表（表格 2/2、容器与滚动补充收口）

- **列宽是活的**：`table_t`/`table_v_t` 各持一份 `Ref[Array[Double]]` 列宽，表头拖动时改它、表头两格与**已挂载的行内单元格当场改宽**（不重建树）；虚拟表靠一个 `rev : Store[Int]` 让 `virt_list` 整窗重挂（可见行才十来个，重建便宜）。拖动语义是「相邻两列此消彼长」并夹在 `[MIN_COL_W, total − MIN_COL_W]`（40px 下限），末列右缘不设把手。
- **一条真窗口才暴露的接缝**：表头单元格自己会消费按下（点标题排序），于是**可排序列的边界拖动整个失效**——父控件（表头）收不到这次按下。修法是单元格判断「本地 x 距左右缘 3px 内就**不消费**」，把边界让给表头；单测因此特意用**可排序列**钉住（最初用不可排序列写，测试通过但真窗口拖不动）。
- **粘性列表的「当前组」靠读布局结果反推**，不是按偏移硬算：组高由内容决定（行数、换行都可能变），每帧布局后读各组控件的矩形、取「起点 ≤ 偏移」的最后一组写进 `StickyList.cur_group`，吸顶条只负责画它。吸顶条是视口里的一条绝对定位悬浮条（与 `scroll_v` 同一套相对定位平移内容），滚动与滚动条沿用共用件。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **80/80**（新增 2 条：表头边界拖动改列宽且相邻两列此消彼长 + 越过界夹到最小列宽 + 行内单元格跟着改宽 + 松手后不再跟手（用可排序列）；粘性列表滚过组边界时吸顶标题换文字、内容整块上移、可滚上限 = 内容高 − 视口高）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「粘性列表」区块与表格拖动）：注入「按住表头 140px 边界往右拖 80px」得 `head0=24,521,200x40`（= 总宽 240 − 最小列宽 40，与手算逐位一致）、注入「滚轮下滚五格」得 `sticky='组二'`（`NATIVE-APP-STK max=238`）、退出码 0。

### MoonBit 原生 GUI 栈 · 分隔布局与文本族首批（`hsplit`/`vsplit`、`TextRole`/`label_t`/`measure_text_height`）

- **分隔把手拖动只改样式**：旧链路（master `yue/splitter.mbt`）是「直写 `set_bounds` + 双写 `width/flexbasis` 样式」——那套是 GTK 时代的老坑（运行期改布局属性重排不落地，见其 probe-splitter 条）。本栈每帧从根重排、样式改完下一帧就生效，所以只改样式；拖动期间靠宿主的**指针捕获**（按下即进捕获期），指针拖出把手范围仍投给把手，位移按窗口坐标算。
- **总量从三个控件的实际矩形读，不捕获父控件**：夹取要「把手两侧加起来的总长」，而父控件（容器）不能捕获进子控件的回调——父子互指就是引用环。改成 `first.rect + 把手常量 + second.rect`，语义等价且不引入环。
- **把手首栏初始用百分比、拖动后切成固定值**：初始 `percent(ratio*100)` 让首栏随容器缩放（不依赖「先量一次再算」），一旦拖动就换成 `fixed(px)`（此后由用户定）；两端下限 `min_first`/`min_second` 在拖动中夹取。
- **文本角色（`TextRole`）与 `measure_text_height`**：角色把「字号 + 颜色」收成一体（Title/Section/Body/Secondary/Accent），`role_color` 现取主题（不固化）；`measure_text_height(text, role, width)` 供运行期长高的标签显式设高——容器问到的自然高与绘制时按盒宽折行的高未必一致，显式高度最稳（这是旧链路记档过的坑，本栈沿用同口径）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **85/85**（新增 5 条：按宽量高给宽后明显变高且角色字号越大行越高；角色字号/颜色（Accent 用主色）；主题化标签按 `max_width` 折行、固定色覆盖角色色（像素求证）；水平分隔把手拖动改首栏宽 + 两轮极值夹取 + 松手后不再跟手；垂直分隔同上）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「分隔布局与文本族」区块，几何行补 `NATIVE-APP-SPL`）：注入「按住把手往右拖 100px」得 `first=24,1236,788x116` / `split=788`（688 + 100，与手算一致）、退出码 0。
- **一条窗口尺寸的复核纪律（本批又踩）**：示例页面已长到 1400px 上下，窗口还是 1260 时**下半页在窗口外**，注入点落在看不见的区域、静止不动；先把窗口加到 1500 再测即中。**每次给累积验证页加区块，都要按 `NATIVE-APP-RECTS` 的最后一项核对窗口高度**，别只看几何行有坐标就以为点得着。

### MoonBit 原生 GUI 栈 · 表单族首批五件（`button_t`/`link`/`form_item`/`form`/`rate_t`）

- **焦点环落在第几列像素**：`stroke_rect(0.5, 0.5, w-1, h-1)` 配线宽 1 的描边中心在 0.5，覆盖的是 x∈[0,1] 那一列的**第二格**——取样取 `ox` 读到的是底色，会误判「焦点环根本没画」（本批第一条用例就这么假失败）。取样一律 `ox+1`，或先扫一列确认环在哪。
- **越界点击命中不到控件，别拿它当「夹取」用例**：`dispatch_pointer` 先做命中测试（`rect.contains`），x 超出控件宽的事件压根不会投给这个控件，回调里的 `clamp` 也就无从验证。「点最右缘仍得最后一颗」要改用**框内**最右点（126 宽的评分用 x=120），确实要测出界路径用 `dispatch_pointer_to(id, ev)`（宿主的指针捕获就是这条）。
- **`on_change` 只在交互点触发**：master 把回调挂在 `value.subscribe` 里，外部写值也会回调；本栈统一成「回调 = 用户这一次操作」（与日期选择器同口径），外部写值只重绘。两种语义各有道理，混用会让调用方以为「自己写值又收到自己的回调」，故记档。
- **表单项的错误行常驻预留高度**：错误文案行固定 18 高（空文案也在），文案出现/消失不引起布局跳动——真窗口用 `NATIVE-APP-FORM item=` 矩形在点「危险并报错」前后逐位相同回证。文案本身用 `label_dyn(err.signal())`：Store 的信号直接喂给标签，改文案走 `relabel` 就地重测，不重建子树。
- **按钮宽度口径与 master 不同**：master 在 mount 期手动 `get_bounds_for` 测文本宽再 `+32` 定宽、绘制时自己水平居中；本栈的文本测量已经回灌布局引擎（`attach_text_measure` + 左右 padding 12），宽度是布局结果，绘制只按盒居中，不需要那份手动测量。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **90/90**（新增 5 条：按钮配色求解（四变体 × 悬停 + 显式覆盖吃掉悬停）；主题化按钮宽度随文本、抬起出框不算点击、焦点环只在聚焦时画、禁用不消费；链接宽度=文字宽、悬停出下划线、抬起才回调；表单项标签定宽 + 错误行预留 18 高 + 空文案量 0 宽改文案后就地重测；评分星顶点几何、点击写值并回调、悬停只预亮不改值、离开清预亮）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「表单族余项」区块，几何行补 `NATIVE-APP-FORM`）：注入「点实心按钮 → 点链接 → 点危险按钮（写错误文案）→ 点第 4 颗星」得 `btn=2 lnk=1 rate=4 ferr=1`、`item=24,1475,245x39` 与未点击那轮逐位相同、退出码 0；截图复核四型按钮配色（实心白字 / 浅底主色字 / 无底主色字 / 红底白字）、链接悬停带下划线、标签右对齐、五颗空心星。
- **窗口高度按最后一项几何复核**：本批区块落在最下方，页面已长到 1542，窗口 1500 时评分那行在窗口外（点了没反应），加高到 1660 后一次命中；注入前另要注意自动退出定时器（12 秒）与「先 sleep 再找窗口」的竞态——sleep 到点会拿到已销毁窗口，报 `BadWindow`。

### MoonBit 原生 GUI 栈 · 下拉选择与取色器（`select_t`/`color_picker_t`，表单族 13/15）

- **浮层句柄要问「活性」而不是「非零」**：`overlay_show_at` 返回的 id 单调递增、**从不复用**，而「点浮层外收起」是图层代做的——组件自己那份 `open_id` 不会跟着归零。于是用 `open_id.val != 0` 判开关会把**已失效的句柄**当成还开着，症状是「点外面关掉之后，要连点两下字段才重开」（第一下只清了旧句柄）。判开关一律用 `overlay_alive(open_id.val)`（内部就是 `overlay_rect_of(id)` 是否还在）；`close_pop` 里保留 `!= 0` 的守卫无害（隐藏失效 id 是空操作）。浮层组件 `popover_t`/`dropdown_menu` 一开始就是这个写法，日期选择器四只与本批两只此前用的是弱判据，已统一，并各加一条「点外收起后再点字段一击即开」的回归。
- **单独画一个控件到位图，要抵消它的绝对落位**：`w.paint(p)` 会按 `rect.x/rect.y` 平移，而「贴合控件尺寸」的位图只有 w×h 大——浮层里的行控件绝对 y 在几十到几百，画出去之后像素断言恒等（症状：「选中行与未选中行同色」的假失败）。改用 `w.paint_at(p, w.rect.x, w.rect.y)`，平移量归零，位图坐标即控件局部坐标。
- **弹层列表套一层 `scroll_v`**：面板按公式定高（`项数×28+8`，上限 300），选项再多也不顶出窗口；滚动几何仍是第一帧绘制时才抄进 `ScrollState`（见滚动容器那条），所以无头用例点之前要先 `relayout` 一次。
- **`container` 的 `padding` 只给左/上**：`Widget::set_padding(left, top)` 的口径，不是 CSS 的四边内边距——色板容器实测 176×72 而非 176×80，右下那条带靠浮层面板自己的固定高兜住。按四边理解会把几何断言写错一格。
- **与 master 的三条口径差**：① 弹层是浮层图层上的自绘面板，不是原生 Popover，「点外面收起」由图层负责，组件不再跟踪；② master 靠字段失焦收起，本栈字段是否可聚焦取决于调用方给不给 `focus_id`，收起只走「点外面 / 再点字段」两条路；③ 下拉的 ✕ 清空**同样**回调 `on_change("")`（与 master 同），而日期选择器的清空不回调（也与 master 同）——两条口径各自保留，不是本栈内部不一致。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **93/93**（新增 3 条：下拉点开列表与几何（弹层落在字段下方 2px、同宽、行 28 高）、点选项写回并收起、选中行浅底与右侧勾出像素、✕ 清空同样回调；下拉「点外收起后再点字段一击即开」；取色器色板网格几何（两行 5+1、面板 176×80）、选中格比未选格多描边与白勾（逐像素比对差异 >20）、点色块写值并收起）。日期选择器用例同步扩一条失效句柄回归。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 的「表单族余项」区块加一行下拉与取色器，几何行补 `NATIVE-APP-FORM sel= col=`，状态行补 `sel= col= ovmax=`）：注入「点下拉字段 → 点第 2 项 → 点取色字段 → 点第 2 格 → 点下拉 ✕」得 `sel='选项乙/'`（先选中后清空）、`col='#2E9E5B'`、`ovmax=1`（浮层峰值计数——退出时早已归零，故每拍记一次最大值才证明确实开过层）、退出码 0；截图复核色板网格 5×3 落在字段下方并压在内容之上。

### MoonBit 原生 GUI 栈 · 多行输入框（`ui/textarea.mbt`，表单族 15/15）

- **`focus_id` 只是声明，宿主焦点栈要注册**：控件带 `focus_id` 只表示「可聚焦」，`App` 在按下时若发现该 id **不在焦点栈里就不改焦点**（`core/app.mbt` 的注释即此意）。症状很有迷惑性：**点进框里、光标也画出来了（点击走的是指针链路，与焦点无关），打字却毫无反应**。示例里新加的 21..24 四只（实心按钮 / 下拉 / 取色器 / 多行框）都要补 `app.focus.register(id)` 才吃键盘。
- **xdotool 注入按键的正确口径**：`xdotool key --window WID ...` 走 XSendEvent，GTK 侧不吃合成事件——于是出现「**鼠标注入全中、键盘注入全无反应**」的假象。改成先 `xdotool windowactivate --sync WID` + `xdotool windowfocus WID`，再用**不带 `--window`** 的 `key`/`type`（XTEST 投给当前聚焦窗口）就进得来。
- **中文输入法会吃掉字母与方向键**：真窗口里 `type "cd"` 没进文本框（字母被 fcitx 收去拼 preedit），而 `Return` 能过。判据是先看 preedit 是否出现；要回证 ASCII 打字得先把输入法切到英文模式（只读查询用 `fcitx5-remote -n`，**别用 `-t`，那是切换**）。多行框的键盘语义因此以白盒用例为主（`dispatch_key` 直投），真窗口只回证点击定位、回车换行与滚轮。
- **上下键的落点取「不超过 x 的最右码点边界」**：一开始写成「严格小于」，等长两行之间按上键会少走一个字符（实测 caret=1 而不是 2）——与单行框 `byte_at_x` 同口径才是对的。
- **逐字节推进后回退码点要先判末尾**：`while at > ln.start && (bs[at] & 0xc0) == 0x80` 在 `at == 文本长度` 时越界读，症状是测试驱动只报 `SIGABRT (core dumped)`（栈里连断言都看不到）。加 `at < n` 守卫。
- **段循环里别拿 `j = hi` 当 break**：`wrap_units` 内层 while 用「把游标推到端点」退出，等于把整行吞成一个段——外部表现为**任何宽度都不折行**。改成 `let mut go = true` 的显式退出标志。
- **插入点跟随的观感**：光标落在「最后一行半」时整块上移（实测 16px），于是第一行被裁掉一半——这是 `ensure_visible` 的正常结果，不是绘制 bug（截图复核时别当问题报）。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **98/98**（新增 5 条：折行断点单位（空格/拉丁词/中日韩逐字分段与区间截断）；显示行布局（按换行符断行、空文本给一行、贪心折行且断行处不留行首空格、行间首尾相接、中文逐字断三行、超长单词不拆只溢出）；键入与回车、上下键按显示行移动并记住 x、Home/End 走行首尾、Shift+Home 扩选后替换、行首退格并行；点击定位到第几行（中文按字节算行首）、拖选跨行整删、只读不吃编辑键；内容超视口才出滚动条 + 滚轮到底后拇指与轨道换位 + 插入点滚进可视区后顶行像素变化）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 表单区块加多行框，几何行补 `ta=`，状态行补 `ta= tacur=`，示例内容改 8 行）：注入「点框内第 3 行（窗口 y=1644）」得 `tacur=12`（该行行首字节，与手算逐位一致）→ 注入 `Return` 得 `ta='行 1/行 2//行 3/…'`、`tacur=13`（多出一个空行）→ 滚轮上滚回顶，截图复核三行完整可见、右缘拇指回到顶部、插入点跟随造成的 16px 上移在中间帧可见。

### MoonBit 原生 GUI 栈 · 声明式层 L1 构造器（`ui/declarative.mbt`：vbox/hbox/bind_label/hover_group/mount_window…）

- **`hover_group` 在新栈不需要任何轮询机制**：旧链路（`yue/declarative/hovergroup.mbt`）靠一个全局 100ms 指针轮询拍，因为 GTK 的指针事件不冒泡、子控件的 GdkWindow 会独占事件，祖先容器收不到 enter。本栈宿主的悬停态本来就是**父链语义**（指针在子项上时父项也算悬停，与 CSS `:hover` 同义，见 tooltip 那条），所以组件只读 `Widget.hovered` 即可——没有定时器、没有指针查询、也没有「组静止时不触发回调」这类优化要做。记成**机制差**而不是「已实现同款」。
- **`bind_label` 的强制重排在本地栈里是免费的**：旧链路 `set_text` 只标脏不重排，标签变长就截断，必须补一次 `update_layout`；本栈改文本走 `relabel`（重设测量回调 → 节点标脏），下一帧布局自然跟着新文本走。真窗口回证：点一次按钮，标签从 36px 变 87px（`lblw=36/87`），期间没有重建任何子树。
- **`mount_window` 不提供 `center` / `on_close`**：旧链路的窗口居中与关闭回调走的是原生窗口通道；本栈窗口位置由 WM 决定、关闭只是让 `App::run()` 返回，收尾写在调用方 `run()` 之后。少给两个参数比给两个假参数好。
- **与组件同名的构造器不再包第二层**：`label`/`button`/`entry`/`checkbox`/`container`/`group`/`separator`/`image`/`icon`/`radio_group`/`slider`/`progress` 在 `ui` 里已经是返回 `@core.Node` 的声明式构造器，再套一层同名函数只是多一处要维护的签名。本批只补三类：改名者（`vbox`/`hbox`/`text_edit`/`picker`/`scroll`/`tab`/`date_picker`）、地基入口（`mount_window`、`bind`/`bind_label`）、新能力（`hover_group`）。`overlay_scroll` 在本栈就是 `scroll_v`（滚动条一直是视口的绝对定位子控件），`gif` 随图标/动画批，`cursor_group` 要窗口层光标通道（新增 FFI），单列一批。
- **三条工具链写法（本批实测）**：① `test "名字"` 与左花括号**必须同一行**——分行写时解析器把测试体当成独立的顶层块，报错现场跑到几十行外且语义完全不搭（`The value identifier tabs is unbound` + `Parse error, unexpected token id`）；② `Option::is_none()` 在本工具链已弃用（提示改用 `x is None`），别把它写进新代码；③ match 的守卫不是 `v when cond`，MoonBit 写 `| cond`——简单二分支直接退回 `if/else` 更省事。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **103/103**（新增 5 条：vbox/hbox 的方向与间距来自参数、bind_label 改值后就地换文本并重测宽 + 出像素、bind 走派生信号且订阅随回收袋退订、hover_group 子控件悬停即整组换底色且抬起出组不算点击、旧名构造器落到新组件上（picker 点开浮层并回填、scroll 出滚动条且 max>0、tab 按 Store 切页））。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「声明式 L1」区块，几何行补 `NATIVE-APP-DC`，状态行补 `dcl= lblw=`，页面又长一截故窗口 1760→1900）：注入「点卡片里的『加一』按钮」得 `dcl=1 lblw=36/87`（Store 一改，标签文本与宽度都跟着走）、`label=34,1377,87x19`，指针停在卡片空白处截图复核整块换悬停底色。

### MoonBit 原生 GUI 栈 · 窗口层光标通道（`wm_set_cursor` + `Widget.cursor` + `cursor_group`）

- **全自绘栈里光标是「窗口级的一层」**：没有原生控件就没有「每个控件自带光标」这回事，形状只能设在绘图区的 `GdkWindow` 上。所以链路是：组件在控件上声明**请求**（`Widget.cursor`，编号 `@core.CURSOR_*`：0 默认 / 1 手型 / 2 文本 I 形 / 3 横向调整 / 4 纵向调整）→ 宿主在 `Move` 时取「悬停路径上**最深的那个非零请求**」→ 与已下发的形状不同才走一次 FFI（`Window::set_cursor`）。取「最深非零」而不是「最深」，是为了让包住一整组的 `cursor_group` 自然回退：组内子件没提请求时用组的，提了则以子件为准。
- **与 master 的一条机制差**：旧链路的 `cursor_group` 必须把光标**递归设进组根与全部子孙**——GTK 的光标按原生事件窗口生效，只设容器盖不住有独立窗口的子件。本栈只设组自己一处即可，代价是「组内某个子件想保留自己的形状」要靠它自己提请求（提了就赢）。
- **C 侧两道守卫**：`gtk_widget_get_window(area)` 在未 realize 时是 NULL（此时设了也没窗口可挂，直接跳过，下一次悬停会再试）；`WmWindow.cursor_kind` 记着当前形状，同形状重复请求不再新建 `GdkCursor`（`gdk_cursor_new_from_name` 每次都要分配，悬停抖动会白烧）。名字取不到（主题缺字形）时退回 `default`。
- **两条工具链写法**：① `pub(all) enum PointerKind` **不自动带 `Eq`**，`pev.kind == Move` 编译不过（`Type PointerKind does not implement trait Eq`），要写 `match pev.kind { Move => true _ => false }`；② `pub(all) struct Rect` 的字段同样是公开的，测试里 `w.rect.x` 直接可读，不必另开 getter。
- **验证**：`moon test -p NoahLiu/native-gui/core` **62/62**（新增 1 条 `cursor_at`：组内回退到组、子件自己提了以子件为准、组外与空白无命中都回默认）；`moon test -p NoahLiu/native-gui/ui` **104/104**（新增 1 条：按钮/主题化按钮/悬停组手型、`entry`/`textarea` 文本形、`hsplit`/`vsplit` 把手横向/纵向、`cursor_group` 可覆盖形状且子件保持默认）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 每拍采一次宿主已下发形状，状态行补 `cur=手/文本/横向/纵向`）：注入「依次停在实心按钮 → 多行框 → 分隔把手 → 空白处」得 `cur=8/8/8/0`（前三档各被采到 8 拍，纵向那档示例里没有 `vsplit` 故为 0）、退出码 0。**光标的实际形状观感（手型是不是常见的指针、文本形是否为 I 形）由用户在真机复验**——注入只能证明宿主确实按区域下发了不同编号。
- **禁用态的光标请求必须「命中时现算」，建树时定死必错（真机反馈：禁用按钮悬停仍是手型）**：`Widget.cursor` 是建树时写入的**一次性 `Int`**，而禁用态在本栈是**单元**（`Enabled`，`state.mbt` 的既定口径——禁用态若用布尔在建树时固化，后续每次 `set_disabled` 都改不动已定死的字段）；`button()`/`icon_button_t()` 无条件写 `CURSOR_HAND`，于是禁用与可用在光标面上完全没有区分度。修法不是给每个组件补一个「重新算光标」的入口，而是把请求本身变成可现算的：`Widget` 新增 `cursor_fn : Option[(Widget) -> Int]`，**存在时压过静态 `cursor`**；`cursor_at` 改走新增的公开方法 `Widget::cursor_request()` 逐节点求值（返回 0 仍表示「本控件不请求」，查询继续往祖先走，`cursor_group` 的组请求语义不受影响）。`ui/state.mbt` 加私有助手 `enabled_cursor(cell, on)`：禁用时回 `CURSOR_DEFAULT`、可用时给 `on`。改动点：`ui/basic.mbt` 的 `button`/`icon_button_t`、`ui/form.mbt` 的 `checkbox`/`switch_t`/`slider`/`button_t`（步进器两侧走 `button()` 已自动覆盖）。
- **教训：改字段语义要全仓搜该字段的「断言」，不只搜实现侧调用点**——`ui/declarative_wbtest.mbt:151` 是直接读按钮**静态** `cursor` 的断言，改造后当场红（`0 != 1`），是用户跑 `moon test core ui` 抓出来的；它只查实现侧 grep 是搜不到的（断言写的是 `.cursor`，与组件构造点无关）。同类改造的检查清单：实现写入点 → 读该字段的断言 → 该字段的公开访问器（此处补 `cursor_request()` 正是为了给断言一个语义正确的入口）。
- **验证**：`moon test core ui` **243/243**（新增 core 1 条「带 `cursor_fn` 时以现算结果为准，压过静态 `cursor`；同一棵树改状态下一次查询立刻生效」、ui 1 条「按钮光标跟着禁用单元走：禁用不请求手型、改回可用立刻恢复」；修正 `declarative_wbtest` 既有断言 1 条）。真机复验：禁用按钮悬停为普通箭头、恢复可用立刻变手型。

### MoonBit 原生 GUI 栈 · 可编辑下拉（`combo`，声明式 L1 收尾）

- **组合方式：编辑语义全在里面那只 `entry`，本组件只加「候选」这一层**。过滤随输入走（`entry` 的 `on_change` 里重开浮层），回车取高亮用 `entry` 的 `on_enter` 钩子，而 ↑/↓/Esc 靠**按键沿祖先链冒泡**：`entry` 对这三个功能键不消费（内核 `handle_key` 走到 `keysym_to_text` 得 None → `handled=false` → 宿主继续往上问），包在外层的 `combo.on_key` 才拿到它们。这是本栈第一次把「同一次按键先问控件、再问祖先」用在真实分工上，值得记：组件想吃子控件不消费的键，不必给子控件加回调参数，父层的 `on_key` 就是那条通道。
- **抬起才开层（与 popover/dropdown 同一套路）**：`entry` 消费了按下（要落插入点），同一击的抬起才冒泡到包装层，`combo` 在 `Up` 里开层——所以点字段任意位置都是「定位插入点 + 开候选」，不需要额外的下拉箭头热区。
- **高亮不重建浮层**：候选行的选中态是闭包现取（`fn() { hi.val == idx }`），↑/↓ 只改 `hi` 再 `invalidate()`，浮层内容不重挂；过滤结果变了才重开（`close()` + `overlay_show_at`）。
- **浮层 id 单调递增，测试里数错就崩**：每次 `overlay_show_at` 都换新 id（关层不回收编号），所以「第 N 次开层」的断言要按**开层次数**数而不是按当前层数——数错时 `overlay_root_of(不存在的 id)` 给 None，测试助手退回一个空控件，紧接着的 `children()[0]` 就越界，症状是测试驱动只报 `SIGABRT (core dumped)`（本批实测一次，栈里没有断言）。
- **与 master 的一条差**：旧链路的 combo 是原生可编辑组合框（GTK `ComboBoxEntry`），本栈全自绘——浮层开在浮层图层上、点外面收起同样由图层负责。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **105/105**（新增 1 条：点字段开层给全量候选 → `dispatch_commit` 提交「甲」过滤成两行并自动开层 → 高亮行的浅底与勾出像素、下键把高亮挪到另一行 → 回车回填高亮项并收层并回调 → 再开层只剩一行、Esc 收层不改值 → 过滤到空集不开层）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 表单区块的下拉行里加 `combo`，几何行补 `cmb=`，状态行补 `cmb='…'`，焦点 id 25 补注册）：注入「点可编辑下拉字段 → 点第 3 项」得 `cmb='组件丙'`、退出码 0；另一轮四击「开层 → 点第 2 项 → 再点字段 → 点原第 3 行位置」停在 `cmb='组件乙'`——第二次开层时当前文本已是「组件乙」，过滤后只剩一行，点在旧第 3 行位置的点击自然落在浮层外，这正是「随输入过滤」的应有表现（不是丢点）。

### MoonBit 原生 GUI 栈 · 缩放绘制修正与 GIF 动图（`cr_blit` 重写 + `Animation` + `gif`/`icon_button_t`）

- **`cairo_pattern_set_matrix` 的缩放路径实测是错的（本批修掉的真 bug）**：旧写法把「源像素→设备像素」写进图案矩阵（`translate(d0,d1)` + `scale(k)`），Cairo 的语义与这个直觉相反——源 120×120 里 (20,20)-(99,99) 的方块缩到 72 时，图案矩阵路给出 (33,33)-(71,71)（推到目标矩形右下角并被裁掉），而 CTM 路（`identity` → `translate` → `scale` → `set_source_surface` → 以子矩形大小为填充范围）给出正确的 (12,12)-(59,59)。**等尺寸（目标=源大小）时两条路恰好一致**，所以这个错一直藏着：`draw_image`/`draw_canvas` 的缩放分支此前没有任何用例覆盖。诊断顺序值得照抄：先在 MoonBit 侧用**全不透明合成图**证明「能画出来」（2304 格全中），再换**带透明区的源**复现「画歪」，最后把整段 blit 搬进独立 C 程序对照三种写法（父表面+矩阵 / CTM 变换 / 子表面+矩阵），一次定位。
- **改了桩库，`moon run` 的产物同样不会重链**（此前只记过测试 exe 这一条）：`build/librender_cairo_stub.a` 是 13:50，而 `native-app.exe` 还是 13:39——MoonBit 源码没动，moon 就认为产物最新，于是白盒测试全绿、真窗口里 GIF 依旧空白。要删 `_build/native/debug/build/NoahLiu/native-gui/examples/<示例名>`（注意 `moon run` 的可执行文件在 `build/` 子路径下，不在 `execbin/`）。**判据**：比对 `.a` 与 `.exe` 的 mtime，别看「刚跑过就是新的」。
- **GdkPixbuf 动画迭代器是「懒起算 + 只认绝对时刻」**：`gdk_pixbuf_animation_iter_advance(iter, t)` 的第一次调用只把动画起点锚在 `t` 上、必回报「没换帧」；之后换不换完全由加载器按累计时间判定。所以本层的虚拟时钟**每拍只推「当前帧时长 +1ms」**（与真实时间同速），组件按 `delay_ms` 的节奏反复问——早期写成「一次调用里连推四拍」，动画就会比实际快四倍。
- **本机 gif 加载器读不到 `tDelay`**（实测该选项为 NULL，与 PIL 报的 400ms 不符）→ 退回 100ms/拍的轮询；因为换帧时机由虚拟时钟与加载器共同决定，实际仍是每 400ms 换一帧（真窗口 12 秒 `gif=30` 帧 ≈ 2.5 帧/秒，与素材逐帧时长对得上）。
- **`loop` 与 `static` 都是 MoonBit 保留字**：参数名 `loop~` 直接解析失败（改用 `looping~`），结构体字段 `static` 触发 `reserved_keyword` 警告（改 `is_static`）。
- **图标按钮的悬停底色取样点**：圆角 4 的 `fill_round_rect` 会把贴角那格裁掉，像素断言要取上缘中点（`(w/2, 2)`），取 `(1,1)` 会读到「没变」。
- **验证**：`moon test -p NoahLiu/native-gui/render` **42/42**（新增 1 条缩放回归：同一张源图在 120/72/48 三档目标下的不透明包围盒分别为 (20,20)-(99,99)/(12,12)-(59,59)/(8,8)-(39,39)，另含 `draw_image_from_rect` 的取样域不外溢）；`moon test -p .../gui/ui` **107/107**（新增 3 条：动图组件按帧自转/暂停断链/`play` 续上/静图不排自转，且 48×48 缩放后确实有墨；图标按钮尺寸、悬停换底、抬起出框不算点击、禁用不吃事件）；`core` 62/62、`yoga-mbt` 96/96，九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「图标与动图」区块，几何行补 `NATIVE-APP-MEDIA`，状态行补 `gif=`/`ib=`）：注入「点图标按钮」得 `ib=1`、`gif=30`（自转换帧数）、退出码 0；截图复核图标随主题取色、✕ 图标按钮、48×48 的 GIF 圆点确实画在框内（此前是一片空白）。

### MoonBit 原生 GUI 栈 · 主题跟随系统（`theme_from_system` + `App::follow_system_theme`）与 style 通道定案

- **主题包不依赖平台层，跟随逻辑放窗口层**：`theme` 只收两个读数函数作参数（`theme_from_system(sys_color_scheme, sys_accent)`），真正的探针在 `win`、轮询与 `theme_apply` 在 `core/app.mbt`（`App::follow_system_theme(interval_ms)` 返回停表函数）。这样主题包保持零平台依赖（`core` 反过来依赖它不成环），且「跟随」这条策略在无头测试里能用假读数函数直接测四态。与 `local_ymd` 同一个理由：平台探针经 core 转发，示例与集成层不必引用 `win`。
- **读的是桌面环境的 gsettings，不是原生控件样式表**：`org.gnome.desktop.interface` 的 `color-scheme` 优先（值里含 dark/light 才算），读不到再退 `gtk-theme` 名字（大小写归一后找 dark/light）；主色读 `org.gnome.desktop.wm.preferences button-settings`（若直接写了 `#rrggbb`）或 `accent-color`（GNOME 给的是 **blue/teal 这类名字**，本层查表转 hex）。**必须先 `g_settings_schema_has_key` 再读**：本机 schema 里就没有 `accent-color` 键，直接 `g_settings_get_string` 会打 GLib 关键警告。GSettings 对象建一次常驻（每拍新建销毁会反复走 dconf）。
- **本机实测口径（Ubuntu 24.04 + XFCE）**：装了 GNOME 的 schema（`gsettings list-schemas` 里 `org.gnome.desktop.*` 有 38 个），`color-scheme='default'`（既不是 dark 也不是 light → 落到 `gtk-theme='Orchis-Teal-Light-Compact'` → 归一后含 light → 报 "light"），`accent-color` 无此键 → 主色空串。所以 `theme_from_system` 走「亮色 + 内置主色」，与默认盘一致；真窗口状态行回证 `sys='light/'`、`fing=#2D68C4/#F5F6F7`。**判据**：跟随循环只在**指纹**（`primary/bg_page`）变化时才 `theme_apply`，读不出来的桌面每拍算出同一份 → 零重刷。
- **style 通道定案：新栈不做 CSS 风格式样式表**。master 那五个助手（`themed_container`/`set_panel_bg`/`bind_bg`/`bind_fg`/`bind_popover_bg`）存在的前提是「原生控件的底色/字色是命令式设进去的固定值，主题换了不会自己变」；本栈组件在 `on_draw` 里现取主题色板，换主题时靠进程级的一次订阅整体重绘（`watch_theme`），这五个助手在新栈里**结构性不需要**。调用方要覆盖尺寸/间距/底色，走两条更直接的路：组件的类型化参数（`width=`/`bg=`/`padding=`…），或 `handle=fn(w){ ... }` 拿到底层控件自己设 yoga 样式——后者就是本栈的「样式逃生舱」，比维护一张字符串样式表更类型安全。`sub_bag` 批量退订早已在 `core/signal.mbt` 落地并被组件批次反复覆盖（重建式列表整代退订）。
- **验证**：`moon test -p NoahLiu/native-gui/theme` **8/8**（新增 1 条：深浅与主色四态的指纹关系——读不出与读到 light 同指纹、dark 与 light 不同、给了 accent 就走派生公式且与 `theme_from_accent` 一致、`theme_apply_system` 之后 getter 与指纹跟随新快照）；`ui` 107/107、`core` 62/62、`render` 42/42、`yoga-mbt` 96/96，九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 起 `follow_system_theme(interval_ms=1000)` 并在 3 秒处停表验证停表函数归属）：状态行补 `sys='light/'` 与 `fing=#2D68C4/#F5F6F7`、`frames=118` 与其余读数不变、退出码 0。**系统主题真的切换时界面是否即时重着色**由用户在真机复验（可临时 `gsettings set org.gnome.desktop.interface color-scheme prefer-dark` 观察），助手侧不代改桌面设置。

### MoonBit 原生 GUI 栈 · 图表首批（`chart`：算法层 + 折线/柱状/环形/仪表/散点）

- **另起新包而不是原地改 `yue/charts`**：旧目录引用 `@yue` 根包与旧 Painter 契约，属全仓红点积压；新栈要守「本包 `--deny-warn` 零警告」这条分包门禁，混在一起就无从谈起（与 `yue/components` → `ui` 同一个理由）。新包三层：`algo.mbt`（纯函数，与 master 同源：滚动窗口/坐标换算/1-2-5 刻度/单位换挡/柱槽与命中/扇区角度/仪表弧度/最小二乘/值域留白/截断）、`draw.mbt`（绘制，只吃纯函数的结果）、`components.mbt`（`@core.Node` 组件）。
- **像素断言的口径换了**：图表组件在 `on_draw` 里先铺一层面板底，于是「有墨像素数（alpha>0）」恒等于整块面积——本批 5 条用例第一次全假失败就是这个原因。改判据：**两张位图逐像素比差异**（`diff_of`），「换数据后画面变了」与「离开后复原」都用它（后者断言差异恰为 0）。这条对所有「先铺底再画内容」的组件都成立，不只是图表。
- **密集折线的绘制成本与窗口大小脱钩**（沿用 master 定案）：按像素列抽稀，每列取 (x, y_min, y_max) 保极值；面积模式每列填一个到锚线的矩形（填充顶边即折线，不再另描），折线模式每列画 min..max 竖条。稀疏（点数 ≤ 列数）才走真折线 + 多边形面积。依据是软件光栅化下每段描边约 1.8µs，1000 点 × 4 序列全描边超 5ms 验收线。
- **环形命中是新写的 `donut_hit`**（极坐标判扇区，圆心/半径公式与 `draw_donut` 同源，中心孔与圆外给 -1）；柱状命中仍用 master 的 `bar_hit`（与绘制共用槽宽公式，否则高亮与柱子错位）。
- **复用 `ui` 的地基而不是重抄**：`follow_store`/`watch_theme`/`text_width`/`fill_round_rect`/`default_handle` 从 `pub` 出去给图表包用。之前它们在 `ui` 内是私有的，图表包若要同样的东西只能再抄一份订阅逻辑（`watch_theme` 的「进程级只订阅一次」正是不能复制的那条）。
- **四条工具链写法（本批实测）**：① `pub const` 的名字**必须大写**（`pub const pi` 直接报「Expected upper case identifier for name of const, found lower case. Did you mean let?」），小写常量用 `pub let`；② `for i = 1..<n { }` 不支持——range 只在 `for x in a..<b` 里合法，经典 for 要写 `for i = 1; i < n; i = i + 1`；③ `StringBuilder` 的写入方法是 `write_string`/`write_char`，没有 `add`/`append`；④ `Ordering` 类型在本工具链不可直接引用（写比较器函数会报「The type Ordering is undefined」），几个元素排序退回插入排序。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **11/11**（6 条纯函数：窗口丢最旧与越界无操作、值域退化与留白比例、1-2-5 步长与负区间起点、单位换挡 k/M/G、柱槽与两形态命中、扇区只累计正值且单扇区留 0.0002 弧度、仪表分段取色与折线段数、回归退化、8 位色串、标签截断；5 条组件：折线换数据与密集抽推出图、柱状悬停换底与离开复原、环形出图 + 命中四态、仪表盘 smooth 两路（直接跳到位 / 逐拍逼近）、散点带趋势线）。九包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「图表」区块：折线+柱状一行、环形+仪表+散点+推点按钮一行，几何行补 `NATIVE-APP-CH`，状态行补 `ln=`/`chp=`）：注入「点三次推点按钮」得 `ln=27/23 chp=3`（窗口 24→27 点、末值 7→23，与手算 `pushes*7%29+2` 逐位一致）、退出码 0；截图复核五图齐备——折线带面积填充与右端最新值标注、柱状正负异色带类目、环形中心汇总 + 右侧图例带百分比、仪表 68% 弧与中心数字、散点带最小二乘趋势线。

### MoonBit 原生 GUI 栈 · sys 批 3（硬件族六件：brightness / volume / nightlight / printer / powerprofile / monitor）

- **依赖注入解 DBus 耦合**：brightness 的写路径（logind 在线探测 + SetBrightness）在 master 走 `@traybus`；新栈把两处改成**进程级注入槽**——`brightness_set_logind_probe(()->Bool)` 与 `brightness_set_action((subsystem,name,value)->String)`（空串成功、非空错误串），DBus 线接入后由 traybus 侧注入实做，读路径（设备枚举/当前值/最大值，纯 sysfs）不依赖槽。模式与 `ci_tooltip` 的回调反转同构：**语义层定义槽、平台层注入**。
- **monitor 从会话族提前**：夜灯（nightlight）的显示器枚举依赖 monitor（xrandr），而 monitor 只依赖 platform + pr_run，无 DBus——按依赖序归入本批。
- **挪 DBus 线的三件**：`sensor`（iio-sensor-proxy）/`bluetooth`（org.bluez）走 `@traybus` 通用 D-Bus 层属性读取；`disk`（UDisks2）50 处 `@traybus.gdbus_call_system`——它们的核心是总线调用而非命令行，本批不强拆。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **41/41**（新增 11：monitor 的 xrandr 解析矩阵 + 六文件的 pr_run 命令面/解析纯函数同源平移；brightness 注入槽未注入时 set 走 Unsupported、读路径本机真 sysfs）；`moon check sys --deny-warn` 零警告、全仓红点仍 287/68。**真机复验**：volume 音量增减与静音、brightness 读当前值、powerprofile 列表与切换、printer 打印机枚举、nightlight 色温生效、monitor 分辨率列表。

### MoonBit 原生 GUI 栈 · sys 批 2（`sys/dialog.mbt`：文件对话框）

- **GTK 端归 win 桩、语义层归 sys 包**：`GtkFileChooserDialog` 的封装写进 `win/gtk_stub.c`（`wm_file_*` 前缀，槽表与窗口桩同制——对话框要挂 GTK 父窗口、且该文件已由 prebuild 编进 GTK 链接单元）；`sys/dialog.mbt` 只做语义薄封装（filters 字符串透传、选项位、run/取结果/销毁）。sys 包 **不 import win**——`run_for_window` 的 parent 是纯句柄 id（Int64），MoonBit 层无符号依赖，但链接需要 `-lyue_win_stub`，由 `scripts/prebuild.py` 给 sys 包**单独下发** link_configs（GTK 库清单同 win 一套）。
- **未 run 的 chooser 查结果会段错误（本机实测）**：`gtk_file_chooser_get_uri` 在内部文件系统模型未初始化时直接 SIGSEGV——桩加 `wm_dlg_accepted` 标记，只在 `gtk_dialog_run` 返回 ACCEPT 后放行查询，其余一律空串。同因 GTK 断言：`set_current_name`（set_filename）只对 SAVE 动作合法，OPEN 对话框上调用打 Gtk-CRITICAL。
- **无显示环境的退化路径**：`wm_file_dialog_new` 先 `gtk_init_check`，失败返回 0 句柄（wbtest 无 X 连接、CI 场景）——全接口对 0 句柄 no-op 不崩；有显示（本机）则真建对象，测试走双路径断言。
- **「改桩不重链」的第三处案发现场**：改 gtk_stub.c 后 `moon test` 报 undefined reference——`build/libyue_win_stub.a` 的 mtime 比源码新（同批测试产物也没重链），判据是比对 `build/*.a` 与测试 exe 的 mtime，双删 `_build/native/debug/test/.../gui/sys` 与桩库强制重编。与 G 批次的桩教训同源，moon 的增量对「C 源码改动」不可靠是常态了。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **30/30**（新增 1：对话框建/配/释放双路径——有显示真建对象配置后销毁、无显示全接口 no-op；模态 run 与真选文件留真机复验）；`moon check sys --deny-warn` 零警告、全仓红点仍 287/68。**真机复验清单**：应用内触发打开对话框 → 选文件 → 结果路径正确；保存对话框初始名生效；filters 下拉分组正确。

### MoonBit 原生 GUI 栈 · sys 批 1（`sys`：fsx / envx / procrun）

- **sys 桩直接走 native-stub**：目录枚举（dirent）/环境变量（setenv/unsetenv）/文本读写（fopen）/删文件只用标准头，**不需要** win/render/text 桩那套「prebuild 编静态库 + portable 占位」——那些是因为要 GTK 头（native-stub 拿不到 pkg-config 路径）。单文件 `sys_stub.c` 顶部 `#if` 分平台（Windows 分支占位，FindFirstFileW 宽字符路由待 M2），`moonbit_make_bytes` 以 `extern` 声明直接链运行时符号（ime_probe_stub 同款）。
- **`sys_getenv` 走 C 层 getenv 而非 core/env**：进程内 setenv 后要「立即可读」（master 的测试口径），core/env 的环境表在部分实现是启动快照——需要实时语义的读走桩，纯读取场景仍可用 core/env。桩上顺带落了 `sys_read/write_text_file`、`sys_remove_file`（幂等）、`sys_platform()`（编译期 `#if` 判定，master 的 `@yue.platform()` 等价）。
- **procrun 只换依赖面**：`@yue.read_text_file/ffi_remove_file/platform` → 本包 `sys_*` 三件；`@subproc`（chensuiyi/subproc）本就在主模块依赖，`pr_run` 的 spawn → 限时回收 → 临时文件捕获 → C locale 全套原样。
- **平移坑**：旧 wbtest 的 `utf8_bytes/from_utf8_bytes`（根包 helper）→ `@utf8.encode/decode_lossy`；`ffi_getenv_bytes` 的出参 `ok` Ref 断言模式换成返回 `Option` 的 `sys_getenv` 后，旁边残行的 `inspect(ok.val)` 要一并清（改签名不清断言是编译期炸）。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **29/29**（fsx：真实目录枚举含临时文件/`..` 排除/打不开分支、扁平文本解码、进程内写读改删回环含 overwrite=false 保持/幂等删/`a=b` 拒绝；envx：单点读与 core/env 对照、common 集合存在才收/XDG_* 全扫、错误分支；procrun：`pr_available`/`pr_run` 真子进程回环——`echo`/非零退出 stderr 捕获/超时强杀、`/bin/sh` 脚本路）。`moon check sys --deny-warn` 零警告、全仓红点仍 287/68。

### MoonBit 原生 GUI 栈 · Markdown 视图（新包 `mdview`，组件库收口）

- **新包不复用旧目录**：master 的 `yue/markdown` 依赖 `@yue` 根包（红点区），新栈按「一文件夹一包」惯例落 `mdview`（`mizchi/markdown@0.8.3` 已在主模块依赖里，新包 import 即用）。纯函数层（展平/区间计量/脚注扫描/切行）与 master 零差异平移；渲染层换组件面（`@ui.hbox/vbox/label/separator/checkbox/code_view`、`@render.Image`、`@text.AttributedText`）。
- **链接打开改 `on_link` 回调**：master 的富文本行点击直接 `@yue.open_url`；新栈 open_url 属系统能力线（桌面集成族待平移），`markdown_view` 增 `on_link? : (String) -> Unit` 参数、经 `MDCtx` 链传进富文本行闭包——**初版用进程级单槽转发，因多实例互相覆盖改为 ctx 链传**（结构体函数字段按函数应用要写 `(ctx.on_link)(u)`，直接 `ctx.on_link(u)` 报「has no method」）。
- **富文本行的主题跟随按指纹缓存**：AttributedText 重建不能放 on_draw 每帧做（动画帧会反复重建），也不能只在构造期做一次（链接/代码色不随主题）——`on_draw` 里比对 `@theme.theme_fingerprint_of(theme_current())`，指纹变了才重建。
- **块间距策略换了**：master 各块自带 marginBottom（style 串）；新栈 `@ui.hbox/vbox` 只有四边 padding、无 padding_bottom 参数——块间距统一交最外层 `vbox` 的 `row_gap`，个别块的底部留白走 `node.set_margin_bottom(@yoga.fixed(...))`。
- **验证**：`moon test -p NoahLiu/native-gui/mdview` **26/26**（24 条纯函数/展平/区间/GFM 断言同源平移——UTF-16 计量/emoji、脚注编号顺序、引用式链接定义、删除线/上标区间、fence info 首词、切行、图片路径剥 `file://`、表格对齐映射改 `is` 模式断言（yoga 枚举未实现 Eq）；2 条组件挂载——GFM 全要素文档（标题/粗斜删/链接/任务列表/有序/引用/代码块/表格/分隔线/定义列表/脚注）子树 >5 节点且高度按内容长出、链接点击回调不崩）；`moon check mdview --deny-warn` 零警告、全仓红点仍 287/68。真窗口几何行确认布局（`md=24,2745,420x403`），观感留用户真机复验。**至此组件库十族 + Markdown 全部收口**。

### MoonBit 原生 GUI 栈 · code_view 代码高亮（`ui/codeview.mbt`）

- **分词器原样平移、组件换形态**：`Token`/`lang_keywords`（8 语言关键字表）/`tokenize_lang`/`classify_word` 与 master 的 `components_text.mbt` 同源零改动（工具链写法本就是新口径）；`code_view` 从「AttributedText 预排版 + draw_attributed_text」换成「构造期逐 token `@ui.text_width` 测宽 → on_draw 逐段 `@text.draw_box_at`」——旧链路为绕 Windows AttributedText 区间色缺陷的整段设色手法在新栈结构性不需要（自绘直出），行高取 `@text.line_height_font`。
- **逐纯色像素计数是脆弱断言**：13px 等宽小字形（如关键字 "fn"）经次像素抗锯齿后**字芯可能没有一个纯色像素**（本批 `purple=0` 而 6 字符的中文串 `green=22`）——组件像素断言改按「非底色墨迹总数」，逐色断言只对大面积色块（图表扇区/色带）可靠。
- **验证**：`moon test -p NoahLiu/native-gui/ui` **110/110**（新增 3：tokenize 断言同源平移——关键字/类型/限定名/调用/区间/字符串/注释/多语言；组件挂载——深底占九成、墨迹 >150、高度随行数线性）；`moon check ui --deny-warn` 零警告、全仓红点仍 287/68。真窗口几何行确认布局（`code=24,2745,400x153`，moonbit 带行号 + python 两块），观感留用户真机复验。

### MoonBit 原生 GUI 栈 · 专项图批 4（`chart`：effectscatter / themeriver / geo，图表线收口）

- **8 位色串的两种语义冲突（本批实测）**：旧链路图表约定 `#AARRGGBB`（alpha 在前，见「yue 色值与绘制三坑」），而新栈 `@render.Color::parse` 的 8 位语义是 **RGBA（alpha 在后）**。`eff_alpha_color` 直接把 8 位输入喂 `@theme.parse_hex` 会把 alpha 位当红色（`#ff009688` 解析出 r=255——`"#ffff0096" != "#ff009688"` 的根因）；修复：**8 位输入先剥前两位 alpha、取后 6 位解析**（旧链路「RGB 不被改写」语义），新 alpha 由参数重新合成。
- **涟漪动画从「回调返 false 注销」改成真句柄**：旧链路 `set_timer` 无取消 id，停止靠回调返回 false；新栈 `@core.set_timeout`/`clear_timeout` 有真句柄——`EffAnim` 持 `running + timer`，`eff_stop` 即时取消待触发回调（carousel 自转同款续排模式：回调里再 `set_timeout` 下一拍）。
- **GeoJSON 的 JSON 解析走 `@sys`**（`vsc_json_parse` 已平移在 sys），`RectF` 改本地 `GeoRect`（与 treemap 的 `TmRect` 同形各自定义）；`argb_hex` 旧链路在根包红点里，图表包本地实现（`Int::unsafe_to_char` 拼 hex，注意 `Char::from_int` 已弃用）。
- **三条测试教训（本批踩全）**：① `ink_of` 对「铺面板底」的组件恒等于整块面积（首批图表的坑，无头默认主题 bg_panel 还是**纯白** `#FFFFFF`，白底也算墨）——断言内容用**特征色采样**或 `diff_of`；② themeriver 图例预留 240px，画布须 >298 才有绘制区（组件默认宽 560），窄画布测试会整幅早退且无任何报错；③ **测试里手写的 JSON 要用外部验证器过一遍**——本批坐标数组多写一个 `]`，解析器如实返回 None，一度误判为解析器 bug（分段二分全过、完整串挂时优先怀疑字符串本身）。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **189/189**（新增 43：三份 wbtest 同源平移 40 + 组件挂载 3——涟漪换数据变与 eff_stop 后 is_running=false、河流换序列变（画布 560）、地图解析+区域飞线出像素+清空变）；包 `--deny-warn` 零警告、全仓红点仍 287/68。真窗口几何行确认布局（`eff=24,2542,300x170`），视觉观感留用户真机复验。**至此图表线 15 种专项图 + 五种通用图 + 交互层全部收口**。

### MoonBit 原生 GUI 栈 · 专项图批 3（`chart`：sunburst / graph / parallel / pictorialbar）

- **与批 2 同一套路**：转换脚本做依赖名替换，手工段三类——「暂无数据」块、条件对齐的 `draw_text`（pictorialbar 的 4 处省略 `wrap=` 参数，正则要求 wrap 才匹配故漏，这类「省默认参数」的调用形态也要手改）、组件层 mount 块。旭日图中心汇总（20px SemiBold + 「总计」caption）与 `draw_donut_core` 同款 `@text.draw_box_at` 写法。
- **`SunItem`/`TreeItem`/`TmItem` 同字段结构在包内字面量构造会「Mutiple possible record types」**：三个 `{name, value, children}` 形状相同，字面量无法消歧——统一走 `make` + `children.push`（数组字段内容可变），跨包同理（批 2 的坑在此复现并定案为通用口径）。
- **可选参数的位置传参限制**：`GraphNode::make(name, value? : Double)` 与 `GraphEdge::make(s, t, weight? : Double)` 的可选参数**不能按位置传**（`make("甲", 30.0)` 报 requires 1 positional arguments）——一律 `value=30.0`/`weight=5.0` 命名传参。`SunItem::make` 的 `value? : Double?` 是双层 Option，数值要包 `Some(v)`。
- **graph 的布局缓存改挂回收袋**：旧链路 `subscribe` 里清缓存 + `schedule_paint`；新栈 `follow_store` 只管重绘，缓存失效单独 `subscribe_id` + `sub_bag_register` 退订（与 gauge_t 同模式）。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **146/146**（新增 48：四份 wbtest 同源平移 44 + 组件挂载 4——旭日换数据变、关系图数据变更后布局缓存失效画面变、平行坐标换行变、象形柱两形态出像素）；包 `--deny-warn` 零警告、全仓红点仍 287/68。真窗口几何行确认布局（`gph=282,2346,260x190`），视觉观感留用户真机复验。

### MoonBit 原生 GUI 栈 · 专项图批 2（`chart`：kline / sankey / treemap / tree）

- **机械平移 + 手工段**：四个文件用转换脚本做依赖名替换（`@yue.*` → `@theme`/`@render`/`@core`/本包函数），「暂无数据」块、条件 align 的 `draw_text`、组件层 mount 块三处手工改写——`draw_text` 的 `align=` 允许任意表达式（`align=if first_col { @text.End } else { @text.Start }`），转换器按字面量枚举匹配会漏，这类段落一律手改。
- **treemap 的 `RectF` 改本地 `TmRect`**：旧链路复用根包 `RectF`（x/y/width/height），新栈 core 的 `Rect` 字段名是 w/h 且语义是布局矩形——图表包自带同形 `TmRect`（15 处替换），不引跨语义依赖。`from_hsl` 在 `@theme.palette` 就位。
- **`tree_chart_t` 的 `orientation : String` 改 `vertical : Bool`**：旧链路字符串参数（"horizontal"/"vertical"）是历史 API 形态，新栈组件参数一律类型化（对齐 `bar_chart_t` 的 `horizontal?`）。
- **TreeItem/TmItem 跨包构造必须走 `make`**：`pub(all) struct` 的字面量构造在定义包之外报「There is no record definition with the fields」（native-app 里构造树数据踩到）——跨包构造统一 `TreeItem::make(name, value=…)` + `children.push(…)`（children 是数组字段，内容可变）。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **98/98**（新增 34：kline/sankey/treemap/tree 四份 wbtest 同源平移 29 条 + 组件挂载 5 条——K 线涨红跌绿两色都出像素、桑基出图换数据变、树图 hover 提亮与复原（flat 画卷与绘制同源）、树图两形态出像素）；包 `--deny-warn` 零警告、全仓红点仍 287/68。真窗口几何行确认布局（`NATIVE-APP-CHSP sankey=332,2190,300x150`），截图复核受限：窗口 2500 高已超 XFCE 允许的移动范围（`windowmove -1346` 被 WM 钳到 -1278，目标区块底部出屏且钳制路径下 GTK 丢失 expose、截到空 backing）——**视觉观感留用户真机复验**（native-app 专项图区块第二行）。

### MoonBit 原生 GUI 栈 · 专项图批 1（`chart`：boxplot / funnel / heatmap / radar）

- **一图一文件、同源平移**：master 的 `charts_boxplot.mbt`/`charts_funnel.mbt`/`charts_heatmap.mbt`/`charts_radar.mbt` 各平移为 `boxplot.mbt`/`funnel.mbt`/`heatmap.mbt`/`radar.mbt`（纯函数层原样 + 绘制层换 `@render.Painter`/`@text.draw_box_at`/`@theme` 现取色 + 组件层换 `node_of_new` 形态），wbtest 四份对应平移并各补一条**组件挂载出像素断言**（`ink_of > N` + 换数据 `diff_of > 50` + 空数据/维度不足不崩）——纯函数对而组件没接线的回归第一次就能被抓住。旧链路 `AttributedText`「暂无数据」统一换成 `@text.draw_box_at` 固定盒写法（与 `draw.mbt` 同款）。
- **依赖全在新栈就位**：`mix_hex`/`lighten_hex`/`parse_hex`/`rgb_to_hsl` 在 `@theme.palette`，`bar_slot`/`draw_hgrid`/`series_color`/`fmt_axis`/`truncate_to` 复用本包；`mut_view().sort_by(fn(a,b){ -1/0/1 })` 在本工具链可用（返回 Int 的比较器，与 `Ordering` 不可用的坑无关）。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **64/64**（新增 27：箱线分位插值/五数/双端离群/IQR 零、漏斗排序保序/层几何/梯形宽/占比、热力量程/色带插值/格坐标、雷达角度/多边形/量程归一/布局 + 四组件挂载）；`moon check chart --deny-warn` 零警告、全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-app` 加「专项图」区块，窗口加高到 1400×2300，几何行补 `NATIVE-APP-CHSP`）：退出码 0；截图特征色采样四图齐全——箱线 success 箱体 68px + danger 离群红点 28px、漏斗主色首层 3508px、热力浅主色 5773px + 深主色 1944px（色带梯度）、雷达双系列 169/168px。**观感由用户真机复验**。
- **截图实操补充**：窗口移出屏幕过远时 X 会清掉屏外 backing（`import -window` 截到全灰 242）——把目标区块移进屏但**保留窗口大半可见**（本机窗口高 2300 时 client 原点 -1200 左右），截图像素采样才有效。

### MoonBit 原生 GUI 栈 · 图表交互层（`chart`：tooltip + DataZoom/VisualMap/mark/导出 + 可点击图例 + `charts_it` 三交互图）

- **平移面与文件对应**：master 的 `charts_tooltip.mbt`/`charts_interactive.mbt`/`charts_it.mbt` 三个文件同源平移为 `tooltip.mbt`（`CiTip` 浮层状态与防出界定位、`CiPlot` 绘制区、最近点 `ci_nearest_idx`/扇区 `ci_sector_at` 命中、`ci_tooltip` 交互画布组件）、`interactive.mbt`（`CiZoom` 窗口数学全套、`CiVisualMap` 色带、`ci_mark_line`/`ci_mark_area`、`ci_save` 离屏导出、图例命中与显隐位工具、`ci_legend` 组件）、`charts_it.mbt`（`line_chart_it`/`bar_chart_it`/`donut_chart_it`）；wbtest 三份对应平移。
- **图例色的形态改了：不存色串，存 (名字, 原始序号) + `color_at` 现取**。master 把 (名字, 色串) 固化进 Store，主题一换色板全旧，要靠 `on_theme_change` 重建整套 items；新栈 `ci_legend` 收 `color_at : (Int) -> String` 在 `on_draw` 里现取（系列色/环形色/柱状正负色都是主题色现取），主题切换经进程级 `watch_theme` 整体重绘即自动新色，**`on_theme_change` 重建那条链结构性不需要**。柱状的正负分色闭包直接捕获数据 Store 现值判定。
- **`on_scroll` 的回调签名没有控件首参**（`Option[(ScrollEvent) -> Bool]`，与 `on_draw`/`on_pointer` 不同——后两者首参给控件是为了避免引用环，滚轮回调拿不到）。滚轮换算缩放锚点要画布宽高，解法是**构造闭包里持一个尺寸 Ref，`on_draw`（有首参）每帧刷新，`on_scroll` 读最近一帧**——组件可见必然先画过一帧，不存在读到 (0,0) 的窗口期。
- **`ci_tooltip` 加了 `on_leave` 回调**：浮层收起只藏 `CiTip`，但调用方自记的 hover 状态（折线准线/落点、扇区外扩）是 `hit` 之外的绘制态，不清就残留——白盒「离开后复原」断言第一次失败（diff=276/1012）就是准线与外扩还在画。三个交互组件都接 `on_leave=fn(){ hover.val = -1 }`。
- **拖拽捕获不再自己管**：master 的 `set_capture`/`release_capture` 在新栈结构性不需要——宿主 `route_pointer` 在 `Down` 时自动让命中者成为捕获者，之后的 `Move`/`Up` 一律投给它（指针出界不丢抬起）。
- **`draw_donut` 拆出 `draw_donut_core`**（扇区 + 中心汇总，色经 `color_at` 参数）：交互版的图例由 `ci_legend` 承担（可点击/可显隐），不能复用原图例内嵌的 `draw_donut`；`draw_donut` 自己变薄壳（core + 内嵌图例）。`ci_sector_at`（带厚度参数的通用扇区命中）与首批为固定厚度写的简化版 `donut_hit` 并存——交互版环厚可配，命中几何必须同源跟随。
- **PNG 导出在本栈 Linux 真可用**（`render/png.mbt` 纯实现，不走平台 shim）：master 的 `ci_save` 在非 Windows 恒失败（shim 未暴露导出 API），wbtest 只能测格式校验不触盘；新栈 wbtest 直接真落盘 `/tmp` 断言 `Ok`，`ci_save_chart` 的离屏 `Painter` 用完必须 `end()`（Cairo 会话槽有限）。
- **xdotool 的 XTest 滚轮注入对 GTK3 无效（本批实测，注入工具局限而非代码问题）**：`xdotool click 4/5` 在 X 层正常产生 button4/5 事件（`xev` 收到、synthetic NO），但 GTK3 的 X11 后端走 XInput2，**不把 XTest 的 core 按钮事件转成 scroll-event**——20 行最小 GTK 探针（只连 scroll-event + fprintf）复现实锤，桩侧 `wm_on_scroll` 一条都没进。滚轮缩放的组件链路由白盒 `dispatch_scroll` 直调覆盖（注入 `dy:1` → 窗收窄 → 像素变），**真机滚轮手感/观感留给用户复验**；将来要程序化注入滚轮得走 uinput（`/dev/uinput` 在，ydotool/evemu 未装）。
- **真机截图的坐标三重对齐（10px 小目标踩的坑）**：① `xdotool mousemove --window` 给的是 **client 相对坐标**（与 GTK 事件坐标同系，注入不用换算）；② `import -window` 在窗口比屏幕高时只截**屏幕可见部分**，截图原点是屏幕而不是窗口（本机窗口 2080 高 vs 屏幕 1080，窗口被移到负 Y 后截图 y = client y − 866）；③ frame 与 client 差一个标题栏（XFCE 34px）。第一次按错误偏移采样得出「图例色块没画」的错误结论——10px 的色块偏 34px 就完全错过，**先对齐（鼠标落点 `getmouselocation` 反推 client 原点）再下「没画」的结论**；同理窗口比屏幕高时注入点必须先 `xdotool windowmove` 负坐标把目标区块移进屏（XTest 坐标被钳屏幕底边，落在屏外等于没注入）。
- **验证**：`moon test -p NoahLiu/native-gui/chart` **37/37**（新增 26 条：tooltip 三份 wbtest 平移——浮层尺寸估算/防出界定位/最近点与 map_idx 互逆/扇区四象限与环带容差/`CiPlot` 分数与退化；zoom 数学全套——归一/设窗/滚轮锚点不变式/平移边界/可见区间、VisualMap 两色带三色带与非法色回退、图例命中累加几何与宽度门槛、显隐位补齐/翻转/过滤（含偏移寻址）、切片收窄、`ci_save_chart` 尺寸与格式校验 + PNG 真落盘；三交互组件挂载注入——折线 hover 出浮层与准线且离开复原、图例点击隐藏序列画面变、柱状 `dispatch_scroll` 直调缩放改窗、环形扇区 hover 外扩与复原；纯函数——plot 边距与绘制同源、环形几何环厚钳内径、items 原始序号与色板循环、窗口定标取最长序列）。九包测试全绿（core 62/input 10/render 42/text 29/icons 4/theme 8/sys 7/ui 107/chart 37）、十包 `--deny-warn` 全零警告、`yoga-mbt` 96/96、全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 加「交互图表」区块，窗口加高到 1400×2080，几何行补 `NATIVE-APP-CHIT`）：退出码 0；注入「柱状画布滚轮（未生效，见上）→ 环形图例第一项点击 → 环形扇区 hover → 折线画布 hover」后像素采样逐项对上——图例色块齐全（含柱状负值项红色 `(214,69,80)`）、**隐藏项色块变 border 灰 `(216,220,225)`**、12 点方向第一扇区（primary 蓝）消失且剩余扇区重分配（该位置变 success 绿）、tooltip 深底 `(49,49,51)` 落在 hover 点右侧、折线 hover 处有落点色。**滚轮缩放、tooltip 跟手观感、图例点击手感**由用户真机复验。

### MoonBit 原生 GUI 栈 · 平台输入映射层（另线 #19 首批：`core/input_map.mbt`）

- **为什么先落表不先后端**：Windows/macOS 后端在这台机器上验不了（无真机），按「不写不可验的代码」的纪律，先把**平台无关的口径**做成纯函数 + 回归：三平台修饰位折算、两套键码表（Win32 虚拟键码 / macOS `kVK_*`）、shift 折算、按钮号、以及「这颗键先交给谁」的路由表。后端落地时照表填，不必各自再决定一次语义、也不会决定成三个版本。
- **三条口径**：① keysym 用 **X11 值**（Linux 后端本来就是 GDK keyval，另两平台向它对齐），可打印 ASCII 就是字符码；② 字母与数字给**未加 shift 的基码**，shift/caps 由 `win_apply_shift` 折算——X11 的 keyval 已带 shift 语义而 Windows 的虚拟键码没有，不补这一步「Shift+A」会被当成 'a'；③ 符号键（OEM 那一排）**不硬编键盘布局表**：Windows 走 `WM_CHAR`/Unicode、macOS 走 `charactersIgnoringModifiers`，硬编既错得多也维护不起。
- **一条实测语义纠正（写进判定表）**：光标与选区类键要**带 Ctrl 也算内核键**（Ctrl+左右=按词跳、Ctrl+Home/End=到首尾，正是编辑器最常用的动作），但**带 Alt 不算**（Alt+左右是「后退」这类宿主动作）。次序即语义：组合中 → 光标键 → Tab/Shift+Tab（焦点环绕）→ 快捷键组合 → 可打印键（先过输入法）→ 其余归宿主。
- **权威归属要写死在两处注释里**：Linux 的修饰位折算目前在 `win/stub.c` 的 `wm_mods`（C 侧必须自己折，不能反过来调 MoonBit），它与 `gtk_mods_to_mods` **逐位一致**——两边注释都点名了对方，改一处必须改另一处；表的可执行定义在 MoonBit 侧（有回归钉住）。
- **macOS 的 `kVK_*` 只覆盖特殊键**：Return/Tab/Space/退格/ForwardDelete/Home/End/PageUp/PageDown/方向/F1-F12/小键盘——字母与数字**故意不映射**（mac 的字符要由事件带的 Unicode 文本给，键盘布局由系统解析）。另外 mac 的 `kVK_Delete`(51) 其实是**退格**、`kVK_ForwardDelete`(117) 才是删除，这条最容易记反，断言里两条都钉了。
- **验证**：`moon test -p NoahLiu/native-gui/core` **78/78**（新增 7 条：三平台修饰位含「GDK lock 位不算修饰键」「Windows 按钮位不混进修饰位」、Win VK 表（字母/数字/控制/功能/小键盘/未知给 0）、shift 折算（字母看 shift 异或 caps、数字符号查表、表外原样）、mac VK 表（退格与删除分别钉）、按钮号（Win `MK_*` 与 mac `buttonNumber` 都折成 1 左 2 中 3 右）、路由表六条规则、reset 与 surrounding 的触发条件）；`moon check core` `--deny-warn` 零警告；全仓红点仍 287 errors / 68 warnings。本批**没有真机回证**（全是纯函数），后端接线随 Windows 地基与 mac 真机走。

### MoonBit 原生 GUI 栈 · 浮层的原生档（批 E 余项：`core/overlay_native.mbt`）

- **档位只看一件事**：所在窗有没有已挂载的原生子件（`Window::has_child_surfaces()`，读 C 侧槽表 `wm_window_surface_count`）。有网页区就整层改走真窗口，没有就继续走图层——判据放在 C 侧的槽表而不是 MoonBit 记账，省掉一套会漏销的计数器。六件浮层（tooltip/下拉/右键菜单/对话框/轻提示/悬浮卡）都经 `overlay_show_at`/`overlay_show_full`，所以档位切换在一处生效。
- **原生表不放进 `OverlayHost`**：宿主归 `App`，宿主再持 `App` 就是引用环；弹层表放进程级 `Map[句柄, App]`，`overlay_hide`/`overlay_clear`/退出清理都走它。
- **「先开框、量完内容再收框」踩到两条 GTK 事实**：① 绘制区的 `gtk_widget_set_size_request` 是窗口的**最小内容尺寸**（建窗时按初始大小设的），不改它直接 `gtk_window_resize` 就缩不回初始以下——浮层量完内容会留一圈死边；② `set_resizable(FALSE)` 会让程序化 `gtk_window_resize` 被整个忽略（无边框窗用户本来就拖不动，所以设 TRUE 没有副作用）。两条都在 `wm_window_set_size` 里一起处理。
- **「失焦即收起」在映射期会误触发，默认关**（对照实验）：开着时弹层约两秒自关，而内容里的「收起」从没被点过（`hides=0` 证明不是我们主动收的）；把开关关掉后同一序列弹层常驻。根因是 transient + keep-above 的窗口在映射期会连着来 focus-out。在没有「拿到过焦点才算」的判据之前，宁可让浮层常驻由内容自己收——「开一下就自己消失」比「点外不收起」更坏。开关 `overlay_set_dismiss_on_blur(on)` 留着，判据补上就能开。
- **新增事件构造体会打到「冻结」的基准页**：`@win.Event` 加 `LostFocus` 之后全仓红点从 287 变 288——`examples/native-window`（G2–G5 基准，不再加特性）对事件做穷尽 match。判据是先看红点数变化再找是谁变多，加一条空分支即回到基线；**「冻结」不等于可以不跟着改口径**。
- **验证**：`moon test -p NoahLiu/native-gui/core` **81/81**（新增 3 条：无子件时走图层档且 `overlay_show_at`/`hide`/`count` 照常、量尺只算可见子项的右/下边界、没有原生档浮层时失焦与收框两条路径都是空操作）；`moon check core`/`win`/四个示例 `--deny-warn` 零警告；ui 110/110、web 11/11、media 18/18 未掉；全仓红点回到 287 errors / 68 warnings。真窗口回证（在**带网页区的桥接窗**里点「浮层盖网页」）：`NATIVE-WEB-OVL opens=1 tier=1 native=1 layer=0`，截图见自绘内容（标题 + 「收起」按钮）压在 WebKit 渲染的正文之上——这条正是图层档做不到的。
- **本批未做（不假装完成）**：点外收起的可用判据（上一条的开关默认关）、Esc 收起、弹层锚点跟随 owner 滚动/移动、六件组件各自的尺寸提示（现在靠三帧收框）。

### MoonBit 原生 GUI 栈 · 原生弹层窗口（批 E：`win/popup.mbt` + `core/popup.mbt`）

- **为什么非要是真窗口**：自绘像素永远画在原生子件（webview 区）**之下**——z 序在原生侧，Painter 无法把它盖住。所以「下拉/右键菜单/tooltip/toast/对话框要能压住网页」这一条只有一条路：走窗口系统（方案 §4.5 的浮层纪律）。本批给的就是这条通道，而不是又一层自绘图层。
- **GTK 侧五条配置必须一次配齐，且必须在 `show` 之前**：`set_decorated(FALSE)` + `set_type_hint(GDK_WINDOW_TYPE_HINT_POPUP_MENU)` + `set_transient_for(owner)` + `set_skip_taskbar_hint/skip_pager_hint(TRUE)` + `set_keep_above(TRUE)`（外加 `set_resizable(FALSE)`）。类型提示与 transient 关系在**映射时**才生效，show 之后再设就晚了。
- **一条实测硬坑：`gtk_window_get_position` 在窗口管理器的 reparent 下恒返回 (0,0)**。它给的是「相对父窗」的坐标，而顶层窗会被 WM 包进装饰框架里，相对框架当然是 0,0。要**屏幕原点**必须问 GdkWindow：`gdk_window_get_origin(gtk_widget_get_window(w), &x, &y)`。判据不是「报错」而是**弹层落点等于请求的局部坐标、与 owner 在哪无关**——多窗形态下所有窗的菜单都会落在同一屏坐标，看起来像「弹层没跟着按钮」。修后实测 `owner_origin=2,34`、请求局部 (420,300) → 落点 (422,334)，与 xwininfo 逐位一致。
- **摆位做成纯函数**：`popup_place(owner_x, owner_y, x, y, w, h, screen_w, screen_h)`——越过屏幕右/下边时翻到锚点另一侧（贴边的菜单向反方向展开），翻完仍为负则钳回 0，屏幕尺寸给 0 表示「只钳不翻」。三条边界都进了断言（含「翻到另一侧仍在屏内就用翻转位而不是钳 0」这条容易写错的）。
- **弹层就是附窗，不需要第二套生命周期**：`App::open_popup` 走批 A 的注册表，因此它天然共享循环与泵、`close_window()` 只摘自己不影响宿主、`App::shutdown` 一起拆。示例回证：选完菜单项后 `xdotool search --name '^popup$'` 归 0 而主窗仍在，`NATIVE-WEB-POP opens=1 closed=1 choice='乙' wins=1 owner_origin=2,34 win_size=1100x700`，截图清楚看到无边框弹层压在 WebKit 渲染的网页文字之上。
- **本批只给通道 + 一份自绘弹层示例**：`core/overlay.mbt` 那六件（tooltip/下拉/右键菜单/对话框/轻提示/悬浮卡）目前仍走自绘图层，把它们接成「有 webview 时用原生档」是下一步（判据：所在窗存在已挂载的 pane 时才切原生窗口，否则保持图层——没有网页时没必要多开一扇窗）。
- **验证**：`moon test -p NoahLiu/native-gui/core` **71/71**（新增 1 条摆位回归，含七种边界）；`moon check win`/`core`/三个示例 `--deny-warn` 零警告；ui 110/110、web 11/11、media 18/18 未掉；全仓红点仍 287 errors / 68 warnings。真窗口回证见上（弹层 240x150 落在 (422,334)、IsViewable、选项即自关、主窗不受影响）。**待使用者目视**：弹层的无边框观感与 keep-above 在多显示器/切窗后的表现。

### MoonBit 原生 GUI 栈 · 媒体播放器（批 D：新包 `yue/media`，CPU 回灌 + 软解）

- **引擎是平移不是重写**：`modules/gui-media` 的 `audio_player.mbt`(416 行) 与 `video_player.mbt`(476 行) 实测**零 @yue 依赖**（只有组件包装层碰 UI），于是引擎与 15 条既有回归整段搬进新包 `yue/media`，只改测试素材路径与一个公开口。旧链踩过的坑（音画不同轴、seek 后进度从零重涨、换载崩溃、播完态与初始态要区分）就随那批测试一起进了新栈——**这批的价值一半在「把老师写对的东西接住」**。
- **素材路径口径变了**：native 测试的可执行文件 cwd 是**工作区根**，不是包目录（旧包在 `modules/gui-media/src` 时写的是 `../ffmpeg-mbt/src/testdata/`）。新包写 `modules/ffmpeg-mbt/src/testdata/av_1s.mp4` 才对，判据是报错里原样打印的那个相对路径。
- **帧回灌的字节序**：ffmpeg 的 sws 目标是 `AV_PIX_FMT_RGBA`（R,G,B,A），而 `render` 的 `Bitmap` 内部是 Cairo `ARGB32` 的小端布局（B,G,R,A、预乘）。所以灌帧必须换 R/B；不透明像素下预乘等于非预乘，alpha 直接写 255。这条在 `rgba_to_bitmap` 里逐字节钉住（wbtest 断言 `10 20 30 00 → 30 20 10 ff`），真窗口回证是 testsrc 彩条颜色不错位。
- **本工具链没有 `FixedArray::of_list` / `Array::freeze` / `Bytes::of_list`**：造测试字节只能 `FixedArray::make(n, b'\x00')` + 按下标写 + `Bytes::from_array`。另外 `String::split` 给的是 **`StringView` 迭代器**（要 `to_owned()` 才拿到 `String`）、`replace` 是带标签参数（`old=`/`new=`）、`StringBuilder()` 才是构造形态（`Buffer::new` 不存在）、`y` 这类未用形参要写 `_y`。
- **UI 与引擎的分层**：`player_t` 放在 `yue/media`（包内 import `@core`/`@render`/`@text`/`@theme`），**不放进 `ui`**——否则每个只用按钮的应用都要链 ffmpeg 与 miniaudio。引擎文件（`audio.mbt`/`video.mbt`/`subtitle.mbt`）保持零 UI 依赖，媒体层不依赖 webview，两者只依赖窗口/布局/事件层（积木原则第 1 条）。
- **时钟与重绘**：引擎的 `tick()`（原 `vp_tick`，本批开成公开口 `tick` + 新增 `frames_decoded()`）由 `@core.set_timeout(33, ...)` 自续驱动，**不在绘制里推进**；每 tick 调 `on_tick(位置, 帧数, 是否在播)` 观测口，示例用它证明「帧在推进、时钟在走」而不是一张贴图。图片对象按 `frames_decoded()` 变化才重建（每帧重建 Image 会把 cairo surface 反复建掉）。
- **seek 防抖做成了分区纯函数**：`player_bar_hit` 把控制条切成「最左 34px 播放键 / 右侧 150px 时间文字 / 中间进度轨」，拖动期间只更新显示位置、**抬手才真 seek**——旧链的坑是每次拖动都 seek，关键帧距离长时画面卡一整拍。断言里两条边界值得记：轨道两端是钳制而非越界（449px 处 >0.99 而不是 ==1.0），负坐标落进播放键区（先分区再算比例）。
- **打不开媒体不静默**：`player_t` 的 `make` 失败时画一块说明板并把原因经 `on_error` 交出去（探测 + 语义化降级），示例的 `err=''` 就是「没有降级发生」的回证。
- **本批未做（记在 TODO，不假装完成）**：倍速（音频侧要时间拉伸，只做视频侧会破坏音画同步——正是本档反复警告的那条）、内嵌字幕轨（mov_text/ass，本批只吃外挂 SRT/VTT 文本）、全屏、音量条 UI（引擎有 `set_volume`，控件没画）、逐帧步进。
- **验证**：`moon test -p NoahLiu/native-gui/yue/media` **18/18**（15 条平移：音频播放/pump/seek/循环、视频解码/时钟/时长/帧尺寸/无音轨静音推进；新增 3 条：字幕四段（时间戳两种写法、SRT/VTT 通吃、行内标记剥离、命中边界含起止与多条拼接）、帧回灌字节序与短包尾像素、控制条分区）；`moon check yue/media`/`./examples/native-web` `--deny-warn` 零警告；core 70/70、ui 110/110、web 11/11、render 43/43、text 29/29 未掉；全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-web` 的「开一扇播放器窗」= 第三扇窗播 `av_1s.mp4` + 内联 SRT）：`NATIVE-WEB-MEDIA frames=10 pos_ms=1000 playing=0 err=''`（1 秒片解满 10 帧、时钟走到 1000ms、播完自动停、无降级），截图见彩条画面颜色不错位 + 白字「第二条字幕（0.6~1.0 秒）」叠在画面上 + 控制条进度满格与 `0:01 / 0:01`。**待使用者肉眼复验**：有声播放是否真出声（本机有 miniaudio 设备）、拖动进度条的 seek 手感、长片倍速与逐帧（本批未做）。

### MoonBit 原生 GUI 栈 · 点进网页后原生输入框打不进字（两处根因：GTK 焦点拿不回来 + 空框不画组合串）

- **症状（使用者真机）**：点进 webview 页面之后再点回原生输入框，打字毫无反应。
- 用 xdotool 注入复现 + C 侧临时探针定位，查出**两处互相独立的缺陷**：
- **① 我们的绘制区从来没把 GTK 键盘焦点要回来**：窗口显示时 `gtk_widget_grab_focus` 过一次，之后 WebKit 子件在点击时拿走焦点；而 `GtkDrawingArea` 不会因为被点击就把焦点还给自己（GTK 不替它做这件事）。探针实证：点回输入框后 `[focus] in` 一条都没有、`[key]` 也一条都没有——键全进了网页（连 Ctrl+Z 都进网页，所以「某些操作看着还有效」是错觉）。修法：宿主在指针按下时**无条件** `request_focus()`——原来只在「焦点栈真的换人」时才要，而换人恰恰不会发生（栈里还是那个输入框）。
- **② 空输入框（显示 placeholder）时组合串根本不画**：`ui/entry.mbt` 的绘制把「画占位符」与「画文本 + 组合串」写成一个 if/else，空框无文本时走占位符分支，**组合串那条分支被整个跳过**。于是拼音在正常走（探针 `[preedit] '爱'` 一直在到），屏幕上什么都不出现，看起来就是「打不进字」。修法：占位符只在「没文本**且**没组合串」时画，组合串独立成一支。这条与网页无关，空框单独也能复现（多行 `textarea` 没这个问题——它的组合串画在占位符循环之外）。
- **顺带收紧一条**：键盘焦点被拿走（`Event::LostFocus`）时把输入法这一会话交还系统——在途 commit 归当前控件、清组合串显示、`im_reset` 打断引擎侧未完成的组合、复位去重缓存；焦点栈不动（回到本窗时控件焦点照旧）。
- **探针方法论（踩了再记）**：应用侧 `println` 在 stdout 重定向到文件时是**块缓冲**，进程被 kill 就全丢——我第一次据此误判「应用侧一条日志都没有」，加 `stdbuf -oL` 才看到真数据；C 侧 stderr 无缓冲，所以两边日志看起来不对称时先怀疑缓冲，别急着下结论。
- **验证**：`[focus] in` 在点回后出现、`[key]` 跟进（修复前两者都没有）；空框打字截图见组合串「爱」带下划线；完整往返流程（清空 → 点进网页 → 点回 → 打字）截图见组合串「阿宝」。`core` 82/82、`ui` 110/110、`input` 10/10、`web` 15/15 全绿，分包 `--deny-warn` 零警告，全仓红点仍 287 errors / 68 warnings。**待使用者复验**：原报场景（网页里点跳转后回原生框打字）是否恢复正常。

### MoonBit 原生 GUI 栈 · 上屏缓冲的所有权（修复：多开大窗花屏 / 自绘区闪烁）

- **症状（使用者真机报）**：开「桥接窗」或「本地视频窗」这类第二扇窗时花屏、自绘区域闪烁；主窗单开时看不出来。
- **根因**：`wm_present` 把 `w->pending` **直接指向 MoonBit 侧的 `Bitmap` 缓冲**，而真正的贴像素在**下一次** draw 回调里做（GTK 只能在 draw 回调里拿 GdkWindow 的 cairo，绕不开）。回调排上之后，那块 Bitmap 在 MoonBit 侧已经没人引用了——`App::paint_frame` 里它是局部量，下一帧就换一个——GC 什么时候收全看压力。收掉之后 expose 再读那个地址就是**已释放内存**，于是花屏；每次 expose 重读一次，看起来就像「一闪一闪」。
- **为什么偏偏是多开大窗**：单窗小画面时那块缓冲往往还没被回收就又被贴一次；多一扇 1000x620 的动画窗，每秒多几十次分配，GC 压力上来了，窗口就落在「已回收但还要被 expose」的窗口期里。覆盖再移开（强制 expose 旧区域）最容易复现。
- **修复**：后端**自己拥有**帧缓冲——`WmWindow` 加 `backing/backing_cap`，`wm_present` 走 `wm_store_frame`（按需 realloc + 一次 memcpy），`pending` 指向自己的缓冲；`wm_close` 释放（槽位会被下一扇窗复用，只 memset 就是既漏又错）。GTK 与 Win32 两条分支同形改，避免两套语义（Windows 侧本机跑不了，只经代码审查，随 W 线真机复验）。
- **一条口径**：跨 FFI 边界「留到下一次回调」的缓冲必须由**被回调的一侧**拥有。只写注释（原先就写着「所有权在 MoonBit」）不解决问题——所有权写清楚了，可没人负责让它活到那一刻。同类形态在 `web` 的 JS 回包、`yue/media` 的帧回灌里都检查过一遍：那两处都是 C 侧自己 `malloc`/`g_free`，没有这条隐患。
- **验证**：改后 `moon build ./examples/native-web` 重链（`build/libyue_win_stub.a` 重编），真窗口跑「开本地视频窗 → 截图 → 用主窗盖住再移开逼一次 expose → 再截图」：23 分钟真片连解 `NATIVE-WEB-LOCAL present=1 frames=1369 pos_ms=56397 speed=1.25x err=''`（一扇 1000x620 的动画窗每秒几十次分配，正是原先最容易落进「已回收但仍要 expose」的形态），日志里 X 错误 0 条，两帧截图内容与视频一致、无条纹脏区；**使用者已在真机复验：桥接窗与本地视频窗不再花屏、自绘区不再闪**。全仓红点仍 287 errors / 68 warnings。

### MoonBit 原生 GUI 栈 · 跨 FFI 句柄的活期（修复：关窗后日志刷满 GTK/WebKit 断言）

- **症状（对照实验定位，不是猜）**：同一份示例，**只关桥接窗**日志干净，**关主窗**（网页区挂着的那个）退出时固定 5 行 CRITICAL——`webkit_web_view_get_title/get_uri` 报 `WEBKIT_IS_WEB_VIEW(webView)` 断言失败，紧跟 `gtk_widget_get_parent`/`gtk_widget_destroy` 报 `GTK_IS_WIDGET` 失败。断言不崩进程，所以之前一直没被当回事。
- **根因**：窗口拆除走的是窗口层的 `wm_close`，它把归属本窗的原生子件槽整格清零并销毁那棵 GtkWidget 树（WebKitWebView 是它的孙子，一起没了）——但**没人通知能力层**。于是 `Webview` 的 `handle` 仍是旧槽号、`pumping` 仍为真：排期泵与示例的状态轮询继续拿这个句柄调 `wb_get_title/wb_is_loading`，而桩里 `wb_get(id)` 只看「槽位有没有 view」，看不出「那个 view 已经随窗口销毁」，就把悬垂指针交出去。最后 `wb_destroy`（退出时 `close`）再拿它 `gtk_widget_get_parent`/`destroy` 一次，就是那两行 `GTK_IS_WIDGET`。
- **修复（一处收口，两条分支同形）**：把「活期」的判据放到**知道拆除时刻的那一侧**——桩里 `wb_view_alive(v)` = 槽位有 view **且** `wm_surface_container(v->surface_id) != NULL`（容器是 win 的槽表给的，窗口一拆就是 NULL，这是唯一可靠的存活信号）。`wb_get` 一律过这道闸，于是**所有**引擎查询与动作在视图死后自动变空操作，不必逐个函数补判据；`wb_destroy` 也走同一条判据——容器没了就只 `g_free` + `memset` 还资源，不再碰那个指针。MoonBit 侧加公开口 `Webview::is_alive()`，泵的那一拍发现视图不在就 `pumping=false`、`handle=0L`、丢掉 `eval_waiters`（停掉排期，而不是继续空转）。
- **一条口径（与「上屏缓冲的所有权」同族）**：跨 FFI 的**句柄**和跨 FFI 的**缓冲**是同一类问题——「什么时候没了」只有拆除的那一侧知道，所以作废判据必须由它给出。MoonBit 侧看 `handle != 0L` 只能说明「建过」，永远说明不了「还在」；把存活判据写进桩里的统一取回函数（`wb_get`），比在 20 个方法前各写一遍可靠得多。同类形态自查（按「是不是又造了一张按 id 查的 C 槽表」筛）：`win` 的 `wm_windows[]` 拆窗后整格 memset，逐个数过取槽点——凡碰 `w->window`/`w->area` 的都已判空返回，其余只读 `ev_count`/`commit_len` 这类计数（memset 后是 0，天然安全），没有这条缝；`yue/media` 的 FFI 面传的是不透明指针（`MbtAdev`）而不是槽号，生命周期由 MoonBit 自己 `close`，形态不同、不在此列。
- **验证**：`moon test -p NoahLiu/native-gui/web` **17/17**（新增 1 条：句柄非零但视图不在时 `is_alive()` 给假、`retire_if_dead` 收口后 `handle=0`/`pumping=false`/`eval_waiters` 清空）；`web` 与示例 `--deny-warn` 零警告；全仓红点仍 287 errors / 68 warnings。真窗口判据（同一条对照实验重跑）：开桥接窗 → 关桥接窗 → 关主窗，日志 **CRITICAL 0 条**（修复前 5 条）、进程自退（`alive=0`）、退出行读数照常（`last='标题 本地桥接页'`）；**使用者已真机复验（2026-10-12）手动逐扇关窗（点标题栏 X）到只剩主窗再关，日志同样零 CRITICAL**。回归两条确认存活判据没把活视图一起挡掉：桥接页照常从协议装载并读出中文标题；主窗协议行 `reg=1 loads=1 files=2 unreg=1 fails=1 fail='WebKitNetworkError/399 yuedemo://local/index.html'`，与修复前逐字段一致。

### MoonBit 原生 GUI 栈 · 内嵌字幕轨（批 D2c：ffmpeg-mbt 暴露字幕流 + 一条时长谎报）

- **字幕流此前根本不存在**：`modules/ffmpeg-mbt` 只定位视频与音频两条流（`vf_open` 里两次 `av_find_best_stream`），字幕包在解码循环里被当作「不是我要的流」直接 `av_packet_unref` 丢掉。本批补第三条：`VfFmt.sstream` + 一个独立的 `VfSDec`（`vf_sub_open`/`vf_sub_next`/`vf_sub_pts_s`/`vf_sub_end_s`/`vf_sub_close`），MoonBit 侧 `subtitle_cues(path)` 一次读完整条轨给 `Array[SubCue]`。
- **必须另开一份容器读**：字幕解码器若与视频/音频共用 `AVFormatContext`，两边都在推进同一个 `av_read_frame` 游标——读完字幕后视频就从中间开始、或直接 EOF。所以 `subtitle_cues` 内部自己 open 一份、读完就关，代价是一次额外的容器打开（字幕是稀疏的、一次读完，比逐帧查便宜），换来的是**播放中途调用也不搅动主时间轴**——这条写成了无头断言（读完字幕后再开一份继续解，帧 pts 照常推进）。
- **一条时长谎报（真数据抓到，不是猜）**：mov_text 解出来的 `AVSubtitle.end_display_time` **恒为 2000ms**（解码器不填条目时长时的默认值），照它读，第一条字幕会压住第二条、并在应该消失之后还挂着一秒。判据是打印出来的表：`0.2..2.2 / 0.6..2.6`（错）对 `0.2..0.6 / 0.6..1.0`（素材本意）。修法取**「包时长」与「end_display_time」里较短的那个**（包时长要在 `av_packet_unref` 之前取，之后会被清零）——mp4 的 sample duration 是权威的，实测落回素材本意。
- **ASS 整行前缀在 FFI 层剥**：部分文本字幕解码器（mov_text 即其一）不填 `rect->text`、只给整行 ASS 对话 `ReadOrder,Layer,Style,Name,MarL,MarR,MarV,Effect,文本`——那是解码器输出的**形状**不是内容，所以归一化属于搬运（`subtitle_ass_text`）。判据保守：至少八个逗号、`ReadOrder` 是非空数字、三个边距字段是数字或空才剥；样式名/人名/特效是自由文本，不能当判据，否则正文里恰好带八个逗号的字幕会被切掉半句（这条有正反用例钉着）。排版标记（`{\an8}`、`<c.xxx>`）仍归 `yue/media` 的 `strip_cue_tags`，与外部字幕同一条清洗路——两种来源在渲染侧完全同形。
- **播放器两条来源 + 一个观测口**：`player_t` 的 `subtitle` 传了就用（明确意图优先），留空才试容器内嵌轨；`on_subtitle(条数, 是否内嵌)` 与既有 `on_tick`/`on_speed` 同构，示例把两个值写进退出行（`NATIVE-WEB-MEDIA ... subs=2 emb=1`、`NATIVE-WEB-LOCAL ... subs=0`），「这条片没字幕轨」与「字幕轨解不开」在回证里分得开——后者会经 `on_error` 报出原因而不是静默给空表。
- **验证**：`moon test -p NoahLiu/ffmpeg-mbt/src` **6/6**（新增 2 条：`subtitle_ass_text` 的剥前缀与三种「不该剥」的反例、真容器 `av_1s_subs.mp4` 整条读出 + 起止秒 + 中文文本 + 不搅动主时间轴 + 「无轨=Ok([])」与「打不开=Err」分开）；`moon test -p NoahLiu/native-gui/yue/media` **24/24**（新增 2 条：内嵌轨转 `Cue` 的搬运与清洗口径对齐、端到端按位置命中）；`yue/media`/`web`/`core`/`ui`/`ffmpeg-mbt` 与 `examples/native-web` `--deny-warn` 零警告，全仓红点仍 287 errors / 68 warnings。测试素材是仓库内自带的 13KB 三流片（`av_1s.mp4` 流拷贝 + 两条 mov_text，`ffmpeg -map 0:v -map 0:a? -map 1:0 -c copy -c:s mov_text`）。**使用者已真机复验（2026-10-12）**：内嵌字幕窗两条字幕按 0.2~0.6 / 0.6~1.0 出现与消失、外挂那条窗行为不变、长素材窗 `subs=0` 不报错。
- **本批未做（不假装完成）**：ASS 的样式渲染（颜色/定位/多轨选择，目前只按文本叠加）、字幕轨列表与切换（多轨容器只取 `av_find_best_stream` 选中的那条）、倍速下的听感复验。

### MoonBit 原生 GUI 栈 · 播放器倍速（批 D2b：纯 MoonBit 重采样 + 时钟同轴）

- **零 C 做到的倍速**：音频侧不需要新桩——解码出的 s16 交错 PCM 在推给设备前按 `1/speed` 做线性重采样（`media_resample_s16`，纯 MoonBit），设备仍按原采样率消费，于是样本少一倍、走完就快一倍。代价是**音高随动**（这是"变速"而不是"变速不变调"，后者要相位声码器）。视频侧时钟只改一处：`vp_target_pts(base, elapsed_ms, speed) = base + elapsed × speed`，两边同轴，所以不会出现「画面快、声音慢」——那正是旧链反复警告过的失同步形态。
- **一条被倍速逼出来的既有缺陷**：tick 原先是"每 tick 至少解一帧"（解一帧后才比 `pts >= target`），于是低帧率视频与**任何慢速**都会跑在时钟前面（画面 30 帧/秒地走、时钟按 0.5 倍速走）。修法是把闸门提到解码**之前**：先看已解帧的 pts，已在时钟前面就不再解。这条同时兑现了 tick 注释里早就写着的「低帧率视频画面跨 tick 保持」。
- **换速要把时钟基准重钉一次**：`set_speed` 先读当前位置、再改倍速、然后把 `base_pts/pos_base` 设成这个位置、`wall0/played_base` 设成当下——不重钉的话位置会按新旧倍速差跳一下。音频位置口径跟着变：队列里是重采样后的样本，所以「消费 N 个样本 = 走过 N×speed 个源样本」，`AudioPlayer::current()` 里那一项要乘 speed。
- **无时间戳的流不假装支持**：回退路径（每 tick 一帧、按流帧率步进）没有 pts 可追，倍速只影响时钟不影响画面，这一点写在 `tick` 的注释里而不是藏在代码里。
- **档位取自表而不是就地加减**：`bar_speeds = [1.0, 1.25, 1.5, 2.0, 0.75]`，点击只推进下标（`player_speed_at(i)`，含负数与回绕），所以不存在 `+= 0.25` 累加漂出档位的可能；钳制在引擎侧（`media_clamp_speed`，[0.25,4.0]，NaN 回 1.0 而不是最快/最慢档）。控制条多出第六个分区（`speed`），轨道起点随之从 114px 挪到 154px，音量条让位阈值从 400 抬到 440——**绘制与命中读同一组常量**这条判据在这批第二次发挥作用。
- **观测口而不是猜**：`player_t` 加 `on_speed(v)`（与既有 `on_tick`/`on_error` 同构），示例把档位写进退出行 `NATIVE-WEB-MEDIA ... speed=1.5x`，回证不必去读引擎内部状态。
- **本批未做（不假装完成）**：内嵌字幕轨（mov_text/ass 要 `ffmpeg-mbt` 先暴露字幕流）、真出声与听感复验（倍速下是否仍同步、音高随动是否可接受）。
- **验证**：`moon test -p NoahLiu/native-gui/yue/media` **22/22**（新增 3 条：倍速档位表含回绕与负下标 + 标签短写法、`media_clamp_speed` 与 `vp_target_pts` 三条算式、`media_resample_s16` 的 2 倍/0.5 倍样本数与插值中点与双声道不串位及三种原样返回情形；另在真机解码那条里加 `get_speed` 钳制回环；控制条分区测试改到六段）；`moon check yue/media`/`./examples/native-web` `--deny-warn` 零警告。真窗口回证（`examples/native-web`「开一扇播放器窗」→ 在控制条倍速区连点两下：1x→1.25x→1.5x）：`NATIVE-WEB-MEDIA frames=10 pos_ms=1000 playing=0 speed=1.5x err=''`——档位由 `on_speed` 观测口报出（不是读引擎内部），1 秒片在 1.5 倍速下仍解满 10 帧并走到 1000ms 后自停、无降级；截图见控制条 `▶ |< >| 1.5x` + 进度满格 + 音量条 + `0:01 / 0:01`。**使用者已真机复验（2026-10-12）**：倍速下音画仍同步、音高随动可接受、音量条拖动确实变响。

### MoonBit 原生 GUI 栈 · 播放器控制面补齐（批 D2a：逐帧步进、音量条、全屏）

- **逐帧步进必须「当场解到落点那一帧」**：`seek` 会把当前帧清成 `None` 等下一 tick，而**暂停时 `tick()` 直接返回**——于是步进后画面停在黑帧，看起来像「按了没反应」。修法是把 tick 里那段「从解码点向前解到目标时刻（上限 8 帧）」抽成 `vp_settle`，步进 = 先暂停 → 按 `1/fps` 挪位置 → `seek` → `settle`。判据全在无头那条里：步进后 `frames_decoded()` 增加、`current()` 前进、`current_frame()` 非空、`is_playing()` 仍为假（步进不许把播放态带起来）。
- **控制条从三段分区变五段**（播放 / 上一帧 / 下一帧 / 进度轨 / 音量 / 时间文字），绘制与命中读**同一组** `BAR_*` 常量——分区写在两处迟早会对不上。另加一条「窄条让位」判据：`w < 400` 时音量条整个不画也不响应（轨道右端改按时间文字算），否则会出现「看得见却点不着」或反过来。轨道两端仍是**钳制**而不是越界（114px 处 =0.0、354px 处 >0.99）。
- **音量与 seek 的防抖方向相反**：seek 抬手才真做（每次真 seek 要回关键帧，代价高），音量**每步都生效**（边拖边听才是预期，且它不触发解码）。音量条画的是 `engine.get_volume()`（引擎里那份钳制值）而不是组件本地副本——本地副本在 set 被钳制时会与显示不一致。为此给 `VideoPlayer` 补了 `get_volume`（`AudioPlayer` 早有，两边口径对齐）。
- **全屏是窗口级动作**：控件层拿不到窗口，所以链路是 `Window::set_fullscreen` → `App::set_fullscreen`，由宿主（示例）挂按钮请求；C 侧只有 `gtk_window_fullscreen`/`unfullscreen` 两行（ABI-only，判据见「C 桩按需且 minimal」那条口径）。切换后尺寸变化照常走 allocate 事件，宿主不需要自己算新矩形。
- **本批未做（不假装完成）**：倍速（音频侧要么时间拉伸、要么走 miniaudio 的 pitch，两者都要改设备线程那条路，另批做并写清音高随动的代价）、内嵌字幕轨（mov_text/ass 要 `ffmpeg-mbt` 先暴露字幕流）、真出声复验。
- **验证**：`moon test -p NoahLiu/native-gui/yue/media` **19/19**（新增 1 条逐帧步进：`n=0` 不动、步进后帧数/位置/有帧/仍暂停四条都成立、两端钳制、`get_volume` 给钳制值；控制条分区测试改到五段 + 窄条让位）；`moon check win`/`core`/`yue/media`/`./examples/native-web` `--deny-warn` 零警告。真窗口回证（`examples/native-web`「开一扇播放器窗」→ 注入 `>| ×2`、`|< ×1`、音量条中段、全屏按钮）：`NATIVE-WEB-MEDIA frames=21 pos_ms=1000 playing=0 err=''`（1 秒片正常播完 10 帧后再被步进解到 21 帧，说明步进真在解码；`err=''` 即无降级），点全屏后 `xdotool getwindowgeometry` 给 `Position: 2560,0 Geometry: 2560x1440`（附窗真的铺满第二块屏），截图见控制条 `▶ |< >|` + 进度轨 + **音量条**（拖到中段后填充可见）+ `0:00 / 0:01`。**待使用者肉眼复验**：逐帧步进的画面跳动观感、音量条拖动手感与是否真变响、全屏下字幕与控件的位置。

### MoonBit 原生 GUI 栈 · 本地内容通道与导航细粒度原因（批 C 余项：`web/scheme.mbt`）

- **协议按 context 注册，不按视图**：`webkit_web_context_register_uri_scheme` 的回调签名是 `(WebKitURISchemeRequest*, gpointer)`——**没有 view 参数**，所以协议归属天然是 context 级；旧链那种进程级静态注册在多 profile（profile 挂 pane 级）之后语义就不清了。本批的槽表按 `(context, scheme)` 去重：同一 context 下同名协议只向引擎注册一次，再注册只换根目录。
- **「注销」是顶替而不是撤销**：WebKit 没有 unregister-uri-scheme。注销 = 把这条 scheme 的根目录清空，回调从此一律走 `webkit_uri_scheme_request_finish_error`，页面拿到「协议在、内容取不到」。这比留着旧目录安全（切了 profile 还能读到上一个 profile 的文件），也比「假装能撤销注册」诚实——返回值只表示顶替成功。
- **只做根目录下的静态文件，路径穿越在桩侧拦**：请求 path 含 `..` 直接回错误，不做绝对化、不跟符号链接逃逸；MIME 按扩展名查表（html/htm/css/js/mjs/json/svg/png/jpg/jpeg/gif/woff2/txt），其余 `application/octet-stream`。
- **一条口径（2026-10-12 定案）**：C 桩**按需且 minimal**——只在 MoonBit 够不着的地方写（GTK3 窗口层、Cairo、Pango、WebKitGTK、miniaudio/ffmpeg、dirent/getenv/spawn、socket），C 里只做 ABI 翻译与槽表，判断/解析/降级语义一律留在 MoonBit；加函数前先查「已有的 MoonBit 通道能不能组合出来」。本批就是一次实际取舍：目录创建没有新增 C，`sys_make_dirs` 用既有的子进程通道组合（`pr_run("mkdir", ["-p", path])`，仓库里 `defaultapps_wbtest` 已有同样先例），代价是它只在 `pr_available()` 为真的平台上成立，所以函数文档写明「探测即口径」，而不是让调用方以为处处可用。
- **当天晚些回访并修正——口径管的是能力，不是「`sys` 不许有 C」**：两条路**真等价**时才组合，**不等价就加 C**。目录创建按组合写法落地后，代价一实测就兑现：它实际只在 POSIX 成立，因为 Windows 的 PATH 上没有 `mkdir`，`fsx_wbtest.mbt:109` 从上线那天起在 Windows 上就是红的。现改为薄 FFI `yue_sys_make_dirs`（Windows 逐级 `CreateDirectoryW`、POSIX 逐级 `mkdir(2)`），与本来就是 C 的 `sys_read_text_file` / `sys_remove_file` / `fsx_list_dir` 归为同族——这不是给口径开了新例外，而是把唯一那个不合群的成员抹平，顺带丢掉一个子进程依赖（不再要求 `pr_available()`，也不必每次 fork + 落两个临时文件）。
- **`CreateDirectoryW` 对盘符前缀给的不是「已存在」**（本批真机实测）：逐级建目录时把 `"C:"` 当一段去建，它返回 **`ERROR_ACCESS_DENIED(5)`** 而不是 `ERROR_ALREADY_EXISTS(183)`——只认 183 会把盘根读成失败、整个调用返回 0。判法是**先探再建**：`GetFileAttributesW` 有效说明这一级已在，直接跳过；创建期竞态再容 183。POSIX 没这坑——`mkdir` 对已存在目录就是 `EEXIST`。
- **写文件不会顺手建父目录，而症状出现在别处**（本批真窗口踩到）：页面区只显示一句 `not found`，看着像协议没通，实际是根目录 `/tmp/native-web-scheme` 压根不存在、两份 `sys_write_text_file` 全失败。修法是 `sys_make_dirs`，但**判据要先拆开**：示例的退出行加了 `files=` 计数（注册成功 / 加载发出 / 文件真在不在），少了这一段就得靠猜是哪条链断的。
- **导航细粒度原因两条**：① `WEBKIT_LOAD_REDIRECTED` 出 kind 15——调用方要能区分「换了地址」与「重新加载」；② load-failed 的载荷结构化成 `uri|domain|code|message`（`domain` 用 `g_quark_to_string` 给名字），MoonBit 侧 `nav_error_parse` 拆成 `NavError`；错误文本里可能有 `|`，所以前三段按位置取、剩下的全归 message，段数不足给 `None` 而不是猜字段。
- **一条只有真窗口能抓到的接缝缺陷**：`WebEvent` 里**有** `LoadFailed`，而 `Webview::dispatch` 的 kind 表里**没写 14**，于是每次失败都落成 `Unknown(14, raw)`，调用方永远读不到原因。无头套件当时号称「kind→事件逐条映射」却漏了它——因为被走查的那张表本身就跳过了 14：**两半各自有测试，中间那道映射没有**。现在 2/3/4/14/15 全钉进那条测试，另加一条端到端（dispatch 14 → `LoadFailed` → `nav_error_parse` 拆出四段）。
- **`load_html` 装入的页面不进前进/后退历史**（真窗口实测，别当成回退坏了）：桥接页是 `load_html` 装的，随后点一个不存在的域名（示例里的 `a.example`——`.example` 是 RFC 2606 保留域，DNS 必然失败），当时读到 `can_back=0 can_fwd=0`、`go_back()` 空操作。**但根因不是「失败导航清了历史」**——把四步分开测就清楚了：
  ```
  after-load_html  url=https://local.test/  can_back=0   ← load_html 不入历史
  after-ok-nav     url=https://example.com/ can_back=1   ← 成功导航入历史
  after-fail-nav   url=https://a.example/1  can_back=1   ← 失败导航不清历史
  after-go_back    url=https://example.com/ can_fwd=1    ← 真的退回去了
  ```
  也就是说：失败导航照常留下可回退状态；那次之所以是 0，是因为桥接页历史里除了 `load_html` 那一项本来就没别的条目。**跨平台一致**：WebView2 文档对 `NavigateToString` 明写「the back or forward history will not be modified」，与 Linux 实测同形；macOS 的 `loadHTMLString:baseURL:` Apple 未作承诺，随 mac 真机验（已记 TODO）。**口径两条**：① 引擎语义决定的空操作必须在 UI 上说实话（示例的按钮现在要么记「后退 → url」要么记「后退：无处可退（can_go_back=0；load_html 不入历史）」），否则看着就是 bug；② 要给本地页一条真历史，就用上一条的自定义协议给它一个真 URL 再 `load_url`，别用 `load_html`。
- **自定义协议的公开面收成「名字先预声明」**（2026-10-12，三平台取严）：Linux 允许随时按 context 注册新 scheme，但 WebView2 的名单挂在**环境选项**上（建 environment 之前，一进程一次）、WKWebView 挂在**建视图之前**的 configuration 上——把「运行时新增名字」当公开语义，就是在写一份在 Windows/mac 上会失效的代码。现在：`webview_predeclare_schemes([...])`（第一扇 webview 之前）→ `register_protocol(scheme, root)` 只认已声明的名字（根目录随时可换、`unregister_protocol` 照旧顶替成错误 handler）；名单在建视图时由 `webview_seal_schemes()` 封版，空名单补缺省名 `app`，零配置可用。Linux 那份动态能力留在桩里不对外。**验证**：`web` 16/16（新增一条：建视图即封版、未声明的名字注册被挡、封版后再声明返回 false 且名单不变），真窗口 `NATIVE-WEB-SCHEME reg=1 loads=1 files=2`（示例先 `webview_predeclare_schemes(["yuedemo"])` 再建视图，协议页照常生效）。
- **协议登记也要能吃「挂载前」**（2026-10-12，把桥接窗改成协议页时抓到）：pane 的视图是「第一次拿到真实矩形」那一帧才建的，`register_protocol` 原先照 `handle != 0L` 判，于是挂载前一律 false——调用方得自己排期等挂载，而 `load_html` 早就有 `pending_html` 了，同一件事两套规矩。现补 `pending_protos`：挂载前排的 `(scheme, root)` 记下来，`mount_at` 建完视图即应用；`unregister_protocol` 先撤这份待应用的登记（撤到过算 true，本来没登记过仍 false——「未挂载」不等于「随便成功」）。**判据**：示例第一次跑落在了 `load_html` 退回分支并打出「协议未就绪」，就是这条接缝。
- **协议通道只回 MIME，文本类不钉 charset 就是乱码**（同批真机截图）：`wb_mime_of` 对 `.html` 返回裸 `text/html`，WebKit 没有别的口径可猜编码，按 ISO-8859-1 解，中文页整屏花（`桥接页大标题` 成串乱码）。修法两处：桩里文本类扩展名一律带回 `charset=utf-8`（html/css/js/json/txt），页面自身也补 `<meta charset="utf-8">`——两道各自都够用，但走协议时**只有 HTTP 头这一道是可靠的**（`<meta>` 要在解码到那一个字节之后才起作用，而首屏字节已经按错码表解过了）。**验证**：`web` 16/16、`web` 与 `examples/native-web` `--deny-warn` 零警告；真窗口截图见协议页中文正常，事件区 `后退 → yuedemo://local/bridge.html` 证明协议页**在历史里**且退得回去（对照：同一页用 `load_html` 装入时后退是空操作），退出行 `navs=5 … dom_ok=1 text_bytes=68 … last='标题 本地桥接页'`。
- **协议通道只给 MIME，所以文本类必须自己带上 `charset=utf-8`**（真窗口抓到的乱码）：同一份桥接页 HTML 走 `load_html` 中文正常、走 `yuedemo://` 装入就整页成 `æ¡¥æŽ¥é¡µ`。根因是两条通道的编码口径不同——`webkit_web_view_load_html` 的入参本身就是 UTF-8 文本，引擎按 UTF-8 解；协议回灌只递一个 content type，裸 `text/html` 没有编码声明时 WebKit 按 ISO-8859-1 解（页面里的 `<meta charset>` 要等解出标签才看得见，而标签已经先被解坏了）。修法在桩侧一次性收口：`wb_mime_of` 对 html/css/js/mjs/json/txt 一律返回 `...; charset=utf-8`，二进制与图片不动。**口径**：走协议发文本时 MIME 是唯一编码口径，别指望页内的 `<meta>`；页内声明照写（存成文件用别的浏览器打开时还要靠它）。
- **挂载前排的登记要受理，不然「先注册再加载」这条自然写法只能调用方自己等**：视图在第一次拿到真实矩形那一帧才建，`register_protocol` 原先在未挂载时一律 false，示例里桥接窗就是这条路径（`win.mount` 之后立刻注册 → false → 退回 `load_html`，页面上「后退」于是永远空操作）。现在与 `pending_html` 同源：未挂载即记入 `pending_protos`，`mount_at` 建完视图逐条应用，`unregister_protocol` 能把还没应用的登记撤掉（撤到过返回 true，没得撤才 false）——「未挂载」不等于「随便成功」。**示例随之改判据**：桥接页改走协议（真 URL 才有真历史），注册失败时不再静默降级，事件区明写「协议未就绪，退回 load_html（此页不入历史）」。
- **验证**：`moon test -p NoahLiu/native-gui/web` **16/16**（新增 4 条无头：`nav_error_parse` 的四段与「message 里带 `|`」与段数不足、`nav_parse_int` 的负号与非数字即停、未挂载时注册受理/注销可撤/双重注销 false、上面那条 kind 14 接缝）；`moon test -p NoahLiu/native-gui/sys` **164/164**（新增 1 条 `sys_make_dirs`：逐级建目录→写→读回、幂等、空串拒绝、父目录缺失时写失败）；`moon check sys`/`web`/`./examples/native-web` `--deny-warn` 零警告。真窗口回证（`examples/native-web` 的「批 C 余项」一行，两段判据分开跑）：① 加载协议页 `NATIVE-WEB-SCHEME reg=1 loads=1 files=2 unreg=0 title='本地协议页'` + `NATIVE-WEB-STAT ... title='本地协议页' url='yuedemo://local/index.html'`，截图两条硬证据——页面标题是协议页的 `<title>`、正文段落带蓝底（`style.css` 也是走 `yuedemo://` 取到的，不是内联）；② 注销后重载同一 URL `unreg=1 fails=1 raw=0 fail='WebKitNetworkError/399 yuedemo://local/index.html' title=''`，页面区把 `finish_error` 里给的文本原样画出来（屏幕上就是 `scheme unregistered` 一行），证明「注销=顶替成错误 handler」真的生效、且失败原因是**结构**而不是字符串。顺带一条枚举事实：`WEBKIT_NETWORK_ERROR_FAILED = 399`（不是直觉的 -1）。③ 桥接页改走协议后的四条一起回证（注入点击，截图读事件区）：`导航开始 yuedemo://local/bridge.html` → 点链接甲 `加载失败 g-resolver-error-quark/0 https://a.example/1` → 点「后退」`后退 → yuedemo://local/bridge.html`（**这次真退得回去**，之前 `load_html` 那条永远空操作）→ 页面区中文标题/正文/链接全部正常、`抓正文 ok=1 title=本地桥接页 链接=0`（DOM 抓取走的是协议页，标题按 UTF-8 读回）。**使用者已真机复验（2026-10-12）**：协议页中文正常、点保留域链接报出结构化原因、「后退」真回到桥接页。留一条口径给后来人：两扇窗没各给数据目录时共用同一个 context，主窗的「注销该协议」会把桥接窗的根目录一并清空（重新注册即恢复，示例注释里已写明）。

### MoonBit 原生 GUI 栈 · JS 桥 / DOM 抓取 / 导航面（批 C：`web` 的 webkit 桩与契约面）

- **异步事件一律「C 排队 + MoonBit 消费式取」，不写 C→MoonBit 蹦床**：WebKit 的导航、标题、JS 回包、页面 `invoke`、权限、下载、进程终止都是引擎侧异步信号，若每个都做闭包蹦床，就要替 12 个回调各自管生命周期与线程归属。本批的形态是 per-view 一条 32 格环形队列（`wb_next_event` 取 kind、`wb_event_num`/`wb_event_text` 读载荷），队列满**丢最旧**——事件是提示不是账本，堵死会把主循环拖住。
- **泵不挂在绘制里**：回包回调可能装载/卸载控件（例如抓到链接后要重画列表），而绘制遍历中途改树是本栈一直避免的形态（`Widget::paint_at` 正在逐层 translate+clip）。于是挂载时起一条 `@core.set_timeout(30, ...)` 自续的排期泵，`close` 即停。
- **`load_html` 在未挂载时不能丢**（本批真窗口踩到）：pane 的挂载发生在「第一次拿到真实矩形」那一帧，`win.mount(...)` 之后立刻 `load_html` 时句柄还是 0，页面区就只剩 `about:blank`。判据是 `navs=1` 且事件里只有 about:blank、抓取全空。修法与 `load_url` 同构：记下 `pending_html`，`mount_at` 建完视图立刻应用。
- **抓取脚本的括号配平要钉住**：四档各自拼 `}})` 时多写了一个右括号，页面侧回包是 `SyntaxError: Unexpected token '}'`。解析层把它判成 `ok=false` 是对的（不静默），但生成器得钉：改成统一包裹 `dom_wrap(fields)`（四档只写自己的字段），并加一条断言 `{`/`}`、`(`/`)` 数量相等且以 `})` 收尾。
- **2.52 的权限入口只有一个**：`decide-policy` 的枚举里**没有** `WEBKIT_POLICY_DECISION_TYPE_PERMISSION_REQUEST`（只有 NAVIGATION_ACTION / NEW_WINDOW_ACTION / RESPONSE），权限只能连 `"permission-request"` 信号；而且 `webkit_permission_request_allow(request)` **只有一个参数**（不是旧文档里的 `(request, gboolean)`）——回调返回 TRUE 表示「我们自己处理了」，所以默认拒绝就是「报事件 + 返回 TRUE」，放行则是「显式 allow 之后仍返回 TRUE」。
- **可选信号先 `g_signal_lookup` 再连**，并把在位情况做成掩码报出去（`wb_signal_mask()`：1 下载 / 2 进程终止 / 4 权限 / 8 新窗）。缺哪条就少哪条回证，不让「回调没触发」和「没实现」混成一个现象。
- **两个 API 形态与直觉相反**：① `webkit_cookie_manager_get_cookies_finish` 在 webkit2gtk-4.1（这一支链的是 libsoup-3.0，头与库随 `pkg-config --cflags/--libs webkit2gtk-4.1` 一起给）返回的是 **`GList` 而不是 `GSList`**，元素是 `SoupCookie`；② 2.40+ 的 `webkit_web_view_evaluate_javascript_finish` 直接给 **`JSCValue*`**（旧的 `run_javascript_finish` 才给 `WebKitJavascriptResult*`），而 `jsc_value_to_string` 对 JS 字符串返回**不带引号**的内容——所以「结构化载荷」就是 JSON 文本本身，不需要再脱一层引号。
- **profile 挂 pane 级**：`wb_create` 的 `data_dir` 非空时走 `webkit_website_data_manager_new(base-data-directory, base-cache-directory)` + `webkit_web_context_new_with_website_data_manager` + `webkit_web_view_new_with_context`；空则用默认 context + 自带 user content manager。`browser_profile_persistence()` 在 Linux 恒 `Persistent`（macOS 才有「14+ 且要有 bundle id」那道 API 边界），探测口留着，调用方不必为平台写分支。
- **两条示例侧计数坑**：① 四档抓取共用一组计数器时，最后一档（结构）没有正文与链接，直接赋值会把前面几档的回证冲掉——取峰值；② 带子 X 窗（WebKit）的顶层窗用 `import -window <id>` 截出来是条纹状脏区，必须 `import -window root -crop WxH+X+Y` 截合成后的屏幕。
- **契约名沿用旧链**（`load_url`/`get_url`/`get_title`/`reload`/`stop`/`go_back`/`go_forward`/`can_go_back`/`can_go_forward`/`is_loading`/`load_html`/`set_user_agent`/`execute_javascript`/`execute_javascript_with_result`/`add_user_script`/`add_raw_binding`/`remove_binding`/`has_bindings`/`get_cookies_for_url`），`current_url` 作 `get_url` 别名。`remove_binding`/`remove_all_user_scripts` 恒返回 false 并写明原因：WebKit 没有注销口，别让它看起来像本栈的实现缺陷。新窗（`window.open`）默认拦下并回报事件，可选「在当前 pane 里导航过去」——本栈不做一窗多 webview。
- **验证**：`moon test -p NoahLiu/native-gui/web` **11/11**（新增 9 条无头：抓取脚本形态与括号配平、四档 JSON 的结构化解析、解析失败 `ok=false` 且 raw 留着、未挂载时全部调用安全且 `capture_dom`/`add_raw_binding`/带结果的求柄给 false/-1、kind→`WebEvent` 逐条映射、JS 回包按序号配对且只回调一次、invoke 双路（`on_invoke` + 旁路 `on_event`）、持久化探测与引擎在位一致）；`moon check web`/`./examples/native-web` `--deny-warn` 零警告；core 70/70、ui 110/110 未掉；全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-web` 的「开一扇桥接窗」= 第二扇窗装一份 `load_html` 的本地页，不依赖网络）：`NATIVE-WEB-JS binding=1 evals=1 dom_ok=4 dom_bad=0 links=3 text_bytes=68 meta=1 headings=2 elements=14 invokes=1 navs=2 perms=1 wins=1 crashes=0 cookie_bytes=2 last='invoke {"msg":"来自页面","n":7}'`；合成截图三条硬证据——页内正文显示「已被原生改过」（原生→网页 `execute_javascript` 真改了 DOM）、原生事件区逐条列出「页面回话 {...} / 权限请求（默认拒绝）WebKitGeolocationPermissionRequest / 新窗请求已拦下 https://b.example/2」、且桥接窗数量仍为 1（新窗被拦下而不是开出第二个 webview）。**使用者已真机复验（2026-10-12）**：网页内滚动与点链接正常；webview 聚焦时本栈输入法让位、点回原生框后恢复可打字。

### MoonBit 原生 GUI 栈 · 角色区（pane）与 webview 通道（批 B：`win/surface.mbt` + 新包 `web`）

- **窗口内容改成「绘制区 + 可定位子件」的 `GtkFixed`**，而不是 `GtkOverlay`：Overlay 要靠 `pass_through` 让事件穿过容器，而带子件的容器在 Overlay 下事件归属不可靠（容器自身透明不等于它的子件也正确）；`GtkFixed` 是普通容器，指针落在子件上归子件、落在别处归绘制区，**零额外机制**。代价是要自己跟尺寸：`fixed` 的 `size-allocate` 里给绘制区 `set_size_request`，且必须加「尺寸没变就不设」的闸门——`set_size_request` 会再触发一轮分配，无条件设就自激。
- **子件槽表要记归属窗口**：`WmSurface{container, window_id, kind, x,y,w,h}`，`wm_close(window)` 里把属于该窗的槽一并清掉。否则窗口先拆、能力层（webkit 桩）还拿着悬垂的 `GtkWidget*` 去 `gtk_fixed_put` 就是段错误。槽位同样复用（扫 `container == NULL`），与批 A 的窗口槽一个判据。
- **C 之间传指针、MoonBit 只搬整数**：`wm_surface_container(int64) -> GtkWidget*` 由 win 导出，`web/webkit_stub.c` 里 `extern` 声明后使用（同一个可执行文件内链接）。这样 `web` 的 MoonBit 层不引 `win` 的 MoonBit 层，包依赖保持「webview 只依赖窗口/布局/事件层」。
- **缺 webkit 开发包不是错误，是降级**：`scripts/prebuild.py` 探 `webkit2gtk-4.1`，探到就带 `-DWB_HAVE_WEBKIT` 编真实现并把 `-lwebkit2gtk-4.1` 下发给 `web`；探不到就编**无宏**那份占位分支（`wb_available()` 返回 0）。两条都要保证 `wb_*` 符号存在——否则是链接期断，不是运行期降级。桩文件的分支形态照 win：`#if defined(WB_HAVE_WEBKIT)` / `#elif !defined(__linux__)` / 其余为空翻译单元，避免与 prebuild 的 `.a` 双定义。链接顺序 `-lyue_web` 在 `-lyue_win_stub` 之前（前者引用后者的符号）。
- **亚像素必须四舍五入，不能截断**：pane 矩形来自 yoga（Double），每帧同步给子件。若按截断，0.4px 的漂移会让「矩形变了」恒真，于是每帧多走一遍 FFI + 一次原生重排。规则钉在纯函数 `webview_rect_key`（`round()`，负坐标同口径）里，去重按取整后的键比。
- **`ChildKind` 是登记制**：目前只有 `Webview = 1`。子表面只保留「原生控件嵌入」这一条语义（方案 §4.5），不开放自定义值——否则又变成「通用子表面」那句空话。
- **验证**：新包 `web` 无头 2/2（取整与去重键、探测与构造一致且未挂载时零句柄、没挂过就 `close` 安全）；`moon check win`/`web`/`./examples/native-web` `--deny-warn` 零警告；core 70/70、ui 110/110 未掉；全仓红点仍 287 errors / 68 warnings。真窗口回证（`examples/native-web`，本机 X11/XFCE + WebKitGTK 2.52.6）：分栏形态 `NATIVE-WEB-STAT supported=1 loading=0 title='Example Domain' url='https://example.com/'` + `NATIVE-WEB-GEO pane=262,71,848x605 sidebar=12,71,240x605`（两区不重叠）；xdotool 注入「整页/分栏切换 + 载入 + 在页面区点一下」得 `loads=1 toggles=1 mode=full pane=12,71,1098x605`，截图复核页面真的由 WebKit 渲染且切整页后按新宽度重排（**同一条 pane 机制出两种形态**）。**待使用者肉眼复验**：网页内滚动与点链接、webview 聚焦时我们侧纯通道 IME 是否让位（离开后恢复）。

### MoonBit 原生 GUI 栈 · 多窗口宿主（`core/host.mbt`：一宿主管 N 窗）

- **形态**：一扇窗 = 一个 `App`（自己的平台窗口 + 控件树 + `FocusStack` + 输入法/悬停/捕获状态），窗与窗只共用两样——`Loop`（进程级唯一时基，`host_loop()` 建一次）与平台泵（`@win.wait`/`wake` 本就进程级）。注册表只管「有哪些窗、当前是哪扇、关一扇退不退」，`App::step` 改成逐窗排空事件 → 逐窗喂输入法 → 脏窗上屏，遍历一律走 `host_windows()` 快照（排空途中关窗会改表）。
- **主窗裁决**：注册表里第一扇是主窗，关掉主窗或关掉最后一扇才整体退出（`host_close_action(primary, remaining)` 是纯函数，无头可测）；关附窗只摘自己。关窗顺序仍是「先停派发、再拆对象」：`running=false` → 摘表 → `window.close()`。`App::shutdown` 则把**所有**还在的窗一起拆（附窗可能开着），句柄已回收成 -1 的窗 `wm_close` 幂等。
- **两条进程级单槽必须升级，否则多窗会画错/查错**：① `invalidate()` 的重绘钩子改成**广播**（所有在窗置脏 + 一次唤醒）——一个 Store 同时影响两扇窗时两边都重画，被多余置脏的那扇只多一帧，不会画错；② 浮层宿主从「一个 `OverlayHost`」改成**取用函数**（`set_overlay_provider(() -> OverlayHost?)`），浮层开在**当前窗**（新窗建好即当前窗，哪扇收到输入就切哪扇，当前窗被关退回最后一扇）。`set_overlay_host(h)` 保留为静态形态，无头测试照旧用。
- **一条设计缺陷是本批被多窗暴露出来的**：浮层句柄原先按宿主各自从 1 数起，两扇窗的「1 号」撞号；改成**进程级递增**（`overlay_cid()`）并新增 `overlay_ids()`/`overlay_top_id()`。判据不是编译错而是**测试崩**：`ui` 里十几处把句柄写死成 `overlay_root_of(1)`，跨测试累积后取到 `None` → `children()[0]` 直接 `Array::at` 越界 SIGABRT。纪律：**句柄是运行期分配的，调用方只能拿返回值或 `top_id()`，不许写字面量**。
- **`raise` 是 MoonBit 关键字**：`pub fn OverlayHost::raise(...)` 不是报「保留字」而是**整条函数头解析失败**，错误连锁成 `The value identifier self is unbound` + `unexpected token if, you may expect pub|fn|...`，看上去像函数体写坏了。方法名撞保留字时改叫 `raise_layer` 之类，判据是错误从函数头那行开始。
- **GTK 桩的窗口槽要能复用**：`wm_window_new` 原先只 `wm_next_id++`，附窗反复开合会把 32 个槽吃光（表现为 `App::open_window` 静默返回 None）。改成扫第一个 `area == NULL` 的槽——建窗时 `area` 必设、`wm_close` 里 `memset` 清零，所以「拆过的」与「没用的」同样可取。
- **跨窗注入的坑：点击会把别的窗抬上来**（XFCE 默认 click-to-raise）。第一轮实测里「关闭这扇窗」的点击没生效、`closes=0`，看着像按钮坏了；实际是先点主窗把主窗抬到关于窗之上，那一击落在了主窗覆盖的区域上。判据：**跨窗注入前必须 `xdotool windowactivate --sync <目标窗>`**，并且用「点完后 `xdotool search --name 关于` 还在不在」这种可观察状态判定，而不是只看计数。
- **示例侧两条口径**：① 每扇关于窗**自持 Store**（两窗共用一个 Store 会让「打字进哪扇」失去意义，退出读数也会互相覆盖）；② 冒烟自杀点从 12 秒放宽到 25 秒——多窗形态要按「开窗 → 在第二窗点与打字 → 关窗 → 再开」多步注入，12 秒走不完一轮。
- **验证**：`moon test -p NoahLiu/native-gui/core` **70/70**（新增 8 条无头注册表回归：`host_loop` 两次取回同一对象（用 `pending()` 计数证同一性，`started()` 证不了）、主窗/附窗与摘表回退、关窗裁决三态、`close_window` 幂等且附窗不停主窗、`invalidate` 广播置脏、浮层落当前窗且两窗各自一套栈与句柄、`mount` 只升本窗图层、`shutdown` 拆所有窗并复位）；`ui` 110/110、`chart` 189/189、`mdview` 26/26、`render` 42/42、`text` 29/29、`input` 10/10、`theme` 8/8、`sys` 163/163、`dbus` 64/64、`yoga-mbt` 96/96 全绿；`moon check ./examples/native-app`/`./examples/native-sys` `--deny-warn` 零警告；全仓红点仍 287 errors / 68 warnings 未增。真窗口回证（`examples/native-app` 顶部「多窗口（批 A）」面板 + 「关于（第二窗）」）：`NATIVE-APP-MW wins=1 opened=1 closes=1 main_clicks=1 sub_clicks=2 sub_entry_bytes=2 sub_focus=101`，几何行 `NATIVE-APP-MW-GEO open=688,262,160x32 sub_btn=16,53,464x32 sub_entry=16,85,280x32 sub_close=16,117,464x32`；注入序列「点开 → 第二窗计数两下 → 第二窗输入框打字并提交 → 主窗对照键 → 第二窗关闭 → 再开一窗」，中途 `xdotool search --name 关于` 从有到无而主窗 id 始终在（**关单窗不影响宿主**），第二窗截图见「本窗点击 2 / 在窗 2」与输入框里的提交文字（**每窗一棵树、焦点栈按窗独立**）。**待使用者肉眼复验**：两窗同时拖动/遮挡时的重绘、关于窗里 preedit 下划线观感。

### MoonBit 原生 GUI 栈 · 单实例与 logind 亮度接线（`dbus`：instance 收口 + `bridge.mbt`）

- **单实例走「总线名字声称 + Wake 入站调用」**：首实例 `RequestName(app_id, DO_NOT_QUEUE)` 拿 `PrimaryOwner`（重复声称得 `AlreadyOwner`，幂等），第二实例 `RequestName` 拿到 `AlreadyExists`/`InQueue` 时改调首实例 `org.moonbitlibyue.Instance.Wake('as' 命令行)` 然后自己退出；首实例收到 Wake 先应答再触发回调（`is_wake_call` 在 `bus.mbt` 的入站分支里优先判——第二实例的 `call_sync` 有时限，回调里做恢复窗口这种耗时活不能让对端干等）。示例回证：首实例跑着时再启一次，第二实例打印「已有实例，已唤起并退出」并 `exit=0`，首实例打印「收到第二实例的唤起」。
- **亮度写路径的接线方向是单向的**：`dbus` 依赖 `sys`（环境变量、子进程、sysfs 读），反过来不行；所以 `bridge.mbt` 在调用方启动时把 logind 能力**注进** sys 的两个槽（`brightness_set_logind_probe` 给探针、`brightness_set_action` 给 `(subsystem, name, value) -> 错误串` 的动作），sys 自己不引 D-Bus。本机实测注入后 `@sys.brightness_supported()` 由假变真（`logind_available=true`），而 `brightness_devices()` 仍只读 sysfs（本机无背光设备给 0 个）——读写两条路的依赖被这条注入线彻底分开。
- **验证**：`moon test -p NoahLiu/native-gui/dbus` **64/64**（新增 2：注入后 sys 的亮度门与 logind 在线与否一致、同进程重复声称名字得 `AlreadyOwner`）；`moon check ./examples/native-sys --deny-warn` 零警告；真窗口回证见上（`pool=:1.483`、第二实例 `exit=0`）。**待使用者真机复验**：`brightness_set_percent` 真要改屏幕亮度需带背光的机器（本机是台式机，无 `/sys/class/backlight` 设备）。

### MoonBit 原生 GUI 栈 · SNI 托盘与 DBusMenu（`dbus`：sni + icon + instance + filemanager）

- **平移面**：旧链 `traybus` 的 `sni.mbt`(731 行，StatusNotifierItem 对象面 + DBusMenu 服务端)、`icon.mbt`(75 行，程序生成的默认图标位图)、`instance.mbt`(221 行，单实例名字声称/唤醒)、`filemanager.mbt`(98 行，FileManager1 `ShowItems`) 逐行平移进 `dbus`；**之前从 `bus.mbt` 剥掉的托盘挂钩在同批接回**：`Conn.items`/`menus` 两张注册表、`NameOwnerChanged(arg0=watcher)` 重启后逐项重注册、断线迁移时把托盘项一起带回、入站调用三路分派（单实例 `Wake` 先应答后触发 → 路径命中 `items`/`menus` 走 SNI 的 `handle_call` → 最后才是 `CallReq` 兜底）。这正是「基建包先剥语义、能力包回来再接」的收口方式。
- **测试同批平移并把 `inspect` 换成 `assert`**：`sni_wbtest`(212)/`instance_wbtest`(93)/`filemanager_wbtest`(24)，本轮实测这三份里 40 余处旧 `inspect(x, content=…)`。
- **真总线回证（协议侧，规则 5 第一半）**：本机 XFCE 面板（`xfce4-panel`）就是 StatusNotifierWatcher。示例里点「托盘图标」后，watcher 的 `RegisteredStatusNotifierItems` 从 **9 条变成 10 条**（多出来的就是本进程的项），退出前对称注销；`sni_wbtest` 的真总线用例创建多托盘项、验路径与菜单对象互不覆盖、注销后两张表都干净。
- **一条注入/测试环境的坑（判据先行）**：连跑多轮「创建-注销托盘项」的测试时，偶发 `托盘注册失败: org.freedesktop.DBus.Error.NoReply` 或 `NameHasOwner` 拿到非 true。根因不是代码：**测试进程没有主循环，面板对托盘项的同步属性查询只能在 `call_sync` 的泵里被顺带服务**，积压多轮后 xfce4-panel 的一次查询会卡住，后续注册就超时。判据是「重跑即好、且 `dbus-send` 查 `RegisteredStatusNotifierItems` 仍然在线」；修法是让测试进程别长时间不泵（示例里宿主每 200 ms `dbus_pump()` 就不存在这个问题）。当时顺手加过一段 debug 打印定位，确认分支后就撤了。
- **验证**：`moon test -p NoahLiu/native-gui/dbus` **62/62**（新增 12：sni 6 / 单实例 4 / 文件管理器 2），三连跑零 skip；`moon check ./examples/native-sys --deny-warn` 零警告、`moon build` 通过；真窗口回证 `pool=:1.479`、五键几何行 `tray=747,391,110x32`、退出码 0。**待使用者肉眼复验**：点示例里的「托盘图标」后 XFCE 通知区是否出现图标、右键是否弹出「刷新探测 / 退出」菜单、点图标后窗口里的「托盘点击」计数是否 +1。

### MoonBit 原生 GUI 栈 · D-Bus 能力模块首批（`dbus`：UPower/logind/网络/屏保/inhibit/MPRIS + 通知）

- **平移面**：旧链 `traybus` 的 `upower`(197 行)/`logind`(105)/`netmon`(191)/`screensaver`(94)/`inhibit`(146) 五件，与 `yue/system/media.mbt`(707 行，MPRIS) 逐行平移进 `dbus`（只换包前缀；media 里的 `pr_run`/`pr_available` 改指 `@sys`）。**测试同批平移，并且把旧 wbtest 的 `inspect(x, content=…)` 全换成 `assert_eq/assert_true`**——那批 inspect 在 native 后端本来不断言（此前记过两次），平移过来若不换就是「全绿但零覆盖」；本轮实测这一批里就有 54 处。
- **MPRIS 轮询监视改「排期通道注入」**：master 的 `media_watch_status` 直接挂 `@yue.set_timer`（回调返回 Bool 决定是否续拍）；新栈给它加 `schedule : (Int, () -> Unit) -> Unit` 参数（GUI 层给 `@core.set_timeout`，无头测试给把回调收进表里的假通道），内部 `arm()` 自续——与 `clipboard_watch`、主题探针同一个分层理由：能力包不认识事件循环。
- **通知是新做**（master 的通知实现在 C++ libyue 里，MoonBit 侧只有一层包装，属「新栈须重写」项）：`notify_caps` 走 `GetCapabilities`（**无副作用**，能力清单不翻译成枚举、raw 原样留给调用方），`notify_send`/`notify_close` 走 `Notify`/`CloseNotification`。**进度不是独立方法**——按 freedesktop 规范用 `Notify` + `replaces_id` 重发同一张通知，并在标准 hint `value`（INT32，0..100；本层把 >100 钳到 100、负数视为不带进度）里带百分比，桌面端据此画进度条；`notify_progress` 就是这个形状，参数顺序与 hint 形态由纯函数 `nf_notify_args` 钉住。
- **设置类纪律**：发通知会真的在桌面弹气泡，测试只跑到「能力探测 + 参数构造 + 错误归一（未知方法/服务不在线）」，真发送留给示例里的按钮由使用者点（与 open_url/reveal 同一条纪律）。
- **示例接线与真窗口回证**：`examples/native-sys` 加「窗口 / 剪贴板 / D-Bus」面板（会话唯一名 / 通知能力条数 / 系统总线「未连接（首次调用时按需连接）」）+「发通知(带进度)」按钮 + 宿主泵（`dbus_set_post_delayed` 包 `app.timer`、每 200 ms `dbus_pump()`）。整轮跑完 `pool=:1.434`（连接全程存活，证明注入的泵真的在喂总线）、通知能力 7 条、退出码 0，截图复核五行读数。
- **验证**：`moon test -p NoahLiu/native-gui/dbus` **50/50**（新增 27：UPower 4 / logind 2 / 网络 3 / 屏保 2 / MPRIS 12 / 通知 4），`moon check ./examples/native-sys --deny-warn` 零警告。**待使用者真机复验**：点「发通知(带进度)」是否弹气泡且进度随点击递增（本机 xfce4-notifyd 能力清单 7 条已真读到）；UPower/logind/网络/屏保这四件的「事件真的来了才触发」需在插拔电源、锁屏、断网等真动作下观察。

### MoonBit 原生 GUI 栈 · D-Bus 通用基建（新包 `dbus`：wire + dbus + bus + socket 桩）

- **平移面**：旧链 `yue/traybus/` 的 `wire.mbt`（833 行线协议编解码）与 `dbus.mbt`（419 行 `GDBusValue` 通用调用层）**逐行平移**（只把 `sys_f64_to_bits/from_bits` 换成新包的 FFI 名），`bus.mbt`（784 行）按新栈改：连接/握手/收发/分发/断线自愈全保留，**剥掉嵌在通用层里的 SNI 与单实例语义**（`items`/`menus` 字段、watcher 特判、入站 `Wake` 分支）——那些随各自能力模块回来。
- **最大的分层差：不挂 glib fd 监视**。旧链靠 `g_unix_fd_add` 把总线 fd 挂进 GTK 主循环、靠 libyue 的 `PostDelayedTask` 做重连退避；新栈禁 glib 也不依赖 GUI 层，改成两个注入点：宿主周期调 `dbus_pump()`（缺省 `timeout_ms=0`，poll 看一眼就走，适合挂每帧/每拍），断线自愈的延迟重连走 `dbus_set_post_delayed(fn(ms, f){...})`。**两者都不注入时同步调用照样可用**——`call_sync` 与 `gdbus_call_*` 自带 `pump_until` 泵（握手、Hello、注册都走它），纯 CLI 场景因此不需要事件循环；代价是「没人泵就收不到异步信号」，这条写进了包注释。
- **socket 桩只用标准头**（`dbus_stub.c`，走 native-stub 不写链接参数）：`socket(AF_UNIX, SOCK_STREAM|SOCK_NONBLOCK|SOCK_CLOEXEC)` + `connect`（容 `EINPROGRESS`）/ `read` / `write` / 单 fd `poll` / `close` / `getuid` / Double 位模式（`memcpy` 重解释，`static_assert` 钉住 8 字节）。错误码约定与旧 shim **逐位一致**（read：>0 字节 / 0 对端关 / -1 EAGAIN·EINTR / -2 其它；write：>=0 已写 / -1 暂不可写 / -2 其它；poll：revents 位 1=IN 4=OUT 8=ERR 16=HUP），这样上层分流代码一行不用改。
- **SASL EXTERNAL 不需要客户端显式传凭据**：连接时内核自动带上 `SCM_CREDENTIALS`、服务端读 `SO_PEERCRED`，客户端只发 `AUTH EXTERNAL <hex(uid)>` 即可（旧链 shim 里也没有 `sendmsg`，这一点是查证过的而不是猜的）。
- **对外面比旧链干净一处**：旧链的入站方法调用要求处理者拿到同包的 priv `Conn`/`Msg` 才能应答；新包给出 `CallReq{bus, sender, path, iface, action, args, reply, reply_error}`，`reply` 的签名**由参数值推导**（`gdbus_args_wire`），信号订阅回调也只拿到已解码的 `GDBusValue` 数组——线协议值类型不外泄，能力模块与外部调用方看到的是同一份。
- **三条工具链写法（本批实测）**：① 结构体字面量的字段用 `字段: 值`，写成 `=` 直接报 `Unexpected '=' in struct expression`；② **函数类型的结构体字段不是方法**——`req.reply_error(...)` 报 `Type CallReq has no method reply_error`，要先 `let f = req.reply_error` 再调；③ `;` 不是注释（`;;` 也不是），拿它当行内注释会连锁解析失败。
- **真总线回证（规则 5 的总线侧）**：`moon test -p NoahLiu/native-gui/dbus` **23/23**——会话总线握手成功（本端唯一名 `:1.392`）、`ListNames` 真返回并含 `org.freedesktop.DBus`、不存在方法的错误名/错误文本真拿到、信号 `AddMatch` 真登记、`dbus_pump` 空转不阻塞不判死、系统总线 `ListNames` 返回 96 个名字。**面板侧（托盘图标真出现在 XFCE 通知区）与通知弹窗仍待使用者真机复验**，随 SNI/通知模块批次。
- **后续批次**：SNI 托盘 + DBusMenu（含真实面板复验）、通知（`org.freedesktop.Notifications` 与 `set_progress`）、UPower/logind/NetworkManager/屏保/MPRIS 监视、单实例、以及 `brightness` 的 logind `SetBrightness` 注入实做。

### MoonBit 原生 GUI 栈 · 系统能力累积验证页（`examples/native-sys`）

- **一页看全部 `sys`**：五个面板（系统与机器 / 桌面与硬件 / 应用与文件类型 / 窗口与剪贴板 / 最近与历史）全是**只读**探测，三个按钮里只有「重新探测」也是只读（注入回证就点它），「打开链接」「打开目录」是设置类、点了才交给系统。退出前打两行：`NATIVE-SYS-GEO probe=… open=… reveal=…`（注入点位）与 `NATIVE-SYS-STAT os=… de=… mon=… wp=… vol=… prof=… mime=… def=… apps=… recent=… hist=… dl=… bm=… ffx=… vsc=… wins=… clip=… probes=… opens=… reveals=… changes=…`（与屏上读数一一对应）。本机一轮：`os=ubuntu de=XFCE mon=9 wp=ok vol=65 mime=text/plain def=sublime_text.desktop apps=179 recent=156 hist=5 dl=5 bm=166 vsc=1 wins=9 probes=3`、退出码 0。
- **`@core.App` 的根容器默认是 Row**：只调 `app.mount([...])` 而不 `app.root.set_column()`，多块面板会横排挤出窗口（本例第一版就是这样，按钮 rect 的 x 到了 1442 而窗宽只有 1200——注入自然全数落空）。`examples/native-app` 一开始就 `root.set_column()`，新页要照做；面板内部要横排则给容器显式 `direction=@yoga.Row`。
- **注入计数会「少点一次」不是丢事件**：「重新探测」一次要把整库重读（Chrome 的 `History` 本机 37 MB），处理期间 UI 线程阻塞，间隔太短的下一击会被拆成「按下在阻塞前、抬起在阻塞后」而不算点击。判据：同一位置连点三下、每下间隔 1.6 s 得 `probes=3`，间隔 1 s 内则只涨 1——**注入脚本要给重活留一拍**。
- **剪贴板监听的接线形状**：`@sys.cbw_start_watch(fn(ms, f) { let _ = app.timer(ms, f) }, cb, interval_ms=1000)`——排期通道由宿主给，`sys` 不认识事件循环（无头测试用假通道逐拍派，见前一条批次记录）。本机未装 xclip，读数如实写 `ClipboardError::Unsupported`，不是页面缺陷。
- **验证**：`moon check ./examples/native-sys --deny-warn` 零警告、`moon build ./examples/native-sys` 通过；`sys` 163/163、`core` 62/62、`ui` 110/110、`chart` 189/189、`mdview` 26/26、`render` 42/42 全绿，全仓红点仍 287 errors / 68 warnings 未增。**待使用者肉眼复验**：点「打开链接」是否拉起默认浏览器、「打开目录」是否在文件管理器里打开 `/tmp`（注入只证明按钮确实把动作交给了系统调用，不证明对端窗口）。

### MoonBit 原生 GUI 栈 · 系统集成状态族可脱总线三件（`sys`：sysinfo + windowctl + clipboard_watch）

- **桩读文件不能只按 `ftell` 定长（本批修掉的真 bug，覆盖此前所有走这条桩的读盘）**：`/proc/meminfo`、`/proc/uptime`、`/sys/class/dmi/id/*` 这类伪文件的 `lseek(END)` 报 **0 字节**，内容只有真正去读时才出现。旧写法 `fseek(END)` → `ftell` → 按该长度分配再 `fread` 正好命中这个坑：伪文件返回 `Ok("")`（**不是报错**），调用方解析失败还被当成「数据格式不对」。`yue_sys_read_text_file` 改成以 ftell 作提示、按块 `fread` 循环到 EOF（普通文件与数十 MB 的 SQLite 库同一条路径），两条本机断言（MemTotal/MemAvailable、uptime 秒数）当场从红转绿。**判据**：读伪文件得到「成功但空串」先怀疑取长方式，别怀疑权限。
- **窗口/剪贴板/时间日期类走命令路线**：`windowctl` 解析 `wmctrl -l -p`（列窗口）/`-i -a`（按 id 激活）/`-c`（按标题关闭）；`clipboard_watch` 走 `xclip -selection clipboard -o` 只读轮询——本机未装 xclip 时以退出码 127 呈现，归一成 `Unsupported`（与「命令缺失」语义一致而不是报错）；`sysinfo` 纯读 `/etc/os-release`、`/proc/meminfo`、`/proc/uptime`、`/sys/class/dmi/id/`。激活/关闭/挂监听都是设置类：白盒只验命令构造与输出解析，动作留给调用方。
- **剪贴板监听的定时器改「由调用方注入」**：master 的 `cbw_start_watch` 直接挂 libyue 的 `set_timer`（无取消 id，靠停靠标志自然终止）；新栈 `sys` 不引 GUI 核心层，于是把排期能力做成参数 `schedule : (Int, () -> Unit) -> Unit`，GUI 层传 `fn(ms, f) { let _ = @core.set_timeout(ms, f) }`，无头测试传一个把每拍回调收进表里的假通道——于是**续拍与 stop 后不再续拍都能在测试里逐拍手动派**（这条与主题批「探针作参数」是同一个分层理由）。
- **总线依赖的六件留 DBus 线**：`power`（UPower）、`session`（logind/屏保）、`online`（NetworkManager）、`keepawake`（logind inhibit）、`powerctl`（`gdbus_call_system`）、`locale_sys` 的 localed 部分（`timedatectl` 那半可脱总线）。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **163/163**（新增 36：sysinfo 14——含本机 `/proc` 两条活断言；windowctl 14——`wmctrl -l -p` 真实列表读到 8 个窗口；clipboard_watch 8——假定时器通道逐拍派发、stop 不再续拍、xclip 缺失归一 Unsupported 等）。`sys` `--deny-warn` 零警告、全仓红点仍 287 errors / 68 warnings 未增。

### MoonBit 原生 GUI 栈 · 系统集成历史族（`sys`：浏览器历史/书签/Firefox/VS Code）

- **SQLite 读依赖要在包级声明**：`prowk/moonsqlitefile` 已在 `moon.mod` 的 `import` 里，但 `sys` 用到 `@moonsqlitefile.*` 时报的是 `Package "moonsqlitefile" not found in the loaded packages`——**模块级 import 不代替包级声明**，要在 `sys/moon.pkg` 写 `"prowk/moonsqlitefile" @moonsqlitefile`。旧链 `yue/moon.pkg` 里没有这一行（那批文件本就在全仓红点里），照抄旧链的包配置会踩空。
- **读 SQLite 必须有原始字节入口**：新增 `sys_read_bytes_file`，与 `sys_read_text_file` 共用同一条桩（`yue_sys_read_text_file` 本就把文件整段读成 `Bytes`，区别只在 MoonBit 侧解不解码）。文本版那条不能拿来喂 SQLite：`decode_lossy` 之后再 encode 回去与原文不逐字节相等（非法 UTF-8 序列被替换字符吃掉），SQLite 页头一看就错。
- **时间基准各不相同**：Chrome/Edge/Brave 的 `History` 用 **1601-01-01 UTC 起微秒**（换算常数 `11644473600000`，`<=0` 视为未知给 0，微秒以下截断）；书签的 `date_added` 是同一基准但**以数值字符串**存；VS Code 的 entries 用 Unix 毫秒。混用会得到 1601 年或 5 万年后的时间。
- **profile 探测「存在才收、不读库内容」**：目录枚举只看有没有名为 `History`/`Bookmarks` 的条目，取数路径才把命中的库整读——列 profile 不再为判存在把数十 MB 的库读进来。边界：本层没有 profile 目录的枚举手段，按固定候选名探测（`Default` + `Profile 1..24`），自定义目录名的 profile 收不到。
- **本机端到端已真跑**（新增 `bh_browsers`/`bh_history`/`bh_downloads` 的严格冒烟）：Chrome 的 37MB `History` 真读，两个 profile 命中、返回条目时间落在 2026 量级、排序不变式（时间降序、并列按 url 升序）成立、`downloads` 表可读；VS Code 的 `state.vscdb` + recent 端到端 OK；本机未装 Firefox（无 `~/.mozilla/firefox/*/places.sqlite`）→ 走合法跳过分支。**纪律同上一批**：探测到库却读不出必须 `fail`，`Err(_) => ()` 只允许出现在「本机确实没有这份数据」时。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **127/127**（新增 41：浏览器历史 12、Firefox 10、书签 9、VS Code 10，全部含纯函数断言与本机冒烟）。`sys` `--deny-warn` 零警告、全仓红点仍 287 errors / 68 warnings 未增。

### MoonBit 原生 GUI 栈 · 桌面集成族后半（`sys`：最近文件 recently-used.xbel）

- **数据面**：GTK 系应用（Thunar / Nautilus / GIO、xdg-desktop-portal-gtk）都往 `$XDG_DATA_HOME/recently-used.xbel`（缺省 `~/.local/share/`）追加，本层**只读不写**。解析是手写薄扫描器（只取 `bookmark` 与 `bookmark:application` / `mime:mime-type` 的属性），把易错面全交给三块纯函数：XML 实体解码（命名实体 + `&#NN;`/`&#xHH;`，坏码点与代理值按字面保留）、URI 百分号解码（连续 `%XX` 按 UTF-8 组合，`100%` / `%E` / `%zz` 原样留）、ISO 8601 → Unix 毫秒（小数秒取前三位、无时区按 UTC、闰日校验）。本机实读 **156 条**。
- **旧 wbtest 的 `inspect(x, content="…")` 在 native 后端不断言**（此前记过一次，本批是第二个现场）：整批平移过来会「全绿但零覆盖」。转换口径：布尔→`assert_true`/`assert_false`；数字→`assert_eq`，**Int64 的字面量要补 `L`**（XBEL 的毫秒时间戳超出 Int 位宽，写 `assert_eq(items[0].added, 1776757238510)` 会类型不匹配）；数组的 debug 文本 `[1, 2, 3]` 直接改写成数组字面量；`content="<应解析成功>"` 这类不是断言而是错误分支里的说明文字，落成 `println` 并补一条显式失败断言。
- **冒烟用例的报错分支不能静默跳过**：`rf_recent` / `rf_by_app` 的旧写法是 `Err(_) => ()`（「本机没记录就算跳过」），它把「有文件却读不出」这类真回归一起掩盖掉。改成 `Err(e) => { assert_false(rf_supported()); println(...) }`——只有本机确实没有这份文件时才允许走到 Err 分支。
- **两条 XBEL 容错语义（用例钉住）**：注释里藏的假 `<bookmark>` 不收（`skip_declaration` 走 `-->`）；同一 bookmark 出现两个 `mime:mime-type` 时**首个生效**；写到一半截断的 XBEL 只收已闭合的条目。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **86/86**（新增 13：实体解码/ISO 换算与闰日/历法天数/百分号解码/URI 还原/完整 XBEL 样例六态/非 XBEL 与截断/映射与并列排序/按应用精确过滤/`rf_take` 边界/`rf_data_dir` 三态/两份本机真实冒烟）。`sys` `--deny-warn` 零警告、全仓红点仍 287 errors / 68 warnings 未增。

### MoonBit 原生 GUI 栈 · 桌面集成族中半（`sys`：壁纸 + 默认应用，附子进程环境补漏）

- **`pr_env_blob` 少透传 DISPLAY / DBus 两条，桌面侧命令在子进程里必失败（上一批 monitor 只能 skip 的根因就在这一行）**：[pr_run] 给子进程的环境是白名单构造的（原先只有 `PATH` / `XDG_RUNTIME_DIR` / `HOME` + `LC_ALL=C`），`xrandr --query` 拿不到 `DISPLAY` 就退出 1，`xfconf-query`、`gsettings` 拿不到 `DBUS_SESSION_BUS_ADDRESS` 也起不来。本批补 `DISPLAY` / `XAUTHORITY` / `WAYLAND_DISPLAY` / `DBUS_SESSION_BUS_ADDRESS` 四项透传后，**同一个宿主上** monitor 的用例真读出 DP-0..5 与 HDMI-0（主，1920x1080）/HDMI-2，壁纸的只读冒烟读出 `/usr/share/xfce4/backdrops/Dolomites_by_Felix_Hartlieb.jpg`。**判据**：同一命令在 shell 里跑得通、在 `pr_run` 里非零退出，就是白名单少了变量，别先怀疑工具版本。
- **壁纸的属性选择与已连接输出联动**：XFCE 的 `last-image` 按「workspace0 且输出已连接 → 首个 workspace0 → 首个可解析项」三轮挑，第一轮用 [mon_list] 的 connected 集合排掉拔掉显示器留下的陈旧项；xrandr 不可用时退化为「首个 workspace0」。写路径按同一规则选目标属性（绘制与命中同源那条纪律在这里的对应物），一条都没有时创建 `monitorNone-1` 的兜底项。第三轮**不再看已连接**，只按清单顺序取首个可解析项。
- **默认应用的写路径在测试里真写、真读回**：`da_set_default` 的落点是 `$XDG_CONFIG_HOME/mimeapps.list`，测试把 `XDG_CONFIG_HOME` 指到 `/tmp/da_wbtest_config`（存—改—断—复），断三态（文件不存在→新建段；同 mime 再设→原行替换不留第二行；另一 mime→段内追加），既不碰用户真实配置又走完整条读写链。
- **工具链两条（本批实测）**：① **同包多枚举的同名构造器要消歧**——`Unsupported`/`CommandFailed`/`ParseFailed` 在 `WallpaperError`/`MonitorError`/`VolumeError`/`FileManagerError`/`AppFindError` 之间撞名，测试里裸写报 4124（`The constructor ... is ambiguous`），得写 `WallpaperError::ParseFailed(...)`；实现文件里 `match self { Unsupported => ... }` 上下文能定类型，不用改。② **无载荷的 enum 同样不自动带 `Show`**：`println("\{de}")` 编译不过（`Type DesktopEnv does not implement trait Show`），诊断面走专门的 `desktop_name()`。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **73/73**（新增 14：壁纸 9——真实 xfconf 属性清单的三轮选择、`monitorNone-1` 兜底、gsettings/KDE 输出解析与参数构造、JS 单引号转义、文本工具、参数防御与 Show 文案、真机只读冒烟；默认应用 5——mimeapps 段解析与同名键不去重、合并改写四态、关联合并去重排序、临时 `XDG_CONFIG_HOME` 真写读回、xdg-mime 本机探测）。`sys` `--deny-warn` 零警告、全仓红点仍 287 errors / 68 warnings 未增。**`wp_set` 属设置类**：本批只验参数构造、不真改桌面外观（与 master 同纪律），换壁纸由用户按需在真机执行。

### MoonBit 原生 GUI 栈 · 桌面集成族前半（`sys`：桌面识别 + 应用查找 + 打开外部）

- **平移面与文件对应**：master 的 `yue/system.mbt`（`open_url`/`reveal_in_file_manager`）+ `yue/system/appfind.mbt` + `yue/traybus/detect.mbt`（桌面环境识别）→ 新栈 `sys/launcher.mbt` + `sys/appfind.mbt` + `sys/desktop.mbt`。桌面识别**在 sys 包内自带一份纯函数**而不引 `@traybus`：旧链 traybus 属全仓红点积压，且 sys 反过来要给它用（壁纸/默认应用按 DE 分派），引了就成环。DBus 线接入后复用这份识别结果，不要重抄第二个 `detect_desktop`。
- **分离式启动落到本栈自己的桩**：master 走 shim 的 `g_spawn_async`，而 `sys/sys_stub.c` 只用标准头，所以这里是 `fork → setsid → fork → execvp` + 一根 **CLOEXEC 管道**回传 exec 成败。**不用 [pr_run] 等它**是刻意的：`xdg-open` 交出窗口后往往还驻留，等它等于把调用线程钉住；双 fork 同时保证不留僵尸（中间进程由本函数 `waitpid` 收掉，真孙进程过继给 init）。
- **本批踩到并修掉的真 bug（管道写端关早了）**：中间进程在**派生孙进程之前**就 `close(fds[1])`，孙进程就没带写端的 fd，`execvp` 失败时无处可写 → 中间进程读到 EOF（写端全关）当成成功 → 「命令不存在」被报成 `Ok`。判据就是那条「不存在的命令必须 Err」的断言（第一次跑就红）。正确顺序：中间进程先 `fork` 孙进程（它继承写端），**然后**自己关写端、只留读端等信号；写端标 CLOEXEC，所以孙进程 exec 成功那一刻写端自动关闭、中间进程读到 EOF，exec 失败才走到 `write("E")`。
- **`open_url`/`reveal_in_file_manager` 的 `Ok` 只表示「已交给系统」**，能不能真打开由平台负责；参数不经 shell（argv 直传），所以 URL/路径里的shell 元字符不构成注入面。
- **`reveal` 的「选中」这一半本批是缺口**：master 先问 FileManager1 总线 `ShowItems`，服务不在线才回退打开父目录；新栈暂无总线通道，因此**当前每次都是回退路径**（打开父目录、选中态丢失），随 DBus 线补 `ShowItems`。
- **appfind 清单排序按 master 原形保留 `mut_view().sort_by`**：本工具链里**返回 `-1/0/1` 字面量的比较器是可用的**（前批「`Ordering` 类型不可直接引用」那条只针对显式写 `Ordering::Less` 或标注 `Ordering` 类型的写法，与返回 Int 的比较器无关）。排序口径不变：先比 `name` 的码点字典序、同名再比 `id`；`appfind_str_cmp` 逐码点比而不吃 String 默认的「先比长度」shortlex 序（否则 `"New"` 会排在 `"Beta"` 前）。
- **平台面**：Windows 开始菜单（`.lnk`）与 macOS（`.app`）分支未随本批——`sys_stub.c` 的 Windows 侧仍是占位，`open_url`/`reveal`/`appfind_*` 在非 Linux 一律 `Unsupported`；平台分派批接入时按 master 的纯函数（`appfind_win_*`/`appfind_mac_*`）直接补即可。
- **两条工具链写法（本批实测）**：① `500u64` 这类 Uint64 字面量后缀**解析不过**（`unexpected token id (lowercase start)`），单调钟差值要比大小先 `.to_int()`；② **无载荷的 `pub(all) enum` 同样不自动带 `Eq`**（前批记的是带闭包字段的 `PointerKind`，这条补上「简单枚举也一样」）——`desktop_detect() == before` 编译不过，跨态判定用 `match` 或比 `desktop_name()`。
- **验证**：`moon test -p NoahLiu/native-gui/sys` **59/59**（新增 18 条：桌面识别 3——单值映射/冒号多值取首个可识别/真实环境「存—改—断—复」环；应用查找 10——INI 子集解析、条目过滤与 zh_CN 回退、去重合并排序、目录拼装三态、真实读盘收集与静默跳过、`NoScanDir`、`appfind_installed` 真扫本机、`appfind_executable` 命中 `/usr/bin/sh` 与参数防御；打开外部 5——`parent_dir`/相对路径归一、真实 cwd、分离式启动的成功/失败/不阻塞（`sleep 3` 交出后 <500ms 返回）、两个错误枚举的 Show 与平台门）。`core` 62/62、`ui` 110/110、`render` 42/42、`mdview` 26/26、`theme` 8/8，十二包 `--deny-warn` 全零警告、全仓红点仍 287 errors / 68 warnings 未增。**真机复验项**（`examples/native-sys` 批接入后可观感）：`open_url` 是否真拉起默认浏览器、`reveal_in_file_manager` 是否打开父目录窗口、`appfind_installed` 的本机应用清单条数。

## Linux

### 发行版

#### Ubuntu 24.04 ✅ 主链路

- 系统依赖:`build-essential cmake pkg-config libgtk-3-dev libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev`。
- AppIndicator 运行库已移除,libyue 内置托盘不可用 → 用 `yue/traybus/`(纯 MoonBit SNI 直连面板)替代。
- webkit2gtk 包名 4.0 / 4.1 因发行版而异,prepare.py 以 pkg-config 探测,任一存在即可。

#### 其他发行版 ❓ 未实测

- 移植第一步:核对依赖的 pkg-config 名称,再跑 prepare.py。

### 桌面环境(托盘 / 菜单行为差异)

#### XFCE ✅

- 自启动 .desktop 实测:Exec 经 /proc/self/exe readlink 取绝对路径(开发期指向 _build 构建产物,产物位置一变条目即失效——发布版固定安装路径才可靠,AppImage 指向挂载点同理);整文件 desktop-file-validate 零警告;启用位解析兼容系统侧 Hidden=true 与 X-GNOME-Autostart-enabled=false 两种禁用开关,disable 幂等(条目不存在视为成功)。

- 右键菜单由面板自镜像 DBusMenu 渲染,不走 SNI ContextMenu 让应用自绘。
- xfce4-panel 4.18 只发批量版 `EventGroup` / `AboutToShowGroup`,不发单条版:只实现单条版会被 UnknownMethod 静默拒绝,表现为菜单能弹、点击全部无效。
- 桌面通知必须走 `Notification::Show()`;`NotificationCenter::AddNotification` 在 Linux 从不发 DBus Notify,静默失败。
- 全局快捷键是 XGrabKey 排他注册,键位被占用 Register 返回 -1(不崩,静默失败),使用方须检查并提示换键。
- 焦点落在桌面时 xfwm4 抢占键盘,全局快捷键不触发(焦点在应用窗口时正常)。

#### GNOME ✅(X11 与 Wayland 双会话)

- AppIndicator 扩展在注册瞬间读 Menu 属性建代理:空菜单返回 `/` 会让菜单客户端永久坏死(点击图标全程无反应)。traybus 恒返回真实 `/MenuBar`,空菜单也导出,靠 LayoutUpdated 填充。
- `ItemIsMenu=false`:左 / 右键均发 Activate。
- 全局快捷键在 Wayland 会话段错误(上游用 GDK X11 宏强转根窗口):已加 `GDK_IS_X11_DISPLAY` 守卫,非 X11 会话 Register 返回 -1。
- 鼠标键位是 yue 统一语义 1=左 2=右 3=中,GDK 原始的 2/3 已被交换,组件按 yue 语义判断。
- SSH 起 GUI 的环境变量:X11 会话 `XAUTHORITY=/run/user/1000/gdm/Xauthority`;Wayland 会话 `XAUTHORITY=/run/user/1000/.mutter-Xwaylandauth.*` 与 `WAYLAND_DISPLAY=wayland-0`;均需 `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus`。

#### KDE ✅(Plasma 5.27)

- 面板直收 SNI,新图标直接进可见托盘区;托盘 / 菜单 / 退出全链路通过。
- 协议行为与 XFCE 相反:只发单条 `Event` / `AboutToShow`,不发批量版;traybus 两种都实现。

#### Deepin ✅(23 / 25,DDE)

- dde-dock 实现 StatusNotifierWatcher,SNI 直连可用;新图标默认进折叠区,可拖出常驻。
- libyue 的 Popover(透明窗 + 指针抓取)在 DDE 不渲染且拖慢鼠标:shim 按 `XDG_CURRENT_DESKTOP`(23=DDE,25=Deepin)回退无边框普通窗口。
- 宿主机(Ubuntu 24.04)构建的二进制可直接跑:glibc 符号上限 2.38 且 deepin 带 webkit2gtk-4.1 运行库;跨发行版分发先查 glibc 符号需求(`objdump -T | grep GLIBC_`)。
- `TextEdit::Delete()` 是删选区不是清空;清空用 `set_text("")`。
- DDE 剪贴板管理器交互偶发 CHECK / CRITICAL 日志噪音,不影响功能。

#### KDE / MATE / Cinnamon / Budgie / LXQt ❓ 未实测

- 协议层均支持 SNI,traybus 已按协议实现,待真实环境逐一验证。

### DBus 线路协议(traybus)

- DBus 数组长度前缀不含首元素前的对齐填充;算进去会被 dbus-daemon 判违规断连。
- 头部 SIGNATURE 字段的 variant 签名是 "g"(u8 长度编码),按 "s" 编过不了真实总线。
- SNI Menu 属性恒返回真实菜单对象路径,空菜单也不能回 `/`。
- 单测自洽 ≠ 互操作通过:协议问题用 dbus-monitor 抓真总线定位,GNOME 面板侧异常看 journalctl。
- 单实例 RequestName 必须带 flags=4(DO_NOT_QUEUE):默认 0 会排队,第二实例的防多开判定挂到首实例退出为止,语义全错。真总线实测(Ubuntu 24.04 XFCE):回复 3=他连接持有(已有实例→唤醒后退出);首实例 SIGKILL 后总线自动回收名字,新连接回复 1 即 claim 成为首实例;回复 4=本连接已持有(幂等)。完整链路(RequestName flags=4 → EXISTS → Wake('as') → RETURN)经 dbus-monitor 真总线抓包验证:Wake 到 RETURN 39µs;SIGKILL 首实例后第三实例可正常 claim。
- 二次唤起的 Wake 分发必须插在 bus.mbt 的 Conn::handle kind==1 分支、先于 sni.mbt 的 handle_call:所有入站调用都汇进 handle_call,不拦截就落 UnknownMethod 兜底,首实例永远收不到。Wake 命名约定:接口 org.moonbitlibyue.Instance、对象路径 /org/moonbitlibyue/Instance、成员 Wake('as'=第二实例命令行,经 moonbitlang/core/env args() 透传,含 argv[0] 程序路径,使用方自行取舍)。
- FileManager1(打开并选中文件)实测(XFCE):NameHasOwner 在线探测可用;ShowItems 线格式 "ass"(file URI 数组 + startup_id 空串);file URI 的百分号 hex 用大写(RFC 3986 大小写均可,大写为通行惯例),unreserved(A-Za-z0-9-._~)与 '/' 不编码,其余按 UTF-8 字节 %XX,单测锁定。服务不在线或调用失败的回退是 xdg-open 打开父目录——选中态丢失,属语义降级,使用文档须写明。
- 外部打开类的 spawn 走 g_spawn_async(G_SPAWN_SEARCH_PATH + 输出重定向 DEV_NULL),glib 自动回收子进程无僵尸;不经 shell,argv 直传。xdg-open 对不存在路径/不可打开 URL 的行为因桌面而异,库层 Ok 只表示「已交给系统」,系统侧成败不回传。
- 屏幕抑制(Inhibit/UnInhibit)服务名以 NameHasOwner 真实在线为准,不按环境名猜:候选表 [org.freedesktop.ScreenSaver, org.xfce.ScreenSaver],实测 Ubuntu 24.04 XFCE 仅 org.xfce.ScreenSaver 在线(xfce4-screensaver 持有),org.freedesktop.ScreenSaver 无人持有。两家接口同构:对象路径与接口名由服务名点换斜杠派生,Inhibit("ss" = 应用名 + 原因)-> u cookie,UnInhibit("u" = 原 cookie)须逐位一致(真总线抓包:Inhibit 得 cookie 1516211641,2 秒后 UnInhibit 带同值,空应答成功)。GNOME / KDE 的服务持有情况待真机补记。
- 系统总线(Ubuntu 24.04 实测):socket 为 /run/dbus/system_bus_socket,未设 DBUS_SYSTEM_BUS_ADDRESS 时按此默认直连成功;地址显式设置时按逗号分隔取第一个 unix:path=,取不到(如 tcp: 地址)必须显式 Err 带原文——静默回退默认 socket 会连回真有 UPower 的总线,降级验收变假失败。系统总线 BecomeMonitor 被拒(dbus-monitor 与 busctl monitor 同),抓包不可用,验证走探针自身往返 + busctl call 对照应答形状。
- 多总线连接并存(B5 基建):shim 的 fd 监视从进程级单槽(每次 watch 覆盖上一条)改为 fd→回调分发表 + unwatch;MoonBit 侧 fd→Conn 注册表按 fd 路由。双连接(会话 SNI + 系统 UPower)并存实测互不覆盖。glib source 回调返回 0 时 glib 自毁 source,shim 表项同步 erase(否则后续 unwatch 对已亡 id 再 g_source_remove 触发告警)。
- wire 层 'd'(DOUBLE)与 't'(UINT64)必须成套支持:真总线 UPower GetAll 应答里 UpdateTime 是 't'、Percentage/Energy 是 'd',缺 't' 时 variant 未知签名走「返回空串但读位不动」的旧防御分支,后续元素整体错位、read_string 切片越界直接 abort(单测自洽测不出——自造的形状恰好没踩到)。防御已改两层:variant 未知签名把 pos 推到消息尾(解析化为垃圾值而非错位)、read_string/read_sig 加边界检查。新增类型是全链路八处联动:DVal/Sig/sig_align/parse_one_sig/sig_of/sig_char/encode/decode_in。
- Double↔IEEE 754 位转换放 shim(moonbitlang/core 无 Double::to_bits/from_bits,实测确认):yue_mbt_sys_f64_to_bits/from_bits 纯位重解释(static_assert sizeof(double)==8),wire 层 'd' 借道 Int64 的 8 字节小端读写。注意:traybus 的 whitebox 测试目标一旦引用此类 extern,链接就吃 -lyue_mbt——而 link_configs 按「依赖该包的目标」传播,traybus 不依赖 yue(反向),prebuild.py 须为 NoahLiu/native-gui/yue/traybus 单列一份同值配置(静态库单成员引用 gtk 全套,不能给精简 flags)。
- UPower 读数路径(实测 Ubuntu 24.04,台式机):DisplayDevice(/org/freedesktop/UPower/devices/DisplayDevice,接口 org.freedesktop.UPower.Device)聚合主电池,IsPresent=false → Ok(None);属性接口名注意区分——设备是 …UPower.Device、顶层是 …UPower,PropertiesChanged 的 arg0 过滤天然把设备级信号挡在顶层订阅外。OnBattery 在顶层对象,交直流事件订阅顶层 PropertiesChanged、回调内直解 changed 字典(信号分发在 drain 栈上,回调内 call_sync 会重入收包路径,严禁)。
- 断线自愈(B5,未经真机断线演练):mark_dead 幂等(以 fd 注册表为准),经 shim 的 post_delayed_task(符号直 extern,绕开 traybus→yue 反向依赖)延迟 500ms 重连、最多 3 次;成功后重放 AddMatch 规则、迁移订阅表与托盘项并重新注册(断线期间 watcher 已按唯一名消失清掉旧注册)。纯 CLI 场景(主循环未跑)重连回调不触发,自然放弃。
- logind 事件订阅(B6):PrepareForSleep(b) 在 Manager 接口、Lock/Unlock 在各会话对象的 Session 接口(空体信号,按成员各一条 AddMatch,不限定 path——所有会话都收,多用户登录时别人的会话锁屏也会触发,归属限制调用方自查 sender)。降级实测(私有总线无 logind):suspend_resume_supported()==false、session_lock_watch 返回 Err(SystemError::Unsupported),不静默。快速挂起唤醒可能连收两条 Resuming(库内不去抖);唤醒后网络/DBus 可能未就绪,回调里的重试逻辑应延迟。
- 锁屏事件必须双信号源(真机踩坑修正):XFCE 的 xfce4-screensaver 锁屏**不调 logind**(logind Lock/Unlock 无信号;busctl 直接调 Session.Lock 方法可正常触发信号,证明订阅链路无恙、是锁屏器不通知),它锁屏时在自己持有的 org.xfce.ScreenSaver 上发 ActiveChanged(b)。修复:session_lock_watch 双源订阅——logind Lock/Unlock(系统总线,GNOME/KDE 走此)+ 屏保服务 ActiveChanged(会话总线,候选 [org.xfce.ScreenSaver, org.freedesktop.ScreenSaver] 按真实在线选定),多源同报经状态机去重(同态重复不派发,翻转才派发)。ActiveChanged 订阅 key 带服务名前缀,与 logind 订阅不冲突。
- XFCE「黑屏设置不生效」与常亮验证口径(真机诊断):电源管理器 GUI 的「黑屏 1 分钟」依赖 DPMS 或屏保空白屏,实测宿主机三条息屏链路全关(xfce4-screensaver /saver/enabled=false、X DPMS Disabled、xfce4-power-manager 无任何 dpms/blank 键)——设置界面有值但没人执行黑屏,常亮开关自然无从观测。验证常亮前须先开一路执行器(推荐屏保空白屏:锁屏器同源,抑制与锁屏事件都能配套);org.xfce.PowerManagement 抑制接口在本机不在线(NameHasOwner=false),XFCE 下 DPMS 黑屏不可经 DBus 抑制,避开该路径。
- Windows 电源/会话事件窗口(B6,代码落地真机待验):一个 message-only 窗口同时收 WM_POWERBROADCAST(PBT_APMSUSPEND;PBT_APMRESUME 与 PBT_APMRESUMEAUTOMATIC 都归已唤醒)与 WM_WTSSESSION_CHANGE(WTS_SESSION_LOCK/UNLOCK,NOTIFY_FOR_THIS_SESSION),WNDPROC 内 PostTask 抛回主循环(B1 消息窗口模式复用)。C 侧单窗口单回调,休眠/锁屏共用——MoonBit 侧全局单点登记按 event 码派发,后注册不得覆盖前者。WTSRegisterSessionNotification 失败只影响锁屏事件不视为整体失败。wtsapi32.lib 是全计划唯一链接清单改动,prebuild.py 的 WINDOWS_LINK_LIBS 与 shim/CMakeLists.txt 必须同提交(双清单无一致性注释背书)。
- NetworkManager 在线状态(B7):State 与 Connectivity 都是顶层属性,Properties.Get 的应答体是单 "v"(内为 u32),与 GetAll 的 a{sv} 不同形状。变化信号两条都订——老式 StateChanged(i) 直带新值,新式 PropertiesChanged(a{sv}) 的 changed 里可能带任一属性;订阅回调在 drain 栈上,只更新缓存与归并通知,严禁 call_sync 重查(首次缓存建在注册动作里,主线程非 drain 栈合法,最坏阻塞 1.5s)。归一口径:State 70/50 且 Connectivity 4/3 为 Online,门户劫持(Connectivity=2)按 Offline(「在线」= 可达互联网)。实测 Ubuntu 24.04:State=70/Connectivity=4 → Online,与 busctl 逐位一致;私有总线降级 Err(NetworkError::Unsupported)。Windows NLM GetConnectivity 位掩码:含 IPV4_INTERNET(0x40)/IPV6_INTERNET(0x400)为 Online,轮询 5s(监听式后置);netlistmgr.h 无需额外链接库。
- NM StateChanged 信号参数是 Int32(i) 不是 u32(真机踩坑修正):D-Bus 规范里属性 State 是 u、信号 StateChanged 的 state 参数是 i,两者类型不同源;wire 层 i 解码为 VI32,旧实现只匹配 VU32 被静默丢弃——信号照发、回调不触发,面板断开连接/关「启用网络」(State 70→20/10)后 UI 恒显示初始 Online(单测自洽测不出:自造信号体恰好写成 u)。修复:statechanged_of 对 VI32/VU32 双匹配,bool 等其余类型照旧丢弃;Properties.Get 与 PropertiesChanged 里的 State 仍是 u,不动。分发链路本身用无害属性写实测存活(NM 1.46 WwanEnabled 开关,无 WWAN 硬件机器零网络影响,PropertiesChanged 实时到达);信号触发后的 UI 翻转由真机断网/恢复验证。
- 网络回调登记必须平台分支外统一(真机两级观测定位):on_network_status_change 的派发统一走 net_dispatch 遍历 g_net_cbs,但登记 g_net_cbs.push(cb) 原本只在 Windows 分支——Linux 信号全数到达、缓存逐值更新(State 70→10→20→40→60→70 与 nmcli monitor 逐条一致)而回调零执行,UI 恒显初值;两级探针(traybus nm_on_change 层 + online 派发层)一对比即锁定。修复:push 提到平台分支外,两平台统一登记。同类事件注册(on_suspend_resume/on_power_source_change)是回调闭包直接内嵌、不经全局数组,无此问题;net_dispatch 的去重以注册时回填的 network_status() 为基线,注册后首条同态信号不派发属预期。
- 通用 D-Bus 调用层(yue/traybus/dbus.mbt,横切地基,媒体/磁盘/蓝牙/传感器/时区五模块共用):在 wire.mbt 的线协议与 bus.mbt 的进程级双连接之上加薄薄一层「任意服务的方法调用 + 属性读写」,六个公开入口 gdbus_call_session / gdbus_call_system / gdbus_get_property_session / gdbus_get_property_system / gdbus_set_property_session / gdbus_set_property_system(连接取进程级单例,没有则现连;同步调用 1.5 秒超时,与总线既有约定一致,应答超时给 gdbus.timeout)。**a{sv} 支持是这层的立项理由**:MPRIS 的 Metadata、udisks 的 GetAll 属性字典都是 a{sv},只支持基本类型的话每个模块都要各自解一遍字典,重复且易错。值模型 GDBusValue 覆盖 GVArray(元素签名, 元素表) / GVDict(a{sv},Map 按插入序序列化) / GVVariant(保持包裹) / GVStruct 四种容器:编码侧 GVArray 的元素签名由调用方给全("s"/"{sv}"/"(ii)" 等完整类型),套 GVStruct 时逐字段拼签名后整体过 parse_signature 预检**不带超时代价**(坏签名在本地就报 gdbus.encode,不用等 1.5s 总线超时);解码侧 `VArray("{sv}")` 折成 GVDict 并拆掉 variant 包裹(终端数据是取值,类别细分无后续编码影响),Byte/16 位整数并入 GVInt32、'g' 签名并入 GVString。参数树递归禁 GVNone(类型签名无从推导),入口先过 gdbus_args_ok 全树扫描。属性读路径的返回值已拆变体包裹(Properties.Get 的应答体恒为单 "v",解开直取内层),写路径的 value 传裸值、variant 包裹在本层完成。错误模型 GDBusError{ name, message }:name 取 D-Bus 错误名原样(UnknownMethod / ServiceUnknown 等),本地错误用 gdbus.io(连不上/已断开)/ gdbus.timeout / gdbus.encode 前缀,调用方按 name 前缀即可分流「服务不在线」与「应答超时」。
- udisks2(org.freedesktop.UDisks2,系统总线)接口要点:对象枚举走 `/org/freedesktop/UDisks2/Manager` 的 GetBlocks 返回 a{oa{sv}}(设备路径 → 该 block 对象的全部属性字典),每块再按需 Properties.GetAll 补 Filesystem 接口;**挂载点属性(MountPoints)的类型是 aay(字节数组数组)**,不是 as——按字符串数组解析会直接把全部条目变成空串,挂载态永远读不出来,须逐字节数组按 UTF-8 解码。挂载/卸载走 Filesystem 接口的 Mount(options : a{sv})/Unmount(options : a{sv}),第一参 options 可传空 GVDict;应答带挂载点字符串(多挂载点设备可能多个)。udisks2 不在线时 lsblk --json 只做枚举回退(char-typed 字段需 ansi 剔除)。
- bluez(org.bluez,系统总线)接口要点:对象枚举用 ObjectManager.GetManagedObjects,应答形状 a{oa{sa{sv}}}(路径 → 接口名 → 该接口的属性字典),按接口名 filter 出 Adapter1 / Device1 两摊;Adapter1 的 Powered / Discovering 与 Device1 的 Name / Alias / Paired / Connected / Trusted 都从字典里取。开扫描用 Adapter1.StartDiscovery(空参),配对用 Device1.Pair(空参),连接用 Device1.Connect——三者都是空参方法,应答为空。**无蓝牙适配器是合法状态**:org.bluez 不在线或枚举不到 Adapter1,bt_supported() 给 false、查询类 API 给 Unsupported,不当异常处理。
- iio-sensor-proxy(net.hadess.SensorProxy,系统总线)接口要点:属性 HasAccelerometer / HasAmbientLight / LightLevel / AccelerometerOrientation 全在同一对象 `/net/hadess/SensorProxy` 的单一接口上(与 udisks / bluez 的多接口多对象不同)。**取值前必须 ClaimLight/ReleaseLight(或 ClaimAccelerometer/ReleaseAccelerometer)**:传感器不点灯时读数停在旧值,取完必须释放,否则别人(如自动亮度)读不到新值。AccelerometerOrientation 的类型是**字符串**(不是枚举整数),取值如 "normal"/"left-up"/"bottom-down"。
- Windows NLM GetConnectivity 在 UI 线程调用可秒级冻结并连带原生布局断言崩溃(实测 Win10 19045 宿主机,网络环境差时必现):showcase 启动 3.7~4.7s 稳定 abort(0xC0000409 = fast-fail),崩前 stderr 打出 yoga 顶层断言「availableHeight is indefinite so heightMeasureMode must be YGMeasureModeUndefined」;崩率随网络环境 0%~100% 漂移(网络健康时查询毫秒级,与提交时冒烟存活一致,极易误判为代码回归)。定位路径:同一 exe 二分页面(仅系统集成页消失即 0 崩)→ 只禁网络初值查询+回调注册即 10/10 稳 → 预热/延迟查询均无效(查询存在即冻结,与时机无关)。根因:GetConnectivity 慢路径单次可达秒级,注册时的同步初值查询冻结 UI 线程数秒,返回瞬间 yoga 在积压布局上走 ScrollView 内容测量的 GetPreferred* 路径(该路径以 NaN 高度调 YGNodeCalculateLayout,对 height 样式已定义的容器是 fatal)。修复:shim 新增 yue_mbt_netwin_start/netwin_cached——后台 MTA 线程独占 COM 与轮询(interval 默认 5s),结果写进程级缓存,UI 线程只读缓存(network_status 缓存未就绪返回 QueryFailed,on_network_status_change 不再同步回填初值,g_net_last 改 None=未知态、首值必派发)。跨线程 COM 的 apartment 问题因接口指针创建与使用都在同一线程自然消解。验证:moon check 零警告、128 测全过、showcase 冒烟 12/12 存活(修复前同环境 7/10 崩)。
- **多托盘项的 DBusMenu 对象路径必须随项路径派生(CORE2,白盒 + 真总线回归)**:SNI 的 Menu 属性旧实现恒返回 `/MenuBar`,menus 注册表(菜单对象路径 → Item)同键互覆——建第二个托盘项时 `c.menus.set("/MenuBar", item2)` 直接顶掉第一项的路由,面板从此只认最后注册那项的菜单(第一项的布局查询/点名落到第二项上或 UnknownObject);注销时按新键也清不掉旧键,注册表永久脏。修复:`menu_path_of(项路径)` 派生(`/StatusNotifierItem`→`/MenuBar`、`/StatusNotifierItem_N`→`/MenuBar_N`,首项沿用 ksni 约定),unregister 与 create 失败路径对称清理 items + menus 两张表;`Conn::next_item_path` 改为扫首个空闲路径(旧实现按 items.length()+1 编号,注销中间项后新项复用已占用路径,与菜单路由一起撞车)。真总线回归(sni_wbtest,无面板 watcher 自动跳过):建两项断言路径/菜单路径互异,经 `gdbus_call_session(自身唯一名, 各菜单路径, GetLayout)` 分别拿到各自菜单标签(互不含对方标签),注销后两表清零且新项从头拿路径;暂存修复前代码(menu_path_of 恒 /MenuBar)相关用例精确失败。**面板侧双图标与各自菜单的实际弹出行为需真机目视复核**(AGENTS 规则 5/6)。
- **断线自愈重连不得无条件新建连接(CORE2,白盒 + 真总线回归)**:`try_reconnect` 旧实现拿到 g_saved 就直接 connect_session/connect_system 并覆盖 g_conn/g_sys_conn——若断线后按需路径(sni_available / Item::create / system_conn)已重建过一条活连接,这条连同它的 fd 与 glib fd 监视一起被泄漏(g_conns 注册表按 fd 路由,覆盖后再无引用能 unwatch/close),订阅与托盘项也分裂在两条连接上,信号只到达被 orphan 的那条。修复:迁移逻辑收敛为 `Conn::adopt_saved(bus)`,由 connect_session/connect_system 在任一新连接建立时立即调用(按需重建与自愈重连同路),`try_reconnect` 先看 g_conn/g_sys_conn 是否已是活连接——是则只补一次迁移(幂等),不再新建。附带修了两个老问题:迁移时本连接已占用的路径不重复注册(防同连接重复 RegisterStatusNotifierItem 出双图标);`Item::unregister` 在连接已断时也清暂存旧连接里的项(旧实现只清当前表,项会随重连复活)。托盘项的重新注册经 `sys_post_delayed(0, …)` 投回主循环:register_item_path 内部 call_sync 要泵总线,同步执行会让 sni_available / Tray::is_supported 这类谓词在 GUI 回调里被调用时阻塞至 1.5s,并让泵期间到达的入站调用重入派发(与 netmon/UPower 回调严禁 call_sync 同一条纪律)。真总线回归:mark_dead 模拟断线 → 按需重建 → try_reconnect 后 g_conn 仍是同一条(唯一名不变)、g_conns 不新增;暂存修复前行为(无条件新建)精确失败。

- sysmonitor 实测(Ubuntu 24.04 XFCE X11,口径同篇首性能基准:启动中位、稳态 Rss、release 二进制):启动(exec → 窗口 map)5 轮 77/78/81/82/88ms,中位 81ms(hello 基线 70ms 是空载系统,本次系统载有 1042 进程);稳态进程页前台 1Hz 刷新 CPU 2-3%(采样 + 派生数据 + 千行表格重建 + 重绘合计约 25ms/秒),Rss 84.9MB → 100s 后 85.8MB 走平;二进制 7.72MB(hello 对照 7.03MB)。千行进程页验收达标:1053 进程全量采样 14.94ms/次(release,≈14µs/进程,每进程两次 /proc 读取),1Hz 下采样占空 1.5%。
- 千行表格用 table_v_t 虚拟滚动(只画可见行):刷新走「数据层全量采样 → 过滤/排序派生 → rows Store set → 表格 load + schedule_paint」,不重建视图树;选择按 pid 重映射(排序每秒变化时选中不漂)。无 C++ 对照副本,「封装层 + 数据层」合计开销以上述数值直接归因,UI 绘制部分与 hello 基线同口径(持平量级)。
- **空 pixmap 形态下 IconPixmap 属性回调 panic(2026-10 用户真机栈 + 修复前后对照实证)**:showcase 托盘 demo 点「切主题图标(Linux)」后,`set_icon_name` 按既定策略清空位图(XFCE 面板 IconPixmap 优先于 IconName,不清则换名后仍画旧图),形态为 w=0/h=0/空 buf;面板收到 NewIcon 回查 IconPixmap,`Item::property` 对空 pixmap 调 `downscale_pixmap(0, 0, …)` 生成 16×16 附档——旧实现的钳位守卫 `if y*h/nh > h-1 { h-1 }` 在 h=0 时条件 `0 > -1` 成立,钳出 **sy=-1**,`px[src+c]` 负索引,DBus 回调里直接 PanicError(exit 134)。用户真机栈:`traybus.downscale_pixmap(icon.mbt:63) ← Item::property(sni.mbt:539) ← Conn::handle_call(sni.mbt:660) ← drain ← on_bus_ready`。修复:`downscale_pixmap` 对退化尺寸(w/h/nw/nh ≤ 0 或缓冲区短于 w*h*4)**早退返 (0,0,空)**,删掉两处合法输入下永不命中的死钳位(y*h/nh 恒 < h);主档 `pixmap_value` 本就容忍空态,面板回落 IconName 走主题图标,SNI 语义不变。修复前后对照(同探针同路径,建托盘→set_icon_name→面板/手动回查 IconPixmap):修复前 exit 134 崩、栈与用户报告逐帧一致;修复后属性返回 `[(0,0,[]), (0,0,[])]`、进程稳定存活(手动 gdbus Properties.Get 复核亦然)。回归:icon_test 补 3 条(0×0 空 pixmap、退化目标尺寸、短缓冲区均返空),moon test 659 全绿。教训:**DBus 属性回调栈上的纯函数同样要防退化输入——回调里 panic 直接杀消息泵;「钳到 h-1」这类尺寸守卫在尺寸为 0 时会把 -1 当合法值,早退比钳位可靠;清空态(0×0)是合法业务状态,所有消费者都要容忍**。
### 系统监控数据层(/proc、/sys,sysmonitor 示例)

- /proc、/sys 伪文件 stat 尺寸恒为 0(fseek/ftell 拿不到长度):整文件读取必须循环增量 `fread` + 倍增缓冲(上限 16MB);读目录时 `fopen` 成功但 `fread` 报 EISDIR,靠 `ferror` 判失败。实现在应用 native-stub `examples/sysmonitor/stub/sysmon.c`,MoonBit 侧统一走 `read_text_file`。
- 应用自有 native-stub 可放子目录:`"native-stub": ["stub/sysmon.c"]` 相对 moon.pkg 所在目录解析;符号全在 libc 默认链接范围,零 shim / fork / vendored / 链接参数改动。测试目标自动链入该 stub,wbtest 可直接读真实 /proc 文件。
- /proc/stat 列序 `user nice system idle iowait irq softirq steal guest guest_nice`:第 9 列 guest 已由内核计入 user/nice,再累加即重复计数;占用率 = (Δ总 − Δidle − Δiowait) / Δ总,iowait 不算 CPU 忙。采样间隔短于一个 tick(USER_HZ 通常 10ms)时 Δ总 ≤ 0,返回 0;首帧前样本取全零,首屏值为开机至今均值。
- /proc/cpuinfo 型号字段平台分歧:x86 是 `model name`,ARM 开发板只有 `Processor` / `Hardware`,三级回退;核数取 `processor` 行数(逻辑 CPU 含超线程,与 nproc 一致)。
- Windows 侧 /proc/cpuinfo 的核数修正(超 64 核,终审发现):GetSystemInfo 的 dwNumberOfProcessors 只覆盖调用线程所在组(单组 ≤64),多组机器须按 GetLogicalProcessorInformationEx(RelationGroup) 的活动组内 ActiveProcessorCount 求和。原实现的守卫与偏移全部不对:关系常量写成 3(RelationProcessorPackage,真实 RelationGroup=4),ActiveGroupCount 读 it+8(真实为 it+10:记录头 8 字节 + MaximumGroupCount 2 字节),GroupInfo 基址与步长按 32+64g(真实为 it+32 起、每组 48 字节),守卫按 32+64g(真实 32+48g)——单组时 API 返回 Size=8+24+48=80 < 96,total 恒 0,修正永不触发,>64 核机器核数停留在当前组值。权威布局(Microsoft Learn winnt.h 文档):GROUP_RELATIONSHIP{WORD MaximumGroupCount; WORD ActiveGroupCount; BYTE Reserved[20]; PROCESSOR_GROUP_INFO GroupInfo[]}(头 24 字节,联合体自记录 +8 起),PROCESSOR_GROUP_INFO{BYTE MaximumProcessorCount; BYTE ActiveProcessorCount; BYTE Reserved[38]; KAFFINITY ActiveProcessorMask}(体 48 字节),SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX 的 Size 是整条记录长度(含 Relationship+Size 头),用作走到下一条记录的步长。验证:harness 以真实结构体填充 2 组(64+32)缓冲区,断言求和得 96;单组与 Size 被裁两种退化各断言回退 64。**多组真机数值须 Windows 真机核实**。
- /proc/meminfo 单位恒为 kB;`MemAvailable` 内核 ≥3.14 才有,缺失回退 `MemFree`;已用口径 = 总 − 可用(含可回收缓存)。
- `moon run` 包装进程不向子进程传播信号:冒烟验证退出行为要杀构建产物 exe 子进程,只杀包装 PID 会留下孤儿窗口。
- 全量进程采样实测(release,Ubuntu 24.04):580 进程 × 2 文件读取(stat + cmdline)共 9.57ms/次,1Hz 刷新约占 1% CPU;RSS 取 stat 的页数 × 页大小(与 status 的 VmRSS 等值),省掉每进程第三次读取。
- /proc/[pid]/stat 的 comm 可含空格与嵌套括号(进程名 "(foo (bar))"),只能按行内最后一个 ')' 切分;comm 截断到 15 字符,完整命令行另读 cmdline(NUL 分隔,空则内核线程回退 [comm])。
- getpriority 的 nice = -1 是合法值,与出错返回值歧义:成败经 `Ref[Int]` 出参报告(kill / setpriority 仍用 errno 返回值)。
- Windows 无 /proc 与 nice 语义:stub 编译期保留同一 ABI、运行期返回「不支持」哨兵(-1000),MoonBit 层语义化为中文提示,进程页整体降级;CI 三平台构建不受影响(macOS 走 POSIX 分支天然可用)。
- NVIDIA 专有驱动的 GPU 占用 / 显存 / 温度不可走进程内 NVML:dlopen `libnvidia-ml.so.1` 后 `nvmlInit_v2` 与宿主运行时偶发堆冲突(本机 RTX 3070 + Ubuntu 24.04 实测启动段错误约 5/6,gdb 下不复现、时序敏感;仅 dlopen+dlsym 不 init 则干净),已改 popen `nvidia-smi` 批量查询(`--query-gpu=pci.bus_id,utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits`,每卡一行),pci 总线地址按「取冒号后最后一段去前导零」与 sysfs 枚举对位(nvidia-smi 的 00000000:01:00.0 vs sysfs 的 0000:01:00.0);代价是每次采样一个子进程(实测几十毫秒,1Hz 可接受)。nvidia-smi 不存在(无 N 卡 / 未装驱动)时自然回退 sysfs 通用节点(amdgpu / nouveau 的 `gpu_busy_percent`、`mem_info_vram_*`),hwmon 温度两者通用;N 卡专有驱动无 hwmon,温度只能来自 nvidia-smi。
- diskstats 同时含整盘与分区条目(nvme0n1 与 nvme0n1p1/p2/p3);LVM 挂载设备名(/dev/mapper/ubuntu--vg-ubuntu--lv)与 diskstats 名(dm-N)对不上,须经 `/sys/block/dm-*/dm/name` 反查 dm-N 再取 slaves 首项(实测 dm-0 → nvme0n1p3)才能把 IO 速率归属到挂载行。
- hwmon 温度编号跳号(coretemp 只暴露部分核的 tempN_input),label 可缺(acpitz 无 label,回退 chip 名);毫摄氏度可为负(电池传感器);NVIDIA 独显普遍不暴露 hwmon 温度(实测 0x2488 无 temp),GPU 温度按 hwmon 口径显示「—」。
- statvfs 容量取 f_bavail(可用,含保留块扣除)而非 f_bfree,与 df 的 Use% 口径一致;结构体跨 ABI 拆成 total/free/avail 三个 int64 出参。
- /proc/mounts 的伪文件系统(proc/sysfs/cgroup2/devtmpfs/efivarfs 等约 20 种)statvfs 无容量意义,容量表按 fstype 黑名单跳过,只留 /dev/ 真实设备行;同一设备多挂载点(btrfs 子卷 / LVM 快照)按设备去重取首个。
- 目录枚举(/sys/class/hwmon、/sys/class/net、/sys/bus/pci/devices、/sys/block/*/slaves)经 stub 的 opendir/readdir 通用化(换行分隔条目名),与 read_text_file 同为数据层唯一两类 IO 原语。
- /dev/fuse 控制挂载(文件管理器拉起 gvfsd-fuse 后出现,挂载点 /tmp/fuse)statvfs 合法返回但 f_blocks=0:只按 fstype 黑名单过滤伪文件系统不够,须再按 total<=0 过滤,否则磁盘页出现 "0 MB / 0 MB" 噪音行(实测 S5 白盒断言 total>0 也因此挂)。
- **Windows 数据层(SYS1):Win32 数据源在 stub 读取入口虚拟出与 Linux 同构的 /proc、/sys 文本,MoonBit 数据层与解析纯函数零改动**。设计定案:与其在 MoonBit 层开平台分支(每个采样器×2 套实现、纯函数测试无法覆盖 Win32 路径),不如让 C 侧把 `read_text_file`/`list_dir`/`statvfs`/`list_pids` 请求的 Linux 路径现场生成同构文本——Linux 路径即跨层契约,单测照常喂字面量全绿。七路映射与偏差清单:
  - CPU:/proc/stat = GetSystemTimes(全局;kernel 含 idle,须相减)+ ntdll `NtQuerySystemInformation(SystemProcessorPerformanceInformation)` 每逻辑核(未公开信息类但 ABI 数十年稳定,任务管理器同源;查询失败只输出总行,各核柱为空);单位统一换算成 10ms tick(100ns ÷ 1e5)与 clk_tck=100 对齐;/proc/cpuinfo 型号与主频取注册表 `CentralProcessor\0` 的 ProcessorNameString/~MHz(编译器无关,比 CPUID intrinsic 免 x86 条件编译),核数 GetSystemInfo(≤64)+ GetLogicalProcessorInformationEx(RelationGroup)组内活动处理器求和修正(>64 核系统 GetSystemInfo 封顶 64)。
  - 内存:GlobalMemoryStatusEx → MemTotal/Free/Available 与 SwapTotal/Free;ullAvailPhys 即 Windows 口径可用(直接充当 MemAvailable 与 MemFree),页面文件额度(ullTotalPageFile=commit limit)充当 swap,与任务管理器「提交」一致而非「页面文件池」。
  - 磁盘:/proc/mounts = GetLogicalDrives 逐盘(GetDriveType 只收 FIXED/REMOVABLE,光驱读盘噪音与网络映射盘跳过),行约定 `dev/C: C:\ ntfs ...`——设备列强制 /dev/ 前缀进 parse_mounts,挂载点直接放真实 Windows 路径(MoonBit 层 statvfs_info 原样传回,stub 侧 GetDiskFreeSpaceExW 直收,UI 显示 "C:\" 自然);/proc/diskstats = PDH `\PhysicalDisk(*)\Disk {Read,Write} Bytes`(PdhAddEnglishCounterW 英文名注册,规避本地化计数器名——中文 Windows 的对象/计数器名不同,硬编码本地化路径必失败;**路径有效性须真机核实**),取原始累计计数器(非 per-sec 变体)单次 Collect 即有效,值÷512 成扇区喂 MoonBit 现有 sector_rate 差值,实例名(如 "0 C: D:")按空格分词、只收形如 "C:" 的盘符 token(磁盘序号与 "_Total" 自然跳过),盘上每个盘符各出一行同名同值——PDH PhysicalDisk 计数按物理盘计, mounts 侧按盘符逐行产出,两个盘符都要能归属到所属物理盘(曾取最后一个 token,多分区盘只记最后一个盘符、其余分区速率恒 None)。**多分区盘实例名形态须真机核实**。
  - 网络:GetIfTable2 全表,InterfaceAlias 做网卡名,Software Loopback 归一为 "lo"(main.mbt 的速率汇总排除逻辑自动生效);InOctets/OutOctets 充当 rx/tx 累计字节。表带 200ms 静态缓存——每块网卡 rx/tx 各读一次路径,1Hz 下无缓存会全表拉取 2×N 次。
  - 进程:K32EnumProcesses(kernel32 导出名带 K32 前缀,须 GetProcAddress)枚举 pid;pid→ppid/线程数/镜像名单次 CreateToolhelp32Snapshot 快照(250ms TTL),每 pid 再 OpenProcess+GetProcessTimes(100ns÷1e5=10ms tick,clk_tck=100 同一单位)+K32GetProcessMemoryInfo(WorkingSetSize÷4096=页数,与 page_size=4096 对位);cmdline = QueryFullProcessImageNameA 全路径,系统进程 OpenProcess 被拒时时间/内存为 0、命令行回退 [comm]。nice 恒 0:Windows 优先级类不映射 Linux nice 语义(映射值会误导),priority 归一是 SYS2 范围(SYS2 已落地:nice 字段改为优先级类反查的档位代表值)。
  - GPU:DXGI CreateDXGIFactory1 枚举适配器,虚拟 pci 地址 `0000:00:NN.0`(MoonBit norm_pci 取尾段去前导零后唯一);vendor/device 出 "0x%04x" 小写喂现有 vendor_name 表;WARP 软件适配器(Flags bit0)跳过;显存 total=DedicatedVideoMemory(为 0 的集显不虚拟 mem_info_vram_total,UI 不出显存曲线),used=IDXGIAdapter3::QueryVideoMemoryInfo(Local 段).CurrentUsage;COM 头不 include dxgi.h——vtable 槽位按接口继承序手工声明(COM 二进制 ABI 稳定),IID 用 SDK 公开常量值自定义,规避 MinGW 头版本差异与 dxgi.lib 链接面。利用率 = PDH `\GPU Engine(*)\Utilization Percentage`,实例名 `pid_*_luid_0xHEX_0xHEX_*` 按适配器 LUID 低 32 位过滤求和(多引擎多进程聚合);**该计数器类型需两次采样才出格式化值,查询句柄静态跨拍保持,首拍恒 0;实例名格式与聚合口径须真机核实**。
  - **手工 COM 声明三处 SDK 事实修正(SYS1 终审修正)**:①三个 IID 全部写错——IDXGIFactory1 写成 770AAE78-F26F-4DBA-83A9-50BC11D9EE9B(真实 770AAE78-F26F-4DBA-A829-253C83D1B387),CreateDXGIFactory1 不被接受、E_NOINTERFACE 返回 → factory==NULL → GPU 一块都枚举不到;IDXGIAdapter3 写成 645967A4-1392-4316-9CEC-9CAF7113F420(真实 645967A4-1392-4310-A798-8053CE3E93FD),QueryInterface 恒失败 → 显存 used 永远拿不到;IDXGIAdapter1(当前无调用点)写成 290462F0-AC1E-4212-AA25-4F95B4968B12(真实 29038F61-3839-4626-91FD-086879011A05)。②IDXGIFactory1 vtable 漏 CreateSoftwareAdapter 且 Make/GetWindowAssociation 顺序颠倒:SDK 顺序(win32metadata dxgi.h 的 IDXGIFactory 块 + IDXGIFactory1 追加块)为 EnumAdapters、MakeWindowAssociation、GetWindowAssociation、CreateSwapChain、CreateSoftwareAdapter,再由 IDXGIFactory1 追加 EnumAdapters1、IsCurrent——原声明下标 11 的「EnumAdapters1」实为 CreateSoftwareAdapter,调用即以 Module=(HMODULE)i 走 CreateSoftwareAdapter(对模块句柄加引用计数),循环 16 次拿不到硬件适配器。③IDXGIAdapter vtable 槽位名同样照 SDK 更正(EnumOutputs;RegisterHardwareContentProtectionTeardownStatusEvent / UnregisterHardwareContentProtectionTeardownStatus,非 RegisterVideoMemoryBudget*)。教训:**手工 COM 声明的 IID 与槽位必须逐项对权威源核(win32metadata generation/WinSDK/RecompiledIdlHeaders 的 dxgi.h/dxgi1_4.h、Microsoft Learn 结构体文档),「自定义常量」不等于「凭印象写」**。验证方式:本机无 Windows 宿主,以「SDK 头文件导出期望 IID/槽位表 + gcc 编译期 _Static_assert(offsetof(槽)==序号)+ 运行期 memcmp」自校验(harness 不进仓库),并对照修复前代码精确失败;语义仍须 Windows 真机验收(GPU 页卡片 / 显存曲线)。
  - 温度:仅 NVIDIA 经 nvidia-smi 子进程,虚拟成 `/sys/class/hwmon/hwmonN/{name,temp1_input,temp1_label}`(每卡一条,输入毫摄氏度),传感器页照常解析;AMD/Intel 温度不可用不硬造(不引 WinRing0 类内核驱动),机器上 hwmon 目录返回 NULL、传感器页为空属合法状态。nvidia-smi 首列总线地址与 DXGI 虚拟地址不同源,按第 6 列型号名与 desc.Description 匹配后重写首列完成对位(型号名是两者共同字符串来源;驱动改名的极端情形对位失败,该卡占用/显存/温度缺失,退化为 DXGI 静态信息)。
  - 子进程原语:CreateProcess+CREATE_NO_WINDOW+匿名管道读输出(hStdOutput/hStdError 同管),不用 _popen——GUI 进程下 _popen 的控制台子进程会闪黑窗;WaitForSingleObject 3s 超时兜底 TerminateProcess。nvidia-smi 结果 500ms 静态缓存(1Hz 下 hwmon 与 gpu_list 各消费一次,避免每秒两次子进程)。
  - 链接纪律:pdh/dxgi/iphlpapi/psapi/ntdll 一律 LoadLibrary+GetProcAddress,kernel32/advapi32 是 MinGW/MSVC 默认链接库直接调用——零链接参数改动,prebuild 托管不破。
  - monotonic 必须真实现(QueryPerformanceCounter):速率类指标全靠墙钟差值,原占位恒 0 会让差值分母恒 0。
  - 验证方式:本机无 mingw/MSVC 无法真编译 Windows 分支,以「最小 Win32 桩头 + gcc -fsyntax-only -Wall -Wextra」验语法与符号面零告警(桩头不进仓库),语义正确性由 CI Windows runner 真实编译 + Windows 真机五页验收(见 TODO.md SYS1 真机清单):重点核实 PDH PhysicalDisk/GPU Engine 计数器路径在中文 Windows 的行为、GPU Engine 的 LUID 聚合数值、nvidia-smi 与 DXGI 型号名匹配、无 N 卡机器传感器页空态。
- **Windows 进程管理语义归一(SYS2):kill / 优先级 / 错误码在 stub 内统一为 Linux errno 语义形态,MoonBit 层 errno_text 与 Result 零改动**。定案:①kill 首版映射 TerminateProcess 一档(SIGTERM/SIGKILL 同映射,UI 收敛为单按钮;TerminateProcess 发起后退出是异步的,短等 WaitForSingleObject 3s 让「已结束 N 个」的报告为真;温和结束 WM_CLOSE 方案后置)。②优先级映射 IDLE/NORMAL/HIGH/REALTIME 四档:set 就近钳制(≥10 IDLE / -9..9 NORMAL / -16..-10 HIGH / ≤-17 REALTIME),get 反查档位代表值(19/10/0/-10/-13/-20;BELOW/ABOVE_NORMAL 钳邻档),虚拟 /proc/[pid]/stat 的 nice 字段从恒 0 改为 GetPriorityClass 反查代表值(进程页 nice 列/排序随之真实)。③Win32 错误码在 stub 内译成 errno 编号:ERROR_ACCESS_DENIED→1(EPERM)、ERROR_INVALID_PARAMETER→22(EINVAL)、ERROR_PRIVILEGE_NOT_HELD/ERROR_SHARING_VIOLATION→13(EACCES)、ERROR_FILE_NOT_FOUND/PATH_NOT_FOUND→2(ENOENT)、NOT_ENOUGH_MEMORY/OUTOFMEMORY→12(ENOMEM)、INVALID_HANDLE→9(EBADF)、ALREADY_EXISTS→17(EEXIST)、BROKEN_PIPE→32(EPIPE),未列出归 EIO=5。④**OpenProcess 对已退出 pid 恒报 ERROR_INVALID_PARAMETER(87)**:不特判会把「进程不存在」显示成「参数非法」,kill/get/set 三入口统一特判 →ESRCH(3),与 Linux kill 不存在进程同语义。⑤REALTIME 档需 SeIncreaseBasePriorityPrivilege,普通用户 SetPriorityClass 报 ERROR_PRIVILEGE_NOT_HELD→EACCES,与 Linux setpriority 负值非属主报 EACCES 对齐。⑥UI 文案平台化(kill_button_labels / priority_ui / priority_result / priority_col_header 纯函数,platform 显式带参便于单测):Windows 单「结束进程(立即终止)」按钮、renice 消息显示档位名 + set 后回读代表值(离散档钳制后的实际值)、优先级列头标「优先级」;Linux 维持两档 kill 与连续 nice。⑦温度等不可用来源按位显示「—」:处理器卡「12% · —」、显卡卡「35% · —」/「— · 55℃」(原为省略对应位,用户分不清「没数据」与「还没刷新」),传感器页无来源时给「暂无可用温度来源」空态行。⑧平台探测新增 yue_sysmon_is_windows(编译期定,两分支各一份),不引 @yue.platform() 保持数据层自足。
  - **踩坑:桩头按代码形状定义会掩盖真实 SDK 的结构成员错误(SYS2 修正 SYS1 遗留)**:SYS1 的 PDH 原始值读取写成 `RawValue.FirstValue.largeValue`,而真实 pdh.h 的 `PDH_RAW_COUNTER.FirstValue` 是 LONGLONG(无 `.largeValue` 后缀,匿名 union 形态的是 `PDH_FMT_COUNTERVALUE` 的 FmtValue)——SYS1 的最小桩头按代码形状定义,`-fsyntax-only` 自然通过,CI Windows runner 真实编译必红。SYS2 修正为 `RawValue.FirstValue`,并把桩头按真实 SDK 形状写(FirstValue 为 LONGLONG、FmtValue 才是匿名 union);结论:桩头只验「符号面与语法」,结构体成员名/布局仍须逐成员对照真实 SDK,`-fsyntax-only` 零告警不等于能真编译。
  - SYS2 验证方式:本机无 Windows 宿主,Windows 分支以最小 Win32 桩头(按真实 SDK 形状定义,不进仓库)过 `gcc -fsyntax-only -Wall -Wextra` 零告警;touch stub 后 `moon build examples/sysmonitor` 零警告(sysmon.o 真实重编);`moon check` 零警告 + `moon test` 608 全绿(sysproc_wbtest 新增 8 条:errno_text 翻译目标值、四档档界、kill/优先级按钮与结果文案、列头、with_temp「—」占位、不存在 pid 的 get/set 归一 ESRCH);**实际终止 / REALTIME 提权行为必须 Windows 真机验证**(清单见 TODO.md SYS2)。
- **macOS 数据层(SYS3):Mach / libproc / getfsstat / getifaddrs / system_profiler 数据源在 stub 读取入口虚拟出与 Linux 同构的 /proc、/sys 文本,MoonBit 解析层与解析纯函数零改动(同 SYS1「Linux 路径即跨层契约」的定案);GPU 走 system_profiler -json 子进程、JSON 解析在 MoonBit 纯函数;磁盘 IO 速率与温度无来源,UI 按「—」边界显示**。七路映射与平台分流:
  - 平台分流:stub 三平台结构(`_WIN32` / `__APPLE__` / Linux),kill / 优先级 / statvfs / monotonic / page_size 走 POSIX 共享实现(macOS 与 Linux 同语义,进程管理 UI 两按钮与连续 nice 口径原样适用);CPU / 内存 / 进程 / 网络 / 挂载五路由到虚拟文本;MoonBit 层只开两处分支(`on_macos() = @yue.platform() == "macos"`):gpu_list 走 system_profiler 解析、DiskMonitor 容忍 /proc/diskstats 缺失。Mach / proc_info / statfs / if_data64 一律按 xnu 源码布局自声明(符号在 libSystem 默认链接范围),免 SDK 头版本差异——同 Windows 分支手工 vtable 与自定义 PROCESS_MEMORY_COUNTERS 的思路。
  - CPU:`host_processor_info(PROCESSOR_CPU_LOAD_INFO)` 每逻辑核 user/system/idle/nice 累计 tick,总行取各核求和,列序与 /proc/stat 对齐(iowait/irq/softirq/steal 无对应恒 0);tick 单位由 mach 自定,只用于差值比率,与 clk_tck 无关;返回缓冲必须 `vm_deallocate(mach_task_self_())`(1Hz 采样每拍一块,泄漏可积少成多)。型号 `machdep.cpu.brand_string`(Apple Silicon 亦实现)→ 回退 `hw.model`;主频 `hw.cpufrequency`(Hz→MHz,部分机型无该键为 0);核数 `hw.ncpu`。
  - 内存:`hw.memsize` 总量;`host_statistics64(HOST_VM_INFO64)` 取 free / inactive,可用 = free + inactive(活动监视器口径);swap 走 sysctl `vm.swapusage`(`xsw_usage` 布局 SDK 未公开,按通用定义自声明:total/avail/used 三 uint64 + pagesize + encrypted)。
  - 磁盘:`getfsstat(MNT_WAIT)` 全量挂载转写成 /proc/mounts 同构文本,过滤口径全部留在 MoonBit 侧——`is_pseudo_fs` 补 BSD 伪文件系统(devfs / fdesc / nullfs / volfs / union / synth,autofs 两平台同名),`is_system_mount` 补 macOS 系统宗卷(/private 即 swap 后备卷、/System/Volumes/{Preboot,Update,VM,Hardware,iSCPreboot},用户数据卷 /System/Volumes/Data 保留);挂载点可含空格(用户卷名),stub 按内核惯例 `\040` 转义、MoonBit 侧 `unescape_mount` 还原(不还原会按空白切错列、statvfs 失败后整行从容量表消失);容量复用 POSIX 共享 statvfs。**IO 速率无来源(IOKit 列远期)**:`/proc/diskstats` 读失败不再让整次 tick 失败(旧实现直接 return None 会让磁盘页整页空白),`DiskInfo.read_bps/write_bps` 由 Double 改 `Double?`,None 时 UI 显示「—」、IO 曲线不推点(不画一条假的 0 线);归属不到 diskstats 的挂载(NFS 等)同样 None,比旧实现恒显 0 B/s 更诚实。
  - 网络:`getifaddrs`(表带 200ms TTL 缓存——每块网卡 rx/tx 各读一次路径,1Hz 下无缓存会每拍两次全表拉取),`ifa_data` 指向 `struct if_data64`,`ifi_ibytes/ifi_obytes` 充当累计字节;每地址族一条按名字去重;loopback "lo0" 归一为 "lo"(main.mbt 的速率汇总排除按 "lo" 口径,同 Windows 分支对 Software Loopback 的处理)。
  - 进程:`proc_listpids(PROC_ALL_PIDS)` 枚举(NULL/0 探所需字节数 + 8KB 余量吸收两次调用间的新进程),pid 0(kernel_task)无命令行与计时,枚举时跳过;`proc_pidinfo(PROC_PIDTBSDINFO)` 取 ppid / nice / 状态 / comm,`PROC_PIDTASKINFO` 取线程数与纳秒计时(÷1e7 → 10ms tick,`yue_sysmon_clk_tck` 在 macOS 分支硬编码 100,与换算口径自洽);RSS 字节 ÷ 页数;`proc_pidpath` 全路径充当 cmdline(权限不足 / kernel_task 返回 NULL,MoonBit 层回退 [comm]);状态按 BSD p_stat 映射(SIDL→I / SRUN→R / SZOMB→Z / SSLEEP→S / SSTOP→T)。选 PROC_PIDTASKINFO 而非 proc_pid_rusage:一次调用同时拿线程数 / 双计时 / RSS,少一次系统调用。
  - GPU:`system_profiler SPDisplaysDataType -json` 子进程——fork + 匿名管道 + poll 超时(8s)后 SIGKILL,不用 popen(GUI 进程下 shell 子进程会闪窗,同 Windows CREATE_NO_WINDOW 的考虑),execv 绝对路径 `/usr/sbin/system_profiler` 免 PATH 搜索分配;首跑秒级,成功后进程内常驻缓存(型号 / 显存总量静态,同 Windows DXGI 枚举一次的思路),失败按 5s 退避重试;JSON 原样回传,MoonBit 侧 `parse_system_profiler_gpu` 纯函数解析(`_items` 按花括号深度切分、跳过字符串内括号,型号取 `sppci_model` 回退 `_name`,显存 `spdisplays_vram`,厂商按名字嗅探)。利用率与温度无来源(GPU 利用率无公开接口、SMC / IOReport 私有键列远期),busy / celsius 留 None,UI 按位显示「—」。
  - 温度:首版不显示(SMC / IOReport 私有键列远期),`/sys/class/hwmon` 在 macOS 自然返回 None,传感器页空态行与处理器卡温度位「· —」沿用 SYS2 既有口径。
  - 链接纪律:新增符号全部在 libSystem 默认链接范围,零链接参数;extern 声明须三平台都可链接——非 macOS 用同 ABI 占位返回 NULL(MoonBit 层 `gpu_list` 的 macOS 分支只在 `on_macos()` 为真时调用,运行期不会到占位),否则 Linux / Windows 的测试构建链接期直接失败(本次即因此补占位)。
  - **踩坑:Mach 常量与结构布局自声明前必须对照 xnu 源码核实**:`PROCESSOR_CPU_LOAD_INFO` 是 2 不是 1、`MNT_WAIT` 是 1 不是 2、`MAXCOMLEN` 是 16、64 位 `statfs` 的 `f_mntonname` 在 `f_mntfromname` 之前、`if_data64` 的字节计数叫 `ifi_ibytes/ifi_obytes`(无 `ifi_oobytes`)——这些凭记忆写错编译器不会报(自声明即真相),`-fsyntax-only` 只验语法与符号面,结构体偏移仍须逐成员对照真实 SDK(同 SYS2 教训);`host_statistics64` 的 count 语义是「小于 REV0 count 返回 KERN_FAILURE、大于则按低版本填」,故按当前 xnu 全字段布局传 40 个整数、多带字段安全。
  - **踩坑:`String::unsafe_get` 返回 UInt16(UTF-16 code unit)而不是 Char**:逐字符扫描 JSON / 转义串时 `c == '\\'` 直接类型不匹配,要么 `to_int()` 比较、要么对未处理区间成段拷贝(`write_stringview` + 切片,代理对安全),混用会踩「has type UInt16, wanted Char」。
  - 踩坑:宿主机时钟回跳会让 moon 增量构建把未来 mtime 的 `.o` 当最新,`touch` 源码不触发重编——验证 stub 改动时若 `moon build` 报 up to date,先删 `_build` 下对应 `.o` 再构建。
  - SYS3 验证方式:本环境无 macOS 实机。Linux 宿主 `moon check` 零警告 + `moon test` 614 全绿(syshw_wbtest 新增 6 条:unescape_mount 转义还原与非法序列、parse_mounts 的 macOS getfsstat 形态(含空格卷名 / BSD 伪文件系统)、is_system_mount 系统宗卷、parse_vram、json_string_value / json_items_objects 切分与嵌套、parse_system_profiler_gpu 双卡解析与宽容口径;DiskInfo 速率字段改 Option 后 S5 / S6 真实采样断言同步放宽为双形态);macOS 分支以 `gcc -fsyntax-only -Wall -Wextra -D__APPLE__` 零告警(只验语法与符号面,结构体布局按 xnu 源码逐字段核对,语义由真机把关);touch stub 后 `moon build examples/sysmonitor` 零警告;非 macOS 占位符号已核在 Linux 构建产物中导出。**七路数据与进程管理必须 mac 真机验证**(清单见 TODO.md SYS3):重点核实 host_processor_info 各核占用数值(顺序错会把 idle 当 user)、system_profiler -json 的键名与解析对位(sppci_model / spdisplays_vram / spdisplays_vendor,Apple Silicon 与 Intel / AMD 卡各测)、getfsstat 挂载表与 df 对照(含含空格卷名与 /System/Volumes/Data)、proc_listpids 进程数与 ps 对照、kill / setpriority 实际生效。
- **Linux GPU 利用率补全(SYS4):DRM fdinfo 聚合采样免 root 得全卡利用率(i915 / xe / amdgpu);点名域原表述「请求超管权限读显卡」经本机实证改为「免 root 数据源补全 + 提权边界显式化」**。定案:①**权限实证**(Ubuntu 24.04 uid 1000 本机实测):`/sys/class/hwmon/hwmon*/temp*_input` 与 amdgpu `gpu_busy_percent` 均 0444,DRM fdinfo 走 /proc 标准接口(本用户进程的 fdinfo 文件 r--r--r--),面板所需常规数据本就免 root;唯一受限的 `/sys/kernel/debug/dri`(debugfs,drwx------ root)是 i915 调试视图(per-engine / per-client 细分),并不含面板所需指标——「请求超管权限读显卡」没有数据支撑,polkit / pkexec 集成暂不做(若用户坚持提权路线再单独排批)。②占用来源优先级:nvidia-smi(N 卡)> sysfs `gpu_busy_percent`(amdgpu,驱动侧全卡均值、覆盖全部客户端)> DRM fdinfo 聚合(i915 / xe / amdgpu 兜底);显存 / 温度口径不变。③fdinfo 聚合口径:枚举 `/proc/<pid>/fdinfo`,解析 `drm-driver` / `drm-pdev` / `drm-client-id` / `drm-engine-*`(全部引擎求和),按 (设备键, client-id) 归并(dup 的 fd、fd 经 unix socket 跨进程传递是同一个 drm_file、累计值相同,只取最大一次),两次采样差值 / 墙钟折算全卡利用率(0..100 钳制)——与 intel_gpu_top / nvtop 同源。④归属:`drm-pdev`(内核 ≥6.5,PCI 槽位地址与 sysfs 设备目录名同形)优先;老内核无该键,按 `/sys/bus/pci/devices/<addr>/uevent` 的 `DRIVER=` 驱动名回退(双同驱动卡会合并成同一值,已知边界)。⑤扫描只在「有显卡既无 sysfs 占用也无 nvidia-smi 覆盖」时才做:AMD / NVIDIA 机器整拍免扫,Intel 机每拍扫(nvtop / intel_gpu_top 同款成本)。⑥首帧无前样本不出数(次帧起),新客户端首现那帧不计;数据层入口由 `gpu_list()` 改为 `GpuMonitor::tick()`(前样本状态随 App 常驻,macOS 分支不变)。
  - **版本边界(对照 torvalds/linux 源码逐版核实)**:`drm-engine-*` / `drm-driver` / `drm-client-id` 自 v5.19 起(amdgpu / i915 "Convert to common fdinfo format v5",2022-05-26,v5.18 无 / v5.19 有);`drm-pdev` 自 v6.5 起(`drm_file.c` 的 `drm_show_fdinfo` 里 `dev_is_pci` 分支,v6.4 无 / v6.5 有,格式 `%04x:%02x:%02x.%d`);cycles / maxfreq 类 6.2 起(本轮不消费)。Ubuntu 22.04 的 5.15 内核无引擎统计键 → busy None 显示「—」;24.04 的 6.8 三者全有。
  - **已知边界(诚实口径,来源不可用即显示「—」)**:①fdinfo 只覆盖本用户进程——他人进程(root 服务 / 其他登录用户)的 `/proc/<pid>/fdinfo/<fd>` 读返回 EACCES(实测 `/proc/1/fdinfo/1` 权限不够),整卡利用率是「本用户可见口径」,会低估;全量统计需 root(polkit 暂不集成)。②扫描成本实测:全 /proc fdinfo 扫描 9123 个文件、4.2MB,约 56ms/拍(与 stub 同款读取循环的 C 程序实测,554 进程桌面;Python 同口径 78ms)。③短命客户端在两次扫描间开闭,其忙时间随客户端消失而丢失( fdinfo 计数器挂在客户端上)。④多引擎并行(gfx + compute 同时跑)合计可超墙钟,钳到 100。⑤计数器非单调更新(内核规范允许)按 0 增量。
  - **踩坑:解析必须排除 `drm-engine-capacity-<name>`**:i915 多视频引擎时打印并行引擎数(如 `drm-engine-capacity-video: 2`),按 `has_prefix("drm-engine-")` 收集会把引擎数(2)当成 ns 累加进忙时间;值侧同理要取首个空白分隔字段再 parse_u64——引擎值带 ` ns` 后缀、旁支键值带 ` KiB` 单位(`drm-memory-vram: 1024 KiB`)、`drm-memory-gtt: ` 冒号后还多带一个空格(amdgpu 源码原样),不取首字段直接 parse 必失败。
  - 踩坑:/proc 目录枚举条目含 `cpuinfo` / `self` / `irq` 等非进程条目,须纯数字过滤后再进 fdinfo;amdgpu 零用量引擎不打印(源码 `if (!usage[hw_ip]) continue;`),条目里只有非零引擎,求和口径不受影响;i915 gen<8 早退不打引擎键 → 解析为 None,busy 显示「—」。
  - SYS4 验证方式:stub 零改动(纯 MoonBit 侧,复用 read_text_file / list_dir 两类原语)。Linux 宿主 `moon check` 零警告 + `moon test` 623 全绿(syshw_wbtest 新增 9 条:parse_drm_fdinfo 的 amdgpu / i915 / None 三形态、is_drm_engine_key 与 drm_device_key、drm_clients_total 归并(dup fd / 跨进程 / 双设备 / 缺 client-id)、drm_busy_percent(首帧 / 回落 / 钳 100)、is_pid_entry、parse_uevent_driver、fdinfo 真实采样两拍);删 `_build` 下 sysmonitor `.o` 后 `moon build examples/sysmonitor` 零警告。**i915 / xe / amdgpu 真机验证由用户执行**(本机为 NVIDIA 专有驱动机,无 fdinfo 用量统计、无法实测此路):①Intel 集显占用与 `intel_gpu_top` 同窗口对照②AMD 独显 sysfs `gpu_busy_percent` 与 fdinfo 双源对照(应优先 sysfs)③双卡机(iGPU + dGPU)归属正确性(drm-pdev 优先)④老内核(<6.5)驱动名回退归属⑤短命 GPU 客户端(反复起停的跑分程序)利用率是否漏计⑥本用户口径与 `sudo intel_gpu_top` 的差异量级⑦扫描耗时对 1Hz 采样占空的影响。
- **Linux GPU 型号名解析(SYS5):AMD / Intel 卡经 pci.ids 显示商业型号名——sysfs 只有数字 id(vendor / device 节点)与驱动绑定名,商业型号名不在任何 /sys 节点中,免 root 纯文本数据库是唯一来源;查不到回退 device id 原文显示**。定案:①来源优先级:nvidia-smi 命中(N 卡,型号名比 pci.ids 更具体,如 smi 的 "NVIDIA GeForce RTX 3070" vs pci.ids 的 "GA104 [GeForce RTX 3070 Lite Hash Rate]")> pci.ids 按 vendor:device 查 > device id 原文(「0x7480」,至少可区分多卡);sysfs 读取失败的占位 id("(未知)")留空,UI 不显示型号位。②路径差异:hwdata 包装 `/usr/share/hwdata/pci.ids`(不少发行版里它是指向 misc 的符号链接)、pciutils 包装 `/usr/share/misc/pci.ids`,依次尝试;两路都不可达(未装数据库 / Flatpak 沙箱 / 非 Linux)按「查不到」兜底。③缓存:pci.ids 全文首次用到时读入常驻(约 1.4MB,在 native-stub 单文件 16MB 上限内),解析结果按 PCI 地址常驻——实测单次全文查找约 14ms(`moon test` debug 构建;Intel vendor 在 27868/38108 行,早退也要扫七成文件),1Hz 每卡每拍重扫不可接受;vendor:device 是静态硬件信息,首拍查一次即可,库不可达时常驻的是回退值、重启后重试。④UI:型号名拼进传感器页小节标题(既有 gpu_label 路径,page_sensors.mbt 零改动),概览页卡片只显示紧凑数值、型号归详情页。
  - **pci.ids 格式实测(2024.03.31 版,38108 行)**:无缩进行 = vendor(4 位十六进制 id + 两空格 + 厂商名),单 Tab 行 = 该 vendor 的 device,双 Tab 行 = subsystem(本面板不消费),'#' 起 = 注释;vendor 2378 个、device 18685 条、subsystem 16258 条;全文无 CRLF、无行尾空白、id 全部恰为 4 位小写十六进制;7 个空行全在文件头注释区与 class 节内(现代版本 vendor 块之间不空行);末尾 class 节("C 00" 起)与 vendor 行同形,但 id 非四位十六进制,自然不匹配;"ffff Illegal Vendor ID" 是最后一个 vendor 且无 device 行、紧接 class 节——查它正好验「出节提前返回」。
  - **踩坑:空 id 归一化不能补零**:`norm_pci_id("")` 按「左补零到 4 位」会补成 "0000" 假有效 id(单测首跑即抓出),空串须保持空串;sysfs 读取失败时 vendor / device 是 "(未知)" 占位串,靠 is_hex4 挡掉后才能走回退。
  - 踩坑:型号名整段保留内部空格与方括号(如 "Navi 33 [Radeon RX 7700S/7600/7600S/7600M XT/PRO W7600]"),不能按空白切 fields 再 join(当前版本名称内含双空格虽为 0 条,按整段切片才是正解);切片按 UTF-16 码元索引(`StringView::exact_view` 的基准),不能用 `iter2` 的码点索引——结构性字符全是 ASCII,代理对只可能出现在名称里;device 行有条目但无名称(真实库不出现)不当命中,继续扫、按查不到回退 id。
  - SYS5 验证方式:stub 零改动(纯 MoonBit 侧,复用 read_text_file 一类原语)。Linux 宿主 `moon check` 零警告 + `moon test` 628 全绿(syshw_wbtest 新增 5 条:norm_pci_id / is_hex4 归一化与判定、pci_ids_device_name 缩进层级解析(subsystem 跳过 / 跨 vendor 不串 / 无 device 行 vendor / class 节 / 出节提前返回 / 非法 id)、gpu_model_name 四形态(smi 优先 / 库命中 / 库不可达与无条目回退 id / 占位 id 留空)、GpuMonitor::gpu_model 常驻缓存与 smi 优先、真实 pci.ids 采样(动态取首对 vendor/device 正向断言 + 无 device 行的 dead vendor 负向));删 `_build` 下 sysmonitor `.o` 后 `moon build examples/sysmonitor` 零警告;本机(Ubuntu 24.04,NVIDIA 专有驱动机)实测三对真实条目解析正确(1002:7480 → Navi 33、8086:3ea0 → WhiskeyLake-U GT2、10de:2488 → GA104)。**AMD / Intel 真机验证由用户执行**:①AMD 独显传感器页小节标题显示商业型号名(与 `lspci -nn` 对照)②Intel 集显同上③双卡机(iGPU + dGPU)两块各显示各的型号④查不到(极新卡 / 数据库缺条目)时回退显示 device id 而非空白⑤最小化安装(无 hwdata / pciutils)与 Flatpak 沙箱下的回退形态⑥其它发行版路径差异(Fedora / Arch 的 hwdata、openSUSE 等)⑦长型号名在小节标题的换行 / 溢出观感。
- sysmonitor 界面文案纪律(整批界面打磨实测):界面文字只说「是什么 / 怎么用」,不写数据口径与实现路径(如 /proc 路径、两次差值、毫摄氏度换算、"nvidia-smi 后置"这类计划说明);速率 / 容量 / 坐标轴一律多级单位动态换挡(B→K→M→G),数值保持短,大号数值卡(24px)尤其忌换行溢出卡片。
- sysmonitor 概览页卡片范式对标 Mission Center(资源管理器式):图标 + 标题、规格副标题(CPU 型号 / 总容量 / 挂载点等硬件规格放卡片副标题,不在窗口顶层占副标题行)、当前值行(占用% · 温度、已用 / 总量 · swap 等组合)、卡内迷你曲线(序列末窗 + 末端圆点;值域固定 0-100 或峰值自适应,双序列同窗叠加如网络 rx/tx)。卡片 flex 均分、同排 stretch 等高,随窗口伸缩;单卡自包含,不看窗口其他部分也能读懂。
- xrandr 输出格式随版本变化(显示器枚举实测):1.5.2 起把刷新率标记('*' 当前 / '+' 首选 / 'i' 隔行)中的 '+' 打成独立 token 且位于被标记刷新率之后(`59.95 +  75.00`,经 xrandr --verbose 证实 59.95 为该 +preferred 模式),旧版直接附着在刷新率尾部(`59.95+`)。mon_fold_marker_tokens 把独立标记 token 回贴到前一 token 尾部统一为附着形态后再解析。
- **进程数据两处正确性缺陷(EX2,高危):负 nice 全显 0、新出现 pid 当拍 CPU% 钉满格**。①`/proc/[pid]/stat` 的 nice 是**有符号**字段(-20..19),而解析用的 `parse_u64` 遇负号整字段返回 None → `unwrap_or(0)` 把负 nice 静默变 0:进程页 nice 列显示失真,ByNice 排序也失真(本机 142 个负 nice 进程,kworker 系全部 -20,是日常就存在的量而非边角)。修法:同一处解析内按字段符号选解析器——无符号字段(utime/stime/starttime/rss_pages)走 `parse_u64`,有符号字段(nice/ppid/threads)走现成的 `parse_i64`,字段序号与取值口径零改动。②`ProcMonitor::tick` 的差值前样本用 `self.prev.get(pid).unwrap_or(0)`:**采样间隙新出现的 pid**(启动新进程、`moon test` 自身起的子进程)本拍没有前样本,却按「前样本 tick = 0」参与差值,把该进程开机以来的全部累计 tick 当成本拍增量 → CPU% 直接顶到 cores×100 钳制值(白盒对照实测 `400 != 0`,即单拍假满格),下一拍才回落真值。修法:差值前样本改为可空,抽成纯函数 `proc_tick_cpu_pct(prev : Int64?, cur, clk_tck, wall_s, cores)`,prev 缺失时本拍直接给 0(与「首帧无前样本给 0」同一口径),`tick` 只传 `self.prev.get(pid)`;有前样本时分派到既有 `proc_cpu_pct`,行为不变。
  - 踩坑:`parse_u64` / `parse_i64` 的失败都收敛成 `unwrap_or(0)`,`None` 与「真的是 0」在调用侧不可区分——有符号字段用错解析器不会报错、只会静默给出错值,是这类缺陷能长期潜伏的原因;按字段符号显式选解析器比「一个 num() 通用」更稳。
  - 踩坑:CPU% 差值类指标的「无前样本」必须与「前样本为 0」区分开。前者是「不知道」,后者是「确实从 0 开始」;用 `unwrap_or(0)` 把前者混成后者,对**单调累计计数器**(tick/字节/扇区)必然产出「开机至今全量」的假增量,且被钳制逻辑掩盖成「满格」而非明显异常,肉眼难以归因。
  - 验证方式:stub 零改动(纯 MoonBit 侧)。`moon check --deny-warn` 零警告 + `moon test` 644 全绿(sysproc_wbtest 新增 3 条:parse_proc_pid_stat 负 nice 真实样本(取本机 /proc/4/stat 的 kworker/R-rcu_gp nice=-20 逐字段断言,外加 nice=-1 / 19 / 裸负号兜底)、sort_procs 的 ByNice 负值升降序(-20/0/19 三档不再混档)、proc_tick_cpu_pct 无前样本当拍置 0(与有前样本满负荷/半负荷/钳制/墙钟无效/负增量各形态对照));删 `_build` 下 sysmonitor `.o` 后 `moon build examples/sysmonitor` 零警告;白盒对照——暂存修复前代码跑 `moon test -p sysmonitor`,负 nice 用例精确失败(`0 != -20`)、把 `proc_tick_cpu_pct` 改回旧语义后 tick 用例精确失败(`400 != 0`),恢复修复后 24/24 通过;真实 /proc 端到端用例(强制起短命进程填满 2s 窗口)实测新出现 pid 的当拍 CPU% 恒 0。
- sysmonitor 界面文案纪律(整批界面打磨实测):界面文字只说「是什么 / 怎么用」,不写数据口径与实现路径(如 /proc 路径、两次差值、毫摄氏度换算、"nvidia-smi 后置"这类计划说明);速率 / 容量 / 坐标轴一律多级单位动态换挡(B→K→M→G),数值保持短,大号数值卡(24px)尤其忌换行溢出卡片。

### 系统能力数据层(音量 / 亮度 / 浏览器历史 / VS Code 历史 / 应用查找)

本批新增五模块(yue/volume、brightness、browser_history、vscode_history、appfind),实测环境 Ubuntu 24.04 + XFCE + X11、PipeWire 音频栈、Chrome 多 profile、VS Code(OSS 官方发行版)。以下为本批真机实测沉淀:

- 音量双后端实测(wpctl 优先、pactl 回退):wpctl `get-volume @DEFAULT_SINK@` 输出形如 `Volume: 0.42 [MUTED]`,sink 显示名取 `wpctl status`(层级文本,取 Audio 段 Sinks 首个);pactl 路径三次查询(get-default-sink + get-sink-volume + get-sink-mute)。**pactl 的可读输出按 locale 本地化**(中文环境输出「音量:」而非 "Volume:"),按英文文案写的解析在本地化环境必挂——子进程环境必须固定 `LC_ALL=C`(vol_env_blob 同时传 PATH、XDG_RUNTIME_DIR、HOME:PipeWire/Pulse 套接字定位靠 XDG_RUNTIME_DIR,缺了工具连不上服务、退出码非 0)。样例断言用实机采集文本(volume_wbtest,pactl 样例即 LC_ALL=C 下输出;出现本地化文案即视为解析失败)。
- 浏览器历史直读 Chrome 系 SQLite 库(moonsqlitefile 纯解析,无 SQLite FFI、不开锁、不复制原库):①时间基准是 1601-01-01 UTC 起微秒(Windows FILETIME 同源),Unix 毫秒 = µs/1000 − 11644473600000,实测样本 13435769563030519 → 2026-10-06T14:12:43.030Z;②urls 表 id 列虽是 INTEGER PRIMARY KEY,磁盘记录里存 **Null**(rowid 别名不落盘),按列序取值不能假设类型;③hidden 列非 0 是重定向等隐藏条目须滤除;④Chrome 运行中的新写入落库的 -wal 文件,当前实现只传主库文件给 open_database(未做 WAL 合并,moonsqlitefile 另有 open_wal_database 可接);⑤探测读入的库字节直接作打开输入,同一库不读第二遍(History 库常达数十 MB)。
- VS Code 本地历史:①`User/History/<hash>/entries.json` 的目录名哈希是 31 进制滚动哈希(种子 149417,Int32 回绕),输出**有符号**小写十六进制——负值目录名真实存在(实测 `-10b5e510`),按资源 URI 复算三例(正数/负数/vscode-userdata 方案)全部命中;②entries.json 部分条目**无 source 字段**(实测),解析不能假设必有;③storage.json 的 windowsState:lastActiveWindow 在前 + openedWindows 数组,窗口对象有 folder(普通文件夹)与 workspaceUri(.code-workspace)两种形态,URI 百分号编码(空格 `%20`、中文 `%E4%B8%AD`)须解码;④端到端仅在存在 VS Code 用户数据的环境执行(vsc_supported 门控),纯逻辑层全部在内存样例上白盒断言。
- 亮度:设置走 logind 的 SetBrightness(系统总线 session/auto 对象,@traybus 层),枚举与当前值走 /sys/class/backlight sysfs 只读——logind 不在线时 set 报 Unsupported 而 devices/get 仍可用;键盘背光在 leds 子系统(设备名形如 `inputN::kbd_backlight`)。sysfs 值文本解析容忍首尾空白与尾换行。
- 应用查找(appfind):desktop entries 无目录枚举原语,`appfind_installed_with` 由调用方注入列举函数,默认便捷入口因恒空已裁撤(名不副实);`appfind_executable` 命中判定为整文件可读(read_binary_file),大体积可执行文件全量读入仅判存在是已知取舍(修需新增原生 stat 原语,暂不动 shim)。
- 默认应用查询(defaultapps,补清单遗漏):①查询走 `xdg-mime query filetype/default`,关联枚举直读三层 mimeapps.list(`~/.config` → `~/.local/share/applications` → `/usr/share/applications`,即 XDG mimeapps 规范优先级),不依赖命令的路径全用 read_text_file 薄解析;②**mimeapps.list 的同名键多行是候选列表,与 .desktop INI 的「首键生效」口径相反**——`[Default Applications]` 同一 MIME 写多行是「后写覆盖先写」的多候选登记,da_parse_mimeapps 因此不去重同键,da_default_for 回退路径取该 MIME 最后一个候选的段首值;③`xdg-mime query default` 对未登记类型**返回空串且退出码 0**(不是非零退出),「无默认」只能判空输出,不能靠退出码;④设置为「读-改-写回」~/.config/mimeapps.list 的 `[Default Applications]` 段:已有该行替换、无该行段内追加、无段文末补段,写文件用 write_text_file(同包 FFI,autostart 同款);⑤libyue 原生 Notification 无进度接口(vendor 头 notification.h 仅 title/body/info/silent/image/actions,shim 无对应 FFI),Linux 通知进度标准在 freedesktop hints 的 `value` 字段(走 traybus D-Bus 可实现)——本批确认原生通知能力已够用,未做进度条,后续若需要走 D-Bus Notify + a{sv} hints。
- 浏览器历史 / VS Code 历史的真机验证入口:NoahLiu/gui-examples/systemprobe 示例(图表 + 系统能力一板),`moon run NoahLiu/gui-examples/systemprobe` 点「读取系统能力」按钮逐项呈现五模块真实结果。

#### 影音与桌面控制命令路线(pr_run 统一封装,含 MPRIS 总线回退)

本批命令行类模块全部经 `yue/procrun.mbt` 的 `pr_run`(spawn → 限时回收 → 临时文件捕获 stdout/stderr),不自行 spawn;环境固定 C locale,退出码 0 归一 Ok、非零归一 Err 带 stderr,调用方不再自行判码。**命令缺失的语义**:Unix 下 shell 以退出码 127 呈现,由各模块自己的 `*_supported()` 探测归一为 Unsupported(pp_profiles / prt_default / nl_supported / win_list 各自探测自身命令),调用方按错误值分类,不用文本猜。命令路线与降级链:

| 能力 | 首选路线 | 降级路线 | 探测方式(只读无副作用) |
|---|---|---|---|
| 夜间色温 nightlight | `redshift -P -O <K>`(2500K..6500K,一次性设) | `xrandr --output <输出> --gamma R:G:B`(红 0.85..1.00 微提、蓝 1.00..2.20 衰减,绿恒 1.00) | `redshift -V` 退出 0;否则 `xrandr --query` 可用(无已连接输出 → Unsupported,无头环境) |
| 显示器配置 monitor | `xrandr --query` 全量解析(刷新率厘赫兹整数) | 无(不可用即 Unsupported) | 同上,一条 `--query` 只读探测 |
| 壁纸 wallpaper | XFCE `xfconf-query -c xfce4-desktop -p /backdrop/.../last-image`(读 / 写) | GNOME `gsettings get/set org.gnome.desktop.background picture-uri`;KDE `qdbus6/qdbus org.kde.plasmashell evaluateScript`(未真机验证) | DE 识别复用 @traybus.detect_desktop(XDG_CURRENT_DESKTOP),未知 DE → UnknownDesktop 带原文 |
| 窗口管理 windowctl | `wmctrl -l` 列表 / `-i -a <id>` / `-ic <id>` | 无(非 Linux 或 wmctrl 缺失 → Unsupported) | 命令缺失以 127 呈现 → Unsupported |
| 剪贴板监听 clipboard_watch | `xclip -selection clipboard -o`(只读轮询) | 无 | 同上,读失败(未装 / 选区无文本)静默跳过该拍 |
| 电源计划 powerprofile | `powerprofilesctl list / get / set` | 无 | 命令缺失 → PpUnsupported;list 输出保留后端序(推荐序在前时即推荐序) |
| 打印机 printer | `lpstat -p / -d / -o <打印机>` + `lp [-d 打印机] -n 份数 文件` | 无 | lpstat 缺失(未装 CUPS)→ PrtUnsupported |
| 磁盘卷 disk | udisks2 D-Bus(系统总线) | `lsblk --json`(仅枚举,挂载卸载不可用) | NameHasOwner 或 Manager 调用可达 |

MPRIS(媒体控制)是这族里唯一「总线优先、命令兜底」的倒置路线。接口要点:播放器实例经会话总线 `org.freedesktop.DBus.ListNames` 应答里过滤 `org.mpris.MediaPlayer2.` 前缀(含 playerctld 代理实例,一并收),对象路径恒 `/org/mpris/MediaPlayer2`,接口 `org.mpris.MediaPlayer2.Player`;播放控制 Play/Pause/PlayPause/Next/Previous/Stop 全为空参方法(应答空),状态读 `org.freedesktop.DBus.Properties.PlaybackStatus` + Metadata 字符串字段 title/artist/album。**总线调用失败才回退 playerctl**(`playerctl --version` 退出 0 判定可用),回退路径用 `-p <player>` 指定实例、读取用 `metadata --format <US>title<US>artist<US>album<US>`(US 分隔符界定,标题含分隔符的场景按首段切分,已知取舍)。探测口径:media_supported 以 ListNames 通为准,总线不可达才看 playerctl。播放控制属设置类,不在探测里触发。

#### 音频与视频(FRAME → draw_image 渲染路线)

- 音频:集成 `CorvusCinereus/miniaudio@0.4.0`(miniaudio 的 MoonBit 封装,产物体积小、ABI 面=引擎+剪辑两组)。链接验证:同样本 prebuild.py 托管体系,moon add 后 moon build 全仓通过,与 subproc/moonsqlitefile 的 native stub 共存无冲突;该包自身 moonbuild 无 supported_targets 声明(第三方包的告警,非本项目问题)。headless 真机冒烟(本机 XFCE + PipeWire):引擎可建、`/usr/share/sounds/alsa/Front_Center.wav` 可加载、volume 读写在 0.5 附近成立;播放/停止属设置类未在测试执行。
- 视频画面渲染路线:**libyue 的 Image 没有裸像素构造入口**(查证 vendor/libyue/include/nativeui/gfx/image.h:构造只有 Image(NativeImage, scale_factor) / Image(FilePath) / Image(Buffer, scale_factor),其中 Buffer 只吃 PNG/JPEG 编码),Canvas/Painter 也无像素写接口。故视频帧走「帧源回调 → pngr_encode_rgba 内存 PNG 编码 → Image::new_from_png 解码 → draw_image 铺满」。PNG 编码为纯 MoonBit(签名/IHDR/IDAT/IEND + CRC32 + Adler32 + zlib stored 块,CR 表与累计全程 Int64 运算——MoonBit Int 的 >> 是算术右移,反射表需要逻辑右移,Int64 非负值的 >> 即 32 位逻辑右移)。
- **PTREF**:headless 测试环境(moon test)里 Image::new_from_png / new_from_file 一律返回空图——无 GUI 上下文(GTK 未初始化)时 libyue 解码恒失败,实测本机真实 PNG(`/usr/share/icons/hicolor/48x48/apps/*.png`)同样 is_empty=true。因此 PNG 编码器的 wbtest 全部为字节级自校验(魔数/IHDR 字段/IDAT stored 块数/总长自洽/adler 尾部),Image 真机解码验证改由 systemprobe 示例承担。
- 视频组件与解码器解耦:VideoFrameSource 回调(帧号→RGBA)注入,moonav1(纯 MoonBit AV1 解码器,mooncakes)作为下一批帧源实现接入;H.264 需 ffmpeg,暂无 MoonBit 绑定,留待需要。
- 帧推进用 @yue.set_timer(无取消句柄,句柄持 Ref 开关,停止后回调返回 false 注销,复用 charts_effectscatter 的 EffAnim 模式);set_progress/媒体轮询同款模式。

#### 媒体状态监视(MPRIS 轮询增量)与通知进度(正文字符条)

- 环境:Ubuntu 24.04 + XFCE + PipeWire(pipewire-pulse)。MPRIS 的 org.freedesktop.DBus.PropertiesChanged 信号可订阅,但订阅需要常驻读循环,与本库「同步请求-回复 socket 事务 + set_timer」的调用模型不兼容(通用 D-Bus 层 gdbus_call 是同步往返,无异步读线程)。故 media_watch_status 走轮询增量:默认 1000ms 读一次 PlaybackStatus + Metadata,播放态 / 标题 / 艺术家 / 专辑任一变化即 on_change;首轮只建基线不触发;查询失败(总线错误 / playerctld 掉线)的轮次静默跳过不影响后续。
- 目标解析:player 参数为空时每轮重试解析首个播放器实例(media_players 失败即跳过本轮),实例出现后锁定;播放中切换播放器不会自动跟随,使用文档已写明。
- 停止语义:set_timer 无取消句柄(只能让回调返回 false),句柄持 Ref[Bool],media_watch_stop 置 false 后下一帧注销,不可恢复——复用 charts_effectscatter 的 EffAnim 同一模式。已知取舍:on_change 回调抛异常会中断该定时器(无 try/catch 保护是 MoonBit unused_try 检查的取舍),文档已注明。
- 真机冒烟:本机无 MPRIS 播放器,watch 启动后立即 stop,on_change 触发 0 次且全程无异常(media_wbtest.mbt 冒烟用例,12/12 通过)。
- 通知进度:freedesktop 通知协议无进度字段(Windows / macOS 原生进度呈现也各自为政),跨平台一致做法是正文内字符条 + 百分比。notification_progress_text 把 percent 钳到 [0,100],NaN 经 percent!=percent 检测按 0 处理,width<=0 只给百分比,格数四舍五入(+0.5 后 to_int);Notification::set_progress 正文=原文字 + 换行 + 进度行。

#### Firefox places.sqlite(纯读取,非 WAL 合并)

- places.sqlite 常处 WAL 模式:最新浏览记录还在 places.sqlite-wal / -shm 里,主库文件是旧快照。当前实现只把主库文件字节交给 moonsqlitefile 的 `open_database`,**尚未 WAL 合并,checkpoint 进主库的最新记录读不到**——这是已知边界,文档须写明「读数是读入时刻的主库快照」。补法(未做):moonsqlitefile 另有 `open_wal_database` 可接,需同时把 -wal 文件交给同一 Database。
- 表与列:`moz_places` 是唯一需要的表,取列 `url`(TEXT,主键为 id 但行解析不依赖)、`title`(TEXT,可为 NULL)、`last_visit_date`(INTEGER,**Unix 纪元微秒**——与 Chrome 的 1601 微秒不同源,ffx_time_to_unix_us 换算毫秒 = us/1000)、`hidden`(INTEGER,非 0 的是书签/收藏条目须滤除,口径同 Chrome)。
- 行解析按列序取值但**类型不做假设**:url 可能是 Blob(SQLite 动态类型,title/url 理论上都可能是 BLOB 存储),BhValue 各分支都要有兜底(ffx_parse_places_row 对非文本值返回 None 跳过该行)。
- profile 定位:`~/.mozilla/firefox/profiles.ini` 取 `Path=` 目录名(分节 [Install*]/[Profile*] 都可能有 Path,全部收),缺失时回退固定候选名(default / default-release / default-esr / default-nightly / dev-edition-default)——**随机前缀命名的 profile 目录(如 `a1b2c3d4.default-release`)只有 profiles.ini 收得到**,本包无目录枚举原语时这是硬边界(fsx_list_dir 落地后可扫目录补齐)。
- 条目类型复用 browser_history 的 `HistoryItem`(字段结构与 Chrome 历史完全一致),排序 / 截断 / 取列也复用 bh_sort_history / bh_take / bh_value_text / bh_value_int,不重造一套。
- 多 profile 聚合口径与 Chrome 侧一致:同一 url 在不同 profile 各出现一次,不去重(去重反而掩盖「多账号分别在两个 profile」的事实)。

### 系统信息(si_machine / memory / uptime)与系统级安全边界

- /sys/class/dmi/id/product_serial 多数发行版仅 root 可读,读不到给 `Err` 带路径,不用空串糊弄;/proc/meminfo 单位恒 kB,MemAvailable 内核 ≥3.14 才有,缺失回退 MemFree;uptime 是浮点秒直接返回。
- 传感器(iio-sensor-proxy)取值前必须 ClaimLight/ReleaseLight,不点灯的读数停在旧值;AccelerometerOrientation 的类型是字符串而非枚举整数。

### 显示协议

- X11 ✅ 主链路;Wayland 未支持,验证 GUI 行为用 X11 会话(托盘 / 快捷键已按会话守卫)。
- 用户空闲秒数走 X Screen Saver Extension(XSS)的 XScreenSaverQueryInfo,运行期 dlopen("libXss.so.1"/"libXss.so") 而非构建期链接:规避 libxss-dev 进分发链(预构建静态库随 mooncakes 分发,多一个动态依赖在消费端未必装);XScreenSaverInfo 结构极简,shim 里手写镜像结构体(idle 毫秒字段偏移 24),加载失败与无 X 同路径返回 Unsupported。
- XWayland 会话输入事件不进 X 服务端,XSS idle 读数虚高(用户刚动过也可能读到小时级):显式探测 WAYLAND_DISPLAY 置位即返回 Unsupported,给错数不如不给;env -u DISPLAY(无 X 会话)同样 Unsupported,均不崩。数值对照实测(Ubuntu 24.04 XFCE X11):idle_seconds 与 xprintidle 同刻双读差 17ms(判据 ±2s),xdotool 模拟鼠标移动后 0.317s vs xprintidle 320ms。
- 锁屏不算输入:XSS 的 idle 在锁屏期间持续增长(锁屏器不上报输入),「用户空闲」与「屏幕锁定」是正交维度,勿用 idle 阈值近似锁屏判定(锁屏事件走 logind,另批落地)。
- 空闲读数的演示交互:点击本身是输入事件,会重置 XSS 空闲计数——「点按钮读当前空闲」的演示自相矛盾(读到的恒为 0.x 秒;命令行探针/xdotool 外部读数测不出此交互矛盾)。正确形态是开关开启后定时刷新(每秒读一次),开关关闭定时器下一拍自行停止(libyue 定时器无取消 id,回调查开关状态自杀)。

### GTK 相关

- Table 放进 Notebook 页签会在尺寸测量时段错误(negative allocation):放普通容器或独立窗口。
- 内容型控件(Group / Scroll)继承 View 而非 Container:挂内容用 `SetContentView`,`AddChild` 会被类型校验拒绝。
- 上游 NUContainer 缺陷(补丁 `patch_linux_container_events`):①事件窗口 map 即 raise,截走子原生控件命中(页签点不动、滚轮失效)→ 改 `gdk_window_show_unraised`;②容器 preferred 尺寸硬编码 0、Scroll 的 size_request 为 0×0 → 宽度随视口、高度取内容 yoga 自然高度。不要向 GTK 报告 yoga 动态自然尺寸:allocate 会污染 yoga 状态,requisition 震荡不收敛。
- `UpdateChildBounds` 开头的可见性守卫会错过 GTK 首次 size-allocate(发生在 map 之前):布局计算须无条件执行。
- `Slider::SetValue` 对相同值也置 ignore 标记,吞掉用户首个回调:仅值变化才设标记。
- `ProgressBar::SetValue` 在 Linux 与 Windows 端语义均为 0..100,yue 层统一 0..1,换算分支须覆盖两平台。
- `View::GetBoundsInScreen` 在 Scroll / 嵌套容器下坐标叠错(补丁 `patch_linux_view_bounds_in_screen`):GTK 屏幕坐标必须「客户区原点(`gdk_window_get_origin`)+ 客户区内偏移(`gtk_widget_translate_coordinates`)」;`gtk_window_get_position` 含标题栏装饰,与 translate 混用必差一个装饰尺寸。
- 表格 Checkbox 列指示器随行高缩放(XFCE 主题):对 Checkbox 列显式 `indicator-size=16`,renderer 高度限 20。
- 拖出数据须用 `Data(std::vector<base::FilePath>)` 构造(string 构造会被静默降级为 Text);相对路径先绝对化(`g_filename_to_uri` 不收相对路径)。
- 拖拽预览图 hotspot 上游写死 (0,0),补丁改图片中心对齐光标(`patch_linux_drag_icon_hotspot`)。
- 拖放能否接收由 drag-motion(`handle_drag_update`)决定,`handle_drag_enter` 只是进入通知;注册数据类型须补 Image(从图片查看器 / 浏览器拖入的是图片内容,不是文件路径)。
- libyue 的 `Entry::SetText` 会吞掉 `on_text_change`:GTK 侧用 `is-editing` 对象数据守卫,编程式设置期间 `changed` 信号被过滤(防回环),程序化清空 / 置文本后可见文本变了但使用方拿不到回调——`input_t` 的清空 ✕ 曾因此「文本没了、筛选列表不刷新」。修复:清空处理里显式补调一次 `on_input("")`。凡编程式改 Entry / TextEdit 文本后又依赖回调的路径,都要手动补回调。
- 拖出发起:同步调 `gtk_drag_begin` 会使 GTK 拖拽状态机不一致(嵌套 gtk_main 不退出、只能拖一次),须推迟到事件队列排空、以 press 事件发起并回填 drag_context;drag-failed 须防御性收尾(fork mbt.12)。
- 浏览器页(WebKitGTK)创建即 abort「Could not create GBM EGL display: EGL_NOT_INITIALIZED. Aborting...」:WebKitGTK 2.5x 的 DRMDeviceManager 在创建 WebView 时初始化主 DRM 设备,GBM EGL 拿不到就 RELEASE_ASSERT 直接杀进程。NVIDIA 专有驱动未装 `libnvidia-egl-gbm` 时 GLVND 只有 X11 后端(`10_nvidia.json` 不含 GBM),card1 / renderD128 都拿不到 display(实测 `eglGetPlatformDisplay(GBM)` 返回 NULL;注意进程内独立探测与 WebKit 实际选路不一致——进程内 renderD128 探测竟能初始化成功而 WebKit 仍炸,勿用探测结果做决策)。showcase 首屏挂 Browser,必炸。库层修复:shim 的 app_init(Linux)统一 `setenv("WEBKIT_DISABLE_DMABUF_RENDERER","1",0)`(overwrite=0,用户显式设置优先),WebKit 退传统渲染路径不再崩,浏览器页功能不受影响(仅网页内容少一层 GPU 加速,界面 cairo 自绘无关);实测裸跑 showcase 正常起窗、存活、零 abort。系统层根治:装 `libnvidia-egl-gbm`(NVIDIA GBM EGL 后端),装后可自行设 `WEBKIT_DISABLE_DMABUF_RENDERER=0` 恢复硬件路径。工程注意:改 shim 后 moon 不必然重链(exe 不在其依赖图),须 `moon clean` 或删 exe 强制重链,`nm exe | grep 新符号` 确认。
- overlay 滚动条的默认语义要靠进程环境保底:环境变量 `GTK_OVERLAY_SCROLLING` 在 GtkSettings 里优先级高于 gsettings(发行版脚本/用户全局导出 `=0` 强制经典滚动条是常见做法),GTK 每次创建 ScrolledWindow 都实时读进程环境——仅在主题初始化时写 `gtk-overlay-scrolling` GtkSettings 属性压不过环境变量路径。app_init(Linux)在 gtk_init 前 `setenv("GTK_OVERLAY_SCROLLING","1",1)`(overwrite=1:库默认语义与 set_overlay_scrollbar(true) 压过全局偏好;调用方对单个滚动区显式 false 仍走 per-widget API 生效),对装了同类脚本的最终用户机器免疫;后置的 GtkSettings 写入保留作兜底。
- **惰性挂载后滚动范围停在骨架高度(滚不动页第二根因,探针二分矩阵实证)**:GTK 下 ScrolledWindow 的滚动范围不来自内容测量——nativeui 的 nu_container 对 GTK preferred 恒报 0(不走 GTK 布局系统),viewport 的 adjustment upper 全靠 fork `Scroll::PlatformSetContentView` 在 **set_content 时刻**对内容自然高做的一次性快照(写成 size request);且重挂同内容时该函数先读旧快照(非 -1)即跳过重算、remove 清掉后 add 又写回旧值——内容在 set_content 之后才挂入(惰性挂载)或明显长高时,滚动范围永停在骨架高度,表现为「内容明明超高却滚不动、滚轮无声」。showcase 全部 111 段均为惰性挂载,图标库长段(9 行图标墙)最先暴露,实为全页共性。探针四列二分定案:常驻文本/图标墙 max=428/518(能滚)、惰性后挂文本/图标墙 max=0(holder 实测 1120/1210、GetPreferredSize 1164/1254 均正确)——与内容类型无关,纯挂载时序;重 set_content 无效(旧快照短路),显式 set_content_size 大值立即生效(adjustment 链路通,锁定 size request 快照不更新)。修复:shim 增 `yue_mbt_scroll_refresh_content_size`(Linux 直写 `gtk_widget_set_size_request(宽保持现值, 高=Container::GetPreferredSize() 即时跑 yoga)`,win/mac 空操作——Windows 的 ScrollImpl::Layout 本就每轮重查内容自然尺寸、macOS 由 documentView frame 决定范围,均无快照问题),yue 层 `Scroll::refresh_content_size()`;惰性挂载方在挂载完成后调用(showcase section_body 已接)。端到端探针:切页/切段/二轮显隐/切回后 max_y 恒为 内容高−视口(598=1290−692)精确恢复、视口变化亦动态正确。与「滚动范围跨轴 bug」(读侧)互补,本条是写侧,两修都在 shim 层。回归工具:`moon run examples/probe-iconscroll`(端到端四时序采样,长段 max_y 应恒 >0)。同一快照机制也咬**非惰性**场景:挂载后 `set_text` 长高(systemprobe 系统能力报告,几十行文本)与挂载后 `mount_into` 动态挂入新子树(视频播放器挂进占位容器)同样不更新滚动范围——表现为「读取结果出来后底部被截/滚不动、播放器挂载后滚不到底」。挂载方在内容变化完成后调 `refresh_content_size()` 即恢复;systemprobe 多页化重构的页面壳把刷新闭包注入正文构建函数,报告 set_text、播放器挂载、命令预览文本三处接上(2026-10 实测)。
- **报告标签 set_text 后不长高(裁剪,滚动范围快照之外的第二半,2026-10 用户真机反馈+探针对照实证)**:systemprobe 系统能力页点「读取系统能力」,几十行报告只显示前 1-2 行(用户截图:音量节只剩 sink 行,「音量: 45% 静音: 否」及其后全部不可见)。根因:GTK 标签(nu_label)的 yoga 高度只在挂载时测量一次(占位文本的高度),`Label::SetText` 只改 pango 文本、不标记 yoga 脏——新文本按旧高度裁剪;`refresh_content_size()` 只把容器**现有的**首选高度写给 GTK viewport,救不了标签自身高度(它修的是上一条的滚动范围那半)。探针对照(同页面壳结构 scroll→vbox→长占位 label):仅 set_text+refresh,16 行报告只渲染第 1 行;set_text 后加 `set_visible(false)`→`set_visible(true)` 再 refresh,16 行全文渲染。显隐切换生效是因 shim 的 `yue_mbt_view_set_visible` 内部走根级 `Layout()` 重算(三平台同代码、无平台分支),迫使 yoga 重新测量标签;显隐在同一拍内完成,无可见闪烁。修复:systemprobe 共享层增 `report_set(label, text, refresh)`(set_text + 显隐切换 + refresh),系统能力 / 命令预览 / 视频播放三页的全部报告写入点改走它。验证:真机点击「读取系统能力」,报告全文(音量 45% / 亮度 / 浏览器历史 / 下载 / VS Code / 二进制查找六节)完整渲染,点击前后截图差异 62979 像素;`moon check` 零警告 + `moon test` 657 全绿。教训:**GTK 标签的「长高」与「滚动范围」是两件事——前者要显隐切换(或等价重排)迫使 yoga 重测,后者才归 refresh_content_size**;演示页的动态长报告一律走 report_set,勿只调 refresh。
- **报告标签自然高的三条路全都不可信(上条「显隐切换即好」的深化,动态内容超视口时才暴露,2026-10 用户反馈+探针+DBus 双旁证)**:上条修复(显隐切换迫使 yoga 重测)只治了半截——内容不超视口时(16 行报告 < 视口)看似全好;内容超视口后仍滚不动、且标签被裁(40 行只显示 19 行),用户反馈「report 更新后调了刷新但没有滚动条」。深挖三层根因:①GTK 标签的自然高由 yoga `MeasureLabel` → `AttributedText::GetBoundsFor` 量,后者 `pango_layout_set_height(text_, size.height() * PANGO_SCALE)` **不防 NaN**——yoga 传未定义高度(GetPreferredSize 的 NaN 测量)时 NaN→int 为垃圾值,pango 把整个布局按**一行**量(shim 临时打印实测 preferred_h=92,即按钮+一行占位);②视口的确定高度(382)沿 holder→vbox 向下传导,MeasureLabel 的 AT_MOST 模式把文本裁到 341(40 行只分 19 行)——内容永不超过视口;③`refresh_content_size` 把 ①的错误值(92)写给 viewport,adjustment upper 不动 → `get_max_scroll_position_y` 恒 0。机制旁证:同探针 `set_content_size(600,1000)` 后下一个 tick `max=618`(=1000−382),证明 adjustment 链路本身是通的、refresh 的写入值才是祸首。修复(纯 MoonBit 侧,不动 shim/fork):yue 新增 `measure_text_height(text, role?, width?)`(同角色字体的 AttributedText 探针 + 大宽高测量,绕开 NaN 与 AT_MOST 两坑);`report_set` 改序为 set_text → 量自然高 → `set_style(label,"height",h+2)` **显式高度** → 显隐切换(根级重排)→ refresh。显式高度后 yoga 不再调用测量函数,两坑同时绕开。验证:探针(同页面壳结构,40 行报告)修复前 label_h=341/max=0,修复后 label_h=699(全文高)、body_h=773、**max=391(=773−382)**、滚轮 5 击 pos=263,截屏确认 40 行全文渲染且滚动到位。边界:显式高度在窗口 resize 后不重算(宽度变→折行变→高度 stale),演示页可接受,后续可在 on_size_changed 重设。教训:**GTK 标签的「自然高」三条路都不可信——yoga 重测遇未定义高度按一行量、遇视口确定高度按裁断量、挂载时量的是占位文本;运行期动态长文本一律「AttributedText 同字体量 + 显式设定高度」,勿把自然高交给任何自动路径**。
- **滚动范围跨轴 bug(滚不动页的根因,探针逐位实证)**:fork 的 Linux ScrollImpl::GetMaximumScrollPosition 把**视口宽度**当垂直 page_size 用——实测 `max_y = 内容自然高 − 视口宽`(窗口 900×600 时:纯自绘行块内容 1064→maxy 164、图表+行块 1088→188、纯标签 1160→260,全部精确命中),水平轴对称错。后果:程序化滚动行程只剩真实量的零头、悬浮 thumb 不浮现(库判定 maxy≤0.5 隐藏)。**初始可见与隐藏后显示同样错**(一度误判为隐藏挂载的测量问题,常驻对照组同值推翻;期间试过的 queue_resize/update_layout 补测均无效——GTK 测量本来就对,错的是 nativeui 的读数)。修复:shim 的 `yue_mbt_scroll_get_max_position_x/y` 在 Linux 改从 `gtk_scrolled_window_get_h/vadjustment` 直读 `upper − page_size`(其余平台仍直通 nativeui),修后 1160−600=560 逐位正确,sysmonitor 右栏滚轮实测生效(前后截图差异 5871 像素)。
- hover 组(hover_group)的判定不能依赖容器 enter/leave:GTK 的指针事件不冒泡,发给最深命中的 GdkWindow 就终结,子容器(NUContainer)/原生控件(Entry 等)的事件窗口会**独占**指针事件,祖先容器收不到 enter(sysmonitor 卡片能收 enter 是因为子件是无窗口的 label;子件一旦是容器/原生控件就断流)——「事件透传」需改 fork 上游(每视图事件广播祖先链)或平台全局钩子(XI2/WH_MOUSE),侵入与维护都重,不走。可行机制=指针位置轮询:**全部组共享一个全局 100ms 定时器(set_timeout 链,无组时完全停转),每 tick 一次指针查询 + 每组一次屏幕矩形比对,均微秒级**;cursor_screen_x/y 与 get_bounds_in_screen 同为屏幕根坐标、多屏拼接含负值一致(探针逐位验证)。enter 仅作命中加速、离场全靠轮询。可见背景必须 on_draw 自绘(set_background_color 与 backgroundColor 样式对无 draw 的容器均不可靠——主题 CSS 与子控件窗口都会压掉;悬停/常态底色直接在组容器 draw 里画,透明子区域自然透出)。实测:子控件(输入框)悬停整卡变 fill_hover(239,241,243)精确命中、移出复原。
- 自绘悬浮滚动条(overlay_scroll)先因跨轴 bug 降级为显式选用组件、后经真机验收捡回 Windows 形态:曾作 declarative `scroll()` 默认形态(为 Windows 经典条统一三平台观感),但 thumb 依赖 maxy/on_size_changed 链,叠加跨轴 bug 后形态不稳,一度回退平台原生滚动条;跨轴修复后经真机验收单独捡回——Windows 上 `scroll()` 在 overlay=true 且未显式 policy 时套 host 容器走 attach_overlay_thumb 自绘细条,非 Windows 与显式 policy 路径仍走平台原生条(overlay=true 请求悬浮样式,Linux 由环境变量保底、Windows 无悬浮对应物);overlay_scroll 组件与 Windows 侧页面滚动同走此路径。
- 系统主色调读取(GTK3 无强调色 API,`yue_mbt_system_accent` 三级递进):①GNOME 47+ 的 GSettings `org.gnome.desktop.interface`/`accent-color`——schema 存在但键不存在时(如 Ubuntu 24.04 的 gsettings-desktop-schemas)`g_settings_get_string` 直接 abort 而非返回空,必须先 `g_settings_schema_has_key` 探测(本机探针实测 abort);②当前主题 CSS 的 `@define-color theme_selected_bg_color`:GTK 各主题把主色统一表达为选中底色,按 `~/.themes` → `$XDG_DATA_HOME/themes` → `$XDG_DATA_DIRS/themes` → `/usr/share/themes` 找 `gtk-3.0/{gtk,gtk-contained,gtk-dark}.css`,深浅偏好决定先解析哪个(Orchis 系 gtk.css 是浅色主色、gtk-dark.css 是深色变体);③都取不到返回空。验证:探针程序(Ubuntu 24.04 + XFCE + Orchis-Teal-Light-Compact)返回 `#009688`,与主题 CSS 定义逐位一致;XFCE 无强调色设置,靠②命中主题主色。
- 容器级 hover 高亮(on_mouse_enter/leave 切底色)遇子控件必闪烁:GTK 的 enter/leave 按**原生窗口边界**派发,进子窗口即视为离开父窗口;libyue 有补偿(responder_gtk.cc `OnMouseEvent`:leave 延迟一拍、子 enter 取消 pending,仅 GTK),但有两洞——①子控件没连任何鼠标 handler 时 `PlatformInstallMouseMoveEvents` 未执行、无 enter 掩码,永远发不出 enter 去取消,pending leave 到点照发(卡片里 label / 图标一带);②空容器(如自绘迷你曲线画布)不满足「Container 且有子节点才延迟 leave」,父 leave 立即触发。实测 sysmonitor 左栏资源卡:鼠标在卡内每跨过一个子控件 hover 底色灭一次。规避:自绘容器的悬停反馈只用 cursor(手型)+ 常驻选中态(描边/浅底),不依赖 enter/leave;确需 hover 类效果须单画布自绘整卡(表格行同款)或改库层事件派发。另:悬停光标也按原生窗口生效,只设在容器上盖不住有独立窗口的子控件(hbox 行 / 自绘画布),须逐子控件 SetCursor(NUSetCursor 对无窗口控件为安全空操作;一个 nu::Cursor 可经 scoped_refptr 被多视图共享,复用同一实例即可)。透传通用化:`cursor_group` 组件与 hover_group 共用同一全局轮询拍——指针落在组 bounds 内时经 shim `yue_mbt_view_set_cursor_deep` 对组根+全部子孙递归 SetCursor,离开恢复 Default;恢复的是默认而非子件原光标(库不提供读回,组内子件需保留自身光标时不要套组)。
- **运行期改布局样式不触发重排(splitter 拖不动的根因,探针 8 场景定性)**:GTK 上挂载后用 `SetStyleProperty` 改任何布局属性(`width` / `flexbasis` 实测)都不落地——`update_layout` 根调用、叶子调用、纯 set_style 等自然布局周期(600ms 后读 bounds)全部无效;初始挂载时的样式值正常(首次全链 size-allocate 会读到)。Windows 上运行期 flexbasis 生效(5f272b4 合成拖拽验证过),平台差异,跨平台组件勿假设样式运行期可写。附带发现:Scroll 内初始 flexbasis 也不落地(首栏掉到 minwidth),width 正常。修复:shim 补 `yue_mbt_view_set_bounds`(直通 `View::SetBounds`)+ MoonBit 侧 `set_view_bounds` 泛型函数;splitter 拖动与初始比例改「set_bounds 直写三件几何 + 首栏 width/height 样式双写」——直写即时生效,样式值供窗口 resize 全链重排时按最后宽度接管。验证:examples/probe-splitter 探针(留仓)两阶段对照——样式路径 8 场景全不生效、set_bounds 6 场景全精确生效(直挂/Scroll 内 × 两档);131 测全过、showcase 冒烟存活,拖动手感真机复验。方法论:机制探针用定时器逐步改参数 + 隔拍 dump bounds,无需模拟鼠标即可定性布局链路。
- **Linux Label 是自绘控件 NULabel,不存在 GtkLabel 的 selectable 通道**:libyue 的 Label 在 GTK 侧是自定义 GtkWidget(nativeui/gtk/nu_label.cc,cairo 自绘文本,preferred 尺寸硬编码 0、无内建文本选择/复制),`gtk_label_set_selectable(GTK_LABEL(GetNative()))` 打在错误对象上静默无效(gtk_label_get_selectable 读回恒 0,运行时探针实证)。文本可选择的能力要走自绘组件方案(自绘命中计算+选中高亮+Ctrl+C 写剪贴板),不走原生通道。曾据 GetNative 是 GtkWidget 的假设加过 set_selectable API,验证失败后整批撤销(experiment/input_probe 为链路探针,留仓)。
- **on_wheel 的 Linux 挂接两处缺陷(0.5.10 修复):Window/View 兄弟类错位强转 + GtkWidget 默认无滚轮 mask**:shim 的 yue_mbt_view_on_wheel 曾用 CastToView(view)——Window 继承 Responder 而非 View,static_cast 错位后 View::GetNative() 读到错误偏移的成员,g_signal_connect 收到垃圾实例报 GLib-CRITICAL「instance of invalid non-instantiatable type」且信号从未挂上(运行时可见两条 CRITICAL 即此症);另 GtkWidget/GtkWindow 默认不含 GDK_SCROLL_MASK,不显式 gtk_widget_add_events 则 scroll-event 永不投递。修复:按 GetClassName 分派(Window 用 Window::GetNative,其余 `dynamic_cast<View*>` 取 GetNative),统一补 GDK_SCROLL_MASK|GDK_SMOOTH_SCROLL_MASK(NUContainer 的事件窗口 mask 走 nu_container_add_event_mask 叠加)。连带教训:**shim 里一切需要 GetNative() 的 view 级接口,对 Window 入参都不能走 CastToView**(Responder 级 Signal 的 Connect 因两类 Responder 头部同布局而碰巧安全,但这不可依赖)。
- **NUContainer(自绘容器)鼠标事件在作为 wgpu 渲染宿主时收不到,Window 级信号可靠(层进探针定案)**:把 wgpu surface present 到 Container 的 GdkWindow 后(甚至仅建 surface 不渲染),该容器的 on_mouse_down/move/wheel 全部收不到;层进实验(render/surface/one-frame 三模式)与无 wgpu 对照、Window 级对照交叉定位——X 层事件未断(Window 的 on_mouse_down 正常触发),断在 NUContainer 的 input-only 事件窗口命中/转发层,且该现象在无 wgpu 的空容器上对合成点击同样出现(XTEST 置顶复现,真机 hello-themed 的原生控件点击不受影响——原生 Button 有独立 GdkWindow)。**规避:渲染宿主场景的鼠标交互一律挂 Window 级信号**(客户区坐标系一致,容器铺满窗口时坐标等价);滚轮建议 window+host 双挂(window 级滚轮对 XTEST 合成事件未收到,真机行为待验,双挂谁通算谁、不同时触发)。诊断工具:three-native examples/input_diag(模式化层进,INPUT_DIAG_MODE=render/surface/frame)。根因(NUContainer 事件窗口与 wgpu surface 的交互)待深挖,列 fork 排查项。
- **主动 quit() 退出段错误(根因链 gdb 实锤,quit 前统一断信号根治)**:程序内 quit()(菜单退出/回调路径,不经 delete-event)时,窗口与控件被 shim 句柄注册表 ViewStore 持有、活到 exit 静态析构期才销毁;析构 ~Window→GTK 同步派发 focus-out,经 OnFocusOut→MoonBit 蹦床→schedule_paint→`Store<Responder>::get` 撞上析构中的 unordered_map→SIGSEGV(复现率约 1/20,窗口内有可聚焦 button_t 时;纯 label 不触发,gdb 下时序敏感不复现)。修复:shim `yue_mbt_quit` 在 MessageLoop::Quit 前遍历 ViewStore 断开全部视图的应用层信号(Responder 级 7 个+View 级 4 个+Window 的 on_focus/on_blur;on_close 故意不断——quit 常在其回调链内,Emit 已持 slots 拷贝不断亦安全),exit 期信号 Emit 空转,跨平台生效。实现注意:Window 继承自 Responder 而非 View(兄弟类),按 GetClassName 分支后各自 static_cast,不能从 View* 直转 Window*(编译期即拒)。验证:主动 quit 探针 ×50 零异常(修前 1/20 段错误)、无焦点探针 ×30 零异常、关窗路径(wmctrl -ic)×12 全 rc=0、135 测全过;复现器与探针留仓 experiment/exit_crash/。根治项(fork 加 is_quitting 标志在 OnFocusOut 入口短路)列 vendor 后续批次可选。
- **运行期 set_text 变长截断(标签宽度不跟随文本,探针 bounds 定量定案)**:bind / bind_label 及任何「订阅信号后 `Label::set_text` 换文本」的路径,文本比挂载时变长即被裁——长度超出挂载瞬间的 allocation 宽度,GTK 按控件 allocation 裁剪绘制,滞后到下一次真实窗口 resize 才恢复。三层根因:①libyue `Label::SetText` 只 `YGNodeMarkDirty` + `queue_draw`(纯重绘,不触发布局);②即便有人调 `Layout()`(yoga 全树重算、深层节点新值已算出),边界**下发**靠每层容器的 `UpdateChildBounds`,而根只对直接子 `SetBounds`;③GTK 对相同 allocation 的 `size_allocate` 短路——自身尺寸未变的中间容器(hbox 等)不下发,其子树里 measure 已变的 label 拿不到新宽度。libyue 的 `Container::Layout()` 非根分支本有「父层没下发就自己补」的自愈(dirty 链回溯逐层 UpdateChildBounds),但其向上传播在非 Container 父(Scroll)处截断,且 shim 的 `yue_mbt_view_layout` 原实现自己走到根调 `root->Layout()`,恰好绕开自愈分支。修复(shim):抽 `layout_root_down`——走根 `Layout()` 后,沿 **root→起点方向**对路径上每个 Container 逐层强制 `UpdateChildBounds()`(幂等下发,非 Linux 平台的可见性守卫照旧);`yue_mbt_view_refresh` 同步换用。**顺序必须外→内**:Scroll 的内容容器是独立 yoga 根(不挂大树,`IsRootYGNode` 以「无 YG 父」判定自成根),它的 `UpdateChildBounds` 才触发局部树重算;逐层下发若按内→外序,内层先执行拿到的是重算前的旧值,新测宽仍到不了目标——showcase 段内滚动架构(页面全在 Scroll 里)下首轮修复(内→外序)探针实测仍滞后一轮,翻序后即时同步。修复(MoonBit):`bind_label` 订阅回调、stat_card 数值(num)、form_item 校验文案(err)三处 `set_text` 后补 `update_layout`。验证:examples/probe-bind 探针(留仓,含 Scroll 包裹形态)定时短/长轮换 + 每轮 dump bounds——修复前长文本 bounds 停在 25px(恒截断)且滞后一轮;修复后 Scroll 内外均长 243 / 短 25 即时精确同步;65 测全过、showcase 冒烟存活。观测教训:①GTK 的 size_allocate 异步于当前回调,同步打印读到的永远是上一帧 allocation,勿据当帧值下结论;②改 shim 后 moon 不必然重链既有 exe(`.a` 不在其依赖图),须删 exe 强制重链,首日修复因此在 showcase 上「看似无效」实为旧 exe。

## Windows 10 / 11 ✅

首次本机全链路验证环境:Windows 10 19045 + VS BuildTools 2022(v17.14)+ SDK 10.0.26100,prepare.py 构建 → moon check / test / build → hello 启动冒烟全通过(此前 Windows 侧仅有 CI 验证,部分分支从未在真 Windows SDK 下编译过)。

### 工具链

- 需 VS Build Tools(VCTools 工作负载 + ATL 组件,`base/win/atl_throw.h` 依赖),在 x64 Native Tools Command Prompt 或 vcvars64 环境执行 moon / cmake;安装器 quiet / passive 模式须提权,否则 Exit 5007。
- 发行包资产名是 `libyue_{v}_win.zip` / `_mac.zip`(非 windows / darwin)。
- 大小写敏感卷上编译报 C1083 找不到 `webview2.h`:SDK 只给 `WebView2.h`(大写 W),prepare.py 解压后补小写别名;同一卷上 `shutil.copyfile` 的 samefile 判定不可靠,复制前先删目标。
- 平台专属代码的 include 与实现必须同批进平台分支:裸 `gtk/gtk.h`、或有使用守卫无定义守卫的函数,都会在另一平台编译端炸出 C1083 / C2065。
- 电源/会话消息(B6)首个真机编译撞出三处 SDK 事实:`PBT_APMRESUME` 宏不存在(唤醒只有必发的 `PBT_APMRESUMEAUTOMATIC` 与其后仅在用户输入唤醒时追加的 `PBT_APMRESUMESUSPEND`,后者是前者子集、两个都认会一次唤醒两次回调);SDK 10.0.26100 已把 `PBT_*` 常量收编进 winuser.h,根本没有独立 `pbt.h`,显式 include 它反而 C1083;`WTSRegisterSessionNotification` / `NOTIFY_FOR_THIS_SESSION` 声明在 `wtsapi32.h`,而 `WTS_SESSION_LOCK` 等消息码在 winuser.h——只缺 include 时报函数未声明、消息码不报错,易误判成「头文件没问题」。
- shim 平台差异:`dlfcn.h` 按 `__linux__` 守卫;MSVC 的 `M_PI` 需 `_USE_MATH_DEFINES`;`base::FilePath` 在 UNICODE 构建下是 `std::wstring`,统一经 `FromUTF8Unsafe / AsUTF8Unsafe` 进出;Windows 无 Popover、无 `SetOverlayScrollbar` / `Clipboard::Selection` / `Tray::SetTitle` 等,shim 降级空操作;`operator new/delete` 重定向 `malloc/free`(moon 运行时以 MOONBIT_ALLOCATOR=SYSTEM 编译);控件 HWND 须经 `dynamic_cast<nu::SubwinView*>(GetNative())->hwnd()` 取,`GetNative()` 本身不是 HWND。
- 原生子控件滚动后 HWND 不随容器移动(悬浮遮挡):`View::Layout()` 强制重摆,scroll 封装已挂 on_scroll,回调经 0ms 定时器推迟到布局完成后执行;输入框内阴影是 `WS_EX_CLIENTEDGE`,borderless 须清 STATICEDGE / CLIENTEDGE / WS_BORDER 三者;DatePicker 不显式给宽只显示年份;字形小图标跨平台不一致,组件内一律 Painter 矢量自绘。

### 链接参数(moon → cl / link)

- `cc-link-flags` 被原样拼进 cl 命令行,GNU 风格 `-L/-l` 报 D9002;正确做法是写链接输入(`build/yue_mbt.lib setupapi.lib …`),cl 把 .lib 位置参数转交 link,系统库由 LIB 环境变量解析。
- 路径分隔符必须正斜杠:反斜杠被 moon 参数解析吃掉,报 LNK1104。
- 官方 CMakeLists 系统库清单缺项,照抄报 144+ LNK2019;prepare.py 清单已补齐。
- CRT 必须与 moon 一致为静态 /MT:CMake 多配置生成器忽略 `CMAKE_BUILD_TYPE`,`cmake --build` 必须带 `--config Release`(prepare.py 已自动化),否则 LNK4098 + `__imp__*` 未解析。
- **exe 控制台黑框已由库内链接机制根治(新栈，2026-10-12 Windows 实测)**：`gui/win/win_gui.c` 里放 `#pragma comment(linker, "/SUBSYSTEM:WINDOWS")` 与 `/ENTRY:mainCRTStartup`，整体在 `#if defined(_WIN32) && defined(_MSC_VER)` 内；该文件与 `stub.c` 一起列在 `gui/win/moon.pkg` 的 `native-stub` 里。pragma 落进目标文件的 `.drectve` 段；moon 会把 native-stub 的 C 源直接编进 exe 构建（cl 命令行里能看到 `win_gui.c`），但链接器只认**实际被抽取**的归档成员的 `.drectve`——所以文件里另留 `wm_win_gui_marker`，由 `win/window.mbt` 的 `init_backend()` 以 `ignore(wm_win_gui_marker())` 引用：这个引用就是抽取锚点，而 `core/app.mbt` 的应用路径会调 `init_backend()`，故依赖方零配置拿到 GUI(2)。`/ENTRY:mainCRTStartup` 不能省：换子系统后默认入口点变成 `WinMainCRTStartup`，而 moon 产出的是控制台形态的 `main()`，不钉回去就报未解析的 `WinMain`。追加参数那条路走不通——用户 `link_flags` 拼在 `/link` 之前，cl 把 `/SUBSYSTEM` 类链接选项当编译选项直接丢弃（D9002）。因此 `release-bin.yml` 从「改写 PE 头兜底」改成**校验**：任一发布 exe 的 OptionalHeader.Subsystem 不是 2 就让 CI 红。实测：`moon build examples/{hello,hello-themed,showcase} --target native --release --strip` 三件套读回 Subsystem 全为 2、无需任何后处理；测试 exe 基本不受影响，只有代码路径走到 `init_backend()` 的那些变成 GUI(2)（实测 `core.whitebox_test.exe`、`ui.whitebox_test.exe`，其余仍 CONSOLE(3)），库门禁仍为 830 条 / 825 过（5 条红是既有的 dbus 会话总线与 `fsx_wbtest.mbt:109`）。GUI 子系统下 stdout 仅管道 / 重定向可见——测试框架正是用管道抓的。
- 换 `yue_mbt.lib` 后 `moon build` 报 no work to do:删 `_build` 下产物 exe 强制重链。
- prepare.py 模式切换坑(prebuilt↔source):`cmake -D` 只在显式传时覆盖 CMakeCache,不传则沿用残留值——旧 build 目录按 prebuilt 配置过(YUE_MBT_PREBUILT=ON)后切源码模式,configure 沿用 ON 导致 GLOB 到的源码一个不编,`yue_mbt.lib` 里只有 shim 一个 obj,最终链接 360 个符号全库缺失。修复:两种模式都显式传 ON/OFF。判定法:`lib /list build\yue_mbt.lib` 数 obj,全量源码构建应有 27 个(Windows)。
- prebuild 的 link_configs Windows 分支曾漏为 `yue/traybus` 单列一份:traybus 不依赖 yue(反向),按「依赖该包的目标」传播拿不到链接配置,`moon test` 链 traybus 测试 exe 时 12 个 `yue_mbt_sys_*` 符号 LNK2019;Linux/macOS 分支本就单列,Windows 补齐后三平台一致。

### manifest

- moon 的链接参数拼接行为(Windows 实测):按 main 包的依赖闭包把每个带 link_configs 的包的 flags 各拼一遍,并对 blackbox 测试目标把「被测包」的 flags 额外再拼一遍(被测包份 ×2)。`.lib` 重复列出无害,`manifest.res` 重复列出则同名 MANIFEST 资源进两次 → CVT1100 链接失败。早期「moon 新版给 exe 自带 MANIFEST 与我们的 res 冲突」的结论有误:mt 实测 moon 链的 exe 不含任何清单资源,冲突的「另一份」始终是重复传入的 res 自己(为 traybus 补 Windows 链接配置后,凡同时拼两份 flags 的目标即触发)。
- 通道探索结论:`/MANIFEST:EMBED` `/MANIFESTINPUT:` 等链接选项放进 link_flags 会被 cl 当编译选项丢弃(D9002,`/link` 之前的链接选项不传递);`#pragma comment(linker,"/manifestdependency")` 依赖链接器开 /MANIFEST,moon 的链接不开(moon 链的 exe 旁也无外部 .manifest 文件);prebuild 的 stdin 只有环境变量快照与 module_root,无目标/包信息,无法按目标输出差异化配置。
- 最终方案:manifest.res 不进默认 link_flags——开发 / 测试 / moon run 零配置。无清单的运行代价不止视觉退化:真机 Win10 19045 实测消息框点击按钮进程即崩——`TaskDialogIndirect` 只有 comctl32 v6 才按序号 345 导出,无清单加载的是 v5.82,其导出表序号 345 指向无关函数,libyue 按序号取址拿到非空垃圾指针直接调用即 UB(python ctypes 探针证实解析出非空地址;MoonBit 探针复刻同用法三连跑全干净退出,UB 非确定性,单次不复现不能下结论)。fork 修复(mbt.13):MessageBox 解析序号前先读 comctl32 的 DllGetVersion,主版本 ≥6 才调用;低于 v6 走经典 `MessageBoxW` 降级(图标按 TD_*_ICON 映射 MB_ICON*,≥2 个自定义按钮时 MB_OKCANCEL 且确定返回首个按钮响应,否则 MB_OK、响应为取消语义),弹窗可用性不受清单影响;OnClose 统一 PostTask 回 UI 线程(原空解析路径在后台线程直接回调也是跨线程隐患)。降级初版是「解析为空即直接关闭」,真机反馈表现为「点消息框没反应」,故补 MessageBoxW 降级;再版真机反馈「有图标按钮没文字」——TaskDialog 的主文字在 `pszMainInstruction`、仅补充文字在 `pszContent`,而 `SetText` 只写前者,降级须把两个字段拼接进 MessageBoxW 的单行文本。分发型构建设 `YUE_MBT_KEEP_MANIFEST=1`:res 随 yue 份传入,moon build 的 main 包对每份 flags 只拼一遍,恰好嵌入一份清单(Common-Controls v6 + supportedOS,mt 实读验证),v6 下有真 TaskDialog;全仓 `moon test` 勿设此开关(blackbox 被测包双拼必炸)。release-bin.yml 已按此配置。
- 环境变量改变 link_flags 后 moon 偶发沿用旧配置不重链:设 / 去变量后行为不变时,`moon clean`(或删 `_build` 下产物 exe)兜底。

### 运行期差异

- **2026-09-25 整树回退至 09-23 晚 f3ba8bf 版本(用户拍板)**:09-24 起为「表单页滚动原生子控件跟随/切页横线/tooltip 不显示」做的整条修复链(第一代 0ms 重摆 → fork 递归下钻 → 去 WS_CLIPCHILDREN → 平移传导 → 像素搬运 → 补画次序 → 切页性能合并,30+ 笔,含 fork ba479418/e373e60a/f4528cb8/cf308737 与浏览器包拆分、tooltip 自绘三代)经真机多轮复验为**净负担**——每轮在旧病未根治的同时引入新病(卡顿/蓝影/横线复发/重影/悬浮/撕裂),应用户要求整树回退,native 钉回 v0.15.6-mbt.12。核心教训:**原生 HWND 与自绘内容混排的「同步层」修复在真机连续失败——任何此类修复必须真机单点验证通过后才可叠加下一层,禁止多修复捆绑推进**;被回退各方案的全过程根因分析见 git 历史 09-24~09-25 各提交说明与 fork 仓库同期提交。回退后接受的已知状态:Windows 原生 tooltip 不显示(原生路径依赖 comctl32 v6 清单)、滚动中原生输入框靠 update_layout 兜底跟随、切页/滚动可见横线(WS_CLIPCHILDREN 固有)。**回退后按用户逐项挑选捡回**(同日):浏览器包拆分(含按库形态分化的链接修)、result 符号矢量自绘、cursor_group 光标组、网络状态 label() 与 Linux 初值派发两修、Windows live-resize 位图占位(纯 shim subclass)、Entry 滚轮放行(fork 7f57e87f,经 v0.15.6-mbt.18 预构建带入;fork 侧未选的 ba479418 已在 3f8e8935 撤除后再出包);未捡回:tooltip 自绘气泡、prepare 追打补丁机制与全部滚动/切页系修复。**悬浮滚动条 Windows 形态后续经真机验收捡回**(同日单独一批):只移植形态本体(host 包装+自绘 thumb+host 分支内 flex/basis 0),9-23 晚基线的 update_layout 跟随兜底原样保留、非 Windows 分支不动;原提交捆带的「删兜底+无条件 basis 0」(aab1a74 所治的塌陷病根)未随入。
- MoonBit 泛型方法的具体类型误传(FFI 句柄类参数):`MessageBox::run_for_window` 曾把 `Window` 结构体直接传给期望 `View` 句柄的 extern(C 侧 `void*` 收到 MoonBit 堆地址而非注册表 id),`CastTo<nu::Window>` 静默失败 → 消息框无父窗口 + 同步路径假死;判定法:MoonBit 生成的 C 原型第二个参数是 `struct ...Window*` 而非 `void*`。凡 FFI 声明带句柄参数,一律用 `View`(external)类型,具体控件 struct 在 MoonBit 侧 `.view()` 解出句柄再传;异步 `show_for_window` 与同步 `run_for_window` 必须同口径。另注:moon 的增量判断不可靠,改 shim/库后 `moon build` 可能报 up to date 不重链,须删 `_build` 下产物 exe 强制重链(否则探到的是旧库行为)。
- 显隐页切换后内容消失(tabs_t 等 set_visible 切换场景,真机实测):libyue win 的 `View::Layout()` 只向 `IsContainer()` 的父传播(`if (GetParent() && GetParent()->IsContainer())`),Scroll 不是 Container——挂在 Scroll 内容里的子树做显隐切换(set_visible → yoga display 切换)后,传播链在 Scroll 处中断,yoga 根永不重算,恢复显示的页拿 0 高尺寸;页内容无显式高度时被压成 padding 之和(实测页高 50→16,内容整块消失)。GTK 端由 gtk size-allocate 全量重排掩掉,Windows 独有。修复:shim 的 `yue_mbt_view_layout`(即 update_layout)改为沿父链遍历到根容器再 `Layout()`,tabs_t 的 `sel.subscribe` 在显隐翻转后补一次 `update_layout(outer)`;探针(页内容 on_draw 自证 + bounds 打印)验证每次切换绘制到位、页高稳定。注意:只对 root 的直接 flex 子场景不触发(根重算一直有),必须经 Scroll 的内容树才断。
- 显隐页切换消失·三层嵌套残余场景(showcase 结构:页容器 set_visible 切页 + scroll + section + tabs_t,真机仍复现):页签切换时,`Container::Layout` 的 dirty 自愈分支(view.cc 里自带 TODO 注释的那条)会用 display 切换中间态的 yoga 值分配外层容器——并列 flex:1 的页容器被按「scroll 内容测量中间态」分配成压缩高度(实测 210→56),且此后无法自救:自愈传播链断在 Scroll(非 Container),根级重算的 SetBounds 链又断在「尺寸未变的中间容器」(hbox 等尺寸相同 → ViewImpl::SizeAllocate 早退 → 不向下触发子级 UpdateChildBounds)。后果:WM_PAINT 的 dirty 被压缩的页容器裁成 24 高碎片,与页区域(74,278,512,50)不相交,`DrawChild` 的 `child_dirty.IsEmpty()` 整块跳过——on_draw 不触发、bounds 却正常。已试无效(均实测):根级重算 ×N、反转显隐顺序(先 true 后 false)、set_visible 内联根重算(shim 侧)、叶子层显隐(显隐只切页内容)、page_c 的 flexbasis 置 0(CSS flex:1 1 0 语义)。结论:根因在 libyue win 的 yoga 集成本身(dirty 自愈用过期布局 + Scroll 断链的双重断裂),yue/shim 层外部修补打不穿,需 fork 侧根治(备选方向:UpdateChildBounds 的分配前强制 YGNodeCalculateLayout,或 Scroll 内容测量避开中间态)。当前 20babb5 修复对「tabs_t 直接位于 scroll 内容」场景(无页容器层)完全有效,showcase 场景待 fork 侧方案。
- 滚动条形态:libyue 在 Windows 的滚动条是自绘经典样式(Scrollbar 类:轨道 + 箭头按钮 + 常驻占布局),`Scroll::SetOverlayScrollbar` 对 Windows 是空操作(头文件里 API 就被 `#if !defined(OS_WIN)` 排除)——GTK 的悬浮形态在 Windows 没有对应物。统一方案是 yue 层 `attach_overlay_thumb`:policy 置 Never 隐藏平台条,自绘 thumb 用 yoga absolute(right/top/bottom 静态样式)占满右缘全高,可见段在 on_draw 按 Ref 状态绘制——滚动更新只 schedule_paint 零 yoga 重排;浮现/渐隐用 clear_timeout 可取消的两级定时器(d9→73→隐藏),拖拽依赖按下后的隐式鼠标捕获(拖出仍收 move,见 splitter 条目的 WM_CAPTURECHANGED 适配),thumb 窄条上的滚轮经 on_wheel 手动转发给 Scroll。收口点:declarative `scroll()` 默认形态(Windows 且 overlay=true、未显式 policy)即套 host 容器走它(style 参数挪给 host,Scroll 在内撑满——thumb 的 absolute 定位以 host 为基准,直接挂页面容器会被 padding/margin 带偏);overlay_scroll 组件与 Windows 侧页面滚动同走此路径。Windows 分支保留 on_scroll→0ms 定时器强制重摆原生 HWND 的兜底。
- 系统强调色:`DwmGetColorizationColor` 取的是「窗口颜色化色」——强调色与系统基色的混合,默认配置下与设置页强调色有明显色偏(参照机 Win10 19045 实测返回黄绿 0xFFB7AC00,而设置页强调色为青 0xFF00B7C3);先读注册表 `HKCU\Software\Microsoft\Windows\DWM\AccentColor`(0xAABBGGRR,Win10 1803+ 写入),缺失 / 0 / 0xFFFFFFFF 才回退颜色化色,修复后探针实测 0xFF00B7C3 与设置页逐位一致。回退值的 alpha 位是「强度」非透明度,只取 RGB。
- GetSystemPowerStatus 语义损失(电量查询):ACLineStatus 255(未知)按非在线;BatteryFlag 128(无电池)/ 255(未知)均按无电池;BatteryLifeTime 语义随交直流漂移且常为 -1,统一不给剩余时间(Linux UPower 侧 State 1/4/5 都归"接着电源",两平台口径对齐)。另:满电接着电源时 BatteryFlag=High 不带 Charging 位(实测 percent=100 charging=false),「已充满仍接着电源」在 Windows 上表现为非充电态;电量本身无变化事件(仅电源插拔有),缓慢放充电要靠轮询兜底(showcase 系统页 30s set_timer + 插拔事件即时刷新,同一查询口径)。
- `AttributedText` 区间字体 / 颜色:上游 Windows 只支持全文(区间 CHECK 崩,GDI+ 无富文本),fork mbt.9 自建分段布局器(run 存储 / 流式折行 / 测量绘制同源),MoonBit 层降级守卫已删,三平台语义一致。坑:`Gdiplus::Font::GetHeight` 重载是 `(const Graphics*)`,传引用编不过。
- `Color::Get(Border)` 触发 NOTREACHED 返回垃圾色:shim 对 Border 用 `GetSysColor(COLOR_WINDOWFRAME)`。
- 自绘字体发虚:libyue GDI+ 画笔写死灰度抗锯齿,prepare.py 幂等补丁换 `TextRenderingHintClearTypeGridFit`。
- 系统通知:WinRT toast 按 AUMID 查 notifier,未设 AppUserModelID 时静默失败;shim 首次通知前自动设 AUMID 并写注册表 DisplayName。
- 浏览器优先 WebView2(loader / 运行时缺失自动回退 IE);WebView2 跟随系统代理,代理失效机器设 `LIBYUE_WEBVIEW2_ARGS=--no-proxy-server` 直连(prepare.py 补丁经环境变量注入 AdditionalBrowserArguments);demo:// 自定义协议在 WebView2 下无效(IE 路径可用)。
- win32 的 Group / Scroll 不按内容自增长:须显式高度;ScrollImpl 滚动范围只认 SetContentSize,prepare.py 补丁在未显式设置时向内容 yoga 树查自然尺寸。
- 键码与修饰键:Windows KeyboardCode 是 Win32 VK 值,events.mbt 入口已归一化到常量表;修饰键位 Windows 原生 Shift=2 / Ctrl=4 / Alt=8,shim `NormalizeModifiers` 补 OS_WIN 分支映射统一 1/2/4/8。
- 幽灵托盘:异常退出不跑 CRT 静态析构,图标残留;shim 装 atexit / SetConsoleCtrlHandler / SetUnhandledExceptionFilter / SIGABRT 四道钩子,按「属主窗口 + 图标 ID 区间」补发 NIM_DELETE;taskkill /F 式硬杀无法进程侧根除。托盘图标显示为空白先查资产(曾用 1×1 占位图)。
- Popover 替代实现(无边框 / 不抢焦点 / 置顶小窗):弹窗须补 `WS_EX_NOACTIVATE`(防点击弹层时抢焦点);嵌套滚动下 `GetBoundsInScreen` 有垃圾偏移,锚点坐标改取原生子控件 HWND 的 `GetWindowRect`;close 在 Windows 是销毁语义,复用弹层改 `SetVisible(false)`;点外收起挂 `WH_MOUSE_LL` 钩子,按下不在弹层矩形即 PostTask 收层;弹层背景不随主题,新增 `Popover::set_background_color` 全链路接入。libyue 的 SetVisible / IsVisible 在无 Activate 置顶窗场景不可靠,直接 Win32 `SetWindowPos` + `SW_SHOWNOACTIVATE`。
- autocomplete 键盘导航:Windows 分支在 Entry 挂 on_key_down(↑↓ 高亮 / 回车选中 / Esc 收起);单行 EDIT 无垂直居中样式,`entry_vcenter` 按字体行高收窄控件高度均分 margin;RichEdit 恒黑字不随主题,`Entry::set_colors`(EM_SETBKCOLOR + CHARFORMAT2)接入主题链路。
- 原生控件暗色:真 Win32 通用控件(RICHEDIT50W / SysListView32 / SysDateTimePick32 等)均不跟系统暗色;RichEdit 可经消息通道暗色化;Table 不可行(custom draw 自绘白底覆盖外部消息);正式方案 = 组件库全自绘,原生暗色列为已知边界。
- 命中测试与绘制层级方向相反:上游 `FindChildFromPoint` 正序遍历,后挂的全屏遮罩视觉在上、事件却穿透到先挂的容器(dialog 关不掉、点击穿遮罩)——fork mbt.6 改倒序遍历对齐绘制层级。凡「视觉在上层收不到事件」先查命中遍历方向。
- 滚轮被最外层 Scroll 直接消费不下发,嵌套滚动与自绘 canvas 收不到:prepare.py 补丁(`patch_win_wheel_dispatch`)按 FindChildFromPoint 下发光标下子视图;shim `yue_mbt_view_on_wheel` 补 Windows 分支,换算 WM_MOUSEWHEEL delta。
- 文字测宽与绘制不一致:`GetBoundsFor` 用 GenericDefault(带 overhang)、`DrawString` 用 GenericTypographic,手动 `x=(宽-测量宽)/2` 摆位必左偏;摆位一律用 `align=Center/End` 交给平台,测宽仅用于算容器宽度。
- splitter 两坑:Windows 端显式 `SetCapture` 会触发 `WM_CAPTURECHANGED` 拆掉隐式捕获(已持捕获须跳过);`flexbasis:"50%"` 百分比字符串仅 GTK 端解析,跨平台统一写像素。
- Entry 无限递归案例:非 Linux 分支两函数互调栈溢出,MSVC C4717 早已告警——「逻辑必死」类警告应按错误对待。GUI「无窗口」用 `Get-Process <name> | Select MainWindowHandle` 判定;MoonBit println 管道下全缓冲,进程被杀即丢,插桩用 stderr。
- mount_window 在 handle 回调执行后自动激活显示,消费方无需手动 activate。
- 平台信息 / 区域 / 缩放 / 剪贴板 / 定时器 / 全局快捷键 / 全局鼠标轮询 / 画布(GDI+)实测正常。
- 离屏 Canvas 在 Windows 不能早于 initialize 创建:`Canvas::new` 一句即 0xc0000005 访问违例(最小复现不含任何绘制调用)。根因:Canvas / DoubleBuffer / Painter 构造依赖 `nu::State`——GDI+(`GdiplusHolder`)、默认字体、NativeTheme 都随 State 建立,而 State 由 initialize() 创建;曾试在 canvas_new 里裸 `GdiplusStartup` 兜底仍崩(State 还有别的空解引用),正解是 `g_state` 为空时先走与 initialize 相同的 `yue_mbt_app_init()`。对照 Linux:cairo image surface 无 State 依赖,离屏几何无需 initialize 可跑(仅文本路径要 GTK 栈,见「自绘画布与图表渲染」);Windows 连几何都起不来,shim 兜底后三平台「离屏 Canvas 随处可用」语义一致。charts_wbtest 的离屏几何基准据此在 Windows 通过(17/17)。
- 平台无关函数误入平台分支的桩:wire 的 `'d'` 编解码走 `yue_mbt_sys_f64_to_bits/from_bits`(纯位重解释,memcpy 实现),实现却放在 OS_LINUX 分支、非 Linux 桩恒返回 0——Windows 上 3 个纯内存 wire 测试解码全 0 失败(wire 编解码测试不依赖总线,非 Linux 也跑)。移到平台分支外修复。判定法:桩清单逐个过「是否真平台专属」,纯计算 / 纯内存逻辑不进桩(与 macOS 小节「`#else` 兜底误吞 macOS」同族)。
- 单实例消息窗口是仓内首例自有 WNDPROC/窗口类代码(此前 grep 0 命中):类名由 app_id 派生(`moonbit_libyue_instance_<app_id 点换下划线>`),必须建在运行 libyue 主循环的主线程;WM_COPYDATA 由 SendMessage 同步派发到 WNDPROC(不走消息队列),收端 MessageLoop::PostTask 抛回主循环再触发 MoonBit 回调,避免在对方进程的 SendMessage 栈里执行应用代码。互斥体用 Local\ 会话命名空间免提升;同进程对同名二次 CreateMutexW 会命中 ERROR_ALREADY_EXISTS,以 static 句柄守卫做幂等。【待真机验证】消息窗口在 libyue 主循环下的实际派发、SetForegroundWindow 在前台互斥下的置前成功率、旧构建混跑时标题查找兜底路径。
- UI 线程 COM 套间必须按 STA 建立,否则文件对话框卡死/崩:公共文件对话框 `IFileDialog::Show` 要求 STA——UI 线程 COM 从未初始化时 `CoCreateInstance(CLSID_FileOpenDialog)` 直接失败(库内空指针解引用),被应用侧后置调用抢先初始化成 MTA(典型:旧版在 UI 线程调 `CoInitializeEx(MTA)` 的网络查询)时 `Show` 永久挂死,现象即「点打开/保存文件应用直接卡死」。修复:shim `yue_mbt_app_init` 建 State 后立即 `State::InitializeCOM()`(ScopedCOMInitializer STA + OleInitialize,幂等);此后 UI 线程上的 `CoInitializeEx(MTA)` 只会得到 `RPC_E_CHANGED_MODE`,本地 COM 对象不受影响。与「NLM 查询挪后台 MTA 线程」互补:后台线程的 COM 初始化是线程局部的,不替代 UI 线程自己的 STA。验证:真机点开/保存文件对话框正常弹出、选完路径回传。
- Windows 切主题无全局重绘,残留旧像素成"重影":GTK 端 `theme_apply` 有 CSS 重建 + 逐窗口同步重绘兜底,Windows 端原本只通知订阅主题的自绘视图,漏订阅区域(以及被隐藏/移走的原生子窗口背后的区域)留旧像素,鼠标划过触发局部失效才消失。修复:shim `yue_mbt_repaint_all` 补 Windows 分支——`EnumWindows` 过滤本进程可见、无属主的顶层窗口,`RedrawWindow(RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN)` 整体失效连带原生子窗口,只失效不同步绘制(WM_PAINT 交回消息循环);`theme_apply` 的 windows 分支调用它。验证:真机来回切深浅,头部/页面无残影。
- 零高度自绘视图整段静默不渲染(table_t 文字列消失):`ViewImpl::Invalidate` 对空尺寸提前返回,childless 且无高度样式的 on_draw 容器被 yoga 测高为 0 后永不绘制——table_t 的 CellText 单元格正是这种容器(文字经 on_draw 自绘、无子节点),现象为整列文字不可见而表头/斑马纹/复选框正常;GTK 端裁剪行为不同故未暴露(同函数族此前已踩过「GTK 小单元格路径填充不渲染」的反向坑)。修复:`cell_view` 给 CellText 容器补 `minHeight=row_height`。教训:自绘 on_draw 容器必须有非零尺寸来源(显式高或子内容),「无子节点 + 自动高」在 Windows 等于不画;离屏 Canvas 像素探针可先排除绘制链本身(AttributedText 带色在 Windows 画布上逐位正常)。
- GDI+ 混合模式仅 Normal/Copy 生效:`PainterWin::SetBlendMode` 只把 Copy 映射为 `CompositingModeSourceCopy`,其余全部落 `SourceOver`——GDI+ `Graphics` 只有这两种合成模式,Multiply/Screen/Difference/Xor 等静默无效。离屏像素探针实测:Multiply 交叉区 (128,128,255) 与 SourceOver 逐位一致(数学期望 #8028FF)。平台能力缺口,不修库(换 D2D 才有完整混合);showcase 画布演示在 Windows 回显「此平台仅 Normal 生效」,`docs` 中 `Image::write_to_file` 平台口径同步修正(Windows GDI+ 编码器 png/jpeg 可用、mac 发行包未编译恒失败)。
- 原生 Tab 添加首页即回调 `on_selected_page_change`(内部初始选中,非用户切换):回调登记先于加页时,挂载期会空触发(declarative `tab()` 曾因此让切换计数演示凭空起跳);登记挪到加页循环之后即避开。

### MoonBit 原生 GUI 栈 · Windows 构建基线(W0/W1,新栈 Windows 化首批)

- **环境**:Windows 10 19045 + VS BuildTools 2022(MSVC 14.44)+ SDK 10.0.26100,moon 0.1.20260920;新栈特性分支 `feature/yoga-mbt`。目的:新栈完成项(TODO.md 全部 `[x]`)逐项在 Windows 验证,Windows 地基(Win32 后端)先行。
- **moon native 在 Windows 开箱即用,不需要 vcvars**:普通 shell(Git Bash / CMD)直接 `moon test`,moon 自行定位 MSVC 工具链并编译链接(报错码是 cl/link 的 C2059/C1083、lib.exe 中文输出可佐证),与老栈时代「须在 Native Tools Command Prompt 执行」的记录不同——那条管的是老栈 prepare.py/cmake 链,新栈构建不适用。
- **workspace 任一成员的 prebuild 硬失败会挡死全部 moon 命令**:`modules/ffmpeg-mbt/prebuild.py` 缺 pkg-config 即非零退出,`moon.work` 五成员里任何包跑 check/test 都先过它;而主 `scripts/prebuild.py` 非 Linux 本就优雅降级(空 link_configs)。修复:ffmpeg prebuild 补「非 Linux 输出空 link_configs 且 exit 0」分支(Linux 行为不变),与主脚本同口径;ffmpeg 消费方(gui-media)本就是过渡期红点,不在新栈验证路径上。
- **非 Linux 占位桩的 GLib 类型在 MSVC 下语法错误**:`win/gtk_stub_portable.c` 用 `gint32` 作占位函数返回类型——该文件整体包在 `#if !defined(__linux__)` 里,Linux 上从不编译故从未暴露;MSVC 下 6 处 C2059(无 glib.h,`gint32` 未定义)。改 `int32_t`(ABI 同为 32 位整型,extern 原型不变)。教训:占位桩也要按「能在 Windows 真编译」的标准写,MSVC 是占位桩的第一位真实读者。
- **`chensuiyi/subproc` 的 C 桩用 POSIX `poll.h`,Windows 编译必炸**:`sys` 的 `procrun.mbt` 基于 @subproc(自己注释就写着「仅 Linux」),sys 与依赖它的 chart 包全被连坐编译失败。Windows 子进程层(spawn→限时回收→输出捕获)归 W14 用 CreateProcess 重做,替换 MoonBit 侧的 @subproc 依赖;在此之前 sys/chart 在 Windows 不可验证。
- **分包测试的连带编译问题 Windows 与 Linux 同款**:workspace 内 cd 进成员目录裸跑 `moon test` 会把主包红点一并编进来,须 `-p` 限定包/模块名(HANDOFF.md 已记,此处确认 Windows 一致)。
- **验证**(2026-10-11,本机):`moon check` 287 errors / 68 warnings 与 Linux 基线**逐字持平**;纯 MoonBit 包全绿——yoga-mbt 96/96、core 62/62、input 10/10、mdview 26/26、theme 7/8(挂的「控件高度基准」一条依赖 Pango 字体实测,占位文本后端必挂,归文本后端批)、icons 2/4(挂的两条是「真画出像素」绘制断言,归渲染后端批);ui 因 `TextMetrics::unwrap` 空值 panic(同归文本批)、sys/chart 因 subproc 编译失败(归 W14)。

### MoonBit 原生 GUI 栈 · Windows 窗口地基(W2,stub 合一 + Win32 后端)

- **架构定案:平台桩合并为单一 `win/stub.c` 三分支**——`_WIN32` 真 Win32 实现、`WM_STUB_GTK` 真 GTK 实现(prebuild 在 Linux 带 `-DWM_STUB_GTK` + pkg-config 头编进 `libyue_win_stub.a`)、其余平台占位;原先的 `gtk_stub.c`/`gtk_stub_portable.c` 两文件删除。合并的物理约束:moon 的 native-stub 会把 moon.pkg 里列的每个 .c 在**所有平台**各编一遍,而 GTK 头路径只有 prebuild 拿得到,所以装 GTK 的分支必须挂在「prebuild 独有的宏」下——Linux 上 native-stub 的那次编译(无宏)落不进任何分支,编出空 TU,避免与 .a 双定义;这正是原两文件结构的等价形态,只是收敛进一个文件。空 TU 在本链已验证可行(原 portable 文件在 Linux 就是空编)。
- **moon native-stub 在 Windows 直接可见 `windows.h`**(探针包实编译链接验证):moon 自行定位 MSVC 工具链并设好 SDK 包含路径,Win32 桩可以直接走 native-stub,无需 prebuild 代编;prebuild 的 Windows 分支只下发系统库链接参数(`user32.lib gdi32.lib imm32.lib advapi32.lib`,MSVC 位置参数口径)。
- **MSVC 的 `IDC_*` 光标宏默认走 ANSI 变体**:不定义 UNICODE 时 `IDC_ARROW` 是 `MAKEINTRESOURCEA` 形态(LPSTR),传给 `LoadCursorW` 的 `LPCWSTR` 形参报 C4133;桩文件顶部强制 `#define UNICODE`/`_UNICODE` 即全 W 化。
- **按键映射口径与 GDK 对齐**:字符面在 `WM_KEYDOWN` 里用 `ToUnicode` 直取(ASCII/Latin-1 原值、其余 `0x01000000|unicode`,与 `gdk_unicode_to_keyval` 一致,`keysym_to_text` 两条 Latin-1/UCS 路都能吃);**Ctrl 组合键要把 `VK_CONTROL` 从 `GetKeyboardState` 的状态副本里摘掉再换算**——带控制位会吐控制字符(`\x01`),内核的 Ctrl+A(判 `keysym=='a'`)就失效了,摘掉后与 GDK 的「keyval 取基准字符、修饰走 mods」同语义;AltGr(Ctrl+Alt)因此拿不到特殊字符,留 IME/后续批次。死键(`ToUnicode` 返回负)不推事件,组合由布局状态自然发生在下一个键上。Alt+F4 放回 `DefWindowProc` 生成 `WM_CLOSE`(与「窗口管理器请求关闭」同语义),其余系统键(F10 菜单/Alt+空格)自己吃掉。
- **贴屏无需换序**:`render` 的 Bitmap 就是 cairo ARGB32(小端字节 B,G,R,A 预乘),GDI 的 32bpp `BI_RGB` 顶底 DIB(负 biHeight)字节口径完全一致,`StretchDIBits` 直贴;present 只记地址 + `InvalidateRect`,真贴在 `WM_PAINT` 里(与 GTK 桩「draw 回调才贴」同口径,避开死窗口期)。`WM_ERASEBKGND` 返回 1 防闪。
- **循环配方**:等待用 `MsgWaitForMultipleObjectsEx(0,NULL,timeout,QS_ALLINPUT,MWMO_INPUTAVAILABLE)`(有未派发消息立即返回,负超时即 INFINITE);跨线程唤醒是 `HWND_MESSAGE` 仅消息窗口 + `PostMessageW(WM_APP+1)`;泵是 `PeekMessageW` 排空 + `DispatchMessageW`,**不做 TranslateMessage**(WM_CHAR 不消费,字符面在 WM_KEYDOWN 直取)。
- **槽位与创建时序**:`WM_SIZE` 在 `CreateWindowW` 期间就会到达,槽号必须经 `CREATESTRUCT.lpCreateParams` 在 `WM_CREATE` 里先行落位(`GWLP_USERDATA` 建完再设会丢掉首条 WM_SIZE);客户区口径用 `AdjustWindowRect` 把外框撑到客户区恰为 width×height。DPI 用 `SetProcessDpiAwarenessContext` per-monitor v2(经 GetProcAddress 取,老系统缺导出不断链),整栈物理像素,`WM_DPICHANGED` 按建议矩形重摆、WM_SIZE 记账。
- **验证**(2026-10-11,本机):`moon build examples/native-window` 全链链接成功;冒烟 `NATIVE-WINDOW-OK frames=45`(5s 定时退出,exit 0,45 帧上屏即 present→WM_PAINT→StretchDIBits 通);core.App 宿主形态用用完即删探针验 `WIN-SMOKE-OK`(App::new + 声明式挂载 + timer + 干净退出);core 62/62 复绿(测试不调 App::new,不会弹真窗),全仓 check 287/68 持平。band_h=0/0/0/0 属文本后端占位(W5)。

### WebView2 webview 桩与 ffmpeg Windows 真链接(平台批,2026-10-13)

- **WebView2 自定义 scheme 必须在 Environment 创建时预注册**:没经 `ICoreWebView2EnvironmentOptions4::SetCustomSchemeRegistrations` 注册的自定义 scheme,导航直接失败(真机实测失败码 9,换 8)。MoonBit 层 `webview_predeclare_schemes` 名单经新 extern 流到 C 桩全局名单,`wb_create` 传手写 `WbOptions`(四子接口嵌套 COM)由引擎在 Environment 创建时取名单。
- **COM propget/propput 手写实现少写 `self` 参数会在 x64 上静默写坏 vtable**:`get_bool(BOOL *value)` 按单参声明,引擎按 COM 约定传 `(self, &value)` 两参——x64 下第一参数 RCX=self 被当成 value,`*value = FALSE` 实际把对象首 8 字节(lpVtbl!)写成 0,之后任何对该接口的调用 = 调 NULL vtable = segfault。put_str/put_bool 同病(少读 this,x64 恰好不炸)。**C 无函数签名检查,vtable 指针赋值只有 C4113 警告**——每个手写 COM 方法的参数表都要逐个对着头文件数。
- **`GetCustomSchemeRegistrations` 返回的数组必须 `CoTaskMemAlloc`**:契约是调用方(loader)用 `CoTaskMemFree` 释放——把静态数组指针交出去,loader 对它 free 直接触发 `0xC0000374`(堆损坏),且崩溃点在引擎内部、get_regs 返回之后,栈上完全看不出与 registration 有关。排查用了 AddVectoredExceptionHandler(打印异常码/地址/所属模块)+ HeapWalk 全遍历堆校验(stderr 无缓冲,segfault 下 stdout 缓冲会丢)。
- **MSVC 默认按系统代码页(GBK)读无 BOM 的 UTF-8 源文件**(C4819):中文注释与 ffmpeg 头的 UTF-8 字节序列被 GBK 误读吞行——注释行末字节恰与换行组成 GBK 双字节时,下一行被并进注释,级联出几百条「非法存储类/未定义标识符」。修法:`stub-cc-flags` 加 `/utf-8`(ffmpeg-mbt 的 vendor 头同样中招,rational.h 也报 C4819)。
- **moon prebuild 的 `vars` + moon.pkg `${build.VAR}` 替换可用**(0.1.20260920 实测):prebuild 输出 `{"vars": {"FFMPEG_INC": "..."}, "link_configs": [...]}`,moon.pkg 写 `link: { "native": { "stub-cc-flags": "/utf-8 -I${build.FFMPEG_INC}" } }`——vendor 头路径不经静态写死即可注入 stub 编译;`stub-cc-flags` 只对 native-stub 编译生效。未下发变量的平台给占位值(`/usr/include` 或 `.`)避免 `${...}` 落空。
- **ffmpeg dev 内容 vendor 口径**:BtbN `ffmpeg-n9.0-latest-win64-lgpl-shared-9.0` 的 include 头 + 7 个导入库 + LGPLv3 LICENSE 共 2.5MB 进 `modules/ffmpeg-mbt/vendor/`(**选 lgpl-shared 不选 gpl-shared**——动态链接场景 LGPL 义务最小);运行期 dll(150MB)不进仓库,与 exe 同目录或放 PATH。`ffmpeg_stub.c` 删 `_WIN32` 全错误降级分支,三平台实现同源(ffmpeg API 本身跨平台,原 Linux 分支无 POSIX 特有调用,原样可移)。
- **miniaudio 在 Windows 零额外链接库**:WASAPI/COM/dsound/winmm 全走运行期 LoadLibrary,`gui-media/prebuild.py` 空 link_configs 即正确形态(非降级)。gui-media 24/24 全过含 AudioPlayer 冒烟(pump 33 拍播完 1 秒素材,WASAPI 设备链真出声);ffmpeg-mbt 6/6(ogg/m4a/wav + 视频真解码)。
- **GUI 子系统示例的无人值守收尾**:`native-web` 不设自杀点(人工验收要逐项点过去),自动化跑法须 `taskkill /IM`(发 WM_CLOSE,app.run() 正常返回后统计才 flush)——`kill -9` 会连 stdout 缓冲一起丢。

### WebView2 跨 HWND 焦点与滚轮转发(焦点批,2026-10-13)

- **GotFocus/LostFocus 挂在 Controller 上,不在 ICoreWebView2 上**:`add_GotFocus/add_LostFocus` 是 `ICoreWebView2Controller` 的方法;且这对事件的 `Invoke` sender 参数是 `ICoreWebView2Controller*`(事件 handler 宏写死 sender 为 `ICoreWebView2*`,x64 下 C4113 之外会真崩)——这对 handler 手写、不走宏。
- **滚轮投递规则是「发给焦点窗口」,与鼠标位置无关**,WebView2 拿焦点后宿主滚动区断轮。修法双向各一半:① 本桩 subclass 引擎输入窗(`Chrome_WidgetWin_1`,controller 创建同步完成后在面板 HWND 下按类名 FindWindowEx 找;找不到只少一半转发、不算错)——焦点在网页、鼠标不在其上时把滚轮 SendMessage 回宿主主窗;② 宿主 `WM_MOUSEWHEEL` 分支先经 wheel probe(web 桩 create 时经 `wm_set_wheel_probe` 函数指针槽注册,避免 win→web 反向符号依赖)问「该屏幕坐标是否落在网页上」,在则原样转给 Chrome 窗。两半合起来等价 GTK「悬停即滚」观感。subclass 用 SetProp 存原 proc 与自身 HWND,destroy 时还原+RemoveProp。
- **宿主主动给网页焦点**:`MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC)`(WebKit 分支是 `gtk_widget_grab_focus`),随后 GotFocus 事件照发,宿主可做状态联动。
- **焦点事件透出为 kind 16/17(WebView2 独有)**:WebKitGTK 是同树 widget、宿主天然可感知,不发。
- **调试插曲(教训)**:`python -c` 单行脚本对已存在大文件 `io.open(p,'w')` 传错 newline 值,ValueError 在 TextIOWrapper 初始化时抛出——但文件已按 'w' 截空,几百行改动全丢(git checkout 恢复后用 Edit 工具重做)。改大文件永远用 Edit 工具或先写脚本文件再跑,不用内联 python 单行写整文件。

### MoonBit 原生 GUI 栈 · 图片解码后端(W9:Windows 走 WIC)

- **为什么这条是「平台矩阵」的唯一例外**:Windows 的渲染是**纯 MoonBit 光栅器**(零第三方依赖,plan 矩阵定案),但光栅器不负责解码——图片解码只能借系统能力,**WIC**(`windowscodecs.lib`,系统组件,不是第三方包)。此前非 Linux 分支把 `img_*` 整组写成占位 no-op,于是 Windows 上 `Image::new_from_file` 恒返回空图、动图组件退成 0 尺寸;测试侧靠 `decode_available()` / `ui_decode_guard()` 探针跳过(不算红)。本批把 `gui/render/stub.c` 的 `_WIN32` 分支实装。
- **三条 WIC 实测事实**(`experiment/img_probe` 纯 C 探针回证,与 MoonBit 运行时无关):
  1. **WIC 的 GIF 解码器给的是「原始子矩形帧」,不替调用方合成**——`IWICBitmapFrameDecode::GetSize` 报的是**帧矩形**(探针实测 12×12),偏移在 `/imgdesc/Left|Top`(实测 14/14)。Linux 侧 GdkPixbuf 的 `GdkPixbufAnimationIter` 是替我们做了合成的,所以这条差异是本批新踩:整幅合成必须本层做——画布取 `/logscrdesc/Width|Height` 的逻辑屏幕,逐帧按 disposal 收尾(0/1 保留、2 清帧矩形、3 还原到「画本帧之前」的快照)。
  2. **透明索引已由 WIC 应用**(帧像素 alpha 实测只有 0 与 255 两档)。GIF 的透明语义是「此处保留前帧」而非混合,所以合成规则就是「alpha==0 跳过、其余整像素覆盖」,不需要 alpha 混合。
  3. **`/grctlext/Delay` 单位是厘秒**(GIF 规格),×10 才是毫秒;缺省/0 统一成 100ms,与 Linux 分支同口径。
- **预乘口径与 Linux 逐字同式**:WIC 转 `GUID_WICPixelFormat32bppBGRA`(straight)后,本层按 `(c*a+127)/255` 预乘再交给 MoonBit——与 Linux 分支同一公式,保证「编码→解码→再编码」字节稳定(`image_wbtest` 的半透明往返断言就吃这条)。静态首帧的尺寸口径也向 Linux 对齐:**GIF 按逻辑屏幕尺寸合成**,首帧是子矩形时不会被裁成帧矩形大小。
- **动图的内存策略**:像素**按需现解**(不把 N 帧全缓存),合成结果缓在 canvas 上——同一帧被反复取(每拍重绘)时不重复解码;逐帧前进走增量(只收尾上一帧的 disposal),回绕/跳帧才从 0 重放。帧数上限 4096 只防病态文件(内存与帧数无关,但回绕那一拍是 O(n))。
- **帧号语义沿用 Linux 的单调口径**:`img_anim_frame()` 只增不减(显示帧 = 帧号 % 帧数)。因此组件侧 `gif(looping=false)` 的「帧号回到 0 就停」判据**在两个平台都不触发**——这是既有行为,`image_wbtest` 的「帧号等于成功次数」断言正依赖它,本批不改。顺带一条资产事实:showcase 用的 `examples/showcase/assets/dot.gif` 四帧的压缩数据**逐字节相同**、只有局部调色板不同(所以看起来是「同一个点变色」而非移动)。
- **链接面**:`gui/scripts/prebuild.py` 的 Windows 分支新增 **RENDER_PACKAGE** 条目(`windowscodecs.lib ole32.lib user32.lib`)——此前 render 包在 Windows 一条 link_configs 都没有(桩全是 no-op,不需要外部符号),`render.whitebox_test.exe` 一旦调 WIC 就会缺符号。GUID 常量(`CLSID_WICImagingFactory1` / `IID_IWICImagingFactory` / `GUID_WICPixelFormat32bppBGRA`)与 W20f 图标加载同源,C 模式用不了 `__uuidof` 故链接期取。
- **`/utf-8` 不必补**:render 桩的中文注释在 MSVC 按 GBK 误读下只出 2 条 C4819(与改动前逐字持平;`win/stub.c` 是 6 条),无吞行、无语法错——故不引入 `stub-cc-flags`(ffmpeg-mbt 那条是 vendor 头真中招才要)。
- **验证**:纯 C 探针 `experiment/img_probe/img_backend_probe.c`(独立于 moon 工具链,`cl /W4 /utf-8` 直编,include 进 `render/stub.c` 直喂 `img_*` 入口)末行 **`IMG-BACKEND-OK`**,60 条断言全过:PNG 文件/内存两入口尺寸一致且预乘不越界、坏图/NULL/零长/越界句柄/不存在文件全给 0、`dot.gif` 静态首帧 120×120、动图 4 帧 + 延时 400ms + 逐帧前进帧号单调 + 不同帧像素确实不同 + 回绕后显示帧与首帧逐字节一致、释放幂等且释放后全空操作、PNG 经动图入口 `is_static=1` 且 `advance` 恒 0、**子矩形帧合成**(`experiment/img_probe/assets/subrect.gif` 第二帧 12×12@(14,14):画布仍是 40×40、(0,0) 保留第 0 帧的黑、框内偏红)。跑法:先 `cl` 编出 exe 再在仓库根执行 `experiment/img_probe/img_backend_probe.exe .`(资产重建脚本 `make_asset.py` 用 ffmpeg 现场生成 subrect.gif)。`moon check` 库模块零警告。
- **本批未做且不假装完成**:macOS 后端(仍是占位);`looping=false` 的「帧号归零」语义(跨平台既有行为,要改得同时动 `ui/gif.mbt` 与 `image_wbtest` 断言);JPEG/BMP/TIFF 未逐格式单独验(走同一条 `CreateDecoderFromFilename` 嗅探路径,PNG/GIF 已实证);真机观感(showcase 卡片/媒体页的图片区、动图是否在动)归 `_人工测试清单.md`。

### 文本布局对象 C 侧缓存(Pango / DirectWrite,2026-10-14,实测数据驱动)

- **背景与实测依据**:帧耗时分段账本(`gui/core/prof.mbt`)在 native-app 真机读数 `frames=190 layout=220ms paint=34487ms present=78ms total=34785ms`——**paint 占 99.1%,layout 只占 0.6%**(yoga 内部缓存有效,「每帧全树 relayout」不是瓶颈),瓶颈是每帧全窗重画时屏内每个文本控件都在 C 侧重建布局对象(Pango `PangoLayout` / DirectWrite `IDWriteTextLayout`,itemize+shaping+字体解析全重算)。
- **修法(两分支同构)**:布局对象按键缓存,键 = 路径标记(`"m"` 测量/无盒绘制、`"b"` 盒内绘制)+ 全量文本字节 + 字体四要素(族/号/重/形)+ 宽约束/换行/省略/对齐——同键的布局配置完全一致,复用是只读的。上限 1024(Pango)/1024(DWrite),超限整表清空(与 MoonBit 侧度量缓存同口径)。测量与无盒绘制共用 `"m"` 键(配置路径相同);盒内绘制走 `"b"`(宽约束按 wrapped_axis 归一化,对齐只在有宽约束时参与布局)。
- **复用只读的前提(两平台各自成立)**:Pango 侧颜色在 `cairo_set_source_rgba` 设、几何偏移逐调用现算,都不碰布局;DWrite 侧 `ptw_render` 无区间时不改布局(区间字体/颜色只属于富文本 rt_* 路径,rt_* 仍现搭布局不走缓存),文字色在共享画笔上 `SetColor`。
- **Windows 侧的免费前提**:`img_anim_advance`(WIC)是「一拍一帧」、组件按 `delay_ms` 节奏问一次,布局对象天然按拍复用;画布资源(WIC 位图 + D2D 渲染目标)此前已进程级缓存,本次补的正是 `CreateTextLayout`(含整段 shaping)这块剩余大头。
- **实测(平台更正 2026-10-14)**:`experiment/anim_cost_bench`(30 行「按钮+输入框+文本」典型页,1400×900)全窗重绘 **21ms/帧**、90×32 小脏区一帧 **0.8ms**、relayout 0ms。**这批读数出在本机 Linux/X11(cairo 后端),不是 Windows 纯光栅**——见下面「动画开工判据」一节对同一台机器后端选择的实测判定;`PureBackend(Raster)` 那条路径的每帧代价至今没有真机数(使用者目前全部真机验证都在本机 Ubuntu + X11 做,Windows/mac 侧待有机器时复跑同一探针)。P5 的开工判据按本机读数放行,Windows 侧风险已在此记档。native-app 全页的 after 读数以复跑 `NATIVE-APP-PROF` 为准(账本已落盘 `native-app-prof.txt`)。
- **未做且不假装完成**:富文本 rt_*(AttributedText)仍逐次现搭布局(演示页用量小,收益另估);测量路径在 MoonBit 侧缓存命中时根本不会到 C 侧,这层 C 缓存主要服务绘制路径与 MoonBit 缓存清空后的冷启动。

### 光栅填充快路径:fill_rect 直写 + 圆角矩形解析填充(2026-10-14,探针定位)

- **定位过程**:NATIVE-APP-RENDER 三段统计证明文本只占全窗帧 ~15ms/232ms——真凶在非文本侧。`experiment/paint_probe`(组件级隔离计时)给出分解:60 张 400×120 圆角卡片 **432ms/帧(单张 7.2ms)**、直角 110ms、三张图表 56ms、表格 22ms——**圆角矩形走通用路径扫描(路径化+多边形 AA)是全帧 paint 的最大单项,单张 20ms**。
- **修法(纯光栅后端,render 包)**:①`composite_solid_span`——纯色**不透明**源 + Normal 算子的整段直写(免逐像素取源/预乘/混合函数调用,预乘 BGRA 序不透明源即原色);②`Raster::fill_device_rect` 先试快路径再走通用 cov 合成;③`Raster::fill_round_rect` **解析填充**——不走路径扫描,按行求墨迹:中段整行(快路径),角部条带像素按「像素中心到角圆心的距离」求覆盖(圆外 0/圆边 AA/圆内 256),轴对齐且 x/y 等比(角仍是圆)才适用,斜矩阵/非等比退通用路径(`fill_round_rect` 返回 Bool,Painter 侧退 `trace_round_rect+fill`)。
- **陷阱(实测踩过)**:快路径入口**必须先 `apply_fill()`**——直接调 `raster.fill_round_rect` 绕过了 Painter::fill 的设源步骤,画出来的是上一次的源色(表格色块/浮层面板两条像素断言立刻红,即此因)。
- **实测(paint_probe 同口径复跑)**:单张圆角 20ms→**1ms(20×)**、60 张卡片 432→**23ms(19×)**、直角 60 张 110→**10ms(11×)**、虚拟表格 22→**5ms(4×)**;图表排 56→36ms(矢量路径/stroke 仍是下一大头)。分包 866+ 全绿(仅 virtlist 样式槽 1 条为前端化会话既有红)。
- **追加批·文本帧级批（DWrite 提交合并）**（2026-10-14）：NATIVE-APP-RENDER 显示 d2d 段 132us/段（62 段/帧 8.2ms）——每段一次 BeginDraw→EndDraw 的固定提交开销是大头。`dwrite_text.cpp` 加批队列：连续的 pt_draw/pt_draw_box（同一目标位图）攒批（上限 128），冲刷时一次 BeginDraw → Clear(**并集**) → 逐段 DrawTextLayout → EndDraw → 读回并集一次、逐像素混合一次（批内重叠段由 D2D 按入队序合成）。**z 序三重保障**：①目标/尺寸变化即冲（多窗交替）②render 加进程级「光栅前置闸」——每个写像素操作（fill/stroke/圆角/box_shadow/draw_image/draw_canvas 共 11 个入口）前以当前裁剪矩形调 `pt_flush_if_overlap`，与本批墨迹相交才冲（不相交继续攒批，卡片墙的「填充-文本」交错序列照样攒长批）③core `paint_frame` 帧尾 present 前 `flush_pending`。布局缓存整清可能发生在入队与冲刷之间，入队 AddRef/冲刷后 Release 防悬垂。**开关隔离**：批只在生产路径开（core `text_batch_init` 接线），测试/探针默认走旧路径逐位一致—— suite 零扰动。实测（paint_probe）：200 段/帧逐段提交 **21ms → 攒批一次 2ms（10×）**；即时路径（rt_* 富文本）入口先冲批保序。Pango/mac 分支无批（桩空操作），stub.c 公共尾部用 `#ifndef _WIN32` 防与 dwrite_text.cpp 双定义。
- **追加批·增量活动边表（AET）**（fill_polys 第二次重写，pixman 同构）：GET（全局边表）按 y_lo 排序一次，扫描线推进时每子采样只做「失活压缩 / 新边激活（指针只前进）/ x 全精度重算 + 近有序插入排序」——不再每子采样全边重扫。**两条实测铁律**：①x 必须与旧跨点公式 `ax + (bx-ax)×t` **逐位一致**（保存原始遍历方向端点 ax/ay/bx2/by2；步进增量的浮点漂移、以及 t 分母误用 bx2 当 by2，都会让边界像素覆盖量化翻转——box_shadow/星形/图标断言实测抓红）；②跨度 <1px 但骑在两个像素上（如 [10.6,11.4)）的短跨段覆盖范围是 `[floor(xa), ceil(xb))` 而非单像素（星形尖端/细环实测抓红）。**对拍方法论**：旧算法从 git 提取改名嵌进临时 wbtest，同形状双渲染逐像素 diff（本轮抓出三角形整块零墨迹=激活指针误用未排序下标）。实测（paint_probe）：折线 80 段 11→**4ms**、圆弧 15→**2ms**、图表排 28→**17ms**；icon 全量扫描崩溃为调试打印 cov 越界（非 AET）。已知渲染变化：自交多边形（五角星）内边界像素的欠覆盖瑕疵（旧实现 239/207/159 的暗缝）修正为满覆盖 255——非零环绕下 wind 1↔2 边界两侧都非零，理应全覆盖。**补记（2026-10-14 晚）**：AET 批带进一个崩溃真凶——y1 夹取误写 `cx1`（裁剪框右界）应为 `cy1`（下界），位图宽>高且几何越出底边时行循环越过位图高、composite_span 越界写（0xc0000409，graph_wbtest 抓住，494fa72→728d0d5 修复）；同批曾误归因前端化会话，git worktree 二分（3be0d9b 189 全绿→e2c7c14 崩）纠正。
- **追加批·扫描线引擎 pixman 化**（fill_polys 重写，2026-10-14）：照搬 pixman/Cairo 扫描线的四个成熟套路——①**满覆盖段直取**：跨点区间内四样本全入的整段像素直接置 256（原实现逐像素逐样本判 `xs∈[xa,xb)`，多边形内部白烧 16 次样本判断）；②**只在跨度两端各至多一个边界像素做采样**（`add_pixel_samples`，封顶 256）；③**只合成有墨区间**（逐行记录 ink_l/ink_r，composite 不再扫全 bbox 宽——宽度里通常九成是空覆盖）；④`composite_span` 加**纯色不透明满覆盖 run 直写**（cov==256 连续段绕过取源/预乘/混合，部分覆盖像素展开同式保证逐位一致）；⑤跨点排序换 `sort_by` 索引排序（原插入排序 O(n²)：160+ 跨点 × 4 子采样 × 每行重排）+ **零分配刮擦数组**（三元组直 push 每跨点装箱一次，实测 5.7 万次分配/帧的 GC 压力，刮擦区+索引排序降为零）。实测（paint_probe）：折线 80 段 18→**11ms**、圆弧 15→**12ms**、图表排 39→**28ms**。剩余结构性大头=增量活动边表（AET：边每行只遍历一次、x 增量步进、免每子采样全边重扫+排序），属更大的重写。
- **追加批·解析描边**:`paint_probe` 补 stroke 基准后定位——60 张 400×120 圆角卡片**描边 49ms/帧**(0.82ms/张,卡片密集页的剩余最大项)。`Raster::stroke_round_rect` 解析描边:环带像素按中心唯一分区(直段按行/列与 `[边-hw,边+hw]` 重叠求覆盖、角部象限逐像素 `|dist-rr|≤hw` SDF、线宽≥2×圆角时内孔自然消失),实测 **49→6ms(8×)**;顺带补 `Painter::stroke_round_rect` 公开 API。折线(80 段 18ms)与圆弧(3 个 14px 环 15ms)仍是通用路径,图表图元解析化列为下一批候选。
- **收官实测(native-app 真机,五批优化全量后)**:`frames=4421 paint=144299ms`——**全帧 paint 232ms→32.6ms(7.1×)**,max_frame 344→188ms;文本占 paint ~28%(d2d 9.3ms/帧),剩余大头为图表矢量路径与 stroke。布局 0.23ms/帧、present 0.5ms/帧均可忽略。
- **未做**:stroke_round_rect/图表矢量路径(stroke_polys)仍是通用路径——图表页与卡片描边是剩余大头;斜矩阵与非等比缩放下的圆角(椭圆角)仍走通用路径;DWrite 逐段 BeginDraw/EndDraw 的按帧合并(文本 9.3ms/帧的下一步)。

### 自维持重绘环:present 与 expose 互相点火(2026-10-13 真机反馈)

- **现象**:`examples/native-app` 真机「整体卡顿,滚动/点击/悬浮都有 300–500ms 延迟」,同时「图表推点按钮点了没反应、表格点表头不排序、虚拟表格滚不动」。看代码像三个不相干的 bug,实际是**一个根因 + 一处示例漏接线**。
- **根因(两分支同形)**:`wm_present` 每帧都请系统重画(`_WIN32` 侧 `InvalidateRect(NULL,FALSE)`、GTK 侧 `gtk_widget_queue_draw`),而系统的重画回调(`WM_PAINT` / `wm_on_draw`)又置 `need_draw = 1` → MoonBit 侧 `poll_event` 收到 `NeedsDraw` → `dirty = true` → 全帧重画 → `present` → ……**永动环**。于是:(1) 应用**永不空闲**,`wm_wait` 永远立刻返回(队列里总有 paint 消息),每一拍都在画 1400×3520 ≈ 490 万像素,输入只能排在一整帧之后——这就是 300–500ms 延迟;(2) 一帧里攒下的鼠标移动(高回报率鼠标轻松上百条)把 64 槽事件队列塞满,`wm_push` 的「满了丢弃」把**随后的抬起与滚轮整批丢掉**——这就是「点了没反应/不排序/滚不动」。注意这三条症状在**同一帧里同时成立**:点击的 `Down` 进了队列、`Up` 被丢了,控件停在按下态,看着就是「按钮坏了」。
- **修法(两分支同批改,保持对称)**:重画回调只**贴缓存帧**、不再请求重绘(`WM_PAINT` 只在还没有任何帧可贴时置一次 `need_draw`;`wm_on_draw` 同理)。重绘请求的唯一来源回到 MoonBit 侧的 `schedule_paint`(`@core.invalidate` / `App::schedule_paint`),这也正是本栈既定的契约——**「内容变了才画」**。首帧不受影响:`wm_show` 本来就置 `need_draw = 1`(`wm_mark_draw`)。
- **另一半:队列里合并连续移动**。`wm_push` 里若队列最后一条也是**未消费**的移动,直接替换成新的(位置是状态不是流水)。只在「最后一条也是移动」时替换,中间夹着按下/抬起就不动它,FIFO 语义不破。这一条即使修好永动环也要留着:任何一帧(现在仍有百毫秒量级)期间移动都能攒下几十上百条。
- **窗口高 3520 → 900(示例侧)**:视口剔除(`widget_cull_skip`)只画屏内那部分,**窗口高直接决定每帧像素量**;`enable_root_scroll` 落地后「一屏装下整页」的长柱只剩代价。改成 `APP_WIN_H` 常量,要「一屏看全」改回 3520 即可。
- **表格排序不生效是示例漏接线,不是组件 bug**:表头点击只切 `TableSort` Store(组件**不替使用方排序**,口径早写在 `TableSort` 注释里),示例没订阅它把行序写回 `rows`。补一个 `@ui.sort_rows` 作参考口径(**前导数字优先比数值**——演示数据是「12 处/6 处」这种混排,纯字典序会把 12 排在 6 前面、看着像没排;加**稳定排序**,同键成片时不会乱跳),示例两三行订阅即可。
- **教训**:「永不空闲」类 bug 在真机上表现为**一堆互不相干的功能失效**,而不像性能问题。下次见到「点了没反应 + 卡 + 滚不动」同时出现,先看事件队列的**入队速率与消费速率**,再看有没有自维持的重绘环——两者都会造成「事件被静默丢弃」,而丢弃是没有任何日志的。
- **验证**:`moon check --deny-warn` 库模块与 `examples` 模块零警告(两处注入式探针确认门禁确实覆盖这两个模块);`gui/win/stub.c` 用 MSVC(`cl /c /W4 /utf-8`)单编通过、警告数与改动前逐字持平(仅 2 条既有 C4996);新增 `table_wbtest.mbt` 2 条(排序口径 + 稳定性)。**真机行为(延迟是否真的降到「一帧」、点击是否不再丢)归 `_Windows真机测试清单.md` 复验**。

### Windows 本机库测试三红收口(2026-10-13,W9/排序批跟进)

W9 与表格排序批落库后,Windows 本机库测试长期 3 条红(`moon test` 合并跑在本机还会偶发超时,**分包跑**才稳定)。逐条根因与修法:

- **`moon test` 的测试进程 cwd 是模块根(`gui/`),与调用目录无关**(探针 `yue_sys_getcwd` 实证:从仓根调 `moon test gui/sys` 与从 `gui/` 调 `moon test sys`,进程 cwd 都是 `gui/`)。于是 wbtest 里按仓根写的相对路径 `examples/showcase/assets/dot.gif` 在测试里**永远不存在**,动图解码用例 `None => assert_true(false)` 恒红;`ui_decode_guard()` 也因此探不到图,ui 的动图组件断言一直在静默跳过。修法:测试侧路径改「两候选探测」(`examples/...` 与 `../examples/...` 哪个解得出图用哪个,`image_wbtest` 的 `test_asset` 与 `basic_wbtest` 的 `gif_asset` 同口径),守卫与组件测试从此在 Windows 真跑。
- **`Image::resize` 只开 Cairo 会话,Windows 无 Cairo 后端整帧空图**——放大后取像素得 `(0,0,0,0)`。`Cairo::over` 在无后端平台返回 `None`,原实现直接放弃填充。修法:改走 `Painter::draw_image`(Cairo / 纯光栅两后端都实装的拉伸 blit),平台无关。
- **`compare_cells` 只摘串首数字,不是自然序**——`"虚拟行 3"` 首字符非数字即回落字典序,`"虚拟行 12"` 反而排前面(平台无关的真 bug,Linux 同样该红,只是该用例落库后没赶上过一次绿 CI)。修法:重写为**自然序**(逐字符走,两侧同处数字段时整段按数值比,数值相等视同相等继续,先耗尽者排前),`leading_int` 删除。
- **动图换帧节奏的平台差异(测试口径)**:Windows(WIC)的 `img_anim_advance` 是**一拍一帧**(组件按 `delay_ms` 节奏问一次进一帧,无内部时钟);Linux(io-gif)按虚拟时钟锚定,每拍推进的帧数不同。`basic_wbtest` 的「12 拍 2..6 帧」上限是按 Linux 标定的,改成平台无关不变量「12 拍至少走 2 帧、至多 12 帧(一拍至多一帧的失控护栏)」。
- **验证**:Windows 本机分包全绿——core 132、ui 125、render 43、text/theme/icons 41、sys/input/win/dbus 280、chart/mdview/web 233,**854/854**;`moon check` 零警告。合并跑偶发 SIGTERM 超时为本机现象,CI(Linux)与分包口径不受影响。

## macOS(CI 构建链已验,GUI 待真机)

- libyue v0.15.6 发行包含 ARC / no-ARC 双库:Darwin 链接参数 = 主库 + `-lyue_mbt_noarc`(no-ARC 符号被主库引用,须排其后)+ AppKit / Carbon / IOKit / Security / WebKit / OpenDirectory 框架 + `-lobjc -lc++ -lpthread -lbsm -Wl,-dead_strip`;prebuild Darwin 分支已按此预修。
- CI(macos runner)承担构建 + 测试;headless 无 WindowServer,不做 GUI 冒烟。
- shim 平台分支的 `#else` 兜底会误吞 macOS:borderless 须 `#elif defined(OS_WIN)`;CurrentDirForDrag 拆三支(mac 用 `getcwd`);`Window::SetSkipTaskbar` / `SetIcon` / `App::SetID` 在 mac 头文件无声明,调用补守卫空操作。
- **AppleClang 17(macos-15 镜像更新后)把 `getRed:green:blue:alpha:` 返回值解析成 void**,`![...]` 一元取反编译错误;已判空且转 sRGB 后取分量必然成功,丢弃返回值写法对 BOOL/void 双解析都可编译(69136b7,曾被整树回退丢失又捡回——回退基线含带病文件时,后续修复会随回退消失,重推 vendor 前需对照该文件历史)。
- **0.5.0 发布前的 CI 连红三根因(9-22 起,Linux/macOS 红、Windows 绿)**:① `yue_accent_mac.mm` 的 AppleClang 编译错误(见上)卡死 prepare;② extern "C" 缺失(见 ABI 小节)卡死链接;③ sysmonitor 的 S4 硬件采样测试断「coretemp 必有 Package 传感器」,虚机 runner 无此硬件即败——环境缺件(无传感器/无 DISPLAY)只跳过不硬断。另:CI 原生层缓存 key 必须含 shim 源码哈希(只含 prepare.py 时,shim 变更不换 key,恢复的 build/ 缓存里是旧 shim 库);无 Actions 日志权限时,把失败输出切片塞进 `::error` 注解(check-runs annotations API 匿名可读)是唯一取证通道。

### ffmpeg CLI 视频解码路线(帧集整读 + 偏移切片)

- 环境:Ubuntu 24.04,ffmpeg 6.1.1 + ffprobe(apt)。决策:mooncakes 无 ffmpeg 绑定(ABI 面 +100 不收),视频解码走 ffmpeg CLI:`vidf_probe` 用 ffprobe CSV(`-show_entries stream=... -of csv=p=0`),`vidf_extract` 用 `-f rawvideo -pix_fmt rgba` 解码为单个连续帧文件(rawvideo muxer 顺序写帧,无需 image2 序列),`read_binary_file` 整读进内存后按帧号偏移切片——帧数据不落 stdout(pr_run 的 stdout 捕获是文本语义,二进制会坏),直接 ffmpeg 写文件绕开。
- 内存钳制:帧集大小 = 帧数×宽×高×4,默认 fps=8/max_frames=240;480p 12fps 60 秒会到 ~630MB,长视频必须降采样,文档已写明。
- ffprobe CSV 解析坑:r_frame_rate 是分数("30000/1001"),format duration 是纯小数行("2.000000")且无标签前缀——用「video,/audio, 前缀分流 + 其余纯数字行当时长」解析;分隔符逗号,字段无引号(探测输出字段不含逗号,不处理转义)。
- 真机全链路验证:lavfi `testsrc` 生成 2 秒 160x120@5 AVI(容器验证用 AVI 对齐需求方场景)→ probe 宽高帧率对 → 提取 8fps 得 9 帧 → 帧源切片首帧 76800 字节;systemprobe 演示板点「载入演示视频」实渲染 testsrc 彩条画面(xdotool 截图确认),状态栏显示「已载入 160x120 × 16 帧(@8fps,循环播放)」。
- 音画同步:音轨提取 WAV 交 AudioEngine 各自从 0 起播,属近似同步;精确同步需播放时钟对齐,留后续批次。

### 媒体三层拆分(yue 零 ffmpeg / gui-media 可选层 / ffmpeg-mbt FFI)

- 背景:VideoPlayer 曾直接放 yue 且引 ffmpeg FFI——moon 依赖是 **module 级**的,yue 只要 import 了 ffmpeg,所有 GUI 库用户构建都会跑 ffmpeg prebuild(没装 dev 包即失败),不用视频的人被传染依赖。音频曾走 `CorvusCinereus/miniaudio`(MoonBit 依赖),2026-10 用户定案「音频也交给 ffmpeg」后连音频一并统一:yue 核心删 AudioEngine/audio.mbt,音视频都在可选层。
- 三层:①yue 核心(零 ffmpeg 零 miniaudio 依赖,纯 GUI);②modules/ffmpeg-mbt(FFI 绑定,零 yue,moon 名称 `NoahLiu/ffmpeg-mbt`——用户定名,ffmpeg 训练语料污染太重不敢占 ffmpeg 裸名);③modules/gui-media(VideoPlayer/AudioPlayer + 播放器组件,依赖前两者)——要媒体播放的人 import 这层,别 import 这层就零额外依赖。workspace 成员互相引用:被引 module 在主 moon.mod import 列表带版本号,moon 就近解析 workspace 成员(不去 registry);**workspace 内改名**(ffmpeg→ffmpeg-mbt)三处同步:moon.work members、主/依赖方 moon.mod import、prebuild.py 的 link_configs package 字段(写死包名,漏改报 "Link config package name ... does not start with module name")。
- **「视频只有第一帧」根因**:旧版播放时钟只推进位置 Ref,画面容器的 schedule_paint 无人调用——GTK 不重绘,永远停首帧。修复:组件 50ms 时钟里 vp_tick()(FFI 逐帧解码)+ ViewLike::schedule_paint(cv) 成对出现。
- FFI 流式语义:播放时钟按 fps 每 tick 解一帧(decode_rgba 顺序流),seek 为时间戳级(Demuxer::seek → avformat_seek_file + 解码器 flush);容器无时长元数据(lavfi AVI 的 N/A)时 duration 为 0,进度条按 0 处理(帧照常播)。
- 跨包组件基建:yue 的 attach/themed_container/set_panel_bg/theme_border/theme_bg_panel 原为包私有,yue-video 组件层需要,最小 pub 化这 5 个(组件扩展 API)。
- yue 侧接口对齐:VideoPlayer 迁至 yue-video 后 vpc_frame_image(RGBA→PNG→Image)替代 vid_frame_image 直调;音频切段/提取保留 CLI 单命令(audiof_extract_wav/audiof_supported),FFI 音频 PCM 直出留后续。
- 真机验证:X11 合成点击(xdotool mousedown/up)持续被 XFCE click-to-focus 拦截(motion 事件可达、button 不可达),播放中视觉验证留真机;逻辑层 wbtest 全断言(make→play→vp_tick 帧推进→seek 清帧重解→pause/stop→free)。演示板视频页载入即 autoplay。

### 声明式根容器高度塌陷(mount_window 默认 flex)

- 环境:Ubuntu 24.04 + X11 + XFCE,systemprobe 示例。现象:`mount_window([scroll(vbox(...))])` 打开是空白窗口(纯底色,无内容,进程正常)。
- 根因:mount_window 的根容器无任何样式,窗口内容区不弹性分配;Scroll 视口高度来自 flex 分配,无高度约束时塌陷为 0。showcase 未踩坑是因为外层恰好有 `hbox(style=[("flex", 1.0), ("alignItems", "stretch")])` 包裹。
- 修复:mount_window 的根容器默认 `style=[("flex", 1.0)]`(窗口根语义即撑满窗口,默认化安全;`mount()` 面向任意父容器的子树,不默认化以免改坏既有布局);scroll 的文档注释补弹性高度警示;systemprobe 的 scroll 同时显式给 `("flex", 1.0)`(双保险,滚动子节点按需自给 flex 的用法不变)。
- 验证:xdotool + import 截图窗口区域像素方差,修复前纯底色、修复后完整渲染(标题/按钮/雷达图可见);showcase/hello 无回归。

### toolchain 版本升级(弃 fork 路线)

- 环境:本机 toolchain 曾被切到 moonc v0.10.12+1634b282e(core 0.10.12),而 moonsqlitefile 0.7/0.8 全线、moonbitlang/async 均要求 v0.10.14 的 API(`Bytes::exact_view`、`eprintln`);CI 无版本锁定(install.sh 装最新),两端漂移导致本机 clean 后全仓编译失败,而 `_build` 旧缓存掩盖了这一点。
- 决策演变:一度把 moonsqlitefile 0.8.0 vendored 进 `third_party/`(patch exact_view 为字节切片)应急;确认正解是**升级 toolchain 而非 fork 规避**(fork 生态包是长期维护债,只为应急),遂执行官方 install.sh 升级 moon 至 v0.10.14,撤销 third_party fork、恢复 prowk/moonsqlitefile@0.8.0 官方依赖,sysmonitor 的 4 处 String::exact_view 恢复正版写法。
- 结论:版本代差一律升级 toolchain 解决(与 CI 对齐),不 fork 生态包;third_party/ 仅保留确无替代的 vendored。
- 验证:moon clean 后全量重建 check 零警告、moon test 575 全绿、moon build 通过。

### ffmpeg 动态链 FFI(workspace 子模块 modules/ffmpeg-mbt)

- 形态:moon.work workspace 成员 `modules/ffmpeg-mbt`(module `NoahLiu/ffmpeg-mbt`),与主 module 并列(yue 不 import 它,避免给 GUI 库强加系统库依赖;主 module 因 examples 直接用 @ffmbt 而声明,GUI 库用户不传染)。动态链零 vendored:编译期 pkg-config 探测 libav*(含音频的 libswresample),运行期加载系统 .so。
- **链接传播**:库包 moon.pkg 的 link 段不会传播给最终链接(AGENTS 规则 2 的老坑)——照主仓库架构给子模块挂自己的 `prebuild.py`(moon.mod options --moonbit-unstable-prebuild),输出 `{"link_configs":[{"package":"NoahLiu/ffmpeg/src","link_flags":"-lavformat ..."}]}` 自动传播给依赖方 main 包;link 段从 moon.pkg 移除。测试方式:在 module 目录内 `moon test src`(workspace 根的全量 test 会连带 examples,他人未完成代码会干扰)。
- **FFI 三个坑(真机 gdb 定位)**:① extern 类型声明必须 `#external`(缺它时 GC 把 FFI 返回裸指针当 GC 堆对象,drop 走 mi_free 段错误——崩栈 moonbit_drop_object→mi_free);② C 侧句柄失败不返回 NULL,统一哑句柄+vf_ok 探测(NULL↔Option 转换语义不确定);③ MoonBit 侧中间裸值立即装 struct 字段再传(miniaudio 的持有模式)。FFI 指针参数按新 toolchain 要求逐个 `#borrow` 注解。
- Demuxer 形态(2026-10 音频并入后):open 只开容器探测流(vstream/astream),视频/音频解码器**显式按需打开**(open_video_decoder RGBA/sws、open_audio_decoder s16 交错/swr)——纯音频文件不再因无视频流被拒(旧版 NoVideoStream 直接 Err 的坑)。同一 Demuxer 实例上视频/音频解码器**共享 AVFormatContext 读游标会互吃 packet**,视频带音轨的场景必须双 Demuxer(同文件各 open 一个,VideoPlayer 即此形态)。
- 音频解码坑:①vf_decode_pcm 的 EOF 冲刷——av_read_frame 返回 AVERROR_EOF 后还要 `avcodec_send_packet(NULL)` + 继续 receive_frame 取解码器残留帧(AAC 尾部 ≈1 帧样本),否则尾部丢帧(实测 m4a 45056 帧 vs wav 44100 帧的差即编码器延迟);②seek 后 swr 要重 init 丢弃旧位置重采样缓存,否则残音。
- 测试素材内置:src/testdata/ 进仓(mp3/ogg/m4a/wav 各 1 秒正弦 + testsrc AVI + 带音轨 av_1s.mp4,ffmpeg lavfi 生成,共 <120KB),摆脱「本机 trae 素材路径」依赖,CI 可复现。**moon test 的 cwd 是各 module 目录**(workspace 全量 test 时 ffmpeg-mbt 包里 `src/testdata/...` 过、gui-media 包里同串失败),跨模块引用素材用 `../ffmpeg-mbt/src/testdata/...`。
- 真机验证:四格式音频 PCM 直出(累计帧数 ±10% 断言 + seek 后续解)+视频 RGBA 逐帧/seek,全部内置素材,CI 可跑;错误路径(不存在文件 OpenFailed)与版本探测自包含。
- 运行库版本:Ubuntu 24.04 = libavcodec60(avformat 60.16);CI 与本机一致需 apt 装 dev 包(见 modules/ffmpeg-mbt/README)。

### 音频 ffmpeg 全链路(miniaudio 降级为内嵌设备层)

- 起因:用户真机载 MP3 报 `音频加载失败: Invalid file`(浏览器可播)。独立 C 程序直链同一份 miniaudio 0.11.25 实测:libmp3lame 标准 MP3、系统 MP3 全部解码 OK——miniaudio 上游没有坏,是 `CorvusCinereus/miniaudio` MoonBit 封装的错误语义脏(load_sound 复用 engine->result 传错误码,加载失败后引擎 result 被污染,后续所有 load 永远报 Invalid file)且解码器集合仅 WAV/MP3/FLAC(OGG 需 stb_vorbis、m4a/aac 无内置)。用户定案:音频也交给 ffmpeg(全格式、与视频同栈、音画同源)。
- 架构:**ffmpeg 管解码,miniaudio 只管输出设备**。miniaudio.h(0.11.25 上游单头)vendored 进 `modules/gui-media/src/`,与 audio_stub.c 一起作为 native-stub 编译——miniaudio 从「MoonBit 依赖(mooncakes)」降级为「播放器的内部实现细节」,不再出现在任何 moon.mod import 里,不引入 gui-media 的人零感知。
- 设备层设计(audio_stub.c):ma_device(playback,s16,声道/采样率与 ffmpeg 解码输出一致零重采样)+ 互斥锁保护的 PCM chunk 链表;MoonBit 层 pump(50ms)把 decode_pcm 的字节 push 进队列(高水位 40KB≈0.3s),设备回调线程从队列取数混出、音量在回调内逐样本钳制乘。位置 = 设备累计消费字节(played_bytes)- seek 时记录的基准;自然播完 = demuxer EOF && 队列空。seek = 清队列 + 双 Demuxer 重定位 + 重填。
- **无输出设备降级**:headless/CI 环境 ma_device_init 失败时返回哑设备句柄(has_device=0),push 静默丢弃、状态机照常(pump 按 tick×25ms 近似推进位置)——AudioPlayer 冒烟在无设备环境也能全断言跑通,不为环境写跳过分支。
- AudioPlayer/VideoPlayer 共用这套设备层;组件(audio_player_t/video_player_t)50ms 时钟 pump+refresh,free 后凭 closed 标志停摆。
- 踩坑:① C 侧 data_callback 里消费 chunk 后 queued_bytes 统计口径要统一 recount(半播块/整块消费混写递减会漏);② ma_device_init 是三参 (context,cfg,device),漏 context 编译错;③ MoonBit `guard` 是保留字(循环哨兵变量名撞上,Parse error);④ 自定义 Node 的 mount 闭包返回 View 不是 Node(结尾 `(row.mount)(parent)`);⑤ 换载 free 旧播放器后旧组件 50ms 时钟还在 pump 已释放的 FFI 句柄(悬垂)——free() 置 closed、时钟查 is_closed 返回 false 停摆,同理 VideoPlayer::duration 改用 make 时缓存的字段(free 后旧时钟的 refresh 曾会调 demuxer.duration_s() 解引用已释放的 fmt)。
- 真机验证:AudioPlayer 冒烟 1 秒 MP3 从 play 到自然播完 17 tick(真实设备消费队列,非降级路径)+seek/循环重播/错误路径;VideoPlayer 双路(视频帧+音轨 PCM 队列)与无音轨静音路径;全仓 575 测全绿;systemprobe 冒烟进程存活。

### 播放器组件换载崩溃与 seek 防抖风暴(2026-10 真机)

- 现象(用户真机):视频页「选择本地视频」后崩溃(段错误)、音频页「选择本地音频」后卡死。本机复现(GUI 复现程序模拟用户时序:演示视频播放中换载真实 960x720 大 mp4):稳定段错误,gdb 栈定格 `vf_seek_s → d->fmt->streams[...]` 悬垂。
- 根因(两层叠加):①slider_t 的 on_change 对**程序性 Store.set 同样触发**(订阅无来源区分)——播放中 50ms 时钟每 tick 刷新进度条都排一个 180ms seek 防抖定时器(seek 风暴,每 ~230ms 一次冗余 seek);②换载时 vid_mount_player 先 make 新(含新设备)、free 旧,而旧组件的最后一个防抖定时器仍在飞,180ms 后触发对已 free 的 demuxer 调 vf_seek_s——use-after-free。触发窗口=「最后一次程序刷新排定的定时器恰落在 free 之后」,演示视频播放中换载必然命中。「卡死」是同源另一个面:FileDialog 回调里同步跑 make(大文件双 Demuxer find_stream_info + 设备握手,数秒)冻结 GTK 主循环,观感即死机。
- 修复(三层):①组件 refresh 用 syncing 抑制标志包住 pos_store.set(程序性刷新不再触发 on_change/不再排 seek 定时器);②user_seeking 标志——用户拖动+防抖期间 refresh 跳过进度条(顺带修了拖到一半被弹回播放位置);③防抖闭包与两播放器全部公开 mutating 方法(play/pause/stop/seek/set_volume/set_looping)开头补 closed 守卫(free 后一律 no-op,残留闭包不触碰 FFI);④音频页 FileDialog 选完先 set_text「载入中」+ set_timeout(50) 延后 make(对话框先关、UI 先渲染,同步耗时不再叠加模态循环)。
- 验证:复现程序(修复前 100% 段错误)修复后连跑 3 轮×20 秒全存活;575 测全绿;systemprobe 冒烟存活。真机视觉/交互验证由用户执行。
- GUI 免点击复现方法论(本轮关键手法):xdotool 合成点击被 XFCE click-to-focus 拦截(见前文),「用户点了才崩」类问题用 **set_timeout 编排用户时序**复现——按用户真实操作序列排定时器(0.3s autostart 演示视频 → 4s 播放中换载本地大文件 → 12s 二次换载),零交互稳定命中崩溃窗口;配合 `import -window root` 差分截图确认画面在更新。gdb 抓栈用 `gdb -batch -ex "set environment DISPLAY :0.0" -ex "handle SIGSEGV stop nopass" -ex run -ex bt` 直跑 `_build/.../xxx.exe`(gdb 环境可能丢 DISPLAY,gdb 内显式 set;moon run 是包装进程,gdb 要直指 exe)。
- 排查弯路两则:①yue 应用必须先 `@yue.initialize()` 再创建任何控件/窗口(mount_window 内的 Window::make 也依赖它),复现程序漏掉会在 `nu::View::View()` 段错误或 `Gtk-ERROR: Can't create a GtkStyleContext without a display connection`——极易误判为音视频问题;②`pgrep -f` 匹配 `moon run` 会命中 moon 父进程造成「进程存活」假象,验证存活要核对真实 exe 进程名或退出码语义;gdb 调试前 `touch` 源文件强制重编,防旧产物误导。

### 视频播放时钟与时长不同轴(帧计数 / 硬编码 fps,2026-10 真机)

- 现象(用户真机):「视频的时长对不上」——时间文本与进度条和真实视频时长脱节:帧率高于 12 的视频进度早早爆表(30fps 视频播完位置=2.5×时长)、低于 12 的走不满格;且画面播放速率随真实帧率漂移(解码固定 20fps,30fps 视频画面 0.67 倍速拖慢),音轨设备实时直出,音画偏差随播放发散。
- 根因:`vp_tick` 的播放时钟 = `frame_no / fps`,fps 是 make 参数(演示视频传 8、本地文件传 12,全是调用方硬编码),而 duration 是容器头真实秒数——**两条时间轴不同尺度**,pos 与 duration 相除无意义。演示视频自己都是歪的:生成 `rate=5` 却传 `fps=8`,2 秒视频播完 pos 停在 1.25s(进度只到 62%)。内置测试素材恰好 12fps、测试恰好传 12,单测全绿完全掩盖问题——**时钟类回归必须故意传错 fps 参数断言时间轴不受影响**。
- 修复(墙钟 + 帧时间戳,与 duration 同轴):ffmpeg-mbt 透出帧级信息——`vf_decode_next` 成功时记录帧 pts(`best_effort_timestamp` 优先,流时间基换算成秒,`vf_frame_pts_s` 读出;seek 后重置 -1)与流真实帧率 `vf_stream_fps`(avg_frame_rate 优先 r_frame_rate 回退);gui-media 增单调墙钟 `mbt_now_ms`(audio_stub.c,CLOCK_MONOTONIC)。VideoPlayer 时钟重写:play/seek 记基准(位置 + 墙钟),每 tick `target = 基准 + 真实流逝`,解帧推进到 target 时刻的帧(高帧率视频跳帧追时钟、低帧率画面跨 tick 保持,追帧上限 8 帧/tick——seek 落点离关键帧远也不卡 UI 一整拍),`pos = clamp(target, duration)`——恒 1 倍速,EOF 位置钉在时长(进度满格)。fps 参数降级为**无 pts 流的回退帧率**(优先用流真实帧率)。附带收益:音频设备按采样率实时消费、视频按墙钟推进,两条速率天然同尺度,音画偏差从「随帧率倍率发散」降为常数级。
- 验证:回归测试故意传错 fps=5(素材实为 12fps)断言位置仍按时间戳走(墙钟回拨 500ms → pos=0.5;回拨超时长 → EOF 钉 duration=1.0 转停);ffmpeg 侧 pts 非负单调、末帧贴近容器时长、seek 重置 -1。576 测全绿;systemprobe 冒烟存活。真机交互(进度/时间显示)由用户复验。

### 音频进度条「拖不动」(seek 后 current 从零重涨,2026-10 真机)

- 现象(用户真机):音频页进度条拖到一半松手,进度条立即被拉回开头——观感即「拖不动」。视频页进度条正常(两侧组件层 syncing/user_seeking 同构,差异在播放器层)。
- 根因:AudioPlayer 的 `current()` = 自 played_base 以来设备已消费秒数,**语义是"消费量"而非"媒体时间轴位置"**。seek 只重置了 played_base(消费基准),pos 语义仍从 0 重新累计——seek(0.3) 后 current 从 ~0 开始涨,组件 refresh 每 50ms 把进度条 set 回 vp_pct(current≈0)=开头。VideoPlayer 的 seek 直接 pos=target,所以视频侧无此问题。组件层的 user_seeking 拖动锁只保护「拖动+180ms 防抖期间」,防抖定时器触发 seek 后锁即释放,下一拍 refresh 就把条弹回。
- 修复:AudioPlayer 加位置基准 `pos_base`(seek 时=target,stop/循环重启归零),`current() = pos_base + 自基准以来消费秒数`(哑设备分支同样加 pos_base,pump 哑设备 EOF 判断改用 current())——回到媒体时间轴语义,与 duration/进度条同轴。
- 验证:回归断言 seek(0.3) 后 current ≥0.29、pump 一拍不回落(真设备=0.3+消费、哑设备=0.3+0.025 两分支覆盖);576 测全绿;systemprobe 冒烟存活。真机拖动手感由用户复验。
- 教训:**「位置」字段的语义必须在 seek/play/pause 全生命周期自洽**——消费计数型时钟(设备字节/帧计数)换算位置时,seek 必须携带位置基准,否则进度 UI 会被拉回。与上一条视频时钟 bug 同族:都是播放时钟与媒体时间轴脱节,一个差在速率,一个差在原点。

### 视频比例畸变与透明色失效(HEX 字节序 + 解码器单边尺寸,2026-10 真机+探针实证)

- 现象(用户真机):控制条「背景色还是没有,是不是不支持透明?」;「比例还是不对」。全屏/页面 letterbox 数学此前已修,用户复测仍不对。
- 根因一(**透明**):nu::Color 的 8 位 HEX 是 **AARRGGBB 序(alpha 在前)**——库自家 `argb_hex()` 即产出 `#ffd46a6a` 形态。组件里全部按 RRGGBBAA 语义写(`#00000080` 意图 50% 黑),实际 AA=00 全透明,控制条半透明黑底、滑杆半透轨道、按钮 hover 蒙层全部不可见;`#ffffffe6` 之类前三位白被当 AA=ff 才侥幸可见。**dialog_t 遮罩 `#00000059` 同款错序(AA=00),对话框淡黑遮罩一直是透明的**(存量 bug 一并修)。探针实证:`#80000000` 50% 黑、`#ff000000` 不透明黑、`#000000ff` 全隐形(前导 00=全透明)。
- 根因二(**比例**):页面调用 `VideoPlayer::make(width=480, height=0)`,C 层 `vf_open_video_decoder` 对 0 尺寸直接用源值→16:9 视频被 sws 解码成 480×1080(横向压扁的竖长帧),后续 letterbox 数学再对也无救。修复:单边指定时另一边按源宽高比补齐(ffmpeg `-1` 语义,双向支持,最小 1)。探针实证:320x180 视频传 width=480 解码帧变 `480x270`(修复前 480x180)。
- 定位手法:GUI 探针 × 截图像素采样(`import -window` + ImageMagick `pixel:p{x,y}`)+ 组件内临时 DBG 打印帧尺寸;2×2/组合矩阵探针逐因素隔离(absolute 定位/画法/高度来源均排除,最终靠「不透明黑也不显示」锁定色值解析)。注意探针窗口截图坐标含标题栏偏移,肉眼比对裁剪图比逐点采样更快。
- 排查弯路:曾误判「absolute 定位子容器不渲染」——实为采样坐标落窗外;曾怀疑「宿主 on_draw 吞子绘制」——矩阵证明 absolute+on_draw 照常渲染,一切归因到色值字节序。
- 验证:576 测全绿;探针数值证明(帧 480x270 + 条背景 50% 黑实证);systemprobe 冒烟存活。真机最终观感由用户复验。
- 教训:**库约定色值序是 ARGB(AARRGGBB),写 8 位 HEX 时 alpha 在前**;半透明色务必上真机/探针采样验证——全透明与半透明在深色底上肉眼难分。解码器输出尺寸改写(缩放)必须保持宽高比,单边指定即隐含「按比例补齐」预期。

### 对话框遮罩纯黑(背景色 alpha 被 GTK 钳为不透明,2026-10 用户真机反馈+本机实证)

- 现象(用户真机):dialog_t 遮罩变成纯黑、盖住底下内容——预期 35% 半透明黑(`#59000000`)。
- 根因:遮罩色走 `ViewLike::set_background_color` → shim 裸传 `nu::Color(std::string)` → GTK 后端 `View::SetBackgroundColor` 以 `Color::ToString()` 拼 CSS。libyue(上游与 fork 同)的 `ToString()` 产出 `rgba(r, g, b, a)` 且 **a 是 0-255 整数**,而 GTK CSS 的 rgba alpha 只接受 0..1,超界钳为 1.0——本机 `gdk_rgba_parse` 实测:`rgba(0,0,0,89)`→alpha=1.000、`rgba(0,0,0,128)`→1.000、`rgba(0,0,0,0.35)`→0.350。故任何带 alpha 的 8 位 hex 走背景色路径在 Linux 一律渲染为不透明。`6af827c` 只修对字节序,其「#80000000 50% 黑」探针结论取自 Painter 填充路径,在背景色路径上不成立(深色底上不透明黑与半透明黑肉眼难分,误判来源)。
- 修复:遮罩改 on_draw + Painter `set_fill_color("#59000000")` + `fill_rect`(控制条同款 Cairo 路径,alpha 正常;与 hover_group「可见背景必须自绘」既有结论一致);absolute 容器补显式 `height:"100%"`;删 `set_background_color` 调用;`set_background_color` 文档注释更正为「#AARRGGBB,alpha 不保证生效,半透明底走 Painter」。全仓扫描:带 alpha 的 8 位 hex 走背景色路径仅此一处,`with_alpha` 全走 Painter 无碍。
- 验证:探针示例(白底 + dialog_t 常驻可见)真机截图,遮罩区域三处像素采样均 `srgb(166,166,166)` = `#a6a6a6`,与 `#59000000` 叠 `#ffffff` 理论值(255×(1−0x59/255)=166)逐位一致;`moon check` 零警告 + `moon test` 657 全绿。
- 教训:**半透明底一律 on_draw + Painter 填充,不走 set_background_color**(libyue 的 Color→CSS rgba 把 0-255 alpha 钳成不透明);探针结论必须标明渲染路径——Painter 填充与背景色 CSS 两条路径同一色值行为不同。

### 音频播放无声、仅拖动进度时响一下(has_device 状态判定写反,2026-10 真机)

- 现象(用户真机):音频播放全程无声,只有拖动进度条的瞬间响一下(约 0.4 秒)又静默。视频页音轨正常。
- 根因:C 层 `mbt_adev_has_device` 写成 `started == 0 ? 1 : 0`——`started` 是三值状态(-1=init 失败哑设备 / 0=已初始化停止 / 1=播放中),**`play()` 一把设备 start(started=1),"有设备"判定立刻翻成 0**,pump 误走哑设备降级分支:解码丢弃、永不推队列、设备零消费(无声但状态机照常)。拖动时的声音来自 `seek()` 里的 `ap_fill`——它不查 has_device,直接 push 到真实设备(设备 start 后回调线程活着),队列 ≈0.43s 播完后无人再补,正是「一下子的声音」。视频侧不受影响:VideoPlayer 的 `vp_fill_audio` 从不查 has_device,一直直推。
- 定位手法:**真实节奏探针**——wbtest 里 busy 等待 `mbt_now_ms` 逐 50ms 拍打点 `started/has_device/queued/consumed/current`:`play 后 started=1 has_device=0` 一行铁证;修复后同探针 t0 起 queued≈高水位、consumed 按拍上涨(44100Hz 精确 0.05s/拍)。
- 修复:`has_device` 改 `started >= 0`(停止/播放中都算真设备,只有 init 失败才是哑);wbtest 冒烟改真实节奏(25ms/拍 busy 等待)并新增「真设备播放中队列应有 PCM 在途」回归断言(哑环境自动跳过)。
- 深层教训两条:①**三值状态标志的判定必须写全区间**(`==0` 与 `>=0` 一字之差,把"播放中"判成"无设备");②**降级分支的「能跑通」会掩盖上游判定 bug**——哑设备降级设计让误判表现为无声而不报错,且旧 wbtest 连打 pump 正好借误判的哑分支 0.025/tick 快进"播完"(17 tick 播完 1 秒的假象),测试反而依赖了这个 bug;设备消费类时序必须用真实节奏(按拍等待)测,不能连打。
- 验证:探针修复前后对比复现;576 测全绿(3 存量环境失败);systemprobe 冒烟存活。真机听感由用户复验。

### 悬浮控制条对齐统一与背景不渲染终因(absolute 内容撑高 × 宿主 on_draw,2026-10 探针实证)

- 现象(用户真机):控制条上播放/暂停、等比/原始、全屏按钮高度不一、对齐不齐;进度滑杆与循环勾选不与按钮垂直居中;此前半透明黑底修复(6af827c 改 ARGB 序)后背景**仍然**不可见。
- 对齐统一:三按钮统一高 28(播放钮原生内建高度偏大,`Button::make(style=[("height",28)])` 显式钉;等比 44x28、全屏 28x28);**slider_t 内建 marginBottom 10、checkbox_t 内建 6 会把控件顶离行中线**——调用方 style 传 `("marginBottom", 0)` 覆盖(base 先 push 调用方后 push,可覆盖),交还 alignItems=center 真居中;去掉按钮私有 marginLeft 统一走 gap;等比文字测宽水平居中(`get_bounds_for` 测宽 + 居中绘制)。
- **背景不渲染终因**:组件控制条 absolute+bottom/left/right **无显式高度(内容撑高)**,且宿主(画面容器)自身挂 on_draw(画视频)——此组合下条的自身 on_draw 填色整个不渲染(子控件照常画)。隔离矩阵逐因素实证:absolute 定位✓、on_draw 画法✓、宿主 on_draw✓、内容撑高×宿主 bg✓,唯独「内容撑高×宿主 on_draw」组合失效;给条显式 `height: 40`(28 控件+12 padding)立即恢复,像素采样条区=视频色×50% 黑精确成立。机制深层(GTK draw 链与 yoga 内容测量的时序)待源码级确认,经验规则先行:**absolute 无显式尺寸的子容器,其宿主若挂自定义 on_draw,必须给子容器显式宽高**。
- 排查弯路:①stdout 管道缓冲——`timeout` 强杀探针会丢全部 println(READY 没出现≠程序卡死,自然退出才 flush),窗口是否映射要用 `xwininfo -root -tree` 按真实标题查;②探针窗口截图坐标含标题栏偏移,逐点采样前先剖面扫描找边界;③一度误判 get_bounds_for/对齐改动导致卡死——实为缓冲假象。
- 验证:探针像素采样条区半透明黑精确 50% 压暗;特写截图全行垂直居中;576 测全绿;systemprobe 冒烟存活。真机观感由用户复验。

### 视频播放器(FFI 双 Demuxer:视频帧 + 音轨 PCM 直出)

- 组件:VideoPlayer + video_player_t(播放/暂停/进度拖拽/音量/循环/时间文本)。2026-10 音频并入后:音轨是同文件的第二个独立 Demuxer(读游标与视频互不干扰),vp_tick 按墙钟目标解帧 + 补音频队列到高水位(时钟语义见「视频播放时钟与时长不同轴」节);音画从 play/seek 点各自起播,误差数十毫秒级(精确同步需音频光标回读,留后续)。
- 悬浮控制条 + 全屏(2026-10,纯组件层零平台代码):控制条 `position:absolute` 钉画面底部(bottom/left/right 0,半透明黑 on_draw),与 dialog_t/toast_layer 同一 absolute 先例;控件白色系(label_t/checkbox_t/slider_t 各加可选 color/bar_color/track_color 参数,空=主题色——深色遮盖层上的白字白条是通用需求,提为组件库能力)。显隐为**移动唤醒状态机**——enter/mouse_move 即显示并排静止计时,静止 1s 或移出(250ms 短延时,防指针滑经控制条时画面 leave 先到而闪烁)后隐藏,**与播放状态无关**(初版"暂停/未播常显"被用户实测否决:演示视频播完停在停止态,控制条永不隐藏,观感即"移入移出没有用");拖动进度(user_seeking)顺延;指针移到控制条时 GTK 先给画面发 leave,控制条自身 enter/move 兜底。画面绘制黑底 + 显示模式两态(**等比 letterbox / 原始 1:1 居中超出裁剪**,控制条"等比/原始"文字按钮循环切换)。全屏为**独立全屏窗口自绘画面**:全屏根容器(flex:1,几何来自窗口布局)挂同一份画面绘制函数与事件(enter/move/leave/双击/Esc),控制条 re-parent 过去(absolute 随全屏宽);**不做画面容器 re-parent + set_view_bounds 直写**——直写几何会被后续任意布局事件(控制条显隐触发的重排等)冲回旧尺寸,用户实测"全屏后视频没有放大且比例变了"的根因;几何交给窗口布局才是稳的。退出四路:控制条按钮/Esc(根容器 set_focusable+focus+on_key_down VKEY_ESCAPE)/双击画面(ClickTracker 连击计数,libyue MouseEvent 无 click_count)/WM 关闭(on_close 兜底归还控制条);换载 free 时 tick 的 is_closed 分支顺带收全屏窗口。事件装配先于全屏函数定义的相互递归用 `Ref[() -> Unit]` 间接绑定(MoonBit 局部函数无前向引用,Ref 字段调用要写 `(x.val)()`)。真机显隐/全屏/两模式由用户复验。
- seek 实现:avformat_seek_file 时间戳级(视频/音频 Demuxer 各自 seek + 解码器 flush + swr 重 init),拖拽防抖 180ms;不再走 ffmpeg CLI 切段(音轨 CLI 提取/切段残留 audio_extract.mbt 已删,媒体链路零 CLI)。
- 音轨失败(无音轨/解码器不可用/无设备)时自动静音播放,不阻断视频路径。
- 换源顺序必须是「旧播放器 stop → free(closed 置位,旧刷新定时器停摆)→ 旧根视图 `remove_child_view` → 挂新节点」,乱序会留残音/残定时器;但顺序正确也不够——free 旧后其组件的在飞定时器(seek 防抖等)仍会触发,组件侧必须自防御(closed 守卫),详见「播放器组件换载崩溃与 seek 防抖风暴」节。systemprobe 视频页首次挂载 set_timeout 300ms 自动载入(make 同步耗时);音频页换 AudioPlayer 后:载入即播放、控制条 audio_player_t 挂 holder、200ms 轮询 is_playing 状态标签、演示素材改 MP3(lavfi + libmp3lame)。

### VideoPlayer 重播状态机:播完再 play 不走 / stop 后重播无声(2026-10 白盒回归)

- 现象:视频播完(EOF 非循环)后再点「播放」毫无变化——位置钉在时长、画面钉末帧、音频队列已空;stop 后再 play,画面倒是从头了,但全程无声。
- 根因一(**播完再 play 不走**):`vp_tick` 的 EOF 非循环分支把 state 置回 `VpIdle`,与初始 idle 无法区分——`play()` 对 VpIdle 一律「从当前位置续播」,而播完态 pos=duration,续播目标时刻恒超时长、demuxer 又已在 EOF,首 tick 立刻再次 EOF 转停,点了等于没点。
- 根因二(**stop 后重播无声**):`stop()` 只 seek 了视频 demuxer;**音频 demuxer 是同文件另开的独立容器实例**(读游标与视频互不干扰,见上节),停在 EOF——重播时 `vp_fill_audio` 的 `decode_pcm` 直接 None,队列全空、全程静音。凡「回起点」类操作必须双 demuxer 都 seek,漏一个就是有声画面配静音。
- 修复:① 显式增加 `VpEnded` 态(对标 AudioPlayer 的 `ApEnded`),EOF 非循环转 VpEnded;`play()` 对 VpEnded 先走 `vp_restart`(双 demuxer seek(0) + pos/base_pts/frame_no 归零 + 音频队列重填)再起播;② `stop()` 补音频 demuxer seek(0);③ `seek()` 把 VpEnded 迁移到 VpPaused——播完态拖进度后再 play 从落点续播,不被误判成重播(重播语义只属于「停在末尾直接再 play」)。
- 设计取舍:**用显式态而非 `pos>=duration` 启发式**——播放中 target 超时长但尚未 EOF 时 pos 会被 clamp 到 duration(启发式假阳性,「暂停在末尾再播放」会被误判成重播回 0);且容器无时长头(duration=0)时启发式完全失效,显式态两种场景都对。
- 验证:白盒对照——把 video_player.mbt 暂存回修复前跑 `moon test -p gui-media`,新增两条用例精确失败(播完→play 的 is_playing 断言、stop→play 的音轨 decode_pcm 断言),恢复修复后 11/11 通过;全仓 `moon check --deny-warn` 零警告 + `moon test` 641 全绿(较此前 636 新增 5 条:循环 EOF→vp_restart、播完→play、播完态 seek→play、stop→play、音量钳制)。真机交互(播完再点播放、stop 后重播的观感)由用户复验。

### Store 内建去重与 `T : Eq` 限定实现（2026-10-13，前端化 P3 第 0 步）

- 口径：`Store::set` / `Store::update` 给 `pub fn[T : Eq]` 限定实现（相同值只存不发，走 `Signal::set_eq`）；`Signal::set` 本体与通知发射不动，`Store::signal()` 仍可直连 `Signal::set` 强发。需要无条件重发用 `set_always` / `update_always`。
- 坑①：**同名限定实现会盖过通用实现**——无约束的 `Store::update` 体内调 `self.set(...)` 会撞 `Type T does not implement Eq`，因为名字只绑到限定那条；跨约束复用逻辑要直调底层（`sig.set_eq` / `sig.update`），不能经公共名。
- 坑②：去重要求**元素类型有 Eq**：`Array[T]` 的 Eq 由 `T : Eq` 派生。复合值类型补 `pub impl Eq for X with fn equal` + `pub extend X with Eq::{not_equal, equal}`（不带 extend 会吃 `implicit_impl_as_method` 废弃警告，同 W21c 先例）；`impl Eq for (T,T)` 二元组 core 已有，重复定义报「already defined」。
- 坑③：图表数据窗口（`Array[LineSeries]`、`TreeItem`、`GeoRect` 等）元素无 Eq 且整窗比较代价高于收益——chart 与示例一律 `set_always`，共 33 处调用点由编译器逐点钉出。
- 验证：core 121/121（新增去重回归 1 条：同值不发/异值发一次/`set_always` 强发/`update` 走同口径）；全仓 `moon check --deny-warn` 零错零警；库测试 861 条 859 过（2 条红为 W9/排序既有基线）。

### 动画开工判据:纯软件光栅下 transition = 每帧全窗重绘(2026-10-14,决定 P5 排期)

- 问题:P4 之后要不要马上做 P5(`transition` 状态桶属性插值 + 帧驱动)。判据不能靠感觉,量了一版:`experiment/anim_cost_bench`(30 行「按钮+输入框+文本」的典型页,1400×900,`page.paint` 20 帧)本机读数 `full=16ms/20帧`、`relayout=0ms/20帧`、局部 90×32 圆角填充 `<1ms/帧`。
- **但这台是 Linux,`Painter::new` 探针选中的是 cairo 后端**(见 `render/painter.mbt` 后端选择与 `Cairo::over` 优先),这 0.8ms/帧是**交给系统 cairo/X 的宿主侧提交成本**,不代表 CPU 光栅的每帧代价;真正的纯光栅代价在 Windows/mac 那条 `PureBackend(Raster)` 路径上(§6.6 性能批的真机读数:全窗一帧 300–500ms,修复后仍待分档计时;`text_bench` 在 Win 上单次盒内绘制约 0.35ms,而一次全窗重绘要为**屏内每个文本节点**各付一次布局+落墨)。
- 结论与口径:**动画的本质是连续置脏重绘**,在没有脏矩形之前,Windows 上「一个 150ms 的 hover 过渡」= 约 9 次全窗重绘,反馈会明显掉帧,还会把「输入只重绘那一格」的粒度承诺反噬掉。故 **P5 改排到 §6.6「脏矩形重绘 + 文本布局缓存」之后**,开工判据:局部变化(悬停一颗按钮)一帧 < 16ms。P4 的 `opacity`/`box_shadow` 是**静态属性**(画一帧就够),不受该闸门影响,已先行落地。
- 顺手一条工具链坑:`local` 是**保留字**(实测 `[0035] The word 'local' is reserved`),`let local = ...` 直接撞;探针变量改名 `part`。写新代码遇到 `alias`/`abbrev`/`local` 一类词先当保留字看待(与 §1.6 表同源)。
- 下一步要的真机数(用户执行,一条命令):本机 `moon run examples/native-app` 跑起来后退出,读 `NATIVE-APP-PROF` 行(布局/绘制/上屏三段累加 + 最长帧,由 `core/prof.mbt` 常开统计)——用它定「脏矩形收益有多大」并作为 P5 的开工判据。

### 前端化 P4:Painter 全局 alpha 与硬阴影(2026-10-13)

- 全局 alpha 收在**门面状态机**(`PainterState.global_alpha`,save/restore 随栈):填充/描边(含渐变 stop)在 `apply_fill/apply_stroke` 折算色 alpha;文本经 `Painter::paint_color`(画期把串解析→乘系数→回写 hex);图片/画布在 `global_alpha < 1` 时走 `dim_bitmap` 逐像素降 alpha 再 blit。两后端(cairo/纯光栅)零改动即全路径生效——门面是唯一入口。
- 坑①:**叠加断言量错通道**——不透明目标上再叠 50% 红,像素 alpha 仍是 255(alpha 合成只改颜色不改覆盖度),`alpha==0` 这类判据必须落在**透明目标**上;渐变同理,要在空白位图上比 `full.a` vs `0.25.a`。
- 坑②:`round_rect_path` 自带 `begin_path` 时,阴影「外环+内环」两子路径会被第二个调用清掉——tracer 拆成 `trace_round_rect`/`round_rect_path_ccw`(不开新路径),环=一外一圈+一内逆时针圈,非零环绕只描环不叠色。
- `Style.opacity` 通道:`apply` 落 `Widget.alpha_paint`,绘制遍历进控件时 `p.set_global_alpha(继承 × 自身)`、子树画完还原(CSS 式盒树累乘);`box_shadow` 现给**硬阴影**档(偏移多层圆角矩形、`layers` 等步长描环),模糊档随 blur 能力再评估。
- 验证:render 新增 3 条(全路径系数/圆角/阴影环),render 45/46(1 红为既有 W9 基线);`ui` 的 `fill_round_rect` 上收门面后 ui/nav 行为零改;全仓 `moon check --deny-warn` 零错零警、库测试 882 条 880 过(2 红同基线)。真机观感(opacity 演示页/阴影卡片)归 `_人工测试清单.md`。

## 前端化 P2-e 帧成本对照 + 自转组件的无效重绘闸门(2026-10-14)

真机反馈「showcase 切页卡顿、页面中段组件渲染延迟」后先做对照实验再归因(探针 `experiment/showcase_cost_bench`:14 页 ×120 条文本次、1835 个绘制控件、整页重绘 20 帧,同机同树只换版本):

- **读数**:无文本布局缓存的 `380610a` = 9.9/11.95 ms 每帧(warm/cold);加了 C 侧文本布局缓存的 `323b537` = 3.35/3.25;P2-e 四批之后的 `HEAD` = 3.4/3.35。⇒ **缓存让整页重绘快约 3 倍**,**每帧读样式槽(P2-e)在噪声内**,不是卡顿来源。cold(1680 条各不相同,超缓存 1024 上限)在本机 Pango 路径没有退化到无缓存水平,但**「超限整表清空」这条策略在 Windows/DWrite 侧还没量过**——判据已留(同一探针跑两版对照),真机账本由 `SHOWCASE-PROF` / `showcase-prof.txt` 出。
- **闸门落在「这一帧我被画到了吗」**:轮播自转与动图换帧走进程级 `@core.set_timeout`,原来只判 `rotation.paused`,**所在页被隐藏时照样每个周期切页 + `invalidate()` ⇒ 整窗重绘白做**。控件层**没有指向父控件的引用**——父子互指是引用环,本工具链的计数式回收断不掉(见「分隔布局」批那条),所以不能问「祖先可见吗」。做法:core 加进程级绘制轮次 `bump_paint_epoch()`(宿主 `App::paint_frame` 每帧进遍历前 +1),`paint_at` 过了 `visible` 与视口剔除两道关才把轮次记进 `Widget.paint_epoch`,`Widget::is_painted()` 即「本帧被画到」;自转回调里 `if !w.is_painted() { 只排下一拍,不切页不置脏 }`——隐藏页省掉全部无效帧,复现可见后自动接上。
- **配套坑(测试侧,顺序敏感)**:轮次是**进程级**的,同包多条测试共用。原来那些「不画直接 `fire()` 派拍」的自转测试靠 `0 == 0` 蒙对——新测试一 bump 轮次就把它们变成假红。定则:**驱动自转的测试必须先画一帧**(与真实宿主同形),否则断言量的不是「被画到」而是初始零值。
- **验证**:新增 1 条白盒(隐藏整块 → 派拍:不切页、`invalidate` 计数不涨;恢复可见 → 继续切页),`moon test ui` 140/140、库全包 872/872、`cd gui && moon check --deny-warn` 零警告;showcase 退出打 `SHOWCASE-PROF`(帧数/布局/绘制/上屏/最坏一帧)。`frames` 数还是异常高 = 仍有别的东西在空转(下一步就按这一格判)。

## 脏区局部重绘的收窄缺陷:切段/切页不自动刷新(2026-10-14,真机反馈)

- **环境**:真机走查 `examples/showcase`,在「脏区局部重绘」落地(帧位图复用 + 按裁剪框绘制)之后;账本由示例退出时的 `SHOWCASE-PROF` 行给出。
- **现象**:切段/切页**页面不刷新**,要把鼠标悬浮到某个控件上,那块内容才跟着重画出来;`SHOWCASE-PROF`(615 帧 / 1323ms,均 2.2ms,最坏一帧 134ms)看不出异常——帧确实画了,只是只画了一小块。
- **根因**:`App.dirty_rect : Rect?` 用 `None` **一词双义**——既表示「整窗脏」又表示「本批还没有脏区」。同批里先来一次整窗请求(`invalidate()` / `schedule_paint` / `host_repaint_all` 都只写 `dirty_rect = None`),随后指针路由按 hover 变更走了 `mark_widget_rect`,而它的形态是 `Some(rect_union(dirty_rect, w.rect))`,`rect_union(None, r) = r` ⇒ **整窗请求被收窄成鼠标底下的那个小矩形**,这一帧只重画那一格,其余部分保留上一帧像素。「悬浮才刷」就是收窄后的小矩形恰好盖住了鼠标底下那一格。
- **修复**:`App` 加 `mut dirty_full : Bool`,整窗请求(`schedule_paint`、`host_repaint_all`)置位;局部置脏改走纯函数 `accept_widget_rect(full, cur, r)`——`full` 为真时**只维持不收窄**;`paint_frame` 用 `dirty_clip(full, rect)` 取这一帧的裁剪框(整窗请求 → `None` 即不裁),取完把标志与脏区一起复位。两个判定抽成纯函数是为了能钉桩:宿主 `App` 要真窗口,而这两个判断不需要。
- **通用口径**:`Option` 承载「两种不同的无」迟早出这类事故——同一个 `None` 表示「整窗」又表示「空集」时,任何「往累积里并一笔」的操作都会把强语义写成弱语义。要么加一位标志(本批做法),要么换成显式枚举(`Whole | Region(Rect)`)。
- **验证**:core 新增 1 条纯函数回归(未请求整窗时照常累积成并集;已请求整窗时局部置脏不得写成小矩形;裁剪框整窗优先),`moon test core` 133/133、分包全跑 882/882(13 包逐个绿)、`cd gui && moon check --deny-warn` 零警告。真机复验(用户执行):showcase 切段/切页后**鼠标不动**应立即看到新页,复跑 `moon run examples/showcase` 退出贴 `SHOWCASE-PROF` 行(`frames` 不应因这一改动上涨——只在同批已有整窗请求时维持整窗语义)。

## Windows-only 的 `GUID` helper 漏在守卫外:非 Windows 侧整个库编不过(2026-10-14)

- **现象**:`moon run examples/showcase` / `moon test ui` 起不来,报 `sys/sys_stub.c:2023:45: error: unknown type name 'GUID'`(电源方案那批代码)。
- **根因**:`yue_sys_pp_current_guid` / `yue_sys_pp_set` 两个导出函数体内都写了 `#if defined(_WIN32)` 分支 ✓,但它们共用的两条 `static` helper(`sys_pp_guid_string` / `sys_pp_parse_guid`)签名里带 `GUID`,却写在所有守卫之外——`static` 且未被调用也要过类型检查,Linux/mac 上 `windows.h` 没进来了就当场炸。
- **修复**:两条 helper 一起圈进 `#if defined(_WIN32) ... #endif`(它们只在 Windows 分支里被调用,Windows 侧行为零变化)。
- **通用口径**:平台桩里**只要类型来自平台头**(GUID / HINSTANCE / PangoLayout…),函数本体就得整段进守卫,不能只守函数体而把签名露在外面;`static` helper 同样算。加完 C 代码后至少跑一次**非目标平台**的编译(`cd gui && moon check`),这条守卫漏没漏一眼就知道。
- **验证**:`moon check sys ui --deny-warn` 过、`moon build showcase --target native` 链接过、库全包 924/924。
- **同类复发(2026-10-14 windowctl 批)**:同一口径第二次踩——`sys_win_find_ctx_t`/`sys_win_find`/`sys_win_find_cb`/`sys_mon_find_t`/`sys_mon_find_cb`/`sys_monitor_index`/`sys_win_enum_cb`/`sys_wcs_icontains` 这批 `static` helper(签名带 `HWND`/`HMONITOR`/`BOOL CALLBACK`)照旧写在守卫外,Linux 侧 `moon test sys` 报 `sys_stub.c:2338: error: expected ‘=’, … before ‘sys_win_find_cb’`。修复仍是整块圈进 `#if defined(_WIN32)`(两块:枚举 helper、find+标题匹配 helper;`sys_win_blob_t`/`sys_win_blob_append`/`sys_win_enum_ctx_t` 只用 stdlib,留守卫外)。
- **收口动作(不复发的前提)**:凡给单平台加过 C,**当批必须在对侧平台跑一次 `cd gui && moon test <该平台包> --target native`**——导出函数体有 `#else` 分支不会炸,只有守卫外的 helper 才炸,而这只有对侧编译器看得到;Windows-only 的 `sys` 批在 Linux 上跑,`win`/`dbus` 那类反向同理。本批 Linux 读数:`moon test sys` 182/182、库全包 928/928、`cd gui && moon check --deny-warn` 与 `cd examples && moon check --deny-warn` 零警告、`moon build showcase --target native` 链接通过。
- **第三种踩法(2026-10-14 平台批④音量段)**:守卫范围**划过头**——整段(含 `yue_sys_vol_get` / `yue_sys_vol_write` 两个导出函数)一起被 `#if defined(_WIN32)` 圈住,而这两个函数体内已经各自写了 `#else` 退路。Linux 侧不是类型报错而是**链接报 undefined reference**(`sys.whitebox_test.o: undefined reference to yue_sys_vol_write`),因为 MoonBit 侧声明照写、C 侧整个符号没了。口径补一条:**导出函数本体恒留在守卫外**(它自带两分支),守卫只圈平台专属的 helper/常量/GUID 表;`#endif` 要收在 helper 段尾,不能盖到导出函数上。本批 Linux 读数:sys 185/185、库全包 932/932、`moon build showcase --target native` 链接通过。


## 表格悬停不是整行 & 「添加一行」没反应:脏区只标最深那颗 + 去重 Store 存了被原地改的数组(2026-10-14,真机反馈)

- **现象①**:单选表格鼠标悬停时只有指针底下那一格变色,整行底色不亮(用户确认所有表格都有这问题)。
- **根因①**:不是绘制问题——无头探针实测,`set_hover(cell.id)` 之后整行(440px)从 x=10 到 x=400 全是 `fill_hover` ✓。坏在**脏区范围**:悬停是父链语义(与 CSS `:hover` 同义,`set_hover` 会把整条祖先链标 `hovered`),而宿主在指针路由后只标了「旧/新悬停那颗控件的矩形」——行画了整行底色,重绘窗口却只有鼠标那一格,于是看起来「只亮一格」。
- **修复①**:`App::mark_state_chain(id)` 沿命中链标脏——最深那颗必标,祖先只在**自己的绘制随状态变**时才标。这个「会随状态变」由 `@style.apply` 落成 `Widget.paints_state`(样式带 `hover`/`active`/`focus` 任一桶即为真),core 不认识样式层、只读这个布尔。链上没有状态祖先时代价仍是一格,不会因为改用链标脏就退回整窗。
- **现象②**:showcase 点「添加一行」表格不长行。
- **根因②**:Store 的内建去重按**值**比(`T : Eq` 时走 `set_eq`),而示例把 `lang_base` **这个数组对象本身**存进了 Store,之后「添加一行」原地 `lang_base.push(...)` 再 `table_rows.set(lang_base)`——新旧值是同一个对象(内容也一起被改了),必然相等 ⇒ 通知被吞,订阅里的整表重建根本不跑。换 `set(rows.copy())` 也一样被吞(存着的那个对象已经是新内容)。
- **修复②**:初值存快照 `Store::new(lang_base.copy())`,让 Store 里的值与原地被改的数组不是同一个对象 ⇒ push 后 `set` 的新旧值才真的可比、通知正常发出(排序路径同样受益:顺序变了才通知,顺序没变就跳过——正是去重该做的事)。
- **通用口径**:① 任何「父链语义」的状态(悬停/按下/焦点)都必须在标脏时覆盖到**会自绘该状态的祖先**,否则局部重绘会画出半更新的一帧;② 「原地改数组 + set 同一个数组」在去重 Store 上是死路,要么每次给新快照,要么显式 `set_always`。
- **验证**:`moon test core` 136/136 新增 1 条钉桩(带状态桶的祖先被并进脏区→宽 ≥200;链上无状态祖先→脏区宽 ≤50.5),库全包 922/922,`cd gui && moon check --deny-warn` 与 examples 模块零警告(顺带删掉因此不再被引用的 `App::mark_id_rect`)。真机复验:悬停整行变色;点「添加一行」表格多一行且回显跟着走。

## 时间线连接线断成几截:行间距用 `row_gap` 分行、线只画在行内(2026-10-14,真机反馈)

- **现象**:showcase「数据展示 → 时间线」三个节点之间的竖线是断的(每处间隙空 12px)。
- **根因**:每行的标记格只在自己的行盒里画线(`fill_rect(9, top, 2, bottom - top)`,`top/bottom` 由首/末行夹到点心),而行与行之间的 12px 是容器 `row_gap` 给的——**那段不属于任何控件**,没人画它,线就在每一处间隙断开。
- **修复**:行间距画进**本行**(非末行的 marker 与行盒长到 `height + gap`,末行不带间距),`timeline` 不再传 `row_gap`。点心仍按内容带算(`cy = height / 2`),所以圆点位置与首/末行的起止都没变,只是线多长了一段属于自己的间距。修后行高实测 68 / 68 / 56,行位仍 0 / 68 / 136(整体高度不变)。
- **通用口径**:凡是「跨行连续的装饰」(连接线/时间轴/表格分隔线/滚动条轨道)都不能靠容器间距留白——间隙不属于任何绘制单元。要么把间距画进本行(本批做法),要么让容器自己画那条贯通线。
- **验证**:`moon test ui` 156/156——时间线那条用例改成断言行高 `(68, 68, 56)` 并新增两处**间隙必须有线**的像素断言(`pixel(10,60)`、`pixel(10,130)`);对照实验=改回 `row_gap` + 行内不带间距,当场红 `(56,56,56) != (68,68,56)`。库全包 921/921、`cd gui && moon check --deny-warn` 与 examples 模块零警告。真机复验:时间线竖线从首行点心一路连到末行点心,中间无断口。

## 面包屑「点击不导航」:当前项按位置判(末项)而不是按导航状态判(2026-10-14,真机反馈)

- **现象**:showcase「导航组件 → 面包屑」点末项「基础组件」没反应。
- **根因**:组件自己的注释写的是「**当前项**深色不可点」,代码却按位置判——`is_last` 既当「当前项」用来上深色,又当「不可点」用来拦 `on_click`。演示给的三项是静态列表 `["数据展示", "导航组件", "基础组件"]`,当前页是中间那项 ⇒ 末项既不是当前页又被判成「当前项」,永远点不动。组件逻辑没坏(点非末项确实写 Store),坏在**「当前」的定义取错了**——导航状态才是唯一的权威。
- **修复**:可点与配色都改按 `selected.get() == mine` 判:等于导航状态的那一项深色、点它不改值;其余一律可点直达(含末项)。分隔符 `/` 照旧不可点。
- **配套**:nav_wbtest 那条用例原本断言「末项不改值」(照着错规则写的),改成「末项也直达 + 当前项不改值 + 分隔符不改值」;对照实验=把判据换回按位置(`i < n - 1`)当场红 `"列表" != "详情"`,换回即绿。showcase 段说明同步(原文写「当前项无特殊高亮、点击直达」,与代码两头都对不上)。
- **通用口径**:「哪一项是当前」只有一个来源——绑定的那个 Store。任何用位置(末项/首项)代替状态做判据的写法,在演示与真实层级不一致时就会露出「看着能点却点不动」的死角。
- **验证**:`moon test ui` 156/156、库全包 921/921、`cd gui && moon check --deny-warn` 与 examples 模块零警告。真机复验:面包屑三项逐个点都能换页,只有当前页那一项不变灰也不响应。

## 时间弹层的标题画在面板上不占位:第一行步进被压住(2026-10-14,真机反馈)

- **现象**:时间选择器弹层顶部「00:00」与第一行 `[−] 时 [+]` 叠在一起。
- **根因**:那行时间不是子控件,是面板自己的 `on_draw` 里画在 `(0, 0, w, 28)` 上的一块浮墨;而步进/按钮是真正的子项,从内边距 `top=10` 起排 ⇒ 第一行落在 y=10..42,正好被 0..28 的标题压住。**绘制层「顺手画个头」不等于占了一个布局位**——同一条坑在 `md_marker`(序号格没注册测量→0 高、数字掉到基线)已经记过一次。
- **修复**:标题改成**占位的子件**(高 28、宽 100%),面板 `on_draw` 只留底色与描边;顺手把内边距补成四边(原来只给 `top`/`left`,按钮行贴死下边缘)。修后弹层子项实测:`y=10 h=28`(标题)→ `38/32` → `70/32` → `102/28`,面板高 140,相邻零重叠。
- **配套(测试侧)**:三条按 `panel.children()[0]` / `[2]` 取步进行与按钮行的既有用例索引整体后移一位(标题现在是第 0 个子项),注释写明「标题是占位子件」;另加一条布局钉桩——子项数=4、首项是 28 高标题、逐对相邻不重叠、面板高度包住内容。
- **验证**:`moon test ui` 156/156、库全包 921/921、`cd gui && moon check --deny-warn` 与 examples 模块零警告。真机复验:时间弹层顶部时间独占一行,步进两行与取消/确定依次排开、四周留白一致。

## `stroke_rect` 是内侧描边,调用点却按居中口径给参:整圈往右下偏 1px(2026-10-14,真机反馈)

- **现象**:色板(color_picker)那一格格色块的描边看着「位置偏了」——左/上边留一条 1px 的色底,右/下边描边贴死边缘。
- **根因(逐像素量出来的)**:门面对外口径写死「`stroke_rect` 描边落在矩形**内侧**」(两后端同实现:cairo 桩 `cr_stroke_rect` 与纯光栅 `Raster::stroke_rect` 都按 `lw` 往里画并做像素吸附),但**全仓 28 处调用点按的是 Canvas/CSS 那套「描边居中」习惯**,给的是 `stroke_rect(0.5, 0.5, w - 1.0, h - 1.0)`。内侧语义下这条调用把环画进 `[0.5, 1.5]` → 吸附到第 1 列,而右/下边落在最后一列 ⇒ 环整体往右下偏 1px。探针读数(26×26 色格,中线一行):修前 `F B F…F B`(第 0 列是填充),修后 `B F…F B`(第 0 列与第 25 列都是描边)。
- **换算规则(居中口径 → 内侧口径)**:`(x, y, w, h)` 配线宽 `lw` ⇒ `(x - lw/2, y - lw/2, w + lw, h + lw)`。所以 1px 外圈就是 `stroke_rect(0.0, 0.0, r.w, r.h)`;往里缩一圈的焦点环 `stroke_rect(1.5, 1.5, w - 3.0, h - 3.0)` ⇒ `stroke_rect(1.0, 1.0, w - 2.0, h - 2.0)`。
- **改动范围**:ui 族(overlay/datepicker/form/virtlist/table/nav/datetime/scroll/message_box/declarative)与 chart 族(tooltip/boxplot/draw/treemap)、示例两处(sysmonitor、showcase 的 events/canvas)一起切过,共 28 处;`fill_rect`/`clip_rect` 不受影响(它们本就是整数像素盒语义)。
- **一条测试跟着几何改**:form_wbtest 的按钮焦点环用例原先采第 1 列像素(那是照着偏移后的错几何写的),现在采第 0 列并在注释里写清「内侧描边、环贴盒边」;另加一条色板对称性钉桩(左右同列、上下同列、描边不等于填充)——偏移回归会当场红。
- **验证**:`moon test ui` 155/155、库全包 920/920、`cd gui && moon check --deny-warn` 与 examples 模块零警告。真机复验(本机 Linux/X11):色板每格四边描边等宽、不再有一侧露出色底;按钮/输入框/面板/浮层的 1px 边框四边对齐。

## 输入框默认吃不到键盘焦点:`focus_id=0` 的口径要收在库里(2026-10-14,真机反馈)

- **现象**:showcase「表单组件」页的输入框点不进、打不了字;同页缺 EP 那个清空 ✕;「数据输入」的步进器三格高度看着不齐、没粘成一块。
- **根因①(点不进)**:宿主按「命中路径上第一个非零 `focus_id`」判可聚焦(`Widget::focusable_at`),而 `input` / `textarea` 的 `focus_id?` 默认 **0** —— 不显式给号就是**永久不可聚焦**。示例与使用者都得自己记得给号,等于把「输入框打不了字」埋进每个调用点(探针实测:不给 focus_id 时 `focus_id=0`、`focusable_at` 返回 `None`)。
- **修复①**:文本类组件默认**自动分配**焦点号(`auto_focus_id`:未给就从 1000000 起递增,避开使用者手写的 21/101 那类小序号;显式给了仍以它为准)。Tab 环绕按注册顺序=挂载顺序,与树序一致。`select` / `button` 的 `focus_id` 保持原口径(它们的可聚焦是刻意 opt-in,涉及浮层与激活键语义,不在这个批里动)。
- **根因②(焦点环/光标不重画)**:`App::mark_focus_rect` 把**焦点栈的 id** 直接喂给 `mark_id_rect`,而后者按**控件实例 id** 查树(`root.by_id`)——两个 id 空间不是一回事:命中不到就整窗兜底(白画),恰好撞上某个实例 id 就把脏区标到**别的控件**上,新焦点格的焦点环与光标当帧不重画。
- **修复②**:新增 `App::mark_focus_id_rect`,走 `find_by_focus_id` 查树(查不到才整窗兜底);Down 里那次 `mark_id_rect(id)` 同步切过去。
- **`clearable`(清空 ✕)**:`input` 补同名参数(与 EP 一致**默认关**):有内容且「悬停或已聚焦」时右缘画一块 14×14 的 ✕(先盖一小块底色,长文本不与之叠字),点它整框清空并回写 Store、这一次按下不再定位光标;禁用态与只读态都不画。密码框按 EP 不给清空口。
- **步进器共框**:旧形态 `[-] 值 [+]` 各画一圈边框(左右圆角、中间方角),看着就是三个没粘住的盒子——**布局量出来其实三格同高**(都等于 `control_height`),不齐的是边框。改法:外框交给行容器按样式槽画一次(底色/描边/圆角/1px),三格只画自己的悬停底(内缩 1px 不盖外框)、内容字与靠内侧那条分隔线;整组宽 108 固定,不再随父容器拉伸。
- **验证**:`moon test ui` 154/154,新增 3 条——不给 focus_id 也能被 `focusable_at` 命中且键入回写 Store(并验显式号优先、两个自动号不撞号)、`clearable` 悬停时热区像素确有变化且点它 Store 归空、步进器三格同高同边首尾相接 + 点 +/- 改值 + 触界不再改值;库全包 918/918、`cd gui && moon check --deny-warn` 与 examples 模块零警告。真机复验:表单页输入框能点进能打、悬停出 ✕ 点它清空、步进器三格粘成一块。

## 文本帧级批的三件桩双定义:Linux 链接失败(2026-10-14,`moon run examples/showcase` 当场报)

- **现象**:`/usr/bin/ld: ... multiple definition of pt_flush`(以及 `pt_flush_if_overlap`/`pt_set_batching`),两处分别是 `gui/build/libyue_text_pango.a(stub.o)` 与 `_build/native/debug/build/NoahLiu/native-gui/text/libtext-*.a(stub.o)`——同一个 `stub.c` 的两个编译产物。
- **根因**:Linux 上 `gui/text/stub.c` **被编译两次**:prebuild 带 `-DWM_STUB_PANGO` 编进 `build/libyue_text_pango.a`(真实现),moon 的 native-stub 拿不到 pango 头、不带宏再编一次——那次**必须落空**(文件末尾的注释就写着这条纪律:落不进任何分支、编成空翻译单元,真实现由归档提供)。帧级文本批新增的三件写在文件最外层 `#endif` 之后的 `#ifndef _WIN32` 里,落在所有分支之外 ⇒ 两次编译各出一份。Windows 侧靠 `_WIN32` 排除躲过了,Linux 侧没躲过。
- **修复**:三件挪进分支——`WM_STUB_PANGO` 分支一份(Pango 逐段即绘即混、不攒批,冲刷是空操作)、`#elif !defined(__linux__)` 分支一份(macOS 占位);Windows 的真实现仍只在 `dwrite_text.cpp`;Linux 的 native-stub 那次继续编成空 TU。
- **通用口径**:往 `gui/text/stub.c`(同构的还有 `render`/`win` 等按「单一 stub.c 多分支 + prebuild 宏」组织的平台桩)加跨平台函数,只能加进**已有分支**或新开一条 `#elif`,写在最外层 `#endif` 之后就会与 prebuild 归档双定义。判据一条命令:`nm --defined-only _build/native/debug/build/NoahLiu/native-gui/text/libtext-*.a | grep -c <符号名>` 应为 **0**。
- **验证**:`moon build examples/showcase --target native` 从 workspace 根与 `examples` 模块各跑一次都通过、`showcase.exe` 出件;`nm` 复验 moon 侧归档里 `pt_flush` 定义数 0;`cd gui && moon check --deny-warn` 零警告、text+core+ui+render 360/360。

## 页面构造期排的定时器永不触发:图表页一直「暂无数据」(2026-10-14,真机反馈)

- **现象**:showcase「图表 → 折线」两段画布恒为「暂无数据」、y 轴停在 0..1,仪表盘也不动;「暂停推点」勾与不勾都没反应(这条正是早前那条「点线图推点按钮没用」反馈的剩余部分)。
- **根因**:`@core.set_timeout` 走的是**进程级**延时通道,这条通道由 `App::new`(内部 `install_host_hooks`)安装;没有宿主时它是**空操作并返回 0**(`core/loop.mbt` 的契约)。而示例里 `page_charts(app)` 是 `@ui.mount_window([...])` 的**实参**,求值早于建窗——所以「页面函数体最后一行排第一拍」这种写法排进的是空通道,回调永不触发,自重排的循环也就永远起不来。数据侧没问题:`series_push` 走 `set_always`(绕开 Store 去重)、画布在订阅回调里 `invalidate()`,都是通的。
- **修复(示例侧口径)**:**第一拍挂在挂载回调上**——`@ui.row([...charts...], handle=fn(_) { line_pump() })`。`view` 的 `handle` 在 `mount_children` **之后**跑,而 `mount_window` 先建 App 再挂树,所以排定时器时通道已经装好、图表子件也已订阅到位。页面构造期那两行 `let _ = @core.set_timeout(...)` 删除;页内代码示例串同步改成挂载形态(不然演示文本继续教错写法)。
- **通用口径**:任何在「页面/组件构造函数」里排的定时器、以及任何读 `set_timeout` 返回句柄去 cancel 的写法,都要放到挂载后(或宿主 App 建好之后);`set_timeout` 返回 0 就是「没有宿主」的信号,别把 0 当句柄存。
- **同批一条(同一张截图看到的)**:段说明 `@ui.text(s.desc, max_width=900.0)` 没给 `wrap=true` ⇒ 长说明是**一条不折行的 900px 文本**,超出部分整片被裁(截图里折线段说明末尾断字)。改 `wrap=true`,段容器不再被单行长文本撑宽。
- **验证**:`cd examples && moon check showcase --deny-warn` 零警告、`cd gui && moon check --deny-warn` 零警告、库全包 915/915 不回归。真机复验(用户):打开「图表」页 → 折线两幅应在 0.5s 一拍爬出三角波、y 轴随值自适应、右端有最新值标注;勾「暂停推点」曲线停住、取消勾选继续;仪表盘左环应 2Hz 平滑走。

## yoga-mbt 自由空间漏减行间隙:grow 项吃掉 gap 把整行顶出容器(2026-10-14,真机反馈「复制按钮还是有问题」)

- **现象**:showcase 段正文代码区那行(左「代码」+ 中间 grow 撑开的空文本 + 右「复制」)里,按钮右半边裁在窗口外。同类形态到处都在用(`@ui.row([..., spacer, 按钮], column_gap=...)`),只是别处溢出的是一点边距、没人注意。
- **根因**:本端口的 §9.7 分配里,`initial_free`、循环内的 `remaining`、auto margin 的 `free`、justify-content 的 `free2` 都只减「子项外框之和」,**没减本行的间隙总和** `gap x (n-1)`;而定位阶段又逐项加 `main_gap` ⇒ 有 grow 项时它正好多吃 `gap x (n-1)`。
- **最小判据**(钉在 `modules/yoga-mbt/src/layout_wbtest.mbt`):行宽 100、`column_gap=10`、子项 [固定 30, grow 1] ⇒ grow 项应为 60,修前算成 70(整行 110)。
- **修复**:行分配前先算 `gap_total = main_gap x (line.length()-1)`,上述四处自由空间统一减它(规范:间隙占位、不参与 grow/shrink 分配)。
- **实测**(无头探针挂真实页面树,窗口 1010、侧栏 180 → 视口 830):修前 spacer=728、按钮 `x=962 w=50` → 右边界 1012,越过窗口(1010)与滚动条(1002);修后 spacer=712、按钮 `x=946..996`,正好贴在行右界(内容 802 + 左右 padding 14)上。
- **验证**:`moon test src`(yoga-mbt)102/102(含新增这条)、库全包 916/916、`cd gui && moon check --deny-warn` 与 examples 模块零警告、`moon build examples/showcase --target native` 通过。这条与「段条换行」「视口 min 0」是三个独立问题,叠在一起才造成用户看到的「正文塌 + 按钮裁一半」。

## 段条「超宽自动换行」是假口径:`Style` 补 `flex_wrap` 才真换行(2026-10-14)

- **现象**:showcase 页面顶部的段条(segmented)段数一多就横向溢出被裁,而 `shared/section.mbt` 的注释写着「超宽自动换行」。
- **根因**:本栈 `ui` 从不写 `flex_wrap`,样式层也**没有这个属性**(CSS 有 `flex-wrap`,我们的 `Style` 少一条),所以任何容器都是 `NoWrap` —— 注释描述的是一个不存在的能力。
- **修复(按「属性名 = CSS 属性名」补进样式层,而不是给组件开参数)**:`Style` 开 `flex_wrap : FlexWrap?`(`types.mbt` 用 `pub using @yoga {type FlexWrap}` 引类型短名),工厂收 `flex_wrap=`、`merge`/`empty_style`/setter 同步、`apply` 落 `Node::set_flex_wrap`。
- **换行的两条必备配套(真机第一版只加了 `flex_wrap`,结果把正文压扁)**:
  1. **段条放在列里,不要放在 row 里**:row 的交叉轴不拉伸,换行容器按内容定宽(实测 1000 可用只给到 450),段被折成六七行;列的交叉轴默认 stretch ⇒ 拿到整宽,段多才按整宽折。
  2. **换行容器与父链每一层都显式 `min_height=0`(横向同理 `min_width=0`)**:规范 §4.5 里列内子项的 `min-height:auto` 取其 **min-content 高**,而可换行行容器的 min-content 高 = 全部子项堆叠(6 段 ×30 + 5 间隙 = 200)。这条下限沿父链一路上传——实测段条 224px、正文从 646 掉到 476。引擎行为符合规范、不是 bug:显式归零才是段条这类容器该有的写法。
- **最终形态**:`strip = @ui.col([@ui.segmented(names, selected, class=[style(flex_wrap=Wrap, row_gap=4.0), style(min_height=0.0, min_width=0.0)])], padding=10.0, class=[style(min_height=0.0, min_width=0.0)])`。
- **验证**:`moon test style` 26/26 新增 1 条布局钉桩(100 宽行内容器放两个 60 宽子项:`NoWrap` 时第二项 `top=0`,`flex_wrap=Wrap` 后 `top>=20`);`modules/yoga-mbt` 新增 1 条钉住 §4.5 那条下限与归零后的取值(同一棵树:min:auto 时 strip 高 200,显式 `min_height=0` 后 30)。修完用无头探针量真实页面树(1200×700):段条 54、正文容器 646、代码文档页视口 652 / 内容 808(可滚 155)——段条不再吃高度,正文有确定视口且内容超出即可滚。`cd gui && moon check --deny-warn` 零警告、库全包 915/915、yoga-mbt 全绿。

## 滚动容器视口被内容撑高:内容超出窗口却滚不动(2026-10-14,真机反馈)

- **现象**:showcase 段正文超出窗口高度,滚轮与滚动条都没有可滚的量(内容被底部直接截断)。
- **根因**:`scroll_view` 的视口节点没有设 `min-height`。Yoga 的 flex 子项默认 **min-size = auto**(内容多大就不许小于一屏那么多),于是视口被自己的内容顶到自然高——`view_h == content_h`,`max() = content_h - view_h` 恒为 0,滚轮与滚动条算出来都是「不需要滚」。调用点写 `handle=fn(v){ v.node.set_flex_grow(1.0) }` 只给了 grow,救不了这条默认值。
- **对照实测**(无头探针,20 行 ×20px 内容放进 240×140 的父容器):修前 `viewport=676 content=676`(视口等于内容高)→ 修后 `viewport=200 content=676`(视口停在父给的尺寸,内容按自然高撑开)。
- **修复**:`scroll_view` 内部给视口写 `min_height=0` 与 `min_width=0`(库级收口,所有调用点一起受益:showcase 段正文与侧栏、native-app、`virt_list` 的宿主等)。显式给了 `height=` 的用法不受影响(显式尺寸赢过 min)。
- **验证**:`moon test ui` 151/151,新增 1 条钉桩——只给 `flex_grow` 不给高度时:视口高 ≤ 父高、`content_h=400`、`view_h=140`、`max()>200`,且 `scroll_by(60)` 后内容节点确实上移;库全包 914/914、`cd gui && moon check --deny-warn` 零警告、examples 模块零警告。真机复验:showcase 段正文与侧栏长列表应可滚轮滚、可拖滚动条。

## Markdown 页两处缺陷:样式区间单位错口径 + 富文本行从不折行(2026-10-14,真机反馈)

- **现象**(showcase「代码文档 → Markdown」段):① 中英混排段落里粗体/斜体/行内代码/链接那几段出豆腐块并互相压字;② 右边缘整片被裁字;③ 代码区顶行的「复制」按钮有一半在可视区外;④ 内容区纵向滚不动(同批另查,见下一条)。
- **根因①(单位口径)**:`md_span_ranges` 按 **UTF-16 code unit** 累计区间端点,而 `AttributedText` 的契约是 **UTF-8 字节下标**(`text/attributed.mbt` 头注与 `rt()` 传给 C 的 `tlen` 都是字节;C 侧 Pango 直接把 `start_index/end_index` 当字节索引用,Windows/DWrite 侧再经 `ptw_widx` 换算)。一个汉字 3 字节只算 1 个 code unit ⇒ 区间整体前移,样式落到前面的字符上、端点还会切进字符内部(真机即豆腐块 + 压字)。纯 ASCII 段两者相等,所以这段代码在英文示例里一直是「看起来对」的。
- **根因②(从不折行)**:`md_rich_label` 用 `wrap=false` 并把节点宽设成**整段自然宽**(实测:一段在 `width=480` 的文档里量出 656px)。后果是右边缘整片裁字,并且段容器的宽度被这条超宽行撑到可视区外——「复制」按钮排在行尾,于是被裁一半。
- **修复①**:改 `md_byte_len`(按码点算 UTF-8 序列长度)出区间;`md_span_ranges` 的口径注释与文件头同步改成「UTF-8 字节」。
- **修复②**:构造期贪心折行——中文与全角标点**逐字**为单元(中文没空格,断点只能在字之间)、拉丁词连尾随空格为一个单元(不在词内断)、`\n` 为硬换行、**单个单元就超宽**(长 URL)时按字符硬切;一行一个 `AttributedText`,删除线横线按该行像素区间画,链接命中改成「先按 y 定行、再按行内像素区间定段」。折行宽度按容器派生:`md_narrow(ctx, by)` 给列表项(扣标记列/复选框)、引用块(扣竖条)、脚注定义、定义列表各自收窄,表格单元格按列宽 `max_w=ctx.width/列数`。
- **工具链读数**:MoonBit `String.length()` 返回的是 **UTF-16 code unit 数**(`"甲乙"=2`、`"👍"=2`、`"abc"=3`),既不是字节数也不是码点数;`String.sub(start=,end=)` 也不是字节口径。所以「按字节契约」的 API 一律不能拿这两条当长度 oracle,字节长度要自己按码点算或走 `@utf8.encode`。
- **验证**:`moon test mdview` 31/31,新增 4 条——字节读数(`前👍中` 后粗体段应落 `[10,16)`)、区间端点必须落在字符边界上、折行后没有任何子孙宽过文档宽且段落高明显多于一行、长 URL 必须硬切。**判据有效性已对照实验**:把 `md_span_ranges` 换回旧的 UTF-16 累计,两条新判据当场红(`4 != 10`、「区间终点切进字符内部: 4」),换回即绿。库全包 913/913、`cd gui && moon check --deny-warn` 零警告、`cd examples && moon check --deny-warn` 零警告。
- **待真机复验**(用户执行):豆腐块/压字是否消失、右边缘是否不再裁字、复制按钮是否完整。「内容区纵向滚不动」另查得根因(视口被内容撑高),见下一条。

## 观感修正:`badge_dot` 由方角改真圆点(2026-10-14)

- **现象/根因**:`badge_dot` 注释与命名都是「圆点徽标」,但绘制走的是 `fill_rect`——出来是个 8×8 方角块。属前端化 P2-e 记档的边界项(当时只迁样式通道、不改画法)。
- **修复**:改走 `Painter::fill_round_rect`,默认半径 = 短边一半(内切圆);`class` 给了 `border_radius` 就按它,并夹到短边一半以内——想要方角写 `border_radius=0.0`,旧画法这条路仍然可达。底色仍从样式槽现取(`color_of(s.background_color, "")`),主题切换照旧跟。
- **验证**:`moon test ui` 150/150,新增 1 条像素回归——16×16 档下左上角那格无墨、中心有墨(内切圆判据),`class=[style(border_radius=0.0)]` 档左上角有墨。真机观感(`showcase` 数据展示页 / `native-app` 的圆点)归 `_人工测试清单.md`。

## GTK 后端的窗口增强是空实现:改标题与无边框「按了没反应」(2026-10-14,真机反馈)

- **现象**:窗口页四个按钮只有「全屏切换」有效,「改标题」「无边框切换」按下去毫无变化,「还原尺寸」也看不出作用。
- **根因(三条各不相同)**:① 改标题 / 无边框——`gui/win/stub.c` 的 **GTK 分支是 W20e 留下的空实现**(`wm_set_title` / `wm_set_borderless` 整段 `(void)id;`),当年段首注释写的口径是「属 Linux 后端内部事务、不进路线图」,而 Win32 分支两条都实做了:于是 MoonBit 门面调过去无害、屏幕上什么都没有。② 还原尺寸——`wm_window_set_size` 在 GTK 分支**是真实现**(`gtk_window_resize`),但演示按钮写死 `set_size_pixels(1280, 720)`,而 1280×720 正是 showcase 的启动尺寸:不手动拖过窗口就点不出差别,这是演示缺判据不是后端缺口。③ 全屏——Win32 与 GTK 两分支都实做,所以只有它「有用」。
- **修复**:①GTK 分支补上 `gtk_window_set_title`(id 越界、`win->window == NULL`、`title == NULL` 三道守卫)与 `gtk_window_set_decorated(on ? FALSE : TRUE)`;同段的**图标 / 最小尺寸 / 自绘标题栏拖拽区仍是空实现**,理由写进段首注释(GdkPixbuf 的源与 HICON 不同宗;`geometry_hints` 未接;`begin_move_drag` 要按下时的指针与按钮号,本栈还没把这条请求送到窗口层),不留「看着像没坏」的空白。②演示按钮改成 1280×720 ↔ 960×540 两档切换(按钮名改「尺寸切换」、段文案同步),每次点击都有可见结果。③MoonBit 侧 `set_title` / `set_borderless` 的文档从「非 Windows 后端空实现」改成**逐后端点名**(Win32 改样式位重算外框 / GTK 走 `set_decorated` / macOS 仍空)。
- **验证**:窗口级动作无头判不了(要真窗口 + 窗口管理器),按规则 6 交真机。本批门禁读数:`cd gui && moon check --deny-warn` 零警告、库全包 937/937、`cd examples && moon check --deny-warn` 零警告、`moon build showcase --target native` 链接通过(gtk-3 本就在链接面上)。
- **口径**:后端能力不齐时**演示不许放按钮**(本仓先例:「最大化/还原」「置顶」因 Win32 段没写就不放按钮)。空实现的 API 留在门面里可以(跨平台形状一致),但演示与文档必须点名哪个后端没接。
- **待真机复验**(用户执行):「改标题」→ 标题栏变成「组件库演示板 · 标题已改」(顺带验 UTF-8 中文标题);「无边框切换」→ 标题栏与边框消失、再点回来;「尺寸切换」→ 两档大小来回可见;「全屏切换」照旧。

## 分隔把手拖动不跟手:增量按把手自己的局部坐标算,把手平移后把上一帧位移扣了回去(2026-10-14,真机反馈)

- **现象**:嵌套布局页的 `split` 把手,拖动过程中不跟手——拖到一半会往回弹。
- **根因**:`splitter_impl` 的拖动增量用的是**把手的局部坐标**(`ev.x` 由宿主按 `ev.x - w.rect.x` 下发),而把手本身会随首栏变宽而平移。于是每一帧的增量都少掉了上一帧把手自己的位移:`nw = first0 + (鼠标局部 - 起手局部)`,其中鼠标局部已经减过新的把手原点。实测(400 宽、ratio 0.5、起手在把手中心):第一次移动(鼠标 +50)把手落到 250 **看着对**;第二次移动(鼠标累计 +60)把手却退回 **210**——正确值 260。位移越大退回越多,观感就是"拖不动/往回弹"。
- **修复**:起手与移动都换成**窗口坐标**(`ev.x + s.rect.x`),增量与把手自己的平移解耦。这条换算即使在「一批事件里 rect 还没重排」的情况下也精确:局部值本来就是「窗口值 - 当时那个 rect.x」,加回同一个 rect 就还原。夹取口径不变(`min_first` / `min_second` 照旧生效)。
- **验证**:新增 `gui/ui/split_wbtest.mbt` 两条(本组件此前**零测试**)——① 起手 `hit_test` 必须命中把手、拖 +50 落到 x0+50、再拖 +10 落到 x0+60(旧口径这里退回 210)、抬起后再拖不改布局;② 两个最小宽度夹取(把手最远停在 `总宽 - 8 - min_second` = 312)。测试走的是宿主同款路径:`dispatch_pointer_to(把手 id, ...)` 模拟指针捕获期(直接对根调 `dispatch_pointer` 不带捕获,第二个事件就命中到别的栏里去了——第一版测试就是这么假红的)。**判据有效性已对照实验**:把 `win = at + origin` 换回 `win = at`,第二条移动当场红(实测 210)。`moon test ui` 160/160。
- **残留的那一半**:`@core.invalidate()` 走的是整窗广播(`host_repaint_all` 置 `dirty_full`),一次拖动 = 一拍一帧全视口重绘,debug 构建实测帧成本百毫秒量级——这一档是「已知差异」里的帧成本项(TODO §6.6),不是坐标问题;先确认坐标这条修完后再看观感是否可接受。
- **待真机复验**(用户执行):拖动把手是否跟手(快速来回拖动不往回弹)、两个最小宽度边界仍夹得住、抬起后不再跟随。

## 提示条 `closable` 只有热区没有标记:看不见的热区等于没有按钮(2026-10-14,真机反馈)

- **现象/根因**:`alert(..., closable=true)` 的 `on_draw` 只画浅底 + 左缘 3px 强调条 + 标题/描述,`closable` 那条分支**只装了 `on_pointer` 的右上角 24×24 热区,一个像素的标记都没画**。演示文案写着「点我右侧的 ✕ 试试」,右侧却什么都没有 → 真机报「图标的渲染有问题」。与图标尺寸那条批无关(那条是字形画到盒子短边 176% 被裁),这条是标记整只缺失。
- **修复**:标记与热区同源,一并画进 `on_draw`——`@icons.draw_icon(p, @icons.IconKind::Close2, r.w - 12.0, 12.0, 6.0, main)`:中心落在 24×24 热区正中、字形半径 6(落墨 ≈ 10.6px,走的是「s 为内容半径」口径),颜色用横幅主色 `main`(语义色 token 现取,换主题跟着走)。命名提醒:纯 ✕ 是 `Close2`(font_class 就叫 `close`),`CircleClose` / `CloseCircleFill` 是带圈档,别混用。
- **验证**:`moon test ui` 158/158,原「关闭热区只在右上角」扩成「热区与标记都只在右上角」,加两条判据——可关闭横幅右上角 24×24 里「与浅底不同」的像素 > 8,不可关闭横幅同区域必须 == 0(不许多画)。筛墨用「离浅底三通道差之和 > 30」,范围避开左缘 3px 强调条,不锁具体色值(换主题不假红)。**判据有效性已对照实验**:撤掉 `draw_icon` 那一行,标记判据当场红(`false` is not true),补回即绿。库全包 932/932、`cd examples && moon build showcase --target native` 链接通过。全仓 `--deny-warn` 仍被并行批 60e094e 的 5 条 sys 警告挡住(`appfind.mbt` 4 条、`recent_files.mbt` 1 条),非本批文件。
- **顺带排除**:演示文案里那两个「✕」是**正文里的 U+2715 字符**,本机 DejaVu Sans 与文泉驿微米黑都覆盖该码位(`fc-list :charset=2715` 实测有),不是缺字豆腐块;截图里那三个红框是用户手绘标注。
- **待真机复验**(用户执行):反馈组件页的可关闭横幅右侧应出现 ✕ 标记、点它整条收起;其余不可关闭的横幅不该出现标记。

## 「在文件管理器显示」只开目录不选中：两条通道要在 core 会师（2026-10-14，真机反馈）

- **现象**：XFCE 上点「在文件管理器显示 TODO.md」，Thunar 打开了那个目录，但 `TODO.md` 没有被选中。
- **根因**：`@sys.reveal_in_file_manager` 的 Linux 分支就是 `xdg-open <父目录>`，它自己的文档注释写着「总线通道的『打开并选中』随 DBus 线接入，当前一律落到打开父目录（选中态丢失）」—— 而 `FileManager1.ShowItems` 那一半**早就住在 `@dbus`**（`filemanager_available` / `show_items` / `file_uri` 三条齐全，URI 百分号编码还有测试覆盖），只是**没人把两条接起来**。接不起来是分层决定的：`@dbus` 依赖 `@sys`，sys 不能反向 import dbus，会师点只能是 core。
- **外测（本机）**：`gdbus` 问 `NameHasOwner org.freedesktop.FileManager1` → `(true,)`（Thunar 注册了它）；`thunar --help` 里**没有** `--select` 这类命令行开关 —— 总线是唯一能带选中的通道，退回 `xdg-open` 必然丢选中。
- **修复**：新增 `gui/core/reveal.mbt`，`@core.reveal_in_file_manager(path)`：Linux 且 FileManager1 在线时走 `show_items([reveal_uri(path, cwd)])`，不在线或这次调用失败才退回 `@sys` 的命令行路径；Windows 仍由 sys 直调 `explorer /select`。纯函数 `reveal_uri(path, cwd)` 单独露出来钉测试（选中态成不成就看这一串：必须绝对化 + 百分号编码）。sys 那条的文档改成点名「这是退路，要选中走 `@core`」；演示两处（showcase 外部段、systemprobe 的 reveal）改调 core 版。
- **验证**：core 新增 1 条 URI 回归（相对路径绝对化、空格、中文三段）→ `moon test core` 138/138、库全包 939/939、`cd gui` 与 `cd examples` 的 `--deny-warn` 零错误零警告、`moon build showcase`/`moon build systemprobe` 链接通过。真机可见结果（Thunar 里高亮那一项）按规则 6 归用户（清单 S14）。
- **口径**：**两条通道分住两层时，会师点必须是同时看得见两者的那一层**，并且文档要点名退路会丢什么（这里丢「选中」）。否则能力其实齐备、行为却停在退路上，看起来就像「没做」。
- **待真机复验**（用户执行）：showcase 外部段点「在文件管理器显示 TODO.md」→ Thunar 打开仓库根目录且 **TODO.md 处于选中态**；systemprobe 的 reveal（`/tmp`）应把 `/tmp` 本身选中。

## Linux 托盘「没启动」：演示把整段建托盘挂在图标句柄成功之后（2026-10-14，真机反馈）

- **现象**：showcase / native-app 在 Linux 上托盘图标始终不出，页内回显停在「建图标失败」。
- **根因**：`wm_icon_from_bgra` 在 **GTK 分支是 W20f 留的失败桩**（HICON 是 Win32 概念，恒返回句柄 0），于是 `@win.icon_from_bgra` 给 `None`；而两个演示都把整段建托盘写成 `match icon_from_bgra(...) { Some(ic) => Tray::new(...)  None => 记一句失败 }` —— **Linux 上根本没走到 `Tray::new`**。库侧不是缺口：SNI 后端不读这个句柄（图标走面板的主题图标名或库内置位图，见 `Tray::set_icon_name` 与 `Item::create` 里的 `default_icon_pixmap`）。
- **取证链**（三条各自独立）：① 会话总线上 `org.kde.StatusNotifierWatcher` 的 `NameHasOwner` 用 `gdbus` 外测为 `(true,)`（XFCE 面板的通知区在挂着）；② `moon test dbus` 里既有的四条「真总线」SNI 用例（多托盘项路径/菜单路由/注销对称清理/断线自愈）在本机全过——注册链是通的；③ 读 `Tray::new` 的分支：`sni_watcher_present()` 为真即走 `@dbus.Item::create`，与 `icon` 参数无关。
- **修复（只动演示）**：图标句柄**照传而不作门槛**——`let ic = icon_from_bgra(...)` 后直接 `Tray::new(id, icon=ic)`；成功时把句柄留在持有者里（Win32 的 HICON 在托盘存活期不能释放），失败时才 `free`（Linux 下 `ic` 本就是 `None`，两处都按 Option 走）。
- **口径**：**平台专属的「可选输入」不能当能力开关**——句柄/句柄型资源在别的后端可能恒空，把它当成建对象的前置条件就把那条平台整条路径堵死了。与「后端没接的能力不放按钮」是同一条纪律的另一面：这里是不该藏的按钮被藏了。
- **验证**：`cd examples && moon check --deny-warn` 零错误零警告、`moon build showcase`/`moon build native-app` 均链接通过；库侧无改动（938/938 复测见提交）。Linux 托盘的**可见结果**（面板出图标、左键计数、右键弹菜单）按规则 6 归真机复验（清单 S13）。
- **待真机复验**（用户执行）：切到系统集成页的「托盘」段 → 回显应为「已建（sni）」、XFCE 面板通知区出现托盘图标；左键点击计数走、`挂菜单` 后右键出菜单、`改提示` 后悬停可见新提示。若仍不出图标，把回显原文贴我（那已经是另一条根因）。

## 周期表「停不住」：自重排时把新句柄丢了，取消打在早已跑掉的旧号上（2026-10-14，真机反馈）

- **现象**：系统集成页的定时器区块，「1.5 秒后提示」正常出，「起周期表(1s)」也在响，但点「停表」后计数照涨。
- **根因**：演示里周期表是**回调尾自重排**的（本栈 `timer` 是一次性句柄），而重排那一行写的是 `let _ = a.timer(1000, tick.val)` —— **新句柄被丢弃**，`tick_id` 里留的还是第一次那个号。那个号在上一拍就已经从队列里移除，`cancel_timer(旧号)` 找不到项、什么也不取消，于是表照旧响。不是 `Loop::cancel` 的错：它按 id 找、找不到返回 false，语义正确。
- **修复**：重排时把新句柄记回去（`tick_id.val = a.timer(1000, tick.val)`），起表那一拍同样记；演示页的代码示例文案同步改成「每次都要记回新句柄才可停」。
- **口径**：一次性句柄 + 自重排 = **句柄每拍都要更新**；这条与 `Store` 去重那类一样是「形态自带的约束」，写进 design.md §6 与组件示例，别只留在提交说明里。
- **验证**：`gui/core/loop_wbtest.mbt` 新增一条把语义钉住——跑若干拍后 ①取消首号（早已跑掉）表照旧响、②取消最新句柄才停得住（`hits` 不再涨）。`moon test core` 137/137、库全包 938/938、`cd gui && moon check --deny-warn` 与 `cd examples && moon check --deny-warn` 零错误零警告、`moon build showcase --target native` 链接通过。
- **待真机复验**（用户执行）：起周期表 → 点停表 → 计数应立刻冻住；再点一次停表应回「表没在跑」；重新起表仍可停。

## Linux 剪贴板改走 GtkClipboard：顺带炸出 win 桩缺 `moonbit_make_bytes` 声明的指针截断（2026-10-14，真机反馈）

- **现象**：本机（Ubuntu 24.04 / X11 / XFCE）报「剪贴板不可用」——系统集成页的读写按钮没反应，输入框的 Ctrl+C/X/V 也不接系统。
- **根因一（能力缺口）**：Linux 唯一的后端是命令线 `xclip`，而本机**没装 xclip**（`which xclip` 为空），于是 `clipboard_available()` 恒 false，`ui` 的 `attach_system_clipboard` 不装槽、门面读写全部退回失败。
- **修复一**：`win/stub.c` 的 GTK 分支补 `wm_clipboard_available / get_text / set_text`（GtkClipboard），sys 侧 extern 直链 win 桩——与文件对话框 `wm_file_*` 是**同一条先例**（MoonBit 层不引 win 包，链接由 prebuild 下发）。探测顺序 GTK → xclip；`set_text` 在 `gtk_clipboard_set_text` 后紧跟一次 **`gtk_clipboard_store`**（只登记所有权而不 store，应用退出后别处就读不到了）；监听侧 `cbw_get_text` 同口径改走 GTK（顺带省掉每拍一个子进程）。Win32 与占位分支给同名符号（Windows 的真路径仍在 `sys_stub.c` 自己的 CF_UNICODETEXT，不动它）。演示侧补 `@ui.use_system_clipboard(true)`（此前只有 native-app 开过）。
- **根因二（ABI，被第一条炸出来的）**：**`win/stub.c` 用 `moonbit_make_bytes` 却没有声明**——本文件的 GTK 分支由 prebuild 直接编，拿不到 moon 的 `moonbit.h` 包含路径（`compile_stub` 只加 pkg-config cflags）。隐式声明按「返回 `int`」假定，x86-64 下返回值指针被截成低 32 位。**反汇编实证**：撤掉声明后 `wm_clipboard_get_text` 里出现 `mov %eax,%edi`（把 32 位返回值当 64 位指针参数往下传），而本机堆地址是 `0x61bc76xxxxx` 量级，截断即垃圾地址。补 `extern void *moonbit_make_bytes(int size, int value);`（与 `sys_stub.c:57` 同一行先例；签名与 `~/.moon/include/moonbit.h` 的 `moonbit_bytes_t moonbit_make_bytes(int32_t, int)` 逐位对齐）后该 TU 零隐式声明警告。
- **顺带修掉一处既有隐患**：`wm_file_dialog_get_result`（Linux 文件对话框取回路径）一直在返回截断指针，只是从没被无头测试走到——要真选一次文件才触发。
- **对照实验**：撤声明 + 强制重链 → `moon test sys` SIGSEGV；补回 → 188/188。**踩坑记档**：只改桩里的 C **不会**让 moon 重链测试可执行文件（它按 .mbt 包脏化），第一次对照实验因此「假通过」；必须 `touch` 一个 .mbt 源文件（或删掉归档再脏化包）才作数。
- **读数与口径**：GTK 路径在本机真读到使用者剪贴板（watcher 测试打印 `cbw_get_text: Ok（13 字符）…`）。注意 `gdk_display_get_default()` 在**没跑过 gtk_init 的测试进程里也返回非空**（GDK 按 `$DISPLAY` 惰性开），所以 Linux 探测在无头测试里同样是 true——剪贴板回归因此必须写成「可用则做 save→set→get→restore 往返、不锁使用者内容」的形态（`clipboard_wbtest.mbt` 已是这形态，换后端不假红）。
- **验证**：`cd gui && moon check --deny-warn` 与 `cd examples && moon check --deny-warn` 零错误零警告、库全包 937/937、`moon build showcase --target native` 链接通过。真机复验清单加 S11（系统集成页读写按钮、输入框 Ctrl+C/V 与外部应用互通）。
- **待真机复验**（用户执行）：系统集成页「写入剪贴板」→ 到浏览器/终端里 Ctrl+V 应见同一段中文；页内读取按钮应回读到外部复制的内容；输入框内 Ctrl+C/X/V 与系统互通；退出应用后剪贴板内容仍在（靠那次 `store`）。

## 段条被正文高度挤塌:定高头部要 flex_shrink=0、可伸缩正文要 min=0(2026-10-14,真机反馈)

- **现象**:`代码文档` 页切到 Markdown 段后，页面顶部的 segmented 段条高度塌下去，标签戳出条外；切到「代码高亮」段就正常。
- **根因**：页面装配是「段条 + 正文列(`grow=1.0`)」放在一个列里，两边都给了 `min=0`（段条那侧是上一批为「段条超宽换行」加的：换行容器的 CSS §4.5 主轴 `min:auto` 等于 min-content 高，不归零会反过来吃掉整块正文高度）。**只归零不锁收缩**就留下反向通道：正文列没给 `min=0`，它的 min-content 高 = 整篇正文（Markdown 段是全文，2000px 量级），窗口只有 720，父列超容后 yoga 把**全部压缩量落到唯一可自由收缩的段条**上（它 min=0，而 yoga-mbt 的 `flex_shrink` 默认 **1.0**，`modules/yoga-mbt/src/style.mbt:53`）。短正文的段不触发，所以看着像「切了标签才塌」。
- **无头复现读数**（`gui/ui` 临时探针，结构与装配一致：根 300 高、段条 24 + padding 10、正文 2000）：现状段条实测 **23.32**（自然高 44，标签 24 直接戳出）；加「段条 `set_flex_shrink(0.0)` + 正文列 `min=0`」后实测 **44**。探针跑完即删，修复落在 `examples/showcase/shared/section.mbt`。
- **口径**：一列里「定高头部 + 可伸缩正文」两件事要分开锁——**头部锁收缩**（`flex_shrink=0`），**正文放开收缩**（`min_height=0` + `grow`），滚动交给正文里的 `scroll_view`。只给 `min=0` 是必要条件不是充分条件：它让容器能折行，同时也让它成了唯一能吃压缩的那一层。
- **本栈边界**：`Style` 字段集里有 `flex`(=grow) 没有 `flex_shrink`，所以头部锁收缩走 `handle=` 落 `w.node.set_flex_shrink(0.0)`（与 `scroll_view` 内容列同款）。要不要把 `flex_shrink` 补进样式工厂另计（见 design.md §6）。
- **验证**：`cd examples && moon build showcase --target native` 通过；本批只动演示装配，库侧无改动。全仓 `--deny-warn` 仍被并行批 60e094e 的 5 条 sys 警告挡住（`gui/sys/appfind.mbt` 4 条、`recent_files.mbt` 1 条），非本批文件。
- **待真机复验**（用户执行）：切到 Markdown 段后段条是否恢复定高（标签不再戳出）、段条在窄窗口下仍能换行、正文段内滚动照旧；其余 14 页逐页切一遍看有没有别的定高条被挤。

## 散点图千点级糊成实心带:点径按「点面积 × 点数 ≤ 绘制区面积」收口(2026-10-14,真机反馈)

- **现象/根因**:`scatter_t` 默认 `dot=6.0`,画法是不透明 `fill_rect` 方块。演示页 2000 点画进 320×260 的图(绘制区 260×224),点面积合计 2000×36=72000 px² 已是绘制区的 1.24 倍——**默认点径与点数量级根本不匹配**,相邻点互相咬合,整条相关带涂成一块实心,看不出任何分布形状。方块还额外吃掉 π/4 的视觉留白,密处连缝都不剩。
- **修复口径**:①默认 `dot` 收成 **3.0**,并把这条写成组件文档里的取值规则(点面积 × 点数 ≤ 绘制区面积,大点径要显式传);②画法改 `Painter::fill_round_rect`(半径=短边一半)=**圆点**,点与点之间天然留缝;③点阵层套 `set_global_alpha(0.7)`(在 `save()`/`restore()` 内,恢复照常),重叠处靠叠加显深而不是涂实,疏处仍看得见网格。趋势线与网格不受影响(画在 alpha 之前)。
- **实测读数**(离屏 `Painter::new(Bitmap)` 会话,判据用「离点色比离面板底更近」筛点阵墨迹,网格线/刻度天然排除):单点 `dot=15` 的着色包围盒 14×14、四角不沾墨、中心沾墨(旧画法 15×15 且**四角全沾墨**=方块);2000 点默认档下「纯点色」像素 201 格(旧画法 20189 格 = 绘制区 58240 的 35%,即实心)。两条判据都写进 `moon test chart` 回归。
- **工具链读数**(moon 0.1.20260920):①演示页那串 LCG 用 `% 2147483647` 取正余数不成立——**MoonBit 的 `%` 结果随被除数取号**,而 `seed * 1103515245` 溢出 int64 回绕成负数后余数就是负的,散点于是散到负半轴(真机读数:坐标轴成了 -100..100,而注释写的是 0..100)。取低位一律 `& 0x7fff_ffff`,溢出与符号一起消掉。②多行表达式里**运算符不能起新行**:`a + b
< c` 直接 `[3002]`/`[4139]`,比较要挪成中间 `let`。
- **验证**:`moon test chart` 190/190(新增 1 条双判据回归),**判据有效性已对照实验**:把画法与默认点径换回旧形态(`fill_rect` + `dot=6.0`),四角判据当场为真、纯点色 20189 格越过上界,换回即绿。库全包 931/931、`cd examples && moon build showcase --target native` 链接通过。全仓 `--deny-warn` 现被并行批(60e094e sys 平台批③)的 5 条警告挡住(`gui/sys/appfind.mbt` 重复 `#borrow`、未使用的 `ffi_file_mtime`、两处已废弃的字符串切片写法),非本批文件、未代为改动。
- **待真机复验**(用户执行):散点两图是否读作「一团点」而不是实心带、趋势线仍清晰、右侧小图(250×130,`native-app`)不回归。

## 图标字形画到盒子短边的 176% 再被裁:`draw_icon` 的内容半径口径要收在组件层(2026-10-14,真机反馈)

- **现象/根因**:`@icons.draw_icon` 第 5 参一直是**内容半径**(落墨 ≈ 1.76×s,路径数据 ±1000 归一 × `s*0.88/1000`),但 `@ui.icon` 与 `@ui.icon_button` 把**盒子边长**当半径传了进去(`size` / `icon_size`),字形于是画到盒子短边的 176%;宿主又按控件矩形裁剪,四边各切掉一大块。离屏像素探针读数(`Painter::new(Bitmap)` 会话上直接量落墨包围盒):`icon(size=24)` 的包围盒是 24×24 且**正好顶满盒子边界**(未裁时该是 44×44,`draw_icon(...,24.0,...)` 直接读得 `10,10-53,53`),`icon_button(box_size=28, icon_size=16)` 同样顶满 28 的盒——观感即「图标撑破容器、边缘被切、与容器不协调」。库里另外三处直连调用本来就是半径口径,不受影响:`message_box`(24 盒传 11)、`overlay` 弹条(传 7)、`nav` 侧栏项(传 6.72)。
- **修复**:`@ui.icon` 改按**当前矩形**取半径(`r.w.min(r.h) / 2.0`)——class 覆盖过宽高时字形仍随盒子走、不会溢出;`icon_button` 传 `icon_size / 2.0`,按钮盒(`box_size`)与字形盒(`icon_size`)各管各的,默认 28/16 落墨 ≈ 16,盒内留 6px 以上余量。`draw_icon` 与 `icon` 的文档注释把口径写进入口(「s 为内容半径 = 盒子边长的一半」「字形按盒子短边 88% 光学留白居中」)。图标数据侧无需动:803 条路径全量扫过,包围盒都占满 ±1000 且几何中心偏移 ≤60 定点单位(≈盒子 3%),没有偏心或尺寸不齐的条目。
- **工具链读数**(moon 0.1.20260920):`println` 只收一个 `String`(多参报 `[4015]`);`debug_printline` 对「4 个 Int + 2 个 Double」这类混参没有匹配重载(`%g` 亦不认,报 `[4021]`)——多条数值诊断一律走字符串拼接。
- **验证**:`moon test ui` 158/158,新增 1 条像素回归——`icon(size=24)` 落墨包围盒须落在 `[1,1]-[22,22]` 且横纵中心相等(实测 `1,1-22,22`),`icon_button(box_size=28, icon_size=16)` 须落进 `[5,5]-[22,22]`、宽度 10..17(实测 `6,6-21,21`)。**判据有效性已对照实验**:把两行换回旧口径(直接传 `size` / `icon_size`),该判据当场红(`a.0=0`、`b.0=0`,即顶到盒边界被裁),换回修复即绿。库 13 包 926/926、`cd gui && moon check --deny-warn` 与 `cd examples && moon check --deny-warn` 零错误零警告、`moon build showcase --target native` 链接通过。
- **待真机复验**(用户执行):空状态/结果页的大图标、侧栏深/浅切换按钮(月亮图标)、图标墙页(`size=30`)、表单前后缀与表格排序小图标,是否都不再顶破容器、边缘不再被切且居中。

## 前端化 P5:`transition` 属性过渡(状态桶插值 + 帧驱动,2026-10-14)

- **插值集合按「每帧从样式槽读出」这条线划**:参与过渡的只有 `color` / `background_color` / `border_color` / `border_width` / `border_radius`。理由不是省事——进布局的属性(字号、行高、尺寸、边距)一旦插值,每一帧都要重排整树;`opacity` / `box_shadow` 的生效点在 `apply` 落 `Widget.alpha_paint` / `shadow_paint`,绘制遍历按的是宿主字段而不是槽,插值它们不会有效果。集合外的属性**切换即生效**,`step` 比较的是「插值字段投影」,投影相等就直接落定。
- **状态机口径**:①第一次见到某条控件只记目标、不动画(否则建树与重挂会整片淡入);②目标中途变化时从**当前显示值**续接(`from = shown`,反向打断不跳变);③同一目标按原时钟继续,非插值字段跟着新目标走;④`transition_ms` 未写或 0 立刻落定,并且**不留账**(`style_for` 走 `forget_anim`)。缓动取 smoothstep(`t·t·(3-2t)`)。
- **帧驱动只维持一条定时器**:进程级 `@core.set_timeout(16)` 起表,每拍只给活动中的控件调 `@core.invalidate_id(id)`(命中哪扇窗标哪扇窗的脏区,所有窗都找不到才整窗广播兜底),全部收敛即停表——不按控件各排一条,也不空转。插值按**真实经过时间**算而不是数拍数,所以掉帧/宿主忙只会少几帧,不会让动画变快变慢。隐藏中的账在超时那一拍补交终点值并标脏一次,不留长尾。
- **颜色两端的取法**:`Var` token 现取当前主题再混色(`@theme.mix_hex`),所以过渡中途换主题,这一段动画的端点色停在换色前的值,下一次切换才跟上新主题——主题切换本就整窗置脏,不构成可见缺陷。任一端没写、或写法不是 hex(命名色那类)时 `mix_hex` 退成端点值,中间帧停在起点、终点仍是目标值,**不会画错颜色**。
- 工具链读数(moon 0.1.20260920,`cd gui && moon check --deny-warn` 口径):
  - **`pub(all) enum Color` 不带 `==`**:`Option[Color]` 参与的元组比较直接报 `[4018] Type Color does not implement trait Eq`。与既有记档同族(给值类型 `derive(Eq)` 会把 impl 方法隐式升成普通方法并告警),所以**状态比较一律走字符串投影**(按写法前缀 `#`/`n`/`@` 区分 Hex/Named/Var),不 derive。
  - **包内私有结构必须写 `priv struct`**:裸 `struct Anim` 报 `missing_priv` 警告,在 `--deny-warn` 下即失败。
  - **`}` 与下一段条件的 `{` 不能分行**:`} else if cond` 换行再写 `{` 报 `[3002] Unexpected line break here, missing {`——花括号必须跟在条件那一行行尾(与 `test "名字" {` 同一条纪律)。
  - **`moon fmt` 会顺手改一堆无关文件**:本仓已提交内容**不是** fmt 的规范形态(`moon fmt style core` 一次改了 42 个文件,含 `keys.mbt` 里给每条 `pub const` 前插空行这类)。要格式化只按**本批文件**跑,且跑完逐行看 diff;本批按「只改自己写的行」收口。
- **验证**:style 新增 6 条(插值端点/中点/单端缺省、状态机首帧不动画、150ms 三点读数 `#000000→#808080→#d7d7d7→#ffffff`、中途反向从 `#282828` 续接、集合外属性直接落定、没配过渡不留账)、core 新增 1 条(`invalidate_id` 只标命中窗、另一扇窗不牵连、未知 id 回退整窗),`moon test style core` 159/159、13 库包全绿合计 908/908、`cd gui && moon check --deny-warn` 零警告、`cd examples && moon check showcase --deny-warn` 零警告。观感页:showcase 新增「过渡与效果」页(0/150/600ms 三块对照 + 反向打断 + 文本与效果字段),真机复验归用户(悬停三块比较速度、中途移开看是否跳变)。

## 前端化 P1:gui/style 样式包与 yoga-mbt z_index(2026-10-13)

工具链边界(moon 0.1.20260920 / moonc v0.10.14,读数随升级要重测,同步 design.md §1.6):
- **`alias` / `abbrev` 都是保留字,没有函数或类型别名语法**;类型短名只能 `using @pkg {type X}` 引,且该声明是**包级**的——两个文件各写一遍会撞 `[4051] declared twice`,正确形态是在一个文件里 `pub using` 一次、全包与外部共用短名。
- **labelled 参数没有任何透传通道**:`f(width=width)` 类型不符(体内可选参数是 `T?`)、`f(width?)` / `f(width!)` / `f(...)` 全 `[3002]` 不解析、`pub let g = f` 绑函数值再 `g(width=1.0)` 报 `[4117] labelled 函数只能直接应用`;`moon.pkg` 的 import 不收键值形态(`unexpected token :`),包短名也配不了。结论:样式工厂调用点定死 `@style.style(...)`,状态方法 `.hover/.active/.focus` 的绘制期构造体三处各写一遍。
- `priv` 只修饰 `let`/`fn` 之外的声明形态,顶格 `priv named_x = ...` 解析失败——包内值直接写 `let`。
- `Array::contains` 要 `T: Eq`;`Option` 判含有值用 `is Some(_)`(`is_some()` 已废弃告警);`Map::new()` 已废弃,写 `Map([])` 字面量。
- `for i in 0..n`(半开)与 `0..=n` 在 for 之外都不可用,范围循环要求 `for i in (0..<n)` 形态或直接改 `while`;本包统一退回 `while`。

架构口径:
- **core 不能依赖 style**(style 依赖 core 的 Widget/yoga 落点,反向成环)。Widget 的 resolved Style 槽落为 `@style` 包内**进程级侧表** `Map[控件 id, Style]`(与 overlay_native 的进程级句柄表同款先例),`apply` 写入、绘制期 `resolved(w)` / `style_for(w)`(按 `hovered/pressed/focused` 选桶)读出;从未 apply 过的控件读回空样式。**残账清理已落地(P2-e 收尾)**:core 加进程级「控件丢弃钩子」`set_widget_discard_hook`,`clear_children` 与 `remove_child` 把摘下的整棵子树逐只报出 id,`@style` 首次 `apply` 时自己装钩子把条目清掉——动态换树(`bind_node` 重挂、`for_list` 删行、虚拟列表重挂窗口、浮层收起)不再逐代累积。**口径:摘下来就是丢弃,挪位必须走 `move_child`**(core 不认识挪与丢的区别,钩子只看这两条 API)。判据是 `@style.resolved_count()`(诊断用),回归用例钉住「remove 一棵带子树的控件 ⇒ 条目数回落」。
- **cursor 是绘制期属性,状态桶可携带**;控件的**静态** `cursor` 字段由 `apply` 直接落,状态桶里的 cursor 由 P2 的悬停路径下发读 `style_for`。
- yoga-mbt 的 `z_index` 纯绘制期:setter 不 `mark_changed`(几何无关)、引擎**不物理重排 children**(增量布局按下标缓存),给 `Node::paint_order` 下标投影;gui 侧 `Widget.z_index_paint` 由 `apply` 写入,`widget_paint_order` 插入排序稳定重排 kids(全 0 时恒等序,现有示例逐帧不变)。

验证:style 18/18、yoga-mbt 100/100(基线 95+新增 5)、core 120/120、`cd gui && moon check --deny-warn` 与全仓 `moon check` 零错零警;set_margin labelled 化 14 处调用点整批改完,库测试 858 条 856 过(2 条红为 W9/排序批既有缺口,stash 纯净态复跑同红)。

## 维护约定

1. 新增结论写进对应小节,只记「坑 + 修复」;协议互操作结论必须来自真总线、真面板,单测自洽不算数。
2. 中英两份(本文与 docs/adaptation.md)同批同步。
3. 影音与桌面控制批次的落点:`影音与桌面控制命令路线`(Linux 系统能力数据层下)、`系统信息与系统级安全边界`、`目录枚举与进程内环境变量`(跨平台通用下)、`通用 D-Bus 调用层`(DBus 线路协议下)、`地图与飞线的投影方案`(自绘画布与图表渲染下);浏览器侧结论进 `Firefox places.sqlite` 小节。
