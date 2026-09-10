# 下一步操作指南

当前状态：骨架完成、已推送 gitee，但**从未编译过**。下面是从零到"窗口弹出来"的操作路径，以及每一步预期能踩到的坑。

## 第 1 步：装系统依赖

```sh
sudo apt install build-essential cmake pkg-config libgtk-3-dev \
  libpango1.0-dev libfontconfig1-dev libx11-dev libwebkit2gtk-4.1-dev
```

验证：`pkg-config --exists webkit2gtk-4.1 && echo ok`

## 第 2 步：构建 libyue 静态库

```sh
cd ~/ownCode/moonbit-libyue
python3 scripts/prepare.py
```

这一步做四件事：下载 libyue v0.15.6（约 4MB，校验 sha256）→ 解压到 `vendor/libyue/` → CMake 编译出 `build/libyue_mbt.a` → 把链接参数回写进 `yue/moon.pkg.json`。

预期坑：

| 现象 | 处理 |
|---|---|
| 下载超时 | `export https_proxy=http://127.0.0.1:7890` 后重跑 |
| CMake 报缺 webkit2gtk-4.0 | 正常，脚本会自动落到 4.1；两个都没有才失败 |
| 报缺其他 pkg-config 包 | 按提示补装对应 `-dev` 包 |

## 第 3 步：首次编译验证（改到通为止）

```sh
moon check        # 类型/语法层，最快
moon run examples/hello
```

**已知会报的错，按此修：**

1. `examples/hello/main.mbt` 的 `"\{err}"` 插值报缺 `Show` —— `error.mbt` 里故意没写 Show 实现。最稳修法：hello 里把 match 的错误分支改成显式转字符串，不依赖 Show。
2. `yue/moon.pkg.json` 的 `link.native.cc-link-flags` 写法报错 —— 说明该 moon 版本不认 JSON 格式，把 link 段换成 `moon.pkg`（MoonBit 语法）的 `link(native("cc-link-flags": ...))` 写法（见 `.agents/skills/moonbit-c-binding/SKILL.md` Phase 1）。
3. `extern "c" fn ... -> Tray?` 报不支持 —— 改成永远返回 `Tray`，"失败"前置到 `is_supported()` 检查（图标加载失败这个错误码先放弃）。
4. `FuncRef[((() -> Unit) -> Unit)]` 类型不匹配 —— 对照 skill 的 `references/callbacks.md` 原文签名逐字对齐。
5. 链接期 `cannot find -lyue_mbt` —— `prepare.py` 已回写绝对路径；若仍报，检查回写是否成功（`git diff yue/moon.pkg.json`）。

**验收标准**：弹出 400x300 窗口，显示 "Hello, MoonBit + libyue!"，点关闭后进程退出；终端打印托盘状态行（有 AppIndicator 则创建，没有则打印降级信息——后者在你装了 `libayatana-appindicator3-1` 后可验证正路径）。

## 第 4 步：把修复提交回仓库

```sh
git add -A
git commit -m "【修复】moonbit-libyue：完成首次编译验证并修正 FFI 层问题"
git push
```

## 之后的扩展路线（每加一个控件同一模式）

1. `shim/yue_mbt.cpp` 加机械转换函数（对照 `include/nativeui/` 头文件签名）
2. `shim/include/yue_mbt.h` 加 C 声明
3. `yue/ffi.mbt` 加 extern
4. 新建 `yue/<控件>.mbt` 写类型和方法，字符串统一走 `utf8_bytes()`
5. 有事件的控件：照抄 `window.mbt` 的注册表 + trampoline 模式

优先级建议：Container/Button/Entry（凑出可用表单）→ Menu（托盘配菜单才有实用价值）→ Image/通知 → macOS、Windows 实测 → 发 mooncakes 包。

## 随手可查

- FFI 规范、坑清单：`.agents/skills/moonbit-c-binding/`
- 完整 API 对照：libyue TS 声明（github.com/yue/yue releases 里的 `yue_typescript_declarations`）
- Lua 绑定实现参考：github.com/yue/yue 的 `lua_yue/`（类绑定、信号、平台 gate 的写法）
