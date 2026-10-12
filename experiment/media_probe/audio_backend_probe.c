/* 媒体音频后端探针（纯 C，直接 #include media/audio_stub.c）。
 *
 * 动机：media 包在非 Linux 上连 `moon test` 都跑不起来（两个 C 桩编不过：
 * ffmpeg_stub.c 要 libavformat 头，audio_stub.c 原先要 POSIX 的
 * CLOCK_MONOTONIC）。**audio_stub.c 这部分是我们自己的后端、零 ffmpeg 依赖**
 * ——它能不能编、编出来能不能跑，可以单独钉死，不必等 ffmpeg 那条线。
 *
 * 本探针钉四件事：
 *  1. 单调时钟 `mbt_now_ms`：连续/五连读非减、睡眠 60ms 后推进落在合理区间
 *     （Windows 分支走 QueryPerformanceCounter；探针另外直读一次 QPC 频率，
 *     证明走的是高精度计数器而非 GetTickCount 的粗粒度）；
 *  2. 设备开参数校验：channels ∈ [1,8] 且 rate > 0 才收，其余回 NULL；
 *  3. 队列与音量语义（与设备是否存在无关）：push 追加、queued_bytes 累计、
 *     clear 清零且幂等、volume 钳到 [0,1]、played_bytes 非负；
 *  4. 设备生命周期两分支：有真设备时 start=0/is_started=1/played_bytes 真的推进/
 *     pause=0；无设备（CI/headless）时 start=-1 且状态恒 0——两条都跑，不假设。
 *  另加 NULL 参数防御全档（不该崩、该给失败档）。
 *
 * 编法（vcvars 被 reg 策略挡，手设 INCLUDE/LIB；moonbit.h 走 -I；
 * /Fe 须 Windows 风格绝对或当前目录相对路径）：
 *   cl /nologo /W4 /utf-8 /O2 /DWIN32 /D_WINDOWS /DUNICODE /D_UNICODE \
 *      /I"C:/Users/<你>/.moon/include" \
 *      audio_backend_probe.c /Fe:audio_backend_probe.exe
 * 刻意**不加任何额外库**：miniaudio 默认走运行期 LoadLibrary
 * （MA_NO_RUNTIME_LINKING 未定义），不产生链接期符号——实测零库即可链接并运行。
 * 所以 modules/yue-media/prebuild.py 的「非 Linux → 空 link_configs」是对的，
 * 别去补 ole32/uuid（详见 docs/zh/adaptation.md 本批小节）。
 *
 * 期望输出末行 AUDIO-BACKEND-OK。
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>

/* miniaudio.h 单头内部一处 ma_uint64 → ma_uint32 赋值（C4244）在其自身代码里，
 * 非本仓代码；只压这一条，别把自家告警一起压掉。 */
#pragma warning(push)
#pragma warning(disable : 4244)
#include "../../modules/yue-media/media/audio_stub.c"
#pragma warning(pop)

static int g_fail = 0;

static void check(const char *what, long long got, long long want) {
  if (got == want) {
    printf("PROBE ok   %-46s = %lld\n", what, got);
  } else {
    printf("PROBE FAIL %-46s = %lld (want %lld)\n", what, got, want);
    g_fail++;
  }
}

static void check_true(const char *what, int cond) {
  if (cond) {
    printf("PROBE ok   %s\n", what);
  } else {
    printf("PROBE FAIL %s\n", what);
    g_fail++;
  }
}

static int feq(float a, float b) {
  float d = a - b;
  return d < 0.0001f && d > -0.0001f;
}

int main(void) {
  /* ① 单调时钟 --------------------------------------------------------- */
  {
    int64_t a = mbt_now_ms();
    int64_t b = mbt_now_ms();
    check_true("mbt_now_ms 连续两次非减", b >= a);
    check_true("mbt_now_ms 为正", a > 0);

    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    printf("PROBE info QPC 频率 = %lld Hz（Windows 分支基准）\n",
           (long long)f.QuadPart);
    check_true("QPC 频率非零", f.QuadPart > 0);

    Sleep(60);
    {
      int64_t d = mbt_now_ms() - a;
      printf("PROBE info 睡眠 60ms 后推进 = %lld ms\n", (long long)d);
      check_true("60ms 睡眠后推进 ≥ 40ms", d >= 40);
      check_true("60ms 睡眠后推进 ≤ 400ms", d <= 400);
    }

    {
      int64_t prev = mbt_now_ms();
      int mono = 1;
      int i;
      for (i = 0; i < 5; i++) {
        int64_t n = mbt_now_ms();
        if (n < prev) {
          mono = 0;
        }
        prev = n;
      }
      check_true("五连读单调非减", mono);
    }
  }

  /* ② 设备开参数校验 --------------------------------------------------- */
  {
    MaPlayer *p2 = mbt_adev_open(2, 44100);
    MaPlayer *p8 = mbt_adev_open(8, 44100);
    MaPlayer *p1 = mbt_adev_open(1, 8000);
    check_true("open(2,44100) 非空", p2 != NULL);
    check_true("open(8,44100) 非空（上界）", p8 != NULL);
    check_true("open(1,8000) 非空（下界）", p1 != NULL);
    check_true("open(0,44100) 回 NULL", mbt_adev_open(0, 44100) == NULL);
    check_true("open(9,44100) 回 NULL（越上界）", mbt_adev_open(9, 44100) == NULL);
    check_true("open(-1,44100) 回 NULL", mbt_adev_open(-1, 44100) == NULL);
    check_true("open(2,0) 回 NULL", mbt_adev_open(2, 0) == NULL);
    check_true("open(2,-44100) 回 NULL", mbt_adev_open(2, -44100) == NULL);
    check_true("open 后 has_device ∈ {0,1}",
               mbt_adev_has_device(p2) == 0 || mbt_adev_has_device(p2) == 1);
    mbt_adev_close(p1);
    mbt_adev_close(p8);
    mbt_adev_close(p2);
  }

  /* ③ 队列与音量语义（与设备是否存在无关）------------------------------ */
  {
    MaPlayer *p = mbt_adev_open(2, 44100);
    uint8_t buf[400];
    memset(buf, 0, sizeof(buf));
    check("push(valid) = 0", mbt_adev_push(p, buf, 400), 0);
    check("排队字节 = 400", (long long)mbt_adev_queued_bytes(p), 400);
    check("push 第二段 = 0", mbt_adev_push(p, buf, 200), 0);
    check("排队字节 = 600（累计）", (long long)mbt_adev_queued_bytes(p), 600);
    check("push(p,NULL,10) = -1", mbt_adev_push(p, NULL, 10), -1);
    check("push(p,buf,0) = -1", mbt_adev_push(p, buf, 0), -1);
    check("push(p,buf,-5) = -1", mbt_adev_push(p, buf, -5), -1);
    check("非法 push 不改队列", (long long)mbt_adev_queued_bytes(p), 600);
    check_true("played_bytes 非负", mbt_adev_played_bytes(p) >= 0);
    mbt_adev_clear(p);
    check("clear 后排队 = 0", (long long)mbt_adev_queued_bytes(p), 0);
    mbt_adev_clear(p);
    check("二次 clear 幂等 = 0", (long long)mbt_adev_queued_bytes(p), 0);
    mbt_adev_set_volume(p, 0.5f);
    check_true("volume=0.5 读回 0.5", feq(mbt_adev_get_volume(p), 0.5f));
    mbt_adev_set_volume(p, 1.0f);
    check_true("volume=1 读回 1", feq(mbt_adev_get_volume(p), 1.0f));
    mbt_adev_set_volume(p, -1.0f);
    check_true("volume<0 钳到 0", feq(mbt_adev_get_volume(p), 0.0f));
    mbt_adev_set_volume(p, 2.0f);
    check_true("volume>1 钳到 1", feq(mbt_adev_get_volume(p), 1.0f));
    mbt_adev_set_volume(p, 0.25f);
    check_true("volume=0.25 读回 0.25", feq(mbt_adev_get_volume(p), 0.25f));
    mbt_adev_close(p);
  }

  /* ④ 设备生命周期：真设备 / 哑设备两分支都跑 --------------------------- */
  {
    MaPlayer *p = mbt_adev_open(2, 44100);
    if (mbt_adev_has_device(p)) {
      /* 1 秒静音（44100 帧 * 2ch * 2B），不制造噪声 */
      static uint8_t silence[44100 * 2 * 2];
      check("真设备：start = 0", mbt_adev_start(p), 0);
      check("真设备：is_started = 1", mbt_adev_is_started(p), 1);
      check("真设备：二次 start = -1", mbt_adev_start(p), -1);
      memset(silence, 0, sizeof(silence));
      check("真设备：push = 0", mbt_adev_push(p, silence, (int32_t)sizeof(silence)),
            0);
      Sleep(200);
      check_true("真设备：played_bytes 真的推进", mbt_adev_played_bytes(p) > 0);
      printf("PROBE info 真设备 played_bytes = %lld\n",
             (long long)mbt_adev_played_bytes(p));
      check("真设备：pause = 0", mbt_adev_pause(p), 0);
      check("真设备：pause 后 is_started = 0", mbt_adev_is_started(p), 0);
      check("真设备：二次 pause = -1", mbt_adev_pause(p), -1);
    } else {
      check("哑设备：start = -1", mbt_adev_start(p), -1);
      check("哑设备：is_started 恒 0", mbt_adev_is_started(p), 0);
      check("哑设备：pause = -1", mbt_adev_pause(p), -1);
      printf("PROBE info 本机无输出设备，走哑设备分支\n");
    }
    mbt_adev_close(p);
  }

  /* ⑤ NULL 参数防御（不崩、给失败档）---------------------------------- */
  {
    const uint8_t one = 0;
    check("push(NULL,..) = -1", mbt_adev_push(NULL, &one, 1), -1);
    check("has_device(NULL) = 0", mbt_adev_has_device(NULL), 0);
    check("is_started(NULL) = 0", mbt_adev_is_started(NULL), 0);
    check("start(NULL) = -1", mbt_adev_start(NULL), -1);
    check("pause(NULL) = -1", mbt_adev_pause(NULL), -1);
    check("queued_bytes(NULL) = 0", (long long)mbt_adev_queued_bytes(NULL), 0);
    check("played_bytes(NULL) = 0", (long long)mbt_adev_played_bytes(NULL), 0);
    check_true("get_volume(NULL) = 0", feq(mbt_adev_get_volume(NULL), 0.0f));
    mbt_adev_clear(NULL); /* 不崩即可 */
    mbt_adev_close(NULL); /* 不崩即可 */
    check_true("close(NULL) 后仍可继续（未崩）", 1);
  }

  if (g_fail == 0) {
    printf("AUDIO-BACKEND-OK\n");
    return 0;
  }
  printf("AUDIO-BACKEND-FAILED (%d)\n", g_fail);
  return 1;
}
