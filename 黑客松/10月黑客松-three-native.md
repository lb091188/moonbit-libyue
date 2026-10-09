# moonbit-libyue 项目申报书

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
  let window = @yue.Window::new()
  window.set_content(@yue.mount([
    @yue.button("点我", on_click=fn() { clicks.update(fn(n) { n + 1 }) }),
    // 订阅 clicks：set 即自动刷新文本，"改状态"与"UI 跟随"解耦
    @yue.bind_label(clicks, fn(n) { "已点 \{n} 次" }),
  ]))
  window.center()
  window.on_close(fn(_w) { @yue.quit() })
  window.activate()
  @yue.run()
}
```

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

## 预期验收产物

- 可运行示例：examples/ 下 15 个：
  - `moon run examples/hello` 可直接启动验证；
  - `moon run examples/showcase` 覆盖上列全部组件。
- 三平台 CI：GitHub Actions 在 Linux、Windows、macOS 上自动构建、检查与测试，Linux 含虚拟显示下的 GUI 冒烟，push 与 PR 均触发，结果公开可查。

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
