# 平台适配经验

各平台实测坑与结论,每条只记「坑 + 修复」;协议互操作结论均来自真总线、真面板验证。Linux 按发行版 → 桌面环境组织,Windows / macOS 按版本;新增结论写进对应小节,英文版 [docs/adaptation.md](../adaptation.md) 同批同步。

## 性能基准

MoonBit 全链路(shim + MoonBit 运行时)相对 C++ 原生的开销:examples/hello(release 构建)对比功能相同的纯 C++ libyue hello,两者链接同一 vendored 静态库,C++ 侧不含 shim——差值即封装层全部开销。

| 指标 | C++ 原生 | MoonBit 全链路 |
|---|---|---|
| 启动(热启动 20 轮中位,exec → 窗口 map) | 73ms | 70ms |
| 稳态内存(窗口静置 3s 的 Rss) | 62.1MB | 62.9MB |
| 二进制体积 | 6.52MB | 7.39MB |

口径:Ubuntu 24.04 XFCE(X11)同机同会话,启动差值小于检测粒度视为持平。C++ 侧 `-std=c++20 -O2 -DNDEBUG`;头文件用同版 fork 树(nativeui)+ 预构建配套树(base/build,并把 `base/allocator/partition_allocator/src` 补为 include 根);缺 `-DNDEBUG` 会缺 `RefCountedBase::CalledOnValidSequence` 符号,链接失败。

## 跨平台通用(构建链 / FFI)

### 构建与链接

- moon 必须在仓库根执行:vendor/build 产物与 WebView2Loader.dll 的运行期搜索按工作目录。
- 库包不得写 link 段(moon 会生成无 main 的 exe,构建失败);链接参数全部由 `scripts/prebuild.py` 经 `--moonbit-unstable-prebuild` 钩子输出 link_configs,自动传播给所有依赖 yue 的 main 包,任何包不手写 `cc-link-flags`。
- prebuild 脚本约束:stdout 只能输出最终 JSON(进度信息走 stderr);全部参数放 link_flags 单一字符串自控顺序(`-lyue_mbt` 必须排在 `-lstdc++` 之前,GNU ld 单遍扫描);脚本 cwd 是使用方项目根,库路径必须绝对。
- moon 不因静态库内容变化自动重链(prebuild 只在库缺失时补建):shim 或静态库变更后用 `prepare.py` 重编 + `moon clean`(或删产物 exe)强制重链;`nm build/libyue_mbt.a | grep <符号>` 零命中即库过期。shim 比 vendored 库新时 prebuild 自动增量重编。
- shim 补丁以独立提交进 fork(lb091188/yue,main = 上游 v0.15.6),fork CI 按 tag `v*-mbt*` 出三平台源码包与预构建库;改 shim 的提交必须同批回填本机平台 vendored 库,并尽快走 `vendor-*` CI 拉齐三平台,否则 mooncakes 零编译路径对用户是断链。
- 静态库与 shim 必须同编译器家族:Linux 上 clang 库 + gcc shim 稳定段错误(同 ABI 同 libstdc++ 也崩);预构建库统一 gcc 出。Ubuntu 22.04 工具链产物最终链接需 `-latomic`。
- libyue 版本钉死在 prepare.py(`LIBYUE_VERSION` + 六资产 sha256),升级同步更新校验和。
- vendored 库随 mooncakes 分发(`lib/<平台>/`),prebuild 按「vendored → build/」级联;三平台产物由 `vendor-native.yml`(tag `vendor-*`)固化,维护机 `vendor_native.py --fetch <tag>` 拉齐。
- moon 新版弃用 `moon.mod.json` / `moon.pkg.json`(`moon fmt` 一键迁移);`moon doc` 只认新格式,旧版 moon 不认新格式。
- MSVC 按 cp936 误读无 BOM UTF-8 源码,中文注释会造出假预处理错误(报错行没有那个指令):CMake 对 MSVC 加 `/utf-8`。
- 新增 shim 函数:定义统一 `extern "C"`,声明同批进 `yue_mbt.h` 的 extern "C" 区,`nm` 确认符号无 `_Z` 前缀;GLib(`g_*`)是 Linux 专属,跨平台函数不得引用。
- 新版 moon 弃用 trait 方法隐式提升:调用写显式静态形式 `ViewLike::method(obj)`;`impl Trait for X` 声明点须补 `pub extend X with Trait::{...}`(方法清单从 `moon check --no-render` 输出生成,勿手抄);黑盒测试内引用包内符号须限定 `@yue.xxx`。此类警告增量编译漏报,clean 全量才见全量。

### MoonBit cfg(platform=)

- moonc 已实现 `#cfg(platform="windows"/"linux"/"macos")`,按 `-target` 三元组求值;但当前发布版 moon 只给 moonc 传无 OS 信息的 `native`,所有条件恒 false。`moon build -v` 的 moonc 命令行出现完整三元组即条件可用。
- 现行替代:运行时 `platform()` 判断,声明式树按条件组装节点,不满足就不创建控件。

### 声明式层与自绘组件

- mouse 回调内禁止 `set_background_color`:运行期 CSS 改写会吞掉紧随的首次 press(「点两次才生效」)。交互态(hover / 按下)一律 on_draw 表达;set_background_color 只用于挂载期与主题订阅回调。
- flex 容器的挂载序同时是排列序与 z 序:夹层件(把手 / 分隔线)必须严格按排列位置挂入,且视觉常显——用户靠「看」找它,不靠 hover。

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

### 布局几何(Yoga flexbox)

- 布局断言 16/16 通过(±1px);叠加规律:内容区 = 容器 − 2×padding;gap 不与 margin 叠加;百分比基准为父内容区宽。
- 复合控件(Tab / Scroll / Group)在 yoga 树里是无 measure 的叶节点,外框尺寸必须显式给出(如 `flex:1`),否则塌缩(Tab 构造时固化最小尺寸,页区域归零)。
- tabs_t 曾把 outer 宽度写死 360px、内容页无 flex:放进页里的 Scroll / Table 因此塌缩归零(实测 sysmonitor 概览页整个空白,只有页签头)。修复:outer 去掉固定宽改 `flex:1`(列容器默认 stretch 拿宽度,父有确定高度时填充),内容页同样 `flex:1`。父容器无确定高度时 flex 不增长,内嵌场景(showcase 的分段演示)布局不变。
- 运行时改样式(set_style)后调 `update_layout`,GTK 上对「根容器」调用子树完全不刷新(yoga 状态已改,bounds 纹丝不动),对单个节点调用也只重排「该节点及其父下的兄弟」——跨子树(如表格 body 的行)不受影响。探针同构四组对照实证(挂载后立即 / 500ms 后、update 根 / 叶子、width / flexbasis):唯一可靠形态是「被改样式的容器逐个调用」。table_t 拖列宽曾因对根调用而「手柄在动(bounds 走的 col_w)、列宽纹丝不动(样式没生效)」;splitter 恰好只有一个包装容器要改,对 outer 调用看似通用,实则同坑未爆。修复:apply_col_widths 对表头两个单元格 + 每行两个单元格逐个调用。
- GUI 自动化:键盘驱动(Tab 聚焦 + Space 激活)首选;`xdotool key --window` 走 XSendEvent 会被 GTK 丢弃,必须 XTEST(不带 --window);坐标点击受 WM 装饰偏移影响不可靠。

### MoonBit ↔ C ABI

- 蹦床与 C 函数指针原型逐位对齐,含参数个数:C 以 `(closure, args...)` 调用,蹦床首参收 closure。错位后行数正常、部分回调能跑,极具掩盖性;每个回调都真实触发过才算验证。
- `extern "c"` 返回可空类型:旧版工具链直接段错误(成败经 `Ref[Int]` 出参报告);moon 0.1.20260904 + moonc v0.10.12 实测 `-> Bytes?` 已可用——C 侧返回 NULL 正确映射 None,debug / release 双模式、真实缺失文件与目录(EISDIR)路径均验证(sysmonitor 的 read_text_file)。其余可空类型(句柄等)未复测,仍按出参模式兜底。
- FFI 指针参数标 `#borrow`(编译器强制);控件参数写句柄类型 `View`,不写 MoonBit 包装 struct(否则运行时句柄全部无效且静默丢弃)。
- 闭包跨 ABI:无捕获顶层函数字面量即 C 函数指针;带捕获走「函数指针 + 闭包指针」双参模式。
- 回调闭包由注册表进程级保活,不随窗口回收(单窗口工具场景泄漏可忽略,已定案)。
- Toolbar / Vibrant 的 Linux 静态库无符号,链接必败,不暴露;Browser 空 Cookie 列表崩溃已在 fork mbt.7 修复。
- 改 shim 签名必须 `.cpp` / `yue_mbt.h` / ffi.mbt 三处同批;漏同步或整段漏声明的断链形态都是 mangle 分裂(`_Z` 前缀符号对纯 C 名引用),nm 对比定位;出包前跑「.cpp 全量定义 × 头文件声明」对照扫描。
- XFCE 面板 IconPixmap 优先于 IconName:set_icon_name 与 set_pixmap 互斥,设一方须清空另一方。

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
- Double↔IEEE 754 位转换放 shim(moonbitlang/core 无 Double::to_bits/from_bits,实测确认):yue_mbt_sys_f64_to_bits/from_bits 纯位重解释(static_assert sizeof(double)==8),wire 层 'd' 借道 Int64 的 8 字节小端读写。注意:traybus 的 whitebox 测试目标一旦引用此类 extern,链接就吃 -lyue_mbt——而 link_configs 按「依赖该包的目标」传播,traybus 不依赖 yue(反向),prebuild.py 须为 NoahLiu/moonbit-libyue/yue/traybus 单列一份同值配置(静态库单成员引用 gtk 全套,不能给精简 flags)。
- UPower 读数路径(实测 Ubuntu 24.04,台式机):DisplayDevice(/org/freedesktop/UPower/devices/DisplayDevice,接口 org.freedesktop.UPower.Device)聚合主电池,IsPresent=false → Ok(None);属性接口名注意区分——设备是 …UPower.Device、顶层是 …UPower,PropertiesChanged 的 arg0 过滤天然把设备级信号挡在顶层订阅外。OnBattery 在顶层对象,交直流事件订阅顶层 PropertiesChanged、回调内直解 changed 字典(信号分发在 drain 栈上,回调内 call_sync 会重入收包路径,严禁)。
- 断线自愈(B5,未经真机断线演练):mark_dead 幂等(以 fd 注册表为准),经 shim 的 post_delayed_task(符号直 extern,绕开 traybus→yue 反向依赖)延迟 500ms 重连、最多 3 次;成功后重放 AddMatch 规则、迁移订阅表与托盘项并重新注册(断线期间 watcher 已按唯一名消失清掉旧注册)。纯 CLI 场景(主循环未跑)重连回调不触发,自然放弃。
- logind 事件订阅(B6):PrepareForSleep(b) 在 Manager 接口、Lock/Unlock 在各会话对象的 Session 接口(空体信号,按成员各一条 AddMatch,不限定 path——所有会话都收,多用户登录时别人的会话锁屏也会触发,归属限制调用方自查 sender)。降级实测(私有总线无 logind):suspend_resume_supported()==false、session_lock_watch 返回 Err(SystemError::Unsupported),不静默。快速挂起唤醒可能连收两条 Resuming(库内不去抖);唤醒后网络/DBus 可能未就绪,回调里的重试逻辑应延迟。
- 锁屏事件必须双信号源(真机踩坑修正):XFCE 的 xfce4-screensaver 锁屏**不调 logind**(logind Lock/Unlock 无信号;busctl 直接调 Session.Lock 方法可正常触发信号,证明订阅链路无恙、是锁屏器不通知),它锁屏时在自己持有的 org.xfce.ScreenSaver 上发 ActiveChanged(b)。修复:session_lock_watch 双源订阅——logind Lock/Unlock(系统总线,GNOME/KDE 走此)+ 屏保服务 ActiveChanged(会话总线,候选 [org.xfce.ScreenSaver, org.freedesktop.ScreenSaver] 按真实在线选定),多源同报经状态机去重(同态重复不派发,翻转才派发)。ActiveChanged 订阅 key 带服务名前缀,与 logind 订阅不冲突。
- XFCE「黑屏设置不生效」与常亮验证口径(真机诊断):电源管理器 GUI 的「黑屏 1 分钟」依赖 DPMS 或屏保空白屏,实测宿主机三条息屏链路全关(xfce4-screensaver /saver/enabled=false、X DPMS Disabled、xfce4-power-manager 无任何 dpms/blank 键)——设置界面有值但没人执行黑屏,常亮开关自然无从观测。验证常亮前须先开一路执行器(推荐屏保空白屏:锁屏器同源,抑制与锁屏事件都能配套);org.xfce.PowerManagement 抑制接口在本机不在线(NameHasOwner=false),XFCE 下 DPMS 黑屏不可经 DBus 抑制,避开该路径。
- Windows 电源/会话事件窗口(B6,代码落地真机待验):一个 message-only 窗口同时收 WM_POWERBROADCAST(PBT_APMSUSPEND;PBT_APMRESUME 与 PBT_APMRESUMEAUTOMATIC 都归已唤醒)与 WM_WTSSESSION_CHANGE(WTS_SESSION_LOCK/UNLOCK,NOTIFY_FOR_THIS_SESSION),WNDPROC 内 PostTask 抛回主循环(B1 消息窗口模式复用)。C 侧单窗口单回调,休眠/锁屏共用——MoonBit 侧全局单点登记按 event 码派发,后注册不得覆盖前者。WTSRegisterSessionNotification 失败只影响锁屏事件不视为整体失败。wtsapi32.lib 是全计划唯一链接清单改动,prebuild.py 的 WINDOWS_LINK_LIBS 与 shim/CMakeLists.txt 必须同提交(双清单无一致性注释背书)。
- NetworkManager 在线状态(B7):State 与 Connectivity 都是顶层属性,Properties.Get 的应答体是单 "v"(内为 u32),与 GetAll 的 a{sv} 不同形状。变化信号两条都订——老式 StateChanged(i) 直带新值,新式 PropertiesChanged(a{sv}) 的 changed 里可能带任一属性;订阅回调在 drain 栈上,只更新缓存与归并通知,严禁 call_sync 重查(首次缓存建在注册动作里,主线程非 drain 栈合法,最坏阻塞 1.5s)。归一口径:State 70/50 且 Connectivity 4/3 为 Online,门户劫持(Connectivity=2)按 Offline(「在线」= 可达互联网)。实测 Ubuntu 24.04:State=70/Connectivity=4 → Online,与 busctl 逐位一致;私有总线降级 Err(NetworkError::Unsupported)。Windows NLM GetConnectivity 位掩码:含 IPV4_INTERNET(0x40)/IPV6_INTERNET(0x400)为 Online,轮询 5s(监听式后置);netlistmgr.h 无需额外链接库。
- NM StateChanged 信号参数是 Int32(i) 不是 u32(真机踩坑修正):D-Bus 规范里属性 State 是 u、信号 StateChanged 的 state 参数是 i,两者类型不同源;wire 层 i 解码为 VI32,旧实现只匹配 VU32 被静默丢弃——信号照发、回调不触发,面板断开连接/关「启用网络」(State 70→20/10)后 UI 恒显示初始 Online(单测自洽测不出:自造信号体恰好写成 u)。修复:statechanged_of 对 VI32/VU32 双匹配,bool 等其余类型照旧丢弃;Properties.Get 与 PropertiesChanged 里的 State 仍是 u,不动。分发链路本身用无害属性写实测存活(NM 1.46 WwanEnabled 开关,无 WWAN 硬件机器零网络影响,PropertiesChanged 实时到达);信号触发后的 UI 翻转由真机断网/恢复验证。
- 网络回调登记必须平台分支外统一(真机两级观测定位):on_network_status_change 的派发统一走 net_dispatch 遍历 g_net_cbs,但登记 g_net_cbs.push(cb) 原本只在 Windows 分支——Linux 信号全数到达、缓存逐值更新(State 70→10→20→40→60→70 与 nmcli monitor 逐条一致)而回调零执行,UI 恒显初值;两级探针(traybus nm_on_change 层 + online 派发层)一对比即锁定。修复:push 提到平台分支外,两平台统一登记。同类事件注册(on_suspend_resume/on_power_source_change)是回调闭包直接内嵌、不经全局数组,无此问题;net_dispatch 的去重以注册时回填的 network_status() 为基线,注册后首条同态信号不派发属预期。
- Windows NLM GetConnectivity 在 UI 线程调用可秒级冻结并连带原生布局断言崩溃(实测 Win10 19045 宿主机,网络环境差时必现):showcase 启动 3.7~4.7s 稳定 abort(0xC0000409 = fast-fail),崩前 stderr 打出 yoga 顶层断言「availableHeight is indefinite so heightMeasureMode must be YGMeasureModeUndefined」;崩率随网络环境 0%~100% 漂移(网络健康时查询毫秒级,与提交时冒烟存活一致,极易误判为代码回归)。定位路径:同一 exe 二分页面(仅系统集成页消失即 0 崩)→ 只禁网络初值查询+回调注册即 10/10 稳 → 预热/延迟查询均无效(查询存在即冻结,与时机无关)。根因:GetConnectivity 慢路径单次可达秒级,注册时的同步初值查询冻结 UI 线程数秒,返回瞬间 yoga 在积压布局上走 ScrollView 内容测量的 GetPreferred* 路径(该路径以 NaN 高度调 YGNodeCalculateLayout,对 height 样式已定义的容器是 fatal)。修复:shim 新增 yue_mbt_netwin_start/netwin_cached——后台 MTA 线程独占 COM 与轮询(interval 默认 5s),结果写进程级缓存,UI 线程只读缓存(network_status 缓存未就绪返回 QueryFailed,on_network_status_change 不再同步回填初值,g_net_last 改 None=未知态、首值必派发)。跨线程 COM 的 apartment 问题因接口指针创建与使用都在同一线程自然消解。验证:moon check 零警告、128 测全过、showcase 冒烟 12/12 存活(修复前同环境 7/10 崩)。

- sysmonitor 实测(Ubuntu 24.04 XFCE X11,口径同篇首性能基准:启动中位、稳态 Rss、release 二进制):启动(exec → 窗口 map)5 轮 77/78/81/82/88ms,中位 81ms(hello 基线 70ms 是空载系统,本次系统载有 1042 进程);稳态进程页前台 1Hz 刷新 CPU 2-3%(采样 + 派生数据 + 千行表格重建 + 重绘合计约 25ms/秒),Rss 84.9MB → 100s 后 85.8MB 走平;二进制 7.72MB(hello 对照 7.03MB)。千行进程页验收达标:1053 进程全量采样 14.94ms/次(release,≈14µs/进程,每进程两次 /proc 读取),1Hz 下采样占空 1.5%。
- 千行表格用 table_v_t 虚拟滚动(只画可见行):刷新走「数据层全量采样 → 过滤/排序派生 → rows Store set → 表格 load + schedule_paint」,不重建视图树;选择按 pid 重映射(排序每秒变化时选中不漂)。无 C++ 对照副本,「封装层 + 数据层」合计开销以上述数值直接归因,UI 绘制部分与 hello 基线同口径(持平量级)。
### 系统监控数据层(/proc、/sys,sysmonitor 示例)

- /proc、/sys 伪文件 stat 尺寸恒为 0(fseek/ftell 拿不到长度):整文件读取必须循环增量 `fread` + 倍增缓冲(上限 16MB);读目录时 `fopen` 成功但 `fread` 报 EISDIR,靠 `ferror` 判失败。实现在应用 native-stub `examples/sysmonitor/stub/sysmon.c`,MoonBit 侧统一走 `read_text_file`。
- 应用自有 native-stub 可放子目录:`"native-stub": ["stub/sysmon.c"]` 相对 moon.pkg 所在目录解析;符号全在 libc 默认链接范围,零 shim / fork / vendored / 链接参数改动。测试目标自动链入该 stub,wbtest 可直接读真实 /proc 文件。
- /proc/stat 列序 `user nice system idle iowait irq softirq steal guest guest_nice`:第 9 列 guest 已由内核计入 user/nice,再累加即重复计数;占用率 = (Δ总 − Δidle − Δiowait) / Δ总,iowait 不算 CPU 忙。采样间隔短于一个 tick(USER_HZ 通常 10ms)时 Δ总 ≤ 0,返回 0;首帧前样本取全零,首屏值为开机至今均值。
- /proc/cpuinfo 型号字段平台分歧:x86 是 `model name`,ARM 开发板只有 `Processor` / `Hardware`,三级回退;核数取 `processor` 行数(逻辑 CPU 含超线程,与 nproc 一致)。
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
- sysmonitor 界面文案纪律(整批界面打磨实测):界面文字只说「是什么 / 怎么用」,不写数据口径与实现路径(如 /proc 路径、两次差值、毫摄氏度换算、"nvidia-smi 后置"这类计划说明);速率 / 容量 / 坐标轴一律多级单位动态换挡(B→K→M→G),数值保持短,大号数值卡(24px)尤其忌换行溢出卡片。
- sysmonitor 概览页卡片范式对标 Mission Center(资源管理器式):图标 + 标题、规格副标题(CPU 型号 / 总容量 / 挂载点等硬件规格放卡片副标题,不在窗口顶层占副标题行)、当前值行(占用% · 温度、已用 / 总量 · swap 等组合)、卡内迷你曲线(序列末窗 + 末端圆点;值域固定 0-100 或峰值自适应,双序列同窗叠加如网络 rx/tx)。卡片 flex 均分、同排 stretch 等高,随窗口伸缩;单卡自包含,不看窗口其他部分也能读懂。

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
- **滚动范围跨轴 bug(滚不动页的根因,探针逐位实证)**:fork 的 Linux ScrollImpl::GetMaximumScrollPosition 把**视口宽度**当垂直 page_size 用——实测 `max_y = 内容自然高 − 视口宽`(窗口 900×600 时:纯自绘行块内容 1064→maxy 164、图表+行块 1088→188、纯标签 1160→260,全部精确命中),水平轴对称错。后果:程序化滚动行程只剩真实量的零头、悬浮 thumb 不浮现(库判定 maxy≤0.5 隐藏)。**初始可见与隐藏后显示同样错**(一度误判为隐藏挂载的测量问题,常驻对照组同值推翻;期间试过的 queue_resize/update_layout 补测均无效——GTK 测量本来就对,错的是 nativeui 的读数)。修复:shim 的 `yue_mbt_scroll_get_max_position_x/y` 在 Linux 改从 `gtk_scrolled_window_get_h/vadjustment` 直读 `upper − page_size`(其余平台仍直通 nativeui),修后 1160−600=560 逐位正确,sysmonitor 右栏滚轮实测生效(前后截图差异 5871 像素)。
- hover 组(hover_group)的判定不能依赖容器 enter/leave:GTK 的指针事件不冒泡,发给最深命中的 GdkWindow 就终结,子容器(NUContainer)/原生控件(Entry 等)的事件窗口会**独占**指针事件,祖先容器收不到 enter(sysmonitor 卡片能收 enter 是因为子件是无窗口的 label;子件一旦是容器/原生控件就断流)——「事件透传」需改 fork 上游(每视图事件广播祖先链)或平台全局钩子(XI2/WH_MOUSE),侵入与维护都重,不走。可行机制=指针位置轮询:**全部组共享一个全局 100ms 定时器(set_timeout 链,无组时完全停转),每 tick 一次指针查询 + 每组一次屏幕矩形比对,均微秒级**;cursor_screen_x/y 与 get_bounds_in_screen 同为屏幕根坐标、多屏拼接含负值一致(探针逐位验证)。enter 仅作命中加速、离场全靠轮询。可见背景必须 on_draw 自绘(set_background_color 与 backgroundColor 样式对无 draw 的容器均不可靠——主题 CSS 与子控件窗口都会压掉;悬停/常态底色直接在组容器 draw 里画,透明子区域自然透出)。实测:子控件(输入框)悬停整卡变 fill_hover(239,241,243)精确命中、移出复原。
- 自绘悬浮滚动条(overlay_scroll)降级为显式选用组件(用户裁决):曾作 declarative `scroll()` 默认形态(为 Windows 经典条统一三平台观感),但 thumb 依赖 maxy/on_size_changed 链,叠加跨轴 bug 后形态不稳。`scroll()` 现一律平台原生滚动条(overlay=true 请求悬浮样式,Linux 由环境变量保底、Windows 无悬浮对应物),overlay_scroll 组件保留给显式要统一形态的场景,文档标注不建议新代码采用。
- 系统主色调读取(GTK3 无强调色 API,`yue_mbt_system_accent` 三级递进):①GNOME 47+ 的 GSettings `org.gnome.desktop.interface`/`accent-color`——schema 存在但键不存在时(如 Ubuntu 24.04 的 gsettings-desktop-schemas)`g_settings_get_string` 直接 abort 而非返回空,必须先 `g_settings_schema_has_key` 探测(本机探针实测 abort);②当前主题 CSS 的 `@define-color theme_selected_bg_color`:GTK 各主题把主色统一表达为选中底色,按 `~/.themes` → `$XDG_DATA_HOME/themes` → `$XDG_DATA_DIRS/themes` → `/usr/share/themes` 找 `gtk-3.0/{gtk,gtk-contained,gtk-dark}.css`,深浅偏好决定先解析哪个(Orchis 系 gtk.css 是浅色主色、gtk-dark.css 是深色变体);③都取不到返回空。验证:探针程序(Ubuntu 24.04 + XFCE + Orchis-Teal-Light-Compact)返回 `#009688`,与主题 CSS 定义逐位一致;XFCE 无强调色设置,靠②命中主题主色。
- 容器级 hover 高亮(on_mouse_enter/leave 切底色)遇子控件必闪烁:GTK 的 enter/leave 按**原生窗口边界**派发,进子窗口即视为离开父窗口;libyue 有补偿(responder_gtk.cc `OnMouseEvent`:leave 延迟一拍、子 enter 取消 pending,仅 GTK),但有两洞——①子控件没连任何鼠标 handler 时 `PlatformInstallMouseMoveEvents` 未执行、无 enter 掩码,永远发不出 enter 去取消,pending leave 到点照发(卡片里 label / 图标一带);②空容器(如自绘迷你曲线画布)不满足「Container 且有子节点才延迟 leave」,父 leave 立即触发。实测 sysmonitor 左栏资源卡:鼠标在卡内每跨过一个子控件 hover 底色灭一次。规避:自绘容器的悬停反馈只用 cursor(手型)+ 常驻选中态(描边/浅底),不依赖 enter/leave;确需 hover 类效果须单画布自绘整卡(表格行同款)或改库层事件派发。另:悬停光标也按原生窗口生效,只设在容器上盖不住有独立窗口的子控件(hbox 行 / 自绘画布),须逐子控件 SetCursor(NUSetCursor 对无窗口控件为安全空操作;一个 nu::Cursor 可经 scoped_refptr 被多视图共享,复用同一实例即可)。

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
- exe 控制台黑框已由 yue 包内置 `win_gui.c` 链接 pragma 根治:pragma 存于 .obj 的 drectve 段,静态库归档成员须被引用才会被抽取——`initialize()` 引用 stub 符号 `yue_mbt_win_gui_marker` 保证生效,依赖方零配置;release-bin.yml 的 PE 头改写(Subsystem 3→2)为兜底。用户 link_flags 拼在 `/link` 之前,cl 直接丢弃 `/SUBSYSTEM` 类链接选项(D9002),追加参数路线不可行。GUI 子系统下 stdout 仅管道 / 重定向可见。
- 换 `yue_mbt.lib` 后 `moon build` 报 no work to do:删 `_build` 下产物 exe 强制重链。
- prepare.py 模式切换坑(prebuilt↔source):`cmake -D` 只在显式传时覆盖 CMakeCache,不传则沿用残留值——旧 build 目录按 prebuilt 配置过(YUE_MBT_PREBUILT=ON)后切源码模式,configure 沿用 ON 导致 GLOB 到的源码一个不编,`yue_mbt.lib` 里只有 shim 一个 obj,最终链接 360 个符号全库缺失。修复:两种模式都显式传 ON/OFF。判定法:`lib /list build\yue_mbt.lib` 数 obj,全量源码构建应有 27 个(Windows)。
- prebuild 的 link_configs Windows 分支曾漏为 `yue/traybus` 单列一份:traybus 不依赖 yue(反向),按「依赖该包的目标」传播拿不到链接配置,`moon test` 链 traybus 测试 exe 时 12 个 `yue_mbt_sys_*` 符号 LNK2019;Linux/macOS 分支本就单列,Windows 补齐后三平台一致。

### manifest

- moon 的链接参数拼接行为(Windows 实测):按 main 包的依赖闭包把每个带 link_configs 的包的 flags 各拼一遍,并对 blackbox 测试目标把「被测包」的 flags 额外再拼一遍(被测包份 ×2)。`.lib` 重复列出无害,`manifest.res` 重复列出则同名 MANIFEST 资源进两次 → CVT1100 链接失败。早期「moon 新版给 exe 自带 MANIFEST 与我们的 res 冲突」的结论有误:mt 实测 moon 链的 exe 不含任何清单资源,冲突的「另一份」始终是重复传入的 res 自己(为 traybus 补 Windows 链接配置后,凡同时拼两份 flags 的目标即触发)。
- 通道探索结论:`/MANIFEST:EMBED` `/MANIFESTINPUT:` 等链接选项放进 link_flags 会被 cl 当编译选项丢弃(D9002,`/link` 之前的链接选项不传递);`#pragma comment(linker,"/manifestdependency")` 依赖链接器开 /MANIFEST,moon 的链接不开(moon 链的 exe 旁也无外部 .manifest 文件);prebuild 的 stdin 只有环境变量快照与 module_root,无目标/包信息,无法按目标输出差异化配置。
- 最终方案:manifest.res 不进默认 link_flags——开发 / 测试 / moon run 零配置。无清单的运行代价不止视觉退化:真机 Win10 19045 实测消息框点击按钮进程即崩——`TaskDialogIndirect` 只有 comctl32 v6 才按序号 345 导出,无清单加载的是 v5.82,其导出表序号 345 指向无关函数,libyue 按序号取址拿到非空垃圾指针直接调用即 UB(python ctypes 探针证实解析出非空地址;MoonBit 探针复刻同用法三连跑全干净退出,UB 非确定性,单次不复现不能下结论)。fork 修复(mbt.13):MessageBox 解析序号前先读 comctl32 的 DllGetVersion,主版本 ≥6 才调用;低于 v6 走经典 `MessageBoxW` 降级(图标按 TD_*_ICON 映射 MB_ICON*,≥2 个自定义按钮时 MB_OKCANCEL 且确定返回首个按钮响应,否则 MB_OK、响应为取消语义),弹窗可用性不受清单影响;OnClose 统一 PostTask 回 UI 线程(原空解析路径在后台线程直接回调也是跨线程隐患)。降级初版是「解析为空即直接关闭」,真机反馈表现为「点消息框没反应」,故补 MessageBoxW 降级;再版真机反馈「有图标按钮没文字」——TaskDialog 的主文字在 `pszMainInstruction`、仅补充文字在 `pszContent`,而 `SetText` 只写前者,降级须把两个字段拼接进 MessageBoxW 的单行文本。分发型构建设 `YUE_MBT_KEEP_MANIFEST=1`:res 随 yue 份传入,moon build 的 main 包对每份 flags 只拼一遍,恰好嵌入一份清单(Common-Controls v6 + supportedOS,mt 实读验证),v6 下有真 TaskDialog;全仓 `moon test` 勿设此开关(blackbox 被测包双拼必炸)。release-bin.yml 已按此配置。
- 环境变量改变 link_flags 后 moon 偶发沿用旧配置不重链:设 / 去变量后行为不变时,`moon clean`(或删 `_build` 下产物 exe)兜底。

### 运行期差异

- **2026-09-25 整树回退至 09-23 晚 f3ba8bf 版本(用户拍板)**:09-24 起为「表单页滚动原生子控件跟随/切页横线/tooltip 不显示」做的整条修复链(第一代 0ms 重摆 → fork 递归下钻 → 去 WS_CLIPCHILDREN → 平移传导 → 像素搬运 → 补画次序 → 切页性能合并,30+ 笔,含 fork ba479418/e373e60a/f4528cb8/cf308737 与浏览器包拆分、tooltip 自绘三代)经真机多轮复验为**净负担**——每轮在旧病未根治的同时引入新病(卡顿/蓝影/横线复发/重影/悬浮/撕裂),应用户要求整树回退,native 钉回 v0.15.6-mbt.12。核心教训:**原生 HWND 与自绘内容混排的「同步层」修复在真机连续失败——任何此类修复必须真机单点验证通过后才可叠加下一层,禁止多修复捆绑推进**;被回退各方案的全过程根因分析见 git 历史 09-24~09-25 各提交说明与 fork 仓库同期提交。回退后接受的已知状态:Windows 原生 tooltip 不显示(原生路径依赖 comctl32 v6 清单)、滚动中原生输入框靠 update_layout 兜底跟随、切页/滚动可见横线(WS_CLIPCHILDREN 固有)。
- MoonBit 泛型方法的具体类型误传(FFI 句柄类参数):`MessageBox::run_for_window` 曾把 `Window` 结构体直接传给期望 `View` 句柄的 extern(C 侧 `void*` 收到 MoonBit 堆地址而非注册表 id),`CastTo<nu::Window>` 静默失败 → 消息框无父窗口 + 同步路径假死;判定法:MoonBit 生成的 C 原型第二个参数是 `struct ...Window*` 而非 `void*`。凡 FFI 声明带句柄参数,一律用 `View`(external)类型,具体控件 struct 在 MoonBit 侧 `.view()` 解出句柄再传;异步 `show_for_window` 与同步 `run_for_window` 必须同口径。另注:moon 的增量判断不可靠,改 shim/库后 `moon build` 可能报 up to date 不重链,须删 `_build` 下产物 exe 强制重链(否则探到的是旧库行为)。
- 显隐页切换后内容消失(tabs_t 等 set_visible 切换场景,真机实测):libyue win 的 `View::Layout()` 只向 `IsContainer()` 的父传播(`if (GetParent() && GetParent()->IsContainer())`),Scroll 不是 Container——挂在 Scroll 内容里的子树做显隐切换(set_visible → yoga display 切换)后,传播链在 Scroll 处中断,yoga 根永不重算,恢复显示的页拿 0 高尺寸;页内容无显式高度时被压成 padding 之和(实测页高 50→16,内容整块消失)。GTK 端由 gtk size-allocate 全量重排掩掉,Windows 独有。修复:shim 的 `yue_mbt_view_layout`(即 update_layout)改为沿父链遍历到根容器再 `Layout()`,tabs_t 的 `sel.subscribe` 在显隐翻转后补一次 `update_layout(outer)`;探针(页内容 on_draw 自证 + bounds 打印)验证每次切换绘制到位、页高稳定。注意:只对 root 的直接 flex 子场景不触发(根重算一直有),必须经 Scroll 的内容树才断。
- 显隐页切换消失·三层嵌套残余场景(showcase 结构:页容器 set_visible 切页 + scroll + section + tabs_t,真机仍复现):页签切换时,`Container::Layout` 的 dirty 自愈分支(view.cc 里自带 TODO 注释的那条)会用 display 切换中间态的 yoga 值分配外层容器——并列 flex:1 的页容器被按「scroll 内容测量中间态」分配成压缩高度(实测 210→56),且此后无法自救:自愈传播链断在 Scroll(非 Container),根级重算的 SetBounds 链又断在「尺寸未变的中间容器」(hbox 等尺寸相同 → ViewImpl::SizeAllocate 早退 → 不向下触发子级 UpdateChildBounds)。后果:WM_PAINT 的 dirty 被压缩的页容器裁成 24 高碎片,与页区域(74,278,512,50)不相交,`DrawChild` 的 `child_dirty.IsEmpty()` 整块跳过——on_draw 不触发、bounds 却正常。已试无效(均实测):根级重算 ×N、反转显隐顺序(先 true 后 false)、set_visible 内联根重算(shim 侧)、叶子层显隐(显隐只切页内容)、page_c 的 flexbasis 置 0(CSS flex:1 1 0 语义)。结论:根因在 libyue win 的 yoga 集成本身(dirty 自愈用过期布局 + Scroll 断链的双重断裂),yue/shim 层外部修补打不穿,需 fork 侧根治(备选方向:UpdateChildBounds 的分配前强制 YGNodeCalculateLayout,或 Scroll 内容测量避开中间态)。当前 20babb5 修复对「tabs_t 直接位于 scroll 内容」场景(无页容器层)完全有效,showcase 场景待 fork 侧方案。
- 滚动条形态:libyue 在 Windows 的滚动条是自绘经典样式(Scrollbar 类:轨道 + 箭头按钮 + 常驻占布局),`Scroll::SetOverlayScrollbar` 对 Windows 是空操作(头文件里 API 就被 `#if !defined(OS_WIN)` 排除)——GTK 的悬浮形态在 Windows 没有对应物。统一方案是 yue 层 `attach_overlay_thumb`:policy 置 Never 隐藏平台条,自绘 thumb 用 yoga absolute(right/top/bottom 静态样式)占满右缘全高,可见段在 on_draw 按 Ref 状态绘制——滚动更新只 schedule_paint 零 yoga 重排;浮现/渐隐用 clear_timeout 可取消的两级定时器(d9→73→隐藏),拖拽依赖按下后的隐式鼠标捕获(拖出仍收 move,见 splitter 条目的 WM_CAPTURECHANGED 适配),thumb 窄条上的滚轮经 on_wheel 手动转发给 Scroll。收口点:declarative `scroll()` 默认形态(overlay=true 且未显式 policy)即套 host 容器走它(style 参数挪给 host,Scroll 在内撑满——thumb 的 absolute 定位以 host 为基准,直接挂页面容器会被 padding/margin 带偏);overlay_scroll 组件与全站页面滚动同走此路径。Windows 分支保留 on_scroll→0ms 定时器强制重摆原生 HWND 的兜底。
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
- 单实例消息窗口是仓内首例自有 WNDPROC/窗口类代码(此前 grep 0 命中):类名由 app_id 派生(moonbit_libyue_instance_<app_id 点换下划线>),必须建在运行 libyue 主循环的主线程;WM_COPYDATA 由 SendMessage 同步派发到 WNDPROC(不走消息队列),收端 MessageLoop::PostTask 抛回主循环再触发 MoonBit 回调,避免在对方进程的 SendMessage 栈里执行应用代码。互斥体用 Local\ 会话命名空间免提升;同进程对同名二次 CreateMutexW 会命中 ERROR_ALREADY_EXISTS,以 static 句柄守卫做幂等。【待真机验证】消息窗口在 libyue 主循环下的实际派发、SetForegroundWindow 在前台互斥下的置前成功率、旧构建混跑时标题查找兜底路径。
- UI 线程 COM 套间必须按 STA 建立,否则文件对话框卡死/崩:公共文件对话框 `IFileDialog::Show` 要求 STA——UI 线程 COM 从未初始化时 `CoCreateInstance(CLSID_FileOpenDialog)` 直接失败(库内空指针解引用),被应用侧后置调用抢先初始化成 MTA(典型:旧版在 UI 线程调 `CoInitializeEx(MTA)` 的网络查询)时 `Show` 永久挂死,现象即「点打开/保存文件应用直接卡死」。修复:shim `yue_mbt_app_init` 建 State 后立即 `State::InitializeCOM()`(ScopedCOMInitializer STA + OleInitialize,幂等);此后 UI 线程上的 `CoInitializeEx(MTA)` 只会得到 `RPC_E_CHANGED_MODE`,本地 COM 对象不受影响。与「NLM 查询挪后台 MTA 线程」互补:后台线程的 COM 初始化是线程局部的,不替代 UI 线程自己的 STA。验证:真机点开/保存文件对话框正常弹出、选完路径回传。
- Windows 切主题无全局重绘,残留旧像素成"重影":GTK 端 `theme_apply` 有 CSS 重建 + 逐窗口同步重绘兜底,Windows 端原本只通知订阅主题的自绘视图,漏订阅区域(以及被隐藏/移走的原生子窗口背后的区域)留旧像素,鼠标划过触发局部失效才消失。修复:shim `yue_mbt_repaint_all` 补 Windows 分支——`EnumWindows` 过滤本进程可见、无属主的顶层窗口,`RedrawWindow(RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN)` 整体失效连带原生子窗口,只失效不同步绘制(WM_PAINT 交回消息循环);`theme_apply` 的 windows 分支调用它。验证:真机来回切深浅,头部/页面无残影。
- 零高度自绘视图整段静默不渲染(table_t 文字列消失):`ViewImpl::Invalidate` 对空尺寸提前返回,childless 且无高度样式的 on_draw 容器被 yoga 测高为 0 后永不绘制——table_t 的 CellText 单元格正是这种容器(文字经 on_draw 自绘、无子节点),现象为整列文字不可见而表头/斑马纹/复选框正常;GTK 端裁剪行为不同故未暴露(同函数族此前已踩过「GTK 小单元格路径填充不渲染」的反向坑)。修复:`cell_view` 给 CellText 容器补 `minHeight=row_height`。教训:自绘 on_draw 容器必须有非零尺寸来源(显式高或子内容),「无子节点 + 自动高」在 Windows 等于不画;离屏 Canvas 像素探针可先排除绘制链本身(AttributedText 带色在 Windows 画布上逐位正常)。
- GDI+ 混合模式仅 Normal/Copy 生效:`PainterWin::SetBlendMode` 只把 Copy 映射为 `CompositingModeSourceCopy`,其余全部落 `SourceOver`——GDI+ `Graphics` 只有这两种合成模式,Multiply/Screen/Difference/Xor 等静默无效。离屏像素探针实测:Multiply 交叉区 (128,128,255) 与 SourceOver 逐位一致(数学期望 #8028FF)。平台能力缺口,不修库(换 D2D 才有完整混合);showcase 画布演示在 Windows 回显「此平台仅 Normal 生效」,`docs` 中 `Image::write_to_file` 平台口径同步修正(Windows GDI+ 编码器 png/jpeg 可用、mac 发行包未编译恒失败)。
- 原生 Tab 添加首页即回调 `on_selected_page_change`(内部初始选中,非用户切换):回调登记先于加页时,挂载期会空触发(declarative `tab()` 曾因此让切换计数演示凭空起跳);登记挪到加页循环之后即避开。

## macOS ❓ 未实测

- libyue v0.15.6 发行包含 ARC / no-ARC 双库:Darwin 链接参数 = 主库 + `-lyue_mbt_noarc`(no-ARC 符号被主库引用,须排其后)+ AppKit / Carbon / IOKit / Security / WebKit / OpenDirectory 框架 + `-lobjc -lc++ -lpthread -lbsm -Wl,-dead_strip`;prebuild Darwin 分支已按此预修。
- CI(macos runner)承担构建 + 测试;headless 无 WindowServer,不做 GUI 冒烟。
- shim 平台分支的 `#else` 兜底会误吞 macOS:borderless 须 `#elif defined(OS_WIN)`;CurrentDirForDrag 拆三支(mac 用 `getcwd`);`Window::SetSkipTaskbar` / `SetIcon` / `App::SetID` 在 mac 头文件无声明,调用补守卫空操作。

## 维护约定

1. 新增结论写进对应小节,只记「坑 + 修复」;协议互操作结论必须来自真总线、真面板,单测自洽不算数。
2. 中英两份(本文与 docs/adaptation.md)同批同步。
