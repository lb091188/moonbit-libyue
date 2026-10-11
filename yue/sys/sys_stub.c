// 系统能力桩（sys 线）：目录枚举 / 环境变量写删 / 文本文件读删 /
// 平台标识。只用标准头（POSIX dirent + stdlib/stdio），故直接走
// moon 的 native-stub 编译（区别于要 GTK 头的 win/render/text 桩——
// 那些由 scripts/prebuild.py 编静态库）。Windows 分支为占位实现
// （FindFirstFileW 宽字符路由待 M2 地基批补），保三平台链接不断符号。
// ABI 约定与 master 的 shim 同源：多字符串返回扁平 UTF-8 文本
// （'\n' 分行），字节串经 moonbit_make_bytes 构造（运行时符号，
// extern 声明即可用——ime_probe_stub 同款）。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <dirent.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

// moon 运行时的字节构造（运行期符号，声明即链接）
extern void *moonbit_make_bytes(int size, int value);

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
  // 占位：Windows 走 FindFirstFileW（宽字符），M2 地基批补
  (void)path;
  return moonbit_make_bytes(0, 0);
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
  if (overwrite == 0 && getenv(name) != NULL) {
    *ok = 1;
    return 0;
  }
  if (_putenv_s(name, value) == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
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
  if (_putenv_s(name, "") == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
#else
  if (unsetenv(name) == 0) {
    *ok = 1;
    return 0;
  }
  return -1;
#endif
}

// 读文本文件全文（二进制读整段；打不开/读失败 ok=0 返回空）。
void *yue_sys_read_text_file(const char *path, int32_t *ok) {
  *ok = 0;
  if (path == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  FILE *f = fopen(path, "rb");
  if (f == NULL) {
    return moonbit_make_bytes(0, 0);
  }
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  long sz = ftell(f);
  if (sz < 0) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  rewind(f);
  void *out = moonbit_make_bytes((int)sz, 0);
  if (sz > 0 && fread(out, 1, (size_t)sz, f) != (size_t)sz) {
    fclose(f);
    return moonbit_make_bytes(0, 0);
  }
  fclose(f);
  *ok = 1;
  return out;
}

// 删文件：本就不存在视为成功（幂等）；存在但删失败返回 -1。
int32_t yue_sys_remove_file(const char *path, int32_t *ok) {
  *ok = 0;
  if (path == NULL) {
    return -1;
  }
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
}

// 读环境变量（进程实时环境，反映 setenv/unsetenv 后的状态）。
// 不存在 ok=0 返回空文本。
void *yue_sys_getenv(const char *name, int32_t *ok) {
  *ok = 0;
  if (name == NULL) {
    return moonbit_make_bytes(0, 0);
  }
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
}

// 写文本文件全文（存在覆盖，不存在新建；父目录须已存在）。
int32_t yue_sys_write_text_file(const char *path, const char *data, int32_t *ok) {
  *ok = 0;
  if (path == NULL || data == NULL) {
    return -1;
  }
  FILE *f = fopen(path, "wb");
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

// 当前工作目录（getcwd，失败 ok=0 返回空文本）。Windows 分支为占位
// （_getcwd 属 M2 地基批），故 Windows 下恒 ok=0。
void *yue_sys_getcwd(int32_t *ok) {
  *ok = 0;
#if defined(_WIN32)
  return moonbit_make_bytes(0, 0);
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
  (void)file;
  (void)arg;
  return -1; // 占位：Windows 走 ShellExecuteW（M2 地基批）
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
