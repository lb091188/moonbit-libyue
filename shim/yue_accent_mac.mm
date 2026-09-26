// macOS 系统主色调:NSColor.controlAccentColor → ARGB。
// 独立 ObjC++ 翻译单元:shim 主体是纯 C++,ObjC 运行时调用只能在这里。
// 定义必须显式 extern "C":本文件不 include yue_mbt.h,缺了则按 C++
// mangling 导出,yue_mbt.cpp 按头文件的 C 名引用即链接 undefined
// (macOS CI 实测符号 __Z25yue_mbt_system_accent_macv)。

#import <Cocoa/Cocoa.h>

extern "C" uint32_t yue_mbt_system_accent_mac(void) {
  @autoreleasepool {
    NSColor *accent = [NSColor controlAccentColor];
    NSColor *rgb = [accent colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgb == nil) {
      return 0;
    }
    CGFloat r = 0, g = 0, b = 0, a = 0;
    // AppleClang 17(macos-15 镜像更新后)把 getRed:green:blue:alpha:
    // 的返回值解析成 void,`![...]` 一元取反直接编译错误(invalid
    // argument type 'void');rgb 已确认非 nil 且转为 sRGB,取分量必然
    // 成功,不再判断返回值——万一失败分量保持初值 0,与旧判空分支等价。
    [rgb getRed:&r green:&g blue:&b alpha:&a];
    return (0xFFu << 24) | (static_cast<uint32_t>(r * 255.0 + 0.5) << 16) |
           (static_cast<uint32_t>(g * 255.0 + 0.5) << 8) |
           static_cast<uint32_t>(b * 255.0 + 0.5);
  }
}
