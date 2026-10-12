// 系统能力桩（sys 线）：目录枚举 / 环境变量写删 / 文本文件读删 /
// 平台标识 / 子进程执行 / 分离式启动 / 文件对话框（Windows 端）。
// 只用系统标准头（POSIX dirent/unistd + Windows SDK），直接走 moon 的
// native-stub 编译（区别于要 GTK 头的 win 桩——那个由 prebuild 编静态库）。
// ABI 约定与 master 的 shim 同源：多字符串返回扁平 UTF-8 文本
// （'\n' 分行），字节串经 moonbit_make_bytes 构造（运行时符号，
// extern 声明即可用——ime_probe_stub 同款）。
//
// Windows 侧路径一律 UTF-8 进、宽字符 API 出（FindFirstFileW/_wfopen/
// CreateProcessW——A 版是 ANSI 代码页，中文路径乱码，见 adaptation）。

#if defined(__linux__) && !defined(_GNU_SOURCE)
// execvpe 是 glibc 扩展，不放开特性宏就声明不到（Linux 上编成隐式声明）；
// 必须在任何系统头之前定义。macOS 走 execvp，不需要。
#define _GNU_SOURCE
#endif

#if defined(_WIN32)
// 本桩有意用 getenv/wcscpy/wcscat（POSIX 分支同名调用的对应物），MSVC 的
//「安全版」后缀只是告警不改语义，关掉以免污染构建日志。必须放在所有标准头
// 之前——UCRT 在 stdio.h/string.h 里就按这个宏决定要不要声明弃用名。
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h> // SHCreateItemFromParsingName
// ShellExecuteW（分离式启动）不在 LEAN_AND_MEAN 的窗口头集合里
#include <shellapi.h>
#else
#include <dirent.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

// moon 运行时的字节构造（运行期符号，声明即链接）
extern void *moonbit_make_bytes(int size, int value);

#if defined(_WIN32)
// UTF-8 → 宽字符（返回 malloc 串，调用方 free；失败返回 NULL）
static wchar_t *win_utf8_wide(const char *s, int extra) {
  if (s == NULL) {
    return NULL;
  }
  int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
  if (n <= 0) {
    return NULL;
  }
  wchar_t *w = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)(n + extra));
  if (w == NULL) {
    return NULL;
  }
  MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n);
  return w;
}

// 宽字符 → moon 字节串（UTF-8，不带结尾 NUL；失败给空串）
static void *win_wide_bytes(const wchar_t *w) {
  if (w == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, NULL, 0, NULL, NULL);
  if (n <= 1) {
    return moonbit_make_bytes(0, 0);
  }
  void *out = moonbit_make_bytes(n - 1, 0);
  WideCharToMultiByte(CP_UTF8, 0, w, -1, (char *)out, n, NULL, NULL);
  return out;
}
#endif

// 平台标识：0 = linux，1 = windows，2 = macos
int32_t yue_sys_platform(void) {
#if defined(_WIN32)
  return 1;
#elif defined(__APPLE__)
  return 2;
#else
  return 0;
#endif
}

// 目录枚举：子项名扁平 UTF-8 文本（'\n' 分行，不含 . ..，不递归，
// 含隐藏项）。打不开（不存在/非目录/无权限）ok=0 返回空文本。
void *yue_sys_list_dir(const char *path, int32_t *ok) {
  *ok = 0;
  if (path == NULL) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(_WIN32)
  // 宽字符路由：A 版是 ANSI 代码页，非 ASCII 路径（中文用户目录）乱码
  wchar_t *wpath = win_utf8_wide(path, 0);
  if (wpath == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t wlen = wcslen(wpath);
  wchar_t *pattern = (wchar_t *)malloc(sizeof(wchar_t) * (wlen + 4));
  if (pattern == NULL) {
    free(wpath);
    return moonbit_make_bytes(0, 0);
  }
  wcscpy(pattern, wpath);
  wcscat(pattern, L"\\*");
  WIN32_FIND_DATAW fd;
  HANDLE h = FindFirstFileW(pattern, &fd);
  free(pattern);
  free(wpath);
  if (h == INVALID_HANDLE_VALUE) {
    return moonbit_make_bytes(0, 0);
  }
  size_t cap = 256;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    FindClose(h);
    return moonbit_make_bytes(0, 0);
  }
  int good = 1;
  for (;;) {
    const wchar_t *name = fd.cFileName;
    // 跳过 . 与 ..（FindFirstFileW 不像 readdir 那样保证滤掉）
    if (!(name[0] == L'.' &&
          (name[1] == L'\0' || (name[1] == L'.' && name[2] == L'\0')))) {
      int un = WideCharToMultiByte(CP_UTF8, 0, name, -1, NULL, 0, NULL, NULL);
      if (un > 1) {
        if (len + (size_t)un + 1 > cap) {
          cap = (len + (size_t)un + 1) * 2;
          char *nb = (char *)realloc(buf, cap);
          if (nb == NULL) {
            good = 0;
            break;
          }
          buf = nb;
        }
        WideCharToMultiByte(CP_UTF8, 0, name, -1, buf + len, un, NULL, NULL);
        len += (size_t)un - 1; // 去掉转换出的 '\0'
        buf[len] = '\n';
        len += 1;
      }
    }
    if (FindNextFileW(h, &fd) == 0) {
      break;
    }
  }
  FindClose(h);
  if (!good) {
    free(buf);
    return moonbit_make_bytes(0, 0);
  }
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, buf, len);
  }
  free(buf);
  *ok = 1;
  return out;
#else
  DIR *dir = opendir(path);
  if (dir == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t cap = 256;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    closedir(dir);
    return moonbit_make_bytes(0, 0);
  }
  struct dirent *ent;
  while ((ent = readdir(dir)) != NULL) {
    const char *name = ent->d_name;
    if (name[0] == '.' &&
        (name[1] == '\0' || (name[1] == '.' && name[2] == '\0'))) {
      continue;
    }
    size_t nl = strlen(name) + 1; // 名 + '\n'
    if (len + nl + 1 > cap) {
      cap = (len + nl + 1) * 2;
      char *nb = (char *)realloc(buf, cap);
      if (nb == NULL) {
        free(buf);
        closedir(dir);
        return moonbit_make_bytes(0, 0);
      }
      buf = nb;
    }
    memcpy(buf + len, name, nl - 1);
    buf[len + nl - 1] = '\n';
    len += nl;
  }
  closedir(dir);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, buf, len);
  }
  free(buf);
  *ok = 1;
  return out;
#endif
}

// 写环境变量：overwrite=0 且已存在时保持原值；仅作用当前进程。
int32_t yue_sys_setenv(const char *name, const char *value, int32_t overwrite, int32_t *ok) {
  *ok = 0;
  if (name == NULL || value == NULL || strchr(name, '=') != NULL) {
    return -1;
  }
#if defined(_WIN32)
  // 宽字符路由：_putenv_s/getenv 是 ANSI 版，值里的非 ASCII（中文路径、
  // 中文内容）会按进程 ANSI 代码页（本机 936）来回搅，UTF-8 字节进去就是
  // 「鍊糀」这类乱码出来——必须 _wputenv_s 进宽字符环境块。
  wchar_t *wn = win_utf8_wide(name, 0);
  wchar_t *wv = win_utf8_wide(value, 0);
  if (wn == NULL || wv == NULL) {
    if (wn != NULL) {
      free(wn);
    }
    if (wv != NULL) {
      free(wv);
    }
    return -1;
  }
  int rc = -1;
  // 已存在的判据用 GetEnvironmentVariableW：返回 0 = 不存在（本平台的变
  // 量不存在「存在但值为空」这一档，空值即删除，见 adaptation）
  if (overwrite == 0 && GetEnvironmentVariableW(wn, NULL, 0) > 0) {
    *ok = 1;
    rc = 0;
  } else if (_wputenv_s(wn, wv) == 0) {
    *ok = 1;
    rc = 0;
  }
  free(wn);
  free(wv);
  return rc;
#else
  if (setenv(name, value, overwrite != 0) == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
#endif
}

// 删环境变量：本就不存在也记 ok=1（幂等）。
int32_t yue_sys_unsetenv(const char *name, int32_t *ok) {
  *ok = 0;
  if (name == NULL || strchr(name, '=') != NULL) {
    return -1;
  }
#if defined(_WIN32)
  // 空值即删除（Windows 环境块的固有语义，与 POSIX 的 unsetenv 等价）
  wchar_t *wn = win_utf8_wide(name, 0);
  if (wn == NULL) {
    return -1;
  }
  int rc = _wputenv_s(wn, L"") == 0 ? 0 : -1;
  free(wn);
  if (rc == 0) {
    *ok = 1;
  }
  return rc;
#else
  if (unsetenv(name) == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
#endif
}

// 读文本文件全文（二进制读整段；打不开/读失败 ok=0 返回空）。
// 长度**不能只靠 fseek(END)/ftell**：/proc 与 /sys 下的伪文件报告 0 字节，
// 内容只在真正读的时候才出现（按定长分配就会拿到空串）。这里以 ftell
// 作提示、按块循环 fread 到 EOF，普通文件与大文件（数十 MB 的 SQLite 库）
// 同一条路径。
void *yue_sys_read_text_file(const char *path, int32_t *ok) {
  *ok = 0;
  if (path == NULL) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(_WIN32)
  wchar_t *wpath = win_utf8_wide(path, 0);
  if (wpath == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  FILE *f = _wfopen(wpath, L"rb");
  free(wpath);
#else
  FILE *f = fopen(path, "rb");
#endif
  if (f == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t cap = 65536;
  if (fseek(f, 0, SEEK_END) == 0) {
    long hint = ftell(f);
    if (hint > 0) {
      cap = (size_t)hint + 1;
    }
    rewind(f);
  }
  char *buf = (char *)malloc(cap);
  if (buf == NULL) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  size_t len = 0;
  int failed = 0;
  for (;;) {
    if (len + 1 >= cap) {
      if (cap > (size_t)INT32_MAX / 2) {
        failed = 1; // 超过 moonbit_make_bytes 的 int 长度上限
        break;
      }
      cap *= 2;
      char *nb = (char *)realloc(buf, cap);
      if (nb == NULL) {
        failed = 1;
        break;
      }
      buf = nb;
    }
    size_t n = fread(buf + len, 1, cap - len - 1, f);
    len += n;
    if (n == 0) {
      break;
    }
  }
  if (failed || (ferror(f) && !feof(f))) {
    free(buf);
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  fclose(f);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, buf, len);
  }
  free(buf);
  *ok = 1;
  return out;
}

// 删文件：本就不存在视为成功（幂等）；存在但删失败返回 -1。
int32_t yue_sys_remove_file(const char *path, int32_t *ok) {
  *ok = 0;
  if (path == NULL) {
    return -1;
  }
#if defined(_WIN32)
  wchar_t *wpath = win_utf8_wide(path, 0);
  if (wpath == NULL) {
    return -1;
  }
  // 探测「在不在」：fopen 打开成功即存在（与 POSIX 分支同一判据），
  // 关掉再删——不探的话 _wremove 对不存在的路径也返回非零，幂等语义就丢了
  FILE *probe = _wfopen(wpath, L"rb");
  if (probe == NULL) {
    free(wpath);
    *ok = 1; // 本就不存在
    return 0;
  }
  fclose(probe);
  int32_t rc = _wremove(wpath) == 0 ? 0 : -1;
  free(wpath);
  if (rc == 0) {
    *ok = 1;
  }
  return rc;
#else
  FILE *probe = fopen(path, "rb");
  if (probe == NULL) {
    *ok = 1; // 本就不存在
    return 0;
  }
  fclose(probe);
  if (remove(path) == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
#endif
}

// 读环境变量（进程实时环境，反映 setenv/unsetenv 后的状态）。
// 不存在 ok=0 返回空文本。
void *yue_sys_getenv(const char *name, int32_t *ok) {
  *ok = 0;
  if (name == NULL) {
    return moonbit_make_bytes(0, 0);
  }
#if defined(_WIN32)
  wchar_t *wn = win_utf8_wide(name, 0);
  if (wn == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  // 两趟：先问长度（含结尾 NUL），再取串；长度 0 = 变量不存在
  DWORD need = GetEnvironmentVariableW(wn, NULL, 0);
  if (need == 0) {
    free(wn);
    return moonbit_make_bytes(0, 0);
  }
  wchar_t *buf = (wchar_t *)malloc(sizeof(wchar_t) * ((size_t)need + 1));
  if (buf == NULL) {
    free(wn);
    return moonbit_make_bytes(0, 0);
  }
  DWORD got = GetEnvironmentVariableW(wn, buf, need + 1);
  free(wn);
  if (got == 0 || got > need) {
    free(buf);
    return moonbit_make_bytes(0, 0);
  }
  void *out = win_wide_bytes(buf);
  free(buf);
  *ok = 1;
  return out;
#else
  const char *v = getenv(name);
  if (v == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(v);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, v, len);
  }
  *ok = 1;
  return out;
#endif
}

// 写文本文件全文（存在覆盖，不存在新建；父目录须已存在）。
int32_t yue_sys_write_text_file(const char *path, const char *data, int32_t *ok) {
  *ok = 0;
  if (path == NULL || data == NULL) {
    return -1;
  }
#if defined(_WIN32)
  wchar_t *wpath = win_utf8_wide(path, 0);
  if (wpath == NULL) {
    return -1;
  }
  FILE *f = _wfopen(wpath, L"wb");
  free(wpath);
#else
  FILE *f = fopen(path, "wb");
#endif
  if (f == NULL) {
    return -1;
  }
  size_t len = strlen(data);
  int good = 1;
  if (len > 0 && fwrite(data, 1, len, f) != len) {
    good = 0;
  }
  fclose(f);
  if (good) {
    *ok = 1;
    return 0;
  }
  return -1;
}

// 当前工作目录（getcwd，失败 ok=0 返回空文本）。
void *yue_sys_getcwd(int32_t *ok) {
  *ok = 0;
#if defined(_WIN32)
  // UCRT 没有宽字符版 getcwd（_getwcwd 这个「看着像」的名字在 SDK 里根本
  // 不存在，声明成隐式 int 会把返回的指针截断），直接走 Win32 API：
  // 第一次传 0 问长度（含结尾 NUL），第二次取串。
  DWORD need = GetCurrentDirectoryW(0, NULL);
  if (need == 0) {
    return moonbit_make_bytes(0, 0);
  }
  wchar_t *w = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)need);
  if (w == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  DWORD got = GetCurrentDirectoryW(need, w);
  if (got == 0 || got >= need) {
    free(w);
    return moonbit_make_bytes(0, 0);
  }
  void *out = win_wide_bytes(w);
  free(w);
  *ok = 1;
  return out;
#else
  char buf[4096];
  if (getcwd(buf, sizeof(buf)) == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(buf);
  void *out = moonbit_make_bytes((int)len, 0);
  if (len > 0) {
    memcpy(out, buf, len);
  }
  *ok = 1;
  return out;
#endif
}

// 分离式启动：execvp 直传 argv（不经 shell，参数里无命令替换风险），子
// 进程脱离会话与新进程组，标准输入输出全接 /dev/null。双 fork + 一根
// CLOEXEC 管道：中间进程只读「真正子进程有没有 exec 成功」——exec 成功
// 时管道写端被 exec 关掉（读到 EOF），失败时子进程写一个 'E'，所以调用
// 方等中间进程退出即可拿到结果，既不会留下僵尸（中间进程由本函数回收，
// 真孙进程过继给 init），也不会被 xdg-open 这类启动后仍驻留的程序拖住。
int32_t yue_sys_spawn_detached(const char *file, const char *arg) {
#if defined(_WIN32)
  // ShellExecuteW 的「open」动词自带系统关联：URL 走默认浏览器、文档走
  // 关联程序、可执行文件直接起——正对应 POSIX 分支里 xdg-open 的角色。
  // 返回值是 HINSTANCE 语义的旧式状态：>32 才算启动成功，≤32 是 SE_ERR_*。
  if (file == NULL || file[0] == '\0') {
    return -1;
  }
  wchar_t *wfile = win_utf8_wide(file, 0);
  if (wfile == NULL) {
    return -1;
  }
  wchar_t *warg = (arg != NULL && arg[0] != '\0') ? win_utf8_wide(arg, 0) : NULL;
  // 工作目录传 NULL：ShellExecuteW 用当前目录，与 execvp 的继承语义一致
  INT_PTR rc = (INT_PTR)ShellExecuteW(NULL, L"open", wfile, warg, NULL,
                                      SW_SHOWNORMAL);
  free(wfile);
  if (warg != NULL) {
    free(warg);
  }
  return rc > 32 ? 0 : -1;
#else
  if (file == NULL || file[0] == '\0') {
    return -1;
  }
  int fds[2];
  if (pipe(fds) != 0) {
    return -1;
  }
  // 写端标 CLOEXEC：孙进程 exec 成功即自动关闭，中间进程据此判成败
  fcntl(fds[1], F_SETFD, FD_CLOEXEC);
  pid_t mid = fork();
  if (mid < 0) {
    close(fds[0]);
    close(fds[1]);
    return -1;
  }
  if (mid == 0) {
    setsid();
    pid_t gc = fork();
    if (gc < 0) {
      _exit(1);
    }
    if (gc == 0) {
      close(fds[0]);
      int devnull = open("/dev/null", O_RDWR);
      if (devnull >= 0) {
        dup2(devnull, STDIN_FILENO);
        dup2(devnull, STDOUT_FILENO);
        dup2(devnull, STDERR_FILENO);
        if (devnull > 2) {
          close(devnull);
        }
      }
      char *argv[3];
      argv[0] = (char *)file;
      argv[1] = (arg != NULL && arg[0] != '\0') ? (char *)arg : NULL;
      argv[2] = NULL;
      execvp(file, argv);
      // exec 失败才走到这里：写端仍在（CLOEXEC 只在 exec 成功时关掉）
      ssize_t wrote = write(fds[1], "E", 1);
      (void)wrote;
      _exit(127);
    }
    // 中间进程：先派生完再交回写端，只等 exec 的成败信号
    close(fds[1]);
    char c = 0;
    ssize_t n = read(fds[0], &c, 1);
    close(fds[0]);
    _exit(n == 1 ? 1 : 0);
  }
  close(fds[0]);
  close(fds[1]);
  int status = 0;
  if (waitpid(mid, &status, 0) < 0) {
    return -1;
  }
  if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
    return 0;
  }
  return -1;
#endif
}

// ---------------------------------------------------------------------------
// 子进程执行（proc_spawn / proc_wait / proc_getpid）
//
// 语义与 master 线 shim 的同名实现逐位对齐（那条链路已在 Linux/macOS/
// Windows 三平台跑通），差别只在这里是纯 C：宽字符串自己拼、环境块自己排。
// 约定：
//   · args_blob / env_blob 都是「条目以 NUL 分隔、空条目收尾」的 UTF-8 文本；
//     env_blob 为空 = 继承父进程环境（Windows 走的就是这条，POSIX 侧由调用方
//     给最小环境 + LC_ALL=C）。
//   · proc_spawn 返回 pid（>0），负数 = 失败且绝对值是系统错误码（POSIX 取
//     errno，Windows 取 GetLastError）——命令不存在在 Unix 下由子进程以退出码
//     127 呈现，在 Windows 下 CreateProcessW 直接失败，故两平台落点不同。
//   · proc_wait 返回 0 表示 status/code 有效：status 0=正常退出（code=退出码）、
//     1=超时（已强杀）、2=被信号终止（code=信号号，仅 POSIX 出现）；负数=出错。
//   · Windows 侧只回 pid 不留句柄：wait 时按 pid OpenProcess，句柄用完即关，
//     省掉一张跨调用的句柄表与其泄漏风险。
// ---------------------------------------------------------------------------

#if defined(_WIN32)

// 可变宽字符缓冲（命令行与环境块都要边拼边长）
typedef struct {
  wchar_t *p;
  size_t len; // 已写入的字符数（不含结尾 NUL）
  size_t cap; // 容量（wchar_t 个数，含结尾 NUL 位）
  int ok;
} WBuf;

static void wb_init(WBuf *b, size_t cap) {
  b->p = (wchar_t *)malloc(sizeof(wchar_t) * cap);
  b->len = 0;
  b->cap = b->p != NULL ? cap : 0;
  b->ok = b->p != NULL;
  if (b->ok) {
    b->p[0] = L'\0';
  }
}

static void wb_reserve(WBuf *b, size_t extra) {
  if (!b->ok) {
    return;
  }
  if (b->len + extra + 1 <= b->cap) {
    return;
  }
  size_t cap = b->cap * 2;
  while (b->len + extra + 1 > cap) {
    cap *= 2;
  }
  wchar_t *np = (wchar_t *)realloc(b->p, sizeof(wchar_t) * cap);
  if (np == NULL) {
    b->ok = 0;
    return;
  }
  b->p = np;
  b->cap = cap;
}

static void wb_putc(WBuf *b, wchar_t c) {
  wb_reserve(b, 1);
  if (!b->ok) {
    return;
  }
  b->p[b->len++] = c;
  b->p[b->len] = L'\0';
}

static void wb_puts(WBuf *b, const wchar_t *s) {
  size_t n = wcslen(s);
  wb_reserve(b, n);
  if (!b->ok) {
    return;
  }
  memcpy(b->p + b->len, s, sizeof(wchar_t) * n);
  b->len += n;
  b->p[b->len] = L'\0';
}

// 按 CommandLineToArgvW 的口径加引号：含空格/Tab 才引，串里的 " 前反斜杠
// 翻倍再补一个 \，结尾的反斜杠串整体翻倍（procrun 的实参是路径与固定开关，
// 不会出现嵌套引号前的长反斜杠串，与 master 同一简化版）。
static void win_append_quoted(WBuf *b, const wchar_t *s) {
  int needs = 0;
  for (const wchar_t *p = s; *p != L'\0'; p++) {
    if (*p == L' ' || *p == L'\t') {
      needs = 1;
      break;
    }
  }
  if (!needs) {
    wb_puts(b, s);
    return;
  }
  wb_putc(b, L'"');
  size_t back = 0;
  for (const wchar_t *p = s; *p != L'\0'; p++) {
    wchar_t c = *p;
    if (c == L'\\') {
      back++;
      continue;
    }
    if (c == L'"') {
      for (size_t i = 0; i < back * 2 + 1; i++) {
        wb_putc(b, L'\\');
      }
      wb_putc(b, L'"');
    } else {
      for (size_t i = 0; i < back; i++) {
        wb_putc(b, L'\\');
      }
      wb_putc(b, c);
    }
    back = 0;
  }
  for (size_t i = 0; i < back * 2; i++) {
    wb_putc(b, L'\\');
  }
  wb_putc(b, L'"');
}

static int win_cmp_wide(const void *a, const void *b) {
  return wcscmp(*(const wchar_t *const *)a, *(const wchar_t *const *)b);
}

// env_blob → CreateProcessW 的 lpEnvironment：条目按名排序（环境块的规范
// 要求）、每条宽字符后带 NUL、整体再补一个 NUL 收尾；空 blob 返回 NULL
// （即继承父环境）。
static wchar_t *win_env_block(const char *env_blob) {
  if (env_blob == NULL || env_blob[0] == '\0') {
    return NULL;
  }
  int n = 0;
  for (const char *p = env_blob; *p != '\0'; p += strlen(p) + 1) {
    n++;
  }
  wchar_t **items = (wchar_t **)malloc(sizeof(wchar_t *) * (size_t)(n > 0 ? n : 1));
  if (items == NULL) {
    return NULL;
  }
  int i = 0;
  size_t total = 1;
  for (const char *p = env_blob; *p != '\0'; p += strlen(p) + 1) {
    items[i] = win_utf8_wide(p, 0);
    if (items[i] == NULL) {
      for (int j = 0; j < i; j++) {
        free(items[j]);
      }
      free(items);
      return NULL;
    }
    total += wcslen(items[i]) + 1;
    i++;
  }
  qsort(items, (size_t)n, sizeof(wchar_t *), win_cmp_wide);
  wchar_t *block = (wchar_t *)malloc(sizeof(wchar_t) * total);
  if (block != NULL) {
    size_t at = 0;
    for (int k = 0; k < n; k++) {
      size_t len = wcslen(items[k]);
      memcpy(block + at, items[k], sizeof(wchar_t) * len);
      at += len;
      block[at++] = L'\0';
      free(items[k]);
    }
    block[at] = L'\0';
  }
  free(items);
  return block;
}

// 建可继承的写句柄（stdout/stderr 落临时文件）；失败返回 NULL。
static HANDLE win_inheritable_file(const char *path) {
  if (path == NULL || path[0] == '\0') {
    return NULL;
  }
  wchar_t *w = win_utf8_wide(path, 0);
  if (w == NULL) {
    return NULL;
  }
  SECURITY_ATTRIBUTES sa;
  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;
  HANDLE h = CreateFileW(w, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                         &sa, OPEN_ALWAYS, 0, NULL);
  free(w);
  if (h == INVALID_HANDLE_VALUE) {
    return NULL;
  }
  // 追加口径与 POSIX 分支的 O_APPEND 对齐（同一文件被两次跑复用时不覆写）
  SetFilePointer(h, 0, NULL, FILE_END);
  return h;
}

int32_t yue_sys_proc_spawn(const char *file, const char *args_blob,
                           const char *cwd, const char *out_path,
                           const char *err_path, const char *env_blob) {
  if (file == NULL || file[0] == '\0') {
    return -ERROR_INVALID_PARAMETER;
  }
  WBuf cmd;
  wb_init(&cmd, 256);
  wchar_t *wfile = win_utf8_wide(file, 0);
  if (wfile == NULL) {
    return -ERROR_NOT_ENOUGH_MEMORY;
  }
  win_append_quoted(&cmd, wfile);
  free(wfile);
  if (args_blob != NULL) {
    for (const char *p = args_blob; *p != '\0'; p += strlen(p) + 1) {
      wb_putc(&cmd, L' ');
      wchar_t *wa = win_utf8_wide(p, 0);
      if (wa == NULL) {
        free(cmd.p);
        return -ERROR_NOT_ENOUGH_MEMORY;
      }
      win_append_quoted(&cmd, wa);
      free(wa);
    }
  }
  if (!cmd.ok) {
    free(cmd.p);
    return -ERROR_NOT_ENOUGH_MEMORY;
  }
  wchar_t *env_block = win_env_block(env_blob);
  wchar_t *wcwd = (cwd != NULL && cwd[0] != '\0') ? win_utf8_wide(cwd, 0) : NULL;

  STARTUPINFOW si;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESTDHANDLES;
  SECURITY_ATTRIBUTES sa;
  sa.nLength = sizeof(sa);
  sa.lpSecurityDescriptor = NULL;
  sa.bInheritHandle = TRUE;
  si.hStdInput = CreateFileW(L"NUL", GENERIC_READ,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
                             OPEN_EXISTING, 0, NULL);
  if (si.hStdInput == INVALID_HANDLE_VALUE) {
    si.hStdInput = NULL;
  }
  si.hStdOutput = win_inheritable_file(out_path);
  si.hStdError = win_inheritable_file(err_path);

  PROCESS_INFORMATION pi;
  ZeroMemory(&pi, sizeof(pi));
  // 应用名传空、整条命令行走 lpCommandLine：CreateProcessW 按「应用目录 →
  // 当前目录 → 系统目录 → Windows 目录 → PATH」搜索可执行文件
  BOOL ok = CreateProcessW(NULL, cmd.p, NULL, NULL, TRUE, CREATE_NO_WINDOW,
                           env_block, (wcwd != NULL && wcwd[0] != L'\0') ? wcwd : NULL,
                           &si, &pi);
  if (si.hStdInput != NULL) {
    CloseHandle(si.hStdInput);
  }
  if (si.hStdOutput != NULL) {
    CloseHandle(si.hStdOutput);
  }
  if (si.hStdError != NULL) {
    CloseHandle(si.hStdError);
  }
  free(cmd.p);
  if (env_block != NULL) {
    free(env_block);
  }
  if (wcwd != NULL) {
    free(wcwd);
  }
  if (!ok) {
    return -(int32_t)GetLastError();
  }
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return (int32_t)pi.dwProcessId;
}

int32_t yue_sys_proc_wait(int32_t pid, int32_t timeout_ms, int32_t *status,
                          int32_t *code) {
  *status = -1;
  *code = 0;
  if (timeout_ms < 0) {
    timeout_ms = 0;
  }
  HANDLE h = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE |
                             PROCESS_QUERY_LIMITED_INFORMATION,
                         FALSE, (DWORD)pid);
  if (h == NULL) {
    return -(int32_t)GetLastError();
  }
  DWORD r = WaitForSingleObject(h, (DWORD)timeout_ms);
  int32_t rc = 0;
  if (r == WAIT_OBJECT_0) {
    DWORD ec = 0;
    GetExitCodeProcess(h, &ec);
    *status = 0;
    *code = (int32_t)ec;
  } else if (r == WAIT_TIMEOUT) {
    TerminateProcess(h, 1);
    WaitForSingleObject(h, 5000);
    *status = 1;
    *code = 1;
  } else {
    rc = -(int32_t)GetLastError();
  }
  CloseHandle(h);
  return rc;
}

int32_t yue_sys_proc_getpid(void) { return (int32_t)GetCurrentProcessId(); }

#else  // POSIX：Linux 与 macOS 共用（两处 glibc 扩展按平台分流）

#include <errno.h>
#include <time.h>
#if defined(__APPLE__)
// macOS 没有可直取的 environ 全局，取指针要经 _NSGetEnviron()
#include <crt_externs.h>
#endif

static int proc_redirect(const char *path, int target_fd) {
  int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0600);
  if (fd < 0) {
    return -1;
  }
  if (dup2(fd, target_fd) < 0) {
    close(fd);
    return -1;
  }
  close(fd);
  return 0;
}

int32_t yue_sys_proc_spawn(const char *file, const char *args_blob,
                           const char *cwd, const char *out_path,
                           const char *err_path, const char *env_blob) {
  if (file == NULL || file[0] == '\0') {
    return -EINVAL;
  }
  // argv/envp 在 fork 前建好（fork 后只做 async-signal-safe 调用）；条目
  // 直接指向入参 blob 内部，不拷贝
  int argc = 1;
  if (args_blob != NULL) {
    for (const char *p = args_blob; *p != '\0'; p += strlen(p) + 1) {
      argc++;
    }
  }
  char **argv = (char **)malloc(sizeof(char *) * (size_t)(argc + 1));
  if (argv == NULL) {
    return -ENOMEM;
  }
  argv[0] = (char *)file;
  if (args_blob != NULL) {
    int i = 1;
    for (const char *p = args_blob; *p != '\0'; p += strlen(p) + 1) {
      argv[i++] = (char *)p;
    }
  }
  argv[argc] = NULL;
  int envc = 0;
  if (env_blob != NULL && env_blob[0] != '\0') {
    for (const char *p = env_blob; *p != '\0'; p += strlen(p) + 1) {
      envc++;
    }
  }
  char **envp = (char **)malloc(sizeof(char *) * (size_t)(envc + 1));
  if (envp == NULL) {
    free(argv);
    return -ENOMEM;
  }
  int i = 0;
  if (envc > 0) {
    for (const char *p = env_blob; *p != '\0'; p += strlen(p) + 1) {
      envp[i++] = (char *)p;
    }
  }
  envp[envc] = NULL;

  pid_t pid = fork();
  if (pid < 0) {
    int e = errno;
    free(argv);
    free(envp);
    return -e;
  }
  if (pid == 0) {
    // 独立会话自成进程组（超时可整组 SIGKILL）；macOS 无 setsid，用
    // setpgid 自成组，pgid == pid 时 kill(-pid, SIGKILL) 同样成立
#if defined(__APPLE__)
    setpgid(0, 0);
#else
    setsid();
#endif
    if (cwd != NULL && cwd[0] != '\0' && chdir(cwd) != 0) {
      _exit(126);
    }
    int devnull = open("/dev/null", O_RDONLY);
    if (devnull >= 0) {
      dup2(devnull, STDIN_FILENO);
      close(devnull);
    }
    if (out_path != NULL && out_path[0] != '\0' &&
        proc_redirect(out_path, STDOUT_FILENO) != 0) {
      _exit(126);
    }
    if (err_path != NULL && err_path[0] != '\0' &&
        proc_redirect(err_path, STDERR_FILENO) != 0) {
      _exit(126);
    }
    // 裸命令名按 PATH 解析：Linux 的 execvpe 直接吃 envp；macOS 无 execvpe，
    // 先把 envp 装进自己的 environ 再走 execvp
#if defined(__APPLE__)
    *_NSGetEnviron() = envp;
    execvp(file, argv);
#else
    execvpe(file, argv, envp);
#endif
    _exit(127);
  }
  free(argv);
  free(envp);
  return (int32_t)pid;
}

int32_t yue_sys_proc_wait(int32_t pid, int32_t timeout_ms, int32_t *status,
                          int32_t *code) {
  *status = -1;
  *code = 0;
  if (timeout_ms < 0) {
    timeout_ms = 0;
  }
  // WNOHANG 轮询（10ms 一拍）：预算内退出即归位；超时对进程组 SIGKILL 后
  // 阻塞回收（setsid 下 pgid == pid），回收失败按错误返回
  int32_t slept = 0;
  for (;;) {
    int w = 0;
    pid_t r = waitpid((pid_t)pid, &w, WNOHANG);
    if (r == (pid_t)pid) {
      if (WIFEXITED(w)) {
        *status = 0;
        *code = WEXITSTATUS(w);
      } else if (WIFSIGNALED(w)) {
        *status = 2;
        *code = WTERMSIG(w);
      } else {
        *status = 0;
        *code = 0;
      }
      return 0;
    }
    if (r < 0) {
      return -errno;
    }
    if (slept >= timeout_ms) {
      kill((pid_t)-pid, SIGKILL);
      kill((pid_t)pid, SIGKILL);
      r = waitpid((pid_t)pid, &w, 0);
      if (r < 0) {
        return -errno;
      }
      *status = 1;
      *code = 0;
      return 0;
    }
    struct timespec ts;
    ts.tv_sec = 0;
    ts.tv_nsec = 10 * 1000 * 1000;
    nanosleep(&ts, NULL);
    slept += 10;
  }
}

int32_t yue_sys_proc_getpid(void) { return (int32_t)getpid(); }

#endif

// ---------------------------------------------------------------------------
// 系统剪贴板（W16）：Windows 走 Win32 的 CF_UNICODETEXT（读回 UTF-8 文本）；
// POSIX 侧不经本桩（Linux/mac 的 xclip/pbpaste 走 pr_run 的命令线，见
// yue/sys/clipboard.mbt）。个别时刻剪贴板被别的进程占着时 OpenClipboard
// 会失败——按「拿不到」返回，调用方回退，不重试不等待。
// ---------------------------------------------------------------------------

void *yue_sys_clipboard_get_text(int32_t *ok) {
  *ok = 0;
#if defined(_WIN32)
  if (!OpenClipboard(NULL)) {
    return moonbit_make_bytes(0, 0);
  }
  HANDLE h = GetClipboardData(CF_UNICODETEXT);
  if (h == NULL) {
    CloseClipboard();
    return moonbit_make_bytes(0, 0);
  }
  wchar_t *w = (wchar_t *)GlobalLock(h);
  if (w == NULL) {
    CloseClipboard();
    return moonbit_make_bytes(0, 0);
  }
  void *out = win_wide_bytes(w);
  GlobalUnlock(h);
  CloseClipboard();
  *ok = 1;
  return out;
#else
  return moonbit_make_bytes(0, 0);
#endif
}

int32_t yue_sys_clipboard_set_text(const char *text) {
#if defined(_WIN32)
  if (text == NULL) {
    return -1;
  }
  // 宽字符路由：剪贴板是 UTF-16 的（CF_UNICODETEXT），中文内容必须走宽串
  wchar_t *w = win_utf8_wide(text, 0);
  if (w == NULL) {
    return -1;
  }
  size_t bytes = (wcslen(w) + 1) * sizeof(wchar_t);
  if (!OpenClipboard(NULL)) {
    free(w);
    return -1;
  }
  int rc = -1;
  if (EmptyClipboard()) {
    HGLOBAL h = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (h != NULL) {
      void *dst = GlobalLock(h);
      if (dst != NULL) {
        memcpy(dst, w, bytes);
        GlobalUnlock(h);
        if (SetClipboardData(CF_UNICODETEXT, h) != NULL) {
          rc = 0; // 成功后所有权归系统：绝不能再 GlobalFree
          h = NULL;
        }
      }
      if (h != NULL) {
        GlobalFree(h);
      }
    }
  }
  CloseClipboard();
  free(w);
  return rc;
#else
  (void)text;
  return -1;
#endif
}

// ---------------------------------------------------------------------------
// 文件对话框（wm_file_* 符号）
//
// Linux 端这些符号在 yue/win/stub.c 的 WM_STUB_GTK 分支（GtkFileChooserDialog
// 槽表），本文件只在 Windows 上给同名实现——句柄槽制与 GTK 端同规（表容量 8、
// 句柄 = 槽号 1 起、无效句柄各接口安全退化），dialog.mbt 的 extern 名不改。
// 平台差异（记档）：三个选项位都有对应项（FOS_PICKFOLDERS /
// FOS_ALLOWMULTISELECT / FOS_FORCESHOWHIDDEN）；差异在父窗口——HWND 属
// yue/win 桩的私有表，跨桩拿不到，故 Show 传 NULL；IFileDialog::Show 自带
// 模态消息泵，不挂父窗也能正常阻塞与响应。
// ---------------------------------------------------------------------------
#if defined(_WIN32)

#define SYS_DLG_MAX 8
static IFileDialog *sys_dialogs[SYS_DLG_MAX];
static int sys_dlg_accepted[SYS_DLG_MAX];
static int sys_dlg_com_ready = 0;

static int sys_dlg_com_init(void) {
  if (sys_dlg_com_ready) {
    return 1;
  }
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
  // S_FALSE = 本线程已初始化过（幂等）；RPC_E_CHANGED_MODE = 已被别种模型
  // 初始化过，COM 照样可用——两种都不算失败
  if (hr != S_OK && hr != S_FALSE && hr != RPC_E_CHANGED_MODE) {
    return 0;
  }
  sys_dlg_com_ready = 1;
  return 1;
}

static int64_t sys_dlg_put(IFileDialog *d) {
  for (int i = 0; i < SYS_DLG_MAX; i++) {
    if (sys_dialogs[i] == NULL) {
      sys_dialogs[i] = d;
      sys_dlg_accepted[i] = 0;
      return (int64_t)(i + 1);
    }
  }
  d->lpVtbl->Release(d);
  return 0; // 槽满：句柄无效，调用方按「建不出」退化
}

static IFileDialog *sys_dlg_of(int64_t id) {
  if (id <= 0 || id > SYS_DLG_MAX) {
    return NULL;
  }
  return sys_dialogs[id - 1];
}

static void sys_dlg_free(int64_t id) {
  if (id <= 0 || id > SYS_DLG_MAX) {
    return;
  }
  sys_dlg_accepted[id - 1] = 0;
  if (sys_dialogs[id - 1] != NULL) {
    sys_dialogs[id - 1]->lpVtbl->Release(sys_dialogs[id - 1]);
    sys_dialogs[id - 1] = NULL;
  }
}

static int64_t sys_file_dialog_new(int save) {
  if (!sys_dlg_com_init()) {
    return 0;
  }
  // GUID 只能取头文件里的 extern 常量（__uuidof 是 C++ 专属，MSVC 在 C 模式
  // 直接报 C4233），这些符号由 uuid.lib 提供——链接参数见 scripts/prebuild.py
  IFileDialog *dlg = NULL;
  HRESULT hr = CoCreateInstance(save ? &CLSID_FileSaveDialog
                                     : &CLSID_FileOpenDialog,
                                NULL, CLSCTX_INPROC_SERVER, &IID_IFileDialog,
                                (void **)&dlg);
  if (FAILED(hr) || dlg == NULL) {
    return 0;
  }
  return sys_dlg_put(dlg);
}

int64_t wm_file_open_dialog_new(void) { return sys_file_dialog_new(0); }

int64_t wm_file_save_dialog_new(void) { return sys_file_dialog_new(1); }

/* 选项位：1<<0 选文件夹 1<<1 多选 1<<2 显示隐藏。 */
void wm_file_dialog_set_options(int64_t id, int32_t options) {
  IFileDialog *d = sys_dlg_of(id);
  if (d == NULL) {
    return;
  }
  FILEOPENDIALOGOPTIONS existing = 0;
  if (FAILED(d->lpVtbl->GetOptions(d, &existing))) {
    existing = 0;
  }
  // 只增不减：多次调用互不覆盖（与 GTK 端逐项 set 的行为对齐）
  FILEOPENDIALOGOPTIONS add = 0;
  if (options & 1) {
    add |= FOS_PICKFOLDERS;
  }
  if (options & 2) {
    add |= FOS_ALLOWMULTISELECT;
  }
  if (options & 4) {
    add |= FOS_FORCESHOWHIDDEN;
  }
  if (add != 0 && FAILED(d->lpVtbl->SetOptions(d, existing | add))) {
    return;
  }
}

/* filters 打包："描述:扩展1,扩展2|描述2:扩展3"（'*' 匹配全部）。
 * 一个分组 = 一条 COMDLG_FILTERSPEC，多个扩展名并入同一条模式
 * （"*.png;*.jpg"），与文件资源管理器的下拉项一一对应。 */
void wm_file_dialog_set_filters(int64_t id, const char *filters) {
  IFileDialog *d = sys_dlg_of(id);
  if (d == NULL || filters == NULL) {
    return;
  }
  wchar_t *descs[SYS_DLG_MAX];
  wchar_t *pats[SYS_DLG_MAX];
  int n = 0;
  const char *pos = filters;
  while (*pos != '\0' && n < SYS_DLG_MAX) {
    const char *bar = strchr(pos, '|');
    size_t glen = bar != NULL ? (size_t)(bar - pos) : strlen(pos);
    char group[256];
    if (glen >= sizeof(group)) {
      glen = sizeof(group) - 1;
    }
    memcpy(group, pos, glen);
    group[glen] = '\0';
    const char *colon = strchr(group, ':');
    if (colon == NULL) {
      pos = bar != NULL ? bar + 1 : pos + glen;
      continue;
    }
    size_t dl = (size_t)(colon - group);
    char desc[128];
    if (dl >= sizeof(desc)) {
      dl = sizeof(desc) - 1;
    }
    memcpy(desc, group, dl);
    desc[dl] = '\0';
    // 模式串：*.e1;*.e2（'*' 单条时保持 '*'）
    char pat[256];
    size_t at = 0;
    const char *ep = colon + 1;
    int first = 1;
    while (*ep != '\0' && at + 8 < sizeof(pat)) {
      const char *comma = strchr(ep, ',');
      size_t el = comma != NULL ? (size_t)(comma - ep) : strlen(ep);
      char one[64];
      if (el >= sizeof(one)) {
        el = sizeof(one) - 1;
      }
      memcpy(one, ep, el);
      one[el] = '\0';
      int used = snprintf(pat + at, sizeof(pat) - at, "%s%s%s", first ? "" : ";",
                          strcmp(one, "*") == 0 ? "" : "*.", one);
      if (used <= 0) {
        break;
      }
      at += (size_t)used;
      first = 0;
      ep = comma != NULL ? comma + 1 : ep + el;
    }
    pat[at] = '\0';
    descs[n] = win_utf8_wide(desc, 0);
    pats[n] = win_utf8_wide(pat, 0);
    if (descs[n] != NULL && pats[n] != NULL) {
      n++;
    } else {
      if (descs[n] != NULL) {
        free(descs[n]);
      }
      if (pats[n] != NULL) {
        free(pats[n]);
      }
    }
    pos = bar != NULL ? bar + 1 : pos + glen;
  }
  if (n > 0) {
    COMDLG_FILTERSPEC specs[SYS_DLG_MAX];
    for (int i = 0; i < n; i++) {
      specs[i].pszName = descs[i];
      specs[i].pszSpec = pats[i];
    }
    d->lpVtbl->SetFileTypes(d, (UINT)n, specs);
    d->lpVtbl->SetFileTypeIndex(d, 1);
  }
  for (int i = 0; i < n; i++) {
    free(descs[i]);
    free(pats[i]);
  }
}

/* 初始目录：本地路径直接用；file:// URI 剥前缀并把 '/' 换 '\'（URI 里的
 * 百分号编码不解，中文目录请传本地路径——记档）。 */
void wm_file_dialog_set_folder(int64_t id, const char *folder) {
  IFileDialog *d = sys_dlg_of(id);
  if (d == NULL || folder == NULL || folder[0] == '\0') {
    return;
  }
  const char *p = folder;
  char path[4096];
  size_t at = 0;
  if (strncmp(p, "file:///", 8) == 0) {
    p += 8; // 盘符前的第三个斜杠吃掉，剩下 C:/...
  } else if (strncmp(p, "file://", 7) == 0) {
    p += 7;
  }
  for (; *p != '\0' && at + 1 < sizeof(path); p++) {
    path[at++] = *p == '/' ? '\\' : *p;
  }
  path[at] = '\0';
  wchar_t *w = win_utf8_wide(path, 0);
  if (w == NULL) {
    return;
  }
  IShellItem *item = NULL;
  if (SUCCEEDED(SHCreateItemFromParsingName(w, NULL, &IID_IShellItem,
                                            (void **)&item)) &&
      item != NULL) {
    d->lpVtbl->SetFolder(d, item);
    item->lpVtbl->Release(item);
  }
  free(w);
}

void wm_file_dialog_set_filename(int64_t id, const char *filename) {
  IFileDialog *d = sys_dlg_of(id);
  if (d == NULL || filename == NULL) {
    return;
  }
  wchar_t *w = win_utf8_wide(filename, 0);
  if (w == NULL) {
    return;
  }
  d->lpVtbl->SetFileName(d, w);
  free(w);
}

/* 模态运行（parent 在 Windows 侧忽略，见本节开头记档）。返回 1=确认。 */
int32_t wm_file_dialog_run_for_window(int64_t id, int64_t parent) {
  IFileDialog *d = sys_dlg_of(id);
  (void)parent;
  if (d == NULL) {
    return 0;
  }
  HRESULT hr = d->lpVtbl->Show(d, NULL);
  int accepted = SUCCEEDED(hr) ? 1 : 0;
  sys_dlg_accepted[id - 1] = accepted;
  return accepted;
}

/* 用户选中的绝对路径（SIGDN_FILESYSPATH）；未确认或取消返回空字节串。
 * 多选时取首项——GetResults 才是多选全集的入口，这里与 GTK 端同口径。 */
void *wm_file_dialog_get_result(int64_t id) {
  IFileDialog *d = sys_dlg_of(id);
  if (d == NULL || id <= 0 || id > SYS_DLG_MAX || !sys_dlg_accepted[id - 1]) {
    return moonbit_make_bytes(0, 0);
  }
  IShellItem *item = NULL;
  if (FAILED(d->lpVtbl->GetResult(d, &item)) || item == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  wchar_t *path = NULL;
  void *out;
  if (SUCCEEDED(item->lpVtbl->GetDisplayName(item, SIGDN_FILESYSPATH, &path)) &&
      path != NULL) {
    out = win_wide_bytes(path);
    CoTaskMemFree(path);
  } else {
    out = moonbit_make_bytes(0, 0);
  }
  item->lpVtbl->Release(item);
  return out;
}

void wm_file_dialog_destroy(int64_t id) { sys_dlg_free(id); }

#endif
