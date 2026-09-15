# 原生层变更与强制重链

改了 `shim/`、vendor 补丁或 libyue 版本,重跑 `scripts/prepare.py` 后,
`moon run` 行为不变——修复"不生效"。这不是补丁没打上,而是 moon 复用了
旧的链接产物。

## 原因

两层缓存互不知情:

1. `scripts/prebuild.py` 只在静态库**缺失**时才调 `prepare.py`(存在即
   毫秒级返回),改了 C++ 源码不会自动重建 `build/libyue_mbt.a`。
2. moon 的增量依赖图只含 MoonBit 源文件与 prebuild 输出的 link_configs;
   静态库只以**路径**出现在链接参数里,其内容/时间戳变化不触发重链。

实测时间线(2026-09-15):`moon run` 08:02:25 链接出 exe → `prepare.py`
08:03:01 重建 `.a`(补丁已打入)→ 之后每次 `moon run` moon 认为产物
最新,直接复用旧 exe——跑的永远是链着旧库的二进制。

纯 MoonBit 改动不受影响:源文件在依赖图内,正常重编重链。

## 判别

比较两产物 mtime,exe 更早即命中:

```sh
ls -la --time-style=full-iso \
  _build/native/debug/build/examples/<示例>/<示例>.exe build/libyue_mbt.a
```

## 处理

```sh
moon clean        # 稳妥,全量重建
# 或只删链接产物,强制重链:
rm _build/native/debug/build/examples/<示例>/<示例>.exe
```

处理后 exe 的 mtime 应晚于 `build/libyue_mbt.a`。

## 边界

- 影响面:仓库开发者(C++ 侧改动);mooncakes 使用方不碰 shim/vendor,不涉及。
- 可选根治(未实现):prebuild.py 检测 `.a` 比链接产物新时向 link_flags
  掺入变化标记,迫使 moon 重链。
