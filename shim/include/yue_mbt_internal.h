// shim 内部共享设施（C++ only，勿放进对外 ABI 头 yue_mbt.h）。
// 句柄注册表与类型校验 helper 在 yue_mbt.cpp 与 yue_mbt_browser.cpp 等
// 多个翻译单元间共享：模板/inline 函数的函数内 static 按 C++ 标准
// 全程序唯一，各 TU 拿到的是同一张注册表——Browser 句柄由本文件提供
// 的 ViewStore 创建，也必须能被通用 View 函数查到。
#ifndef YUE_MBT_INTERNAL_H
#define YUE_MBT_INTERNAL_H

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <unordered_map>

#include "base/memory/scoped_refptr.h"
#include "nativeui/responder.h"
#include "nativeui/view.h"

// 不包含 <moonbit.h>：它在 extern "C" 里声明的 memcpy 与 glibc 的
// C++ noexcept 声明冲突。只声明用到的运行时入口，签名照抄
// ~/.moon/include/moonbit.h。
extern "C" void *moonbit_make_bytes(int32_t size, int value);

namespace yue_mbt {

// 全局句柄计数器：inline 函数的函数内 static，全程序唯一、从 1 起。
inline int64_t next_handle() {
  static int64_t counter = 0;
  return ++counter;
}

// 句柄注册表：id → scoped_refptr。
template <typename T>
struct Store {
  static std::unordered_map<int64_t, scoped_refptr<T>> &map() {
    static std::unordered_map<int64_t, scoped_refptr<T>> m;
    return m;
  }
  static int64_t put(T *obj) {
    int64_t id = next_handle();
    map()[id] = scoped_refptr<T>(obj);
    return id;
  }
  static int64_t put(const scoped_refptr<T> &obj) {
    int64_t id = next_handle();
    map()[id] = obj;
    return id;
  }
  static T *get(void *handle) {
    auto it = map().find(reinterpret_cast<int64_t>(handle));
    return it == map().end() ? nullptr : it->second.get();
  }
};

using ViewStore = Store<nu::Responder>;

// CastTo：从注册表取对象，并用 GetClassName 校验运行时类型。
// （View 自身无 kClassName，故模板仅用于具体控件类型。）
template <typename T>
T *CastTo(void *handle) {
  auto *r = ViewStore::get(handle);
  if (r == nullptr) {
    std::fprintf(stderr, "yue_mbt: 句柄无效\n");
    return nullptr;
  }
  if (std::strcmp(r->GetClassName(), T::kClassName) == 0) {
    return static_cast<T *>(r);
  }
  std::fprintf(stderr, "yue_mbt: 类型不匹配，期望 %s，实际 %s\n", T::kClassName,
               r->GetClassName());
  return nullptr;
}

// 通用 View 检查：View 无 kClassName，类型正确性由 MoonBit 侧
// ViewLike 约束保证。
inline nu::View *CastToView(void *handle) {
  auto *r = ViewStore::get(handle);
  if (r == nullptr) {
    return nullptr;
  }
  return static_cast<nu::View *>(r);
}

// MoonBit Bytes 内容拷贝
inline void *BytesFromString(const std::string &s) {
  void *bytes = moonbit_make_bytes(static_cast<int32_t>(s.size()), 0);
  if (!s.empty()) {
    std::memcpy(bytes, s.data(), s.size());
  }
  return bytes;
}

}  // namespace yue_mbt

#endif  // YUE_MBT_INTERNAL_H
