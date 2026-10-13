# 验证单（临时文件，勿提交；验完删）

> 生成于 2026-10-12，对应提交 `2df1fc1`。
> **用法**：A 部分在这台 Linux 上对着示例一条条点；B 部分转 Windows 后照着命令跑。
> 每条验完在「结果」列写 `OK` / 现象；有不对的回来告我编号 + 现象，我改。

---

## A. Linux 本机（对着示例点）

### A0 准备

```sh
moon run examples/native-web      # 已去掉自杀点：不再自己退，关窗即退
moon run examples/native-app
moon run examples/systemprobe
moon run examples/native-window
```

`native-web` 退出时终端会打一组 `NATIVE-WEB-*` 读数行，A1/A2 的「对照读数」列就是我给过的数字。

### A1 native-web · 浏览器族

| # | 操作 | 期望 | 级别 | 结果 |
|---|---|---|---|---|
| A1-1 | 第一行点「载入」「重载」「停止」，点「整页 / 分栏」来回切 | 页面真渲染 example.com；切整页后网页按新宽度重排、侧栏让位；三个按钮都有效果 | 扫一眼 | |
| A1-2 | 在网页区内滚动、点页面里的链接 | 页面自己滚/跳转；不出现滚不动、点空 | **必需**（跨进程，注入不可靠） | |
| A1-3 | 点进网页里的输入框打拼音 → 再点回原生输入框打字 | webview 聚焦时本栈输入法**让位**（候选窗归网页），离开后原生框恢复可打 | **必需**（已修过一轮：见 C 节第 6 条） | |
| A1-4 | 「开一扇桥接窗」 | 页内文字显示「已被原生改过」；原生事件区逐条出现「页面回话 / 权限请求（默认拒绝）/ 新窗请求已拦下」；窗数仍是 1 | 扫一眼 | |
| A1-5 | 「加载本地协议页」 | 页面标题「本地协议页」，正文段落**带蓝底**（说明 `style.css` 也走 `yuedemo://`） | 对照 `SCHEME reg=1 loads=1 files=2` | |
| A1-6 | 接着点「注销该协议」→ 再点第一行「重载」 | 页面区只剩一行 `scheme unregistered` | 对照 `unreg=1 fails=1`；**注意**：两扇窗没各给数据目录时共用同一个 context，这一步会把桥接窗那页的根目录一并清空（重新点「加载本地协议页」即恢复，不是 bug） | |
| A1-7 | 批 E 行「开原生弹层菜单」 | 无边框弹层**压在网页之上**，选完即关，主窗还在 | 扫一眼 | |
| A1-8 | 桥接窗里的「浮层盖网页」 | 自绘浮层也能盖住网页区（这条是原生档的判据） | 扫一眼 | |
| A1-9 | 点弹层以外的地方 | **默认不自动收起**（已知取舍，判据未定前故意留着）；内容里的「收起」能收 | 扫一眼 | |
| A1-10 | 开桥接窗 / 播放器窗 / 本地视频窗各一扇，互相遮挡再移开 | **不再花屏、自绘区不再闪**（你已确认过一次，回归扫一眼） | 扫一眼 | |
| A1-11 | 桥接窗（现在装的是 `yuedemo://local/bridge.html`，不再是 `load_html`）：先看正文，再点页面里的「链接甲」，然后点原生按钮行的「后退」 | ① 中文标题/正文/链接**全部正常无乱码**（协议回灌只递 MIME，文本类已钉 `charset=utf-8`）；② 事件区出现 `加载失败 g-resolver-error-quark/0 https://a.example/1`；③ 「后退」出现 `后退 → yuedemo://local/bridge.html` 且页面**真回到桥接页**（这条以前注定是空操作） | 对照 `NATIVE-WEB-JS ... dom_ok=1 navs=4 fails=1 last='标题 本地桥接页'` | |
| A1-12 | 依次关掉每一扇开过的窗（桥接窗、播放器窗、本地视频窗），最后关主窗 | 终端日志里**不出现** `CRITICAL` 行（修复前关主窗固定刷 5 行 `WEBKIT_IS_WEB_VIEW` / `GTK_IS_WIDGET` 断言）；进程自己退出、退出码 0 | 我已用脚本跑过一轮 = 0 条；你手动关（点标题栏 X / Alt-F4）这条路径没走过，请补这一眼 | |

### A2 native-web · 媒体族

| # | 操作 | 期望 | 级别 | 结果 |
|---|---|---|---|---|
| A2-1 | 批 D 行「开一扇播放器窗」：播放/暂停；拖进度条 | 拖动时只有显示位置动、**松手才真 seek**；不出现卡住一整拍 | 必需 | |
| A2-2 | 同上窗：点 `\|<` `>\|` 逐帧 | 点一下画面跳一帧，不闪黑（黑帧就是 settle 没生效） | 必需 | |
| A2-3 | 同上窗：拖音量条 | 音量真变响/变轻；条上填充跟着走 | **必需（听得见才算过）** | |
| A2-4 | 同上窗：点倍速键循环 1x→1.25x→1.5x→2x→0.75x | 标签随档位变；**音画仍同步**；音高随调（既定代价，不做时间拉伸） | **必需（听感）** | |
| A2-5 | 同上窗：点「全屏 / 退出全屏」 | 整窗铺满屏幕、再点回来；全屏下字幕与控件位置正常 | 扫一眼 | |
| A2-6 | 批 D 行「开一扇本地视频窗」（`/home/lkyh/下载/001.mp4`，23 分钟）：正常播一段 | 画面连续、不漂（对照读数 `frames` 一直在涨、`pos_ms` 与墙上时间对得上） | 必需 | |
| A2-7 | 同上窗：在进度轨中后段点一下（深跳） | 画面与声音都从落点继续，不停在半路 | 必需 | |
| A2-8 | 同上窗：再点倍速两次 | 仍同步；23 分钟片长跑下不明显漂 | 必需 | |
| A2-9 | 批 D 行**新按钮**「开一扇内嵌字幕窗」（播仓库内 `av_1s_subs.mp4`，不喂外挂文本，字幕由组件自己从容器里读） | 画面下方先出「第一条字幕」（0.2~0.6 秒）、再出「第二条带标记」（0.6~1.0 秒），**第一条要在 0.6 秒前消失**（这条钉的是 mov_text 那个恒 2000ms 的时长谎报已修）；片长 1 秒会循环，所以每轮都该重演一遍 | 对照 `NATIVE-WEB-MEDIA ... subs=2 emb=1 err=''` | |
| A2-10 | 同上，看「开一扇播放器窗」（外挂文本那条路） | 仍显示「第一条字幕（0.2~0.6 秒）/第二条字幕（0.6~1.0 秒）」，与改前一致（外挂优先没被内嵌轨抢掉） | 对照 `subs=2 emb=0` | |
| A2-11 | 「开一扇本地视频窗」（`001.mp4` 没有字幕轨） | 画面**没有**字幕、也没有任何报错文字 | 对照 `NATIVE-WEB-LOCAL ... subs=0 err=''`（`subs=0` 是「没这条轨」不是失败） | |

### A3 native-app · 组件库 / 图表 / 主题 / 多窗口

| # | 操作 | 期望 | 级别 | 结果 |
|---|---|---|---|---|
| A3-1 | 开「关于」窗，在里面打拼音 | preedit 下划线观感正常；候选窗贴组合串末尾；caret 闪烁顺眼 | **必需（挂最久的三条）** | |
| A3-2 | 图表页：滚轮缩放、按住拖拽平移 | 图跟着缩放/平移，不跳不抖 | **必需**（XTest 注入对 GTK3 的 XI2 滚轮无效，我验不了） | |
| A3-3 | 图表页：点图例项 | 该项变灰、扇区/线段重分配；再点恢复 | 扫一眼 | |
| A3-4 | 两扇窗互相遮挡再移开、拖动窗口 | 重绘正常，无残留、无花屏 | 扫一眼 | |
| A3-5 | 切系统深浅 / 主色（XFCE 无此通道时按亮色预设走，属已知降级） | 有通道的桌面下界面实时联动；无通道时保持亮色不刷屏 | 扫一眼 | |
| A3-6 | 十族组件扫一遍（基础/表单/导航/数据/反馈/浮层/日期/表格/虚拟表/粘性列表/Markdown） | 没有明显画错、错位、点不动 | 扫一眼 | |

### A4 systemprobe · 系统能力 / 托盘 / 文件对话框

| # | 操作 | 期望 | 级别 | 结果 |
|---|---|---|---|---|
| A4-1 | 五个面板的读数与你这台机器对一下 | 系统/机器、桌面与硬件、应用与文件类型、窗口与剪贴板、最近与历史 都对得上 | 扫一眼 | |
| A4-2 | 「打开链接」「打开目录」两个设置类按钮 | 真拉起浏览器 / 文件管理器定位 | 必需（会真的开外部程序） | |
| A4-3 | 点「托盘图标」 | 面板出现图标；右键菜单内容对；点击计数累加 | **必需（面板观感只有你能看）** | |
| A4-4 | 文件对话框（模态选文件 / 选目录） | 能开、能选、选完读数正确；取消不崩 | 必需 | |

### A5 native-window · 冻结基准

| # | 操作 | 期望 | 级别 | 结果 |
|---|---|---|---|---|
| A5-1 | 起、看动画在动、关窗 | 干净退出、无 X 报错 | 扫一眼 | |

### A6 回报格式

`编号 + 现象（截图/文字）`；读数行与期望不符就把整行贴回来。**发现不对的别自己改**，告我我查。

---

## B. Windows（转过去之后）

> 这一部分的主旨：**纯 MoonBit 的通用逻辑在 Windows 上跑一遍测试就算验过**；平台代码（`yue/win`、`render/text/sys` 的桩、`media`、`web`）各按自己的状态单独看。

### B0 先跑通用测试（主战场）

```sh
moon test -p NoahLiu/yoga-mbt/src                 # 期望 96/96  布局引擎（含 patches 语料回归）
moon test -p NoahLiu/moonbit-libyue/yue/core      # 期望 82/82  宿主/焦点/信号/输入映射表/浮层
moon test -p NoahLiu/moonbit-libyue/yue/ui        # 期望 110/110 十族组件
moon test -p NoahLiu/moonbit-libyue/yue/input     # 期望 10/10  编辑内核
moon test -p NoahLiu/moonbit-libyue/yue/render    # 期望 43/43  绘制契约（纯光栅器路径）
moon test -p NoahLiu/moonbit-libyue/yue/text      # 期望 29/29  文本层（Windows 走 DirectWrite）
moon test -p NoahLiu/moonbit-libyue/yue/chart     # 期望 189/189 图表（全纯算法+自绘）
moon test -p NoahLiu/moonbit-libyue/yue/mdview    # 期望 27/27  Markdown
moon test -p NoahLiu/moonbit-libyue/yue/theme     # 期望 8/8    色板
moon test -p NoahLiu/moonbit-libyue/yue/icons     # 期望 4/4    图标绘制面
moon test -p NoahLiu/moonbit-libyue/yue/sys       # 期望 166/166（Windows 分支 W14/W16 已落；个别用例按平台 skip 属预期）
```

**这些包不含平台代码**，Windows 上应当同样全绿；哪包掉了就是真回归：
`yoga-mbt`、`yue/core`（host/signal/input_map/overlay 全是纯逻辑）、`yue/ui`、`yue/input`、`yue/chart`、`yue/mdview`、`yue/theme`、`yue/icons`、`yue/render` 的算法层、`yue/media` 的数学与重采样（`vp_*`/`media_resample_s16`/`player_bar_hit`/`subtitle_*`）、`yue/web` 的脚本生成与 JSON 解析（`dom_script`/`dom_parse`/`nav_error_parse`）。

### B1 现在**预期编不过/不绿的**（不是回归，是还没接）

| 包 | 状态 | 说明 |
|---|---|---|
| `yue/web` | 链接进不去 | `prebuild.py` 的 Windows 分支没有 web 条目，WebView2 未做 |
| `yue/media` | 链接进不去 | Windows 分支没有 media 条目；ffmpeg-mbt 的 Windows 预构建与 miniaudio WASAPI 未接 |
| `yue/dbus` | 未知 | 依赖会话总线，Windows 上属「随平台批」；跑不绿不算回归，但要把它标出来 |
| 旧链 `yue/`、`examples/{hello,hello-themed,showcase,sysmonitor}`、`modules/yue-examples`、`modules/yue-media` | 预期红 | 本分支的工作队列（全仓红点 287/68 就是它们），别当新问题 |

全仓门禁口径：`moon check`（无参数）287 errors / 68 warnings 是**基线**，只减不增。

### B2 Windows 侧还是占位/待做的（别以为是 bug）

| 项 | 现状 | 影响 |
|---|---|---|
| `wm_window_set_size` | 占位 | 原生浮层「量完内容收框」在 Windows 上不生效 |
| `wm_window_set_fullscreen` | 占位 | 播放器全屏按钮在 Windows 上不生效 |
| `wm_window_set_popup` / `move` / `origin` | 占位 | 原生弹层窗口（下拉/右键菜单/浮层原生的那档）在 Windows 上开不出来 |
| `wm_surface_new/set_rect/close/container` | 占位 | webview pane 放不进窗口（要 WebView2 子 HWND） |
| 图片解码 PNG/JPEG/GIF | 缺 | 只在 Linux 有（GdkPixbuf）；Windows 要 WIC |
| `windowctl`/`monitor`/`wallpaper`/`defaultapps`/`clipboard_watch` | 无 Windows 实现 | 这些是 wmctrl/xrandr/xclip 命令行线 |
| `appfind`/`recent_files`/`launcher` 的 Windows 分支 | 待补 | TODO 记为「随平台批」 |
| sensor/bluetooth/disk、`locale_sys` 的 timedatectl 半、`idle` | 无对应通道 | Linux/DBus 专有，Windows 另议 |

> 上面前五个是纯 Win32 就能写完的（`SetWindowPos` / `ShowWindow` / 无边框 + `WS_EX_NOACTIVATE` / WIC），我没法在这台机器验——**要不要我在这边先写完、你到 Windows 直接编译验**？说一声我就开工。

### B3 Windows 特有真机验收（W 线遗留）

| # | 操作 | 期望 | 结果 |
|---|---|---|---|
| B3-1 | 微软拼音在自绘输入框里打字 | preedit 组合串正常显示、上屏正确（W6 已落，端到端归 W7 注入探针） | |
| B3-2 | 看中英混排字形 | DirectWrite 渲染正常、无彩边（W5 走灰度反锯齿） | |
| B3-3 | 多窗口 | 开附窗、关附窗、宿主仍在（W15 已落） | |
| B3-4 | 跨程序剪贴板 | 复制出去 → 记事本 → 粘回来（W16 已落，跨程序留验） | |
| B3-5 | 文件对话框 | 打开/保存/选目录三段（W14c 探针） | |
| B3-6 | 键码与焦点 | Tab 迁移焦点、回车提交、方向键（W17a 修过键码口径） | |

---

## C. 已知取舍（不是 bug，验到别记）

- 弹层「点外收起」默认关：失焦自收在映射期会误触发，判据未定前故意留着。
- 倍速音高随调：本栈不做时间拉伸。
- XFCE 下主题不跟系统深浅/主色：没有 gsettings 通道，按亮色预设走。
- `remove_binding`/`remove_all_user_scripts` 恒 false：引擎没有注销口。
- 网页 `<video>` 与自绘播放器不统一；一窗不并排多 webview（方案里已锁的「不做」）。
- **6. 2026-10-12 已修（请按 A1-3 复验）**：原先「点进网页再点回原生框，打字毫无反应」。两处根因：① 绘制区没把 GTK 键盘焦点要回来（`GtkDrawingArea` 不会因为被点击就还焦距，WebKit 拿走后键全进网页）；② 空输入框显示 placeholder 时**组合串不画**——拼音在正常走、屏幕上什么都不出现。若还复现，告我行号与现象。
