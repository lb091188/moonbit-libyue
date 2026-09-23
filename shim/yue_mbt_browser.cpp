// 浏览器（WebView）ABI 翻译单元：yue_mbt_browser_* 的全部实现。
// 独立成文件的意图：nu::Browser 引用与 webkit 符号依赖圈在本成员内，
// 静态库按成员拉取，MoonBit 层不 import yue/browser（包边界）的程序
// 链接期接触不到任何 webkit 符号。验证：
//   nm libyue_mbt.a 中 browser 符号只出现在本成员；
//   nm -C libyue_mbt.a | grep 'U.*nu::Browser' 只命中本成员。
// 本文件只做 ABI 翻译，不写业务逻辑（与 yue_mbt.cpp 同一原则）。
#include "nativeui/browser.h"
#include "base/json/json_writer.h"

#include "yue_mbt.h"
#include "yue_mbt_internal.h"

using yue_mbt::BytesFromString;
using yue_mbt::CastTo;
using yue_mbt::ViewStore;

// ---------- Browser ----------

/* GetCookiesForURL：回调收到扁平 UTF-8 文本，每行一条 Cookie，
 * 字段以 \x1f 分隔：name/value/domain/path/http_only/secure */
void yue_mbt_browser_get_cookies_for_url(void *browser, const char *url,
                                         void (*invoke)(void *, void *), void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GetCookiesForURL(std::string(url),
                        [invoke, closure](std::vector<nu::Cookie> cookies) {
                          std::string flat;
                          for (const auto &c : cookies) {
                            flat += c.name;
                            flat += '\x1f';
                            flat += c.value;
                            flat += '\x1f';
                            flat += c.domain;
                            flat += '\x1f';
                            flat += c.path;
                            flat += '\x1f';
                            flat += c.http_only ? "1" : "0";
                            flat += '\x1f';
                            flat += c.secure ? "1" : "0";
                            flat += '\n';
                          }
                          invoke(closure, BytesFromString(flat));
                        });
  }
}

void yue_mbt_browser_load_html(void *browser, const char *html, const char *base_url) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->LoadHTML(std::string(html), std::string(base_url));
  }
}

void yue_mbt_browser_set_user_agent(void *browser, const char *agent) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->SetUserAgent(std::string(agent));
  }
}

void yue_mbt_browser_execute_javascript(void *browser, const char *code) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->ExecuteJavaScript(std::string(code), nu::Browser::ExecutionCallback());
  }
}

/* 自定义协议：MoonBit 回调返回 [ok:i32][mime_len:i32][mime][content] 编码,ok=0 表示拒绝 */
void yue_mbt_browser_register_protocol(const char *scheme,
                                       void *(*invoke)(void *, void *), void *closure) {
  nu::Browser::RegisterProtocol(
      std::string(scheme),
      [invoke, closure](std::string url) -> nu::ProtocolJob * {
        void *bytes = invoke(closure, BytesFromString(url));
        auto *p = static_cast<const char *>(bytes);
        int32_t ok = 0;
        std::memcpy(&ok, p, 4);
        if (ok == 0) {
          return nullptr;
        }
        int32_t mime_len = 0;
        std::memcpy(&mime_len, p + 4, 4);
        std::string mime(p + 8, mime_len);
        int32_t content_len = 0;
        std::memcpy(&content_len, p + 8 + mime_len, 4);
        std::string content(p + 8 + mime_len + 4, content_len);
        return new nu::ProtocolStringJob(mime, content);
      });
}

void yue_mbt_browser_unregister_protocol(const char *scheme) {
  nu::Browser::UnregisterProtocol(std::string(scheme));
}

void *yue_mbt_browser_new_ex(int32_t devtools, int32_t context_menu,
                             int32_t allow_file_access, int32_t hardware_acceleration) {
  nu::Browser::Options options;
  options.devtools = devtools != 0;
  options.context_menu = context_menu != 0;
#if defined(OS_MAC) || defined(OS_LINUX)
  options.allow_file_access_from_files = allow_file_access != 0;
#else
  (void)allow_file_access;
#endif
#if defined(OS_LINUX)
  options.hardware_acceleration = hardware_acceleration != 0;
#else
  (void)hardware_acceleration;
#endif
  return reinterpret_cast<void *>(ViewStore::put(new nu::Browser(options)));
}

void *yue_mbt_browser_new(void) {
  nu::Browser::Options options;
  options.context_menu = true;
#if defined(WEBVIEW2_SUPPORT)
  // Windows 优先 WebView2（loader/运行时缺失时 libyue 内部自动回退 IE）
  options.webview2_support = true;
#endif
  return reinterpret_cast<void *>(ViewStore::put(new nu::Browser(options)));
}

void yue_mbt_browser_load_url(void *browser, const char *url) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->LoadURL(url);
  }
}

void *yue_mbt_browser_get_url(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return BytesFromString(b->GetURL());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_browser_reload(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->Reload();
  }
}

void yue_mbt_browser_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GoBack();
  }
}

void yue_mbt_browser_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->GoForward();
  }
}

int32_t yue_mbt_browser_can_go_back(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->CanGoBack() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_can_go_forward(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->CanGoForward() ? 1 : 0;
  }
  return 0;
}

int32_t yue_mbt_browser_is_loading(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->IsLoading() ? 1 : 0;
  }
  return 0;
}

void yue_mbt_browser_on_change_loading(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_change_loading.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_command(void *browser, void (*invoke)(void *),
                                       void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_update_command.Connect(
        [invoke, closure](nu::Browser *) { invoke(closure); });
  }
}

void yue_mbt_browser_on_update_title(void *browser,
                                     void (*invoke)(void *, void *),
                                     void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_update_title.Connect([invoke, closure](nu::Browser *,
                                                 const std::string &title) {
      invoke(closure, BytesFromString(title));
    });
  }
}

void yue_mbt_browser_on_commit_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_commit_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

void yue_mbt_browser_on_finish_navigation(void *browser,
                                          void (*invoke)(void *, void *),
                                          void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->on_finish_navigation.Connect([invoke, closure](nu::Browser *,
                                                      const std::string &url) {
      invoke(closure, BytesFromString(url));
    });
  }
}

/* Browser:标题与停止(回调版 JS 执行与 AddBinding 另批) */
void *yue_mbt_browser_get_title(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return BytesFromString(b->GetTitle());
  }
  return moonbit_make_bytes(0, 0);
}

void yue_mbt_browser_stop(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->Stop();
  }
}

/* 方法级审计补齐二:Browser JS 回调与绑定 */

void yue_mbt_browser_execute_javascript_callback(
    void *browser, const char *code,
    void (*invoke)(void *, int32_t, void *), void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->ExecuteJavaScript(
        code,
        [invoke, closure](bool ok, base::Value value) {
          std::string json;
          base::JSONWriter::Write(base::ValueView(value), &json);
          invoke(closure, ok ? 1 : 0, BytesFromString(json));
        });
  }
}

void yue_mbt_browser_add_raw_binding(void *browser, const char *name,
                                     void (*invoke)(void *, void *),
                                     void *closure) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->AddRawBinding(name, [invoke, closure](nu::Browser *, base::Value args) {
      std::string json;
      base::JSONWriter::Write(base::ValueView(args), &json);
      invoke(closure, BytesFromString(json));
    });
  }
}

void yue_mbt_browser_remove_binding(void *browser, const char *name) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    b->RemoveBinding(name);
  }
}

int32_t yue_mbt_browser_has_bindings(void *browser) {
  if (auto *b = CastTo<nu::Browser>(browser)) {
    return b->HasBindings() ? 1 : 0;
  }
  return 0;
}
