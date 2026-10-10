# moonbit-libyue 项目申报书（10 月）

## 基本信息

- 项目名称：moonbit-libyue
- 参赛者：刘斌（NoahLiu）
- 联系方式：lbpeter0911@163.com
- GitHub：https://github.com/lb091188/moonbit-libyue
- 项目方向：MoonBit 原生桌面 GUI 基础库
- 是否为移植项目：否

## 项目简介

moonbit-libyue 旨在为 MoonBit 提供原生跨平台桌面 GUI 库
- 以 [libyue](https://libyue.com/docs/latest/cpp/) 封装其全部原生组件，支持 Linux / Windows / macOS
- 为全部组件提供带参构造函数（如 `Button::new("点我")`）命令式 API
- 提供声明式上层 API（响应式 Store + `mount` 布局函数），详见下方三种写法对比
- 补充 libyue 未完善的 Linux 系统托盘与托盘菜单能力
- 自绘主题组件库：现代观感不依赖平台皮肤，深浅色自动跟随
- 系统能力族：亮度 / 音量 / 媒体控制 / 壁纸 / 蓝牙 / 传感器 / 打印机等 25+ 项，统一 `Result` 语义
- 系统集成扩容（Electron 对标 12 项）：防多开、自启动、电源与锁屏事件、电量与网络状态等
- 音频播放（miniaudio）与视频播放（ffprobe/ffmpeg 帧集 → 自绘渲染，浏览器级 VideoPlayer 组件）
- 零配置接入：`moon add` 后直接 `moon run`，链接配置由构建钩子按当前系统自动生成

本库封装将这一切收敛到最薄 C ABI 层，MoonBit 层做平台探测与降级，使用方无平台感知。

### 写法对比

具体功能 `examples/hello`：点击按钮，计数标签自动刷新

**原 CPP**

```cpp
// 未计入的前置成本：CMake 工程集成、静态库编译、三平台依赖安装与链接配置
#include "nativeui/nativeui.h"

int main(int argc, const char *argv[]) {
  nu::Lifetime lifetime;  // 初始化 GUI 工具包
  nu::State state;        // 初始化全局状态

  auto* button = new nu::Button("点我");
  auto* label = new nu::Label("已点 0 次");
  int count = 0;
  button->on_click.Connect([&](nu::Button*) {
    label->SetText("已点 " + std::to_string(++count) + " 次");
  });

  auto* container = new nu::Container();
  container->AddChildView(button);
  container->AddChildView(label);

  auto* window = new nu::Window(nu::Window::Options());
  window->SetContentView(container);
  window->Center();
  window->Activate();
  window->on_close.Connect([](nu::Window*) { nu::MessageLoop::Quit(); });
  nu::MessageLoop::Run();
}
```

**命令式 API**

```moonbit
// 只有 MoonBit：无 C++ 工具链、无链接配置、无手动内存管理
fn main {
  if !@yue.initialize() { return }
  let window = @yue.Window::new()
  let mut count = 0
  let label = @yue.Label::new("已点 0 次")
  let button = @yue.Button::new("点我")
  button.on_click(fn() {
    count += 1
    label.set_text("已点 \{count} 次")
  })
  let root = @yue.Container::new()
  root.add_child(button)
  root.add_child(label)
  window.set_content(root)
  window.center()
  window.on_close(fn(_w) { @yue.quit() })
  window.activate()
  @yue.run()
}
```

**声明式 API**

```moonbit
fn main {
  if !@yue.initialize() { return }
  let clicks : @yue.Store[Int] = @yue.Store::new(0)
  ignore(@yue.mount_window(
    [
      @yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
      // 订阅 clicks：set 即自动刷新文本，"改状态"与"UI 跟随"解耦
      @yue.bind_label(clicks, fn(n) { "已点 \{n} 次" }),
    ],
    title="hello",
    center=true,
    on_close=fn(_w) { @yue.quit() },
  ))
  @yue.run()
}
```

挂载入口 `mount_window` 创建窗口、挂载子树、激活显示一步完成；菜单栏 / 托盘等非视图资产经 `handle` 参数补挂。

## 9 月以来进展

- **图表组件**：折线 / 柱状 / 环形 / 仪表 / 散点五图型自绘组件，千点推点单帧重绘毫秒级（release 实测 1.8~3.1ms），挂 showcase「图表」页
- **sysmonitor 示例**：Ubuntu 进程管理与硬件信息查看器——纯 MoonBit 读 /proc、/sys（CPU / 内存 / 进程 / 温度 / 磁盘 / GPU / 网络），1Hz 刷新、千行虚拟表格、进程 kill / renice，启动中位 81ms、稳态 RSS 86MB、二进制 7.7MB
- **系统集成扩容**（Electron 对标，Linux + Windows 双平台同 API）：防多开与二次唤起、开机自启动、休眠 / 锁屏事件、空闲秒数、屏幕常亮、电量与电源切换、网络状态、打开浏览器 / 文件定位——Linux 侧 DBus 真总线逐项验证
- **系统能力族**：屏幕亮度、键盘背光、系统音量（含逐应用）、媒体播放控制（MPRIS）、夜间色温、壁纸、显示器配置、蓝牙、传感器、打印机、剪贴板监听、最近文件、浏览器书签与历史等 25+ 项，`NoahLiu/yue-examples/systemprobe` 一键呈现本机真实结果
- **音频播放**：miniaudio 后端（WAV / MP3 / FLAC / OGG），引擎 + 剪辑两级 API，音量 / 循环 / 全解码低延迟音效
- **视频播放**：ffprobe CSV 元信息 + ffmpeg CLI 解码 RGBA 帧集（与解码器解耦的帧源回调接口），VideoPlayer 组件（播放 / 暂停 / 进度拖拽防抖 seek / 音量 / 循环 / 时间文本），音画同源时钟
- **质量门禁**：`moon check` 零警告、`moon test` 500+ 用例全绿（每次提交必过）、三平台 GitHub Actions CI、Linux 虚拟显示 GUI 冒烟

## 10 月开发计划

1. **系统接口收尾**：P1-P12 系统集成项在 GNOME / KDE / Windows 10 / 11 真机复验闭环（双开唤起 / 自启动拉起 / 休眠锁屏 / 拔插电源 / 断联网）
2. **音频收尾**：音频光标回读实现精确音画同步（现为同源时钟，误差数十毫秒级）
3. **视频渲染收尾**：真实片源（H.264 mp4 / mkv）全链路实测、长视频内存钳制边界复核、moonav1（纯 MoonBit AV1 解码）帧源接入评估
4. **macOS 真机验证**：全量示例冒烟（hello / showcase / systemprobe）+ 遗留项验证（通知回调、Display 字段、Accelerator / Tray 原生后端、滚轮事件、WebKit 引用面评估），结论回填适配文档

## 核心功能范围

- 主窗口
  - 应用与生命周期
  - 窗口
  - 菜单栏
  - 菜单
  - 菜单项
  - 托盘
- 基础控件
  - 标签
  - 按钮
  - 输入框
  - 滑块
  - 进度条
  - 复选框
  - 单选按钮
  - 容器
  - 页签
  - 声明式界面
- 输入与选择
  - 下拉框
  - 选择器
  - 日期选择器
  - 分组框
  - 滚动视图
  - 文本编辑框
  - 气泡
- 画布
  - 画布
  - 画笔
  - 图片
  - 混合模式
  - 几何值类型
- 网页
  - 浏览器
  - 自定义协议
- 对话框
  - 文件对话框
  - 消息框
  - 文件读写
- 系统集成
  - 外观
  - 区域
  - 屏幕
  - 剪贴板
  - 通知
  - 通知中心
  - 全局快捷键
  - 消息循环
  - 表格
  - 表格模型
- 系统集成扩容（9 月新增）
  - 防多开（单实例）与二次启动唤起
  - 开机自启动
  - 挂起 / 唤醒、锁屏 / 解锁事件
  - 用户空闲秒数
  - 屏幕常亮
  - 电量查询与交直流切换事件
  - 网络在线状态（查询 + 事件）
  - 打开默认浏览器 / 文件管理器定位选中
- 系统能力族（9 月新增，25+ 项）
  - 屏幕亮度 / 键盘背光 / 夜间色温
  - 系统音量（输出设备与逐应用）
  - 媒体播放控制（MPRIS）与状态监视
  - 壁纸 / 显示器配置 / 系统窗口管理
  - 剪贴板监听 / 最近文件 / 目录枚举
  - 电源与登录会话 / 电源计划 / 磁盘卷
  - 系统信息 / 时区与本地语言 / 环境变量
  - 蓝牙 / 传感器 / 打印机
  - 浏览器书签与 Firefox 历史
- 图表组件（9 月新增，全自绘）
  - 折线 / 面积图（y 轴自适应、多序列）
  - 柱状 / 条形图（hover 高亮）
  - 环形 / 饼图（hover 外扩）
  - 仪表盘（阈值分段、数值平滑）
  - 散点图（最小二乘趋势线）
- 媒体（9-10 月新增）
  - 音频播放（miniaudio：WAV / MP3 / FLAC / OGG）
  - 视频播放（帧源回调 + VideoPlayer 组件）
- 事件
  - 鼠标事件
  - 键盘事件
  - 鼠标捕获
  - 全局事件查询
- 富文本
  - 富文本
  - 字体
  - 系统语义色
- 其他已实现组件（独立示例）
  - 拖放（源/目标）
  - 动图播放器
  - 分隔线
  - 光标
  - 窗口选项
- 库级能力
  - 响应式 Store 状态管理
  - 声明式 API
  - Linux 托盘图标与托盘菜单
  - 自绘主题组件库（深浅色跟随）
  - sysmonitor 示例（进程管理 + 硬件监控）

## 预期验收产物

- 可运行示例：examples/ 下 8 个：
  - `moon run examples/hello` 最小示例直接启动验证；
  - `moon run examples/showcase` 全功能演示板（组件库 + 图表 + 系统集成演示）；
  - `moon run NoahLiu/yue-examples/systemprobe` 系统能力族本机实测面板；
  - `moon run examples/sysmonitor` 系统监视器：进程管理 + 硬件监控。
- 三平台 CI：GitHub Actions 在 Linux、Windows、macOS 上自动构建、检查与测试，Linux 含虚拟显示下的 GUI 冒烟，push 与 PR 均触发，结果公开可查；`moon check` 零警告、`moon test` 500+ 用例全绿为每次提交门槛。

## 移植或参考说明

- 原项目名称：libyue
- 原项目链接：https://github.com/yue/yue
- 原项目许可证：GNU Lesser General Public License v2.1
- 本项目许可证：MIT（MoonBit 库层与示例）；vendored libyue 保持 LGPL 2.1，钉版本下载、全源码公开、sha256 校验

与原项目相比，本项目做了以下重新设计与扩展：

- 使用 MoonBit 原生包结构、类型系统与测试方式组织代码；
- 全部控件提供带参构造函数并保留命令式 API；
- 提供声明式 API（响应式 Store + 布局函数）；
- 补齐 libyue 缺失的部分实现；
- 原生层之外新增：系统集成扩容（Electron 对标 12 项）、系统能力族（25+ 项）、自绘图表组件、音频与视频播放。
