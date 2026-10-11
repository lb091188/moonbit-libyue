// D-Bus 客户端的系统调用桩（yue/dbus 线）：Unix 流式套接字 + uid + Double
// 位模式。只用标准头，故直接走 moon 的 native-stub（要 GTK 头的桩才走
// scripts/prebuild.py 编静态库）。错误码约定与旧链 shim 逐位一致，MoonBit
// 侧按这套约定分流：
//   read  : >0 字节数 / 0 对端关闭 / -1 暂不可读(EAGAIN、EINTR) / -2 其它错误
//   write : >=0 已写出(可能短写) / -1 暂不可写 / -2 其它错误
//   poll  : revents 位(1=IN 4=OUT 8=ERR 16=HUP) / 0 超时 / -1 错误
// SASL EXTERNAL 的凭据由内核在 connect 时随 SCM_CREDENTIALS 自动带上，
// 服务端读 SO_PEERCRED，客户端不需要显式传。

#include <assert.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#endif

// 平台不支持时统一给失败桩（本栈当前只在 Linux 上跑真链路）
#if defined(_WIN32) || defined(__APPLE__)

int32_t yue_dbus_unix_connect(const char *path) {
  (void)path;
  return -2;
}

int32_t yue_dbus_read(int32_t fd, void *buf, int32_t off, int32_t len) {
  (void)fd;
  (void)buf;
  (void)off;
  (void)len;
  return -2;
}

int32_t yue_dbus_write(int32_t fd, const void *buf, int32_t off, int32_t len) {
  (void)fd;
  (void)buf;
  (void)off;
  (void)len;
  return -2;
}

int32_t yue_dbus_poll(int32_t fd, int32_t events, int32_t timeout_ms) {
  (void)fd;
  (void)events;
  (void)timeout_ms;
  return -1;
}

void yue_dbus_close(int32_t fd) { (void)fd; }

int32_t yue_dbus_getuid(void) { return -1; }

#else

int32_t yue_dbus_unix_connect(const char *path) {
  if (path == NULL) {
    return -2;
  }
  int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK | SOCK_CLOEXEC, 0);
  if (fd < 0) {
    return -2;
  }
  struct sockaddr_un addr;
  memset(&addr, 0, sizeof(addr));
  addr.sun_family = AF_UNIX;
  if (strlen(path) >= sizeof(addr.sun_path)) {
    close(fd);
    return -2;
  }
  strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
  if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
    if (errno != EINPROGRESS) {
      close(fd);
      return -1;
    }
  }
  return (int32_t)fd;
}

int32_t yue_dbus_read(int32_t fd, void *buf, int32_t off, int32_t len) {
  ssize_t n = read(fd, (char *)buf + off, (size_t)len);
  if (n > 0) {
    return (int32_t)n;
  }
  if (n == 0) {
    return 0; // 对端关闭
  }
  if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
    return -1;
  }
  return -2;
}

int32_t yue_dbus_write(int32_t fd, const void *buf, int32_t off, int32_t len) {
  ssize_t n = write(fd, (const char *)buf + off, (size_t)len);
  if (n >= 0) {
    return (int32_t)n;
  }
  if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) {
    return -1;
  }
  return -2;
}

// events/revents 位沿用调用方的约定：1=可读 4=可写 8=错误 16=挂断
static short to_poll_events(int32_t events) {
  short out = 0;
  if (events & 1) {
    out |= POLLIN;
  }
  if (events & 4) {
    out |= POLLOUT;
  }
  return out;
}

static int32_t from_poll_revents(int32_t revents) {
  int32_t out = 0;
  if (revents & POLLIN) {
    out |= 1;
  }
  if (revents & POLLOUT) {
    out |= 4;
  }
  if (revents & POLLERR) {
    out |= 8;
  }
  if (revents & POLLHUP) {
    out |= 16;
  }
  return out;
}

int32_t yue_dbus_poll(int32_t fd, int32_t events, int32_t timeout_ms) {
  struct pollfd pfd;
  pfd.fd = fd;
  pfd.events = to_poll_events(events);
  pfd.revents = 0;
  int r = poll(&pfd, 1, timeout_ms);
  if (r < 0) {
    if (errno == EINTR) {
      return 0; // 被信号打断视作超时，调用方下一拍再问
    }
    return -1;
  }
  if (r == 0) {
    return 0;
  }
  return from_poll_revents((int32_t)pfd.revents);
}

void yue_dbus_close(int32_t fd) {
  if (fd >= 0) {
    close(fd);
  }
}

int32_t yue_dbus_getuid(void) { return (int32_t)getuid(); }

#endif

// Double 的 IEEE 754 位模式互转（DBus 'd' 编码就是 8 字节小端位重解释）
static_assert(sizeof(double) == 8, "DBus 的 'd' 依赖 double 是 8 字节");

int64_t yue_dbus_f64_to_bits(double v) {
  int64_t bits = 0;
  memcpy(&bits, &v, sizeof(bits));
  return bits;
}

double yue_dbus_f64_from_bits(int64_t bits) {
  double v = 0.0;
  memcpy(&v, &bits, sizeof(v));
  return v;
}
