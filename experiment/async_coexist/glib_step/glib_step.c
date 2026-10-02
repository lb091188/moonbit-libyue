/* GLib 单步迭代可行性验证:ExternalEventLoop 的 poll(timeout) 契约
 * 能否用 g_main_context prepare/query/check/dispatch + g_main_context_wakeup 实现。
 * 场景:g_timeout_add 源(模拟 GUI 事件源)+ 后台线程 300ms 后跨线程唤醒
 * 阻塞中的 poll(timeout=1000)。 */
#include <glib.h>
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>

static GMainContext *ctx;
static gint64 t0;

static gint64 now_ms(void) {
  return g_get_real_time() / 1000;
}
static void log_ts(const char *tag) {
  printf("[+%4ldms] %s\n", (long)(now_ms() - t0), tag);
}

static gboolean on_gui_event(gpointer data) {
  log_ts("GUI timeout source dispatched (in poll iteration)");
  return G_SOURCE_REMOVE;
}

static void *waker(void *unused) {
  g_usleep(300 * 1000);
  log_ts("waker thread calling g_main_context_wakeup");
  g_main_context_wakeup(ctx); /* 纯 C、线程安全:唤醒阻塞中的 poll */
  return NULL;
}

/* 模拟 shim 的 yue_loop_poll(timeout):带超时单步迭代默认 main context */
static gboolean glib_poll_step(gint timeout_ms /* -1 = forever */) {
  gint max_priority = 0;
  GPollFD fds[64];
  if (!g_main_context_acquire(ctx)) return FALSE;
  gboolean acquired = TRUE;
  gboolean some_ready = g_main_context_prepare(ctx, &max_priority);
  if (!some_ready) {
    gint wait = timeout_ms;
    gint n = g_main_context_query(ctx, max_priority, &wait, fds, 64);
    /* 坑:query 会用内部源最近到期时间覆盖 wait(无源时置 -1 无限等),
     * 必须按外部上限 clamp,否则违反 poll(timeout) 契约 */
    if (timeout_ms >= 0 && (wait < 0 || wait > timeout_ms)) wait = timeout_ms;
    gint ready = g_poll(fds, n, wait);
    (void)ready;
    some_ready = g_main_context_check(ctx, max_priority, fds, n);
  }
  if (some_ready) g_main_context_dispatch(ctx);
  if (acquired) g_main_context_release(ctx);
  return some_ready;
}

int main(void) {
  ctx = g_main_context_default();
  t0 = now_ms();

  /* GUI 事件源:250ms 一次性 */
  g_timeout_add(250, on_gui_event, NULL);

  pthread_t th;
  pthread_create(&th, NULL, waker, NULL);

  /* 轮次 1~2:timeout=100ms,无事件则安静返回 */
  for (int i = 0; i < 2; i++) {
    glib_poll_step(100);
    log_ts("poll(100) returned");
  }
  /* 轮次 3:timeout=1000ms —— 应在 ~250ms 被 GUI 源唤醒 */
  glib_poll_step(1000);
  log_ts("poll(1000) returned after GUI event");
  /* 轮次 4:timeout=1000ms —— 应在 ~300ms 被 waker 线程唤醒(空轮) */
  glib_poll_step(1000);
  log_ts("poll(1000) returned after cross-thread wakeup");
  /* 轮次 5:timeout=0 非阻塞 */
  glib_poll_step(0);
  log_ts("poll(0) returned immediately");

  pthread_join(th, NULL);
  log_ts("done");
  return 0;
}
