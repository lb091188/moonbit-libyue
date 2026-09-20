# 关于我和 libyue
## 认识 libyue
我已经记不清我是什么时候知道这个库的了，只记得当初是在 `Nodejs` 里面寻找 GUI 库，虽然这个库在 Nodejs 可用，但其实并不好用，虽然没有用上，但我还是记下了 `Yue` 或者 `libyue` 这个库的名字，毕竟他的作者是 [赵成(zcbenz)](https://github.com/zcbenz) 著名的 [Electron](https://github.com/electron/electron) 项目的主要贡献者。

## 尝试 libyue
在认识这个库之后，他跨平台的能力，以及轻量的特征，让我对这个库念念不忘，前前后后我尝试过基于 `yode` 、 `lua` 把这个库用到我的日常工作中，但是没有成功，之前也没有现在这样有 AI 的加持，然后 yode 和 lua 也有着各自固有的弊端

## 整合 libyue
今年，我在翻开 [陈随易](https://github.com/chensuiyi2) 公众号的时候发现了他在使用 MoonBit 这个新的语言，于是用梁圣的 DS 了解了以下 MoonBit 得知这门语言简单，轻量，速度也不慢，并且 FFI 兼容和性能还蛮好的，加上年初开的 GLM Coding Plan 还没到期，于是 AI 壮我胆，趁着 MoonBit 官方的 9 月黑客松活动开了现在这个 `moonbit-libyue` 项目