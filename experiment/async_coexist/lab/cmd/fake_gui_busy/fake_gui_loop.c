/* 实验 2:模拟 GUI 主循环 —— 非阻塞 pipe 作唤醒源(等价 eventfd/PostMessage/CFRunLoopSource)
 * fgl_wait/fgl_wakeup/fgl_destroy 三个符号即 shim 侧需要的全部平台接口 */
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <moonbit.h>

static struct { int r, w; } g = { -1, -1 };

MOONBIT_FFI_EXPORT int32_t fgl_init(void) {
  int fds[2];
  if (pipe(fds) < 0) return -1;
  g.r = fds[0]; g.w = fds[1];
  int flags = fcntl(g.r, F_GETFL);
  if (flags < 0) return -1;
  if (!(flags & O_NONBLOCK) && fcntl(g.r, F_SETFL, flags | O_NONBLOCK) < 0) return -1;
  return 0;
}

MOONBIT_FFI_EXPORT void fgl_destroy(void) { close(g.r); close(g.w); g.r = g.w = -1; }

/* 只会被 async 的 waiter 专用线程调用:纯 C 写管道,不碰任何 MoonBit 对象 */
MOONBIT_FFI_EXPORT void fgl_wakeup(void) {
  int32_t b = 1;
  ssize_t n = write(g.w, &b, sizeof(b));
  (void)n;
}

/* poll 一轮:timeout<0 无限等,0 不等,t>0 至多 t 毫秒;返回 1=有唤醒字节 */
MOONBIT_FFI_EXPORT int32_t fgl_wait(int32_t timeout) {
  struct pollfd pfd = { g.r, POLLIN, 0 };
  int ret = poll(&pfd, 1, timeout);
  if (ret < 0) { if (errno == EINTR) return 0; return -1; }
  return (pfd.revents & POLLIN) ? 1 : 0;
}

/* 取出并清空积压的唤醒字节,返回字节数(模拟"处理完本轮 GUI 事件") */
MOONBIT_FFI_EXPORT int32_t fgl_drain(void) {
  int32_t total = 0, b;
  while (read(g.r, &b, sizeof(b)) > 0) total++;
  return total;
}

/* 从新线程在 delay 毫秒后向管道写字节:模拟 GUI 事件源(用户输入等) */
struct post { int32_t delay; };
static void* poster(void *p) {
  struct post *req = p;
  struct timespec ts = { req->delay / 1000, (req->delay % 1000) * 1000000 };
  nanosleep(&ts, 0);
  int32_t b = 1;
  ssize_t n = write(g.w, &b, sizeof(b));
  (void)n;
  free(req);
  return 0;
}
MOONBIT_FFI_EXPORT void fgl_post_event(int32_t delay) {
  struct post *req = malloc(sizeof(*req));
  req->delay = delay;
  pthread_t tid;
  pthread_create(&tid, 0, poster, req);
  pthread_detach(tid);
}

/* 模拟 poll 内干重活(GUI 事件处理耗时) */
MOONBIT_FFI_EXPORT void fgl_busy(int32_t ms) {
  struct timespec ts = { ms / 1000, (ms % 1000) * 1000000 };
  nanosleep(&ts, 0);
}
