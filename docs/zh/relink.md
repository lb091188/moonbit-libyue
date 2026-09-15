# 原生层变更后强制重链

改 `shim/`、vendor 补丁或 libyue 版本后：重跑 `scripts/prepare.py`，
再强制重链，否则 `moon run` 复用旧 exe。原理见
[docs/adaptation.md](https://gitee.com/noahliu0911/moonbit-libyue/blob/master/docs/zh/adaptation.md)「跨平台通用 → 构建与链接」。

## 判别

exe 的 mtime 早于 `build/libyue_mbt.a` 即命中：

```sh
ls -la --time-style=full-iso \
  _build/native/debug/build/examples/<示例>/<示例>.exe build/libyue_mbt.a
```

## 处理

```sh
moon clean        # 全量重建
# 或只删链接产物：
rm _build/native/debug/build/examples/<示例>/<示例>.exe
```

处理后 exe 的 mtime 应晚于 `build/libyue_mbt.a`。
