// macOS 系统主色调:NSColor.controlAccentColor → ARGB。
// 独立 ObjC++ 翻译单元:shim 主体是纯 C++,ObjC 运行时调用只能在这里。

#import <Cocoa/Cocoa.h>

uint32_t yue_mbt_system_accent_mac(void) {
  @autoreleasepool {
    NSColor *accent = [NSColor controlAccentColor];
    NSColor *rgb = [accent colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (rgb == nil) {
      return 0;
    }
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![rgb getRed:&r green:&g blue:&b alpha:&a]) {
      return 0;
    }
    return (0xFFu << 24) | (static_cast<uint32_t>(r * 255.0 + 0.5) << 16) |
           (static_cast<uint32_t>(g * 255.0 + 0.5) << 8) |
           static_cast<uint32_t>(b * 255.0 + 0.5);
  }
}
