// 音频输出设备（miniaudio playback 设备 + 线程安全 PCM 字节队列）：
// MoonBit 层用 ffmpeg 解出 s16 交错 PCM 后 push 进来，设备回调线程从
// 队列取数据混出。设备参数（声道/采样率）在 open 时钉死，与 ffmpeg 解
// 码输出一致，无重采样。miniaudio 在此仅作设备抽象（WASAPI/CoreAudio/
// ALSA/PulseAudio），不再是 MoonBit 依赖。

#include <stdlib.h>
#include <string.h>
#include "moonbit.h"
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

typedef struct MaChunk {
    uint8_t *data;
    size_t len;
    size_t pos;
    struct MaChunk *next;
} MaChunk;

typedef struct MaPlayer {
    ma_device device;
    ma_mutex mutex;
    MaChunk *head;
    MaChunk *tail;
    size_t queued_bytes;   // 待播字节（含半播块剩余）
    int64_t played_bytes;  // 设备累计消费字节
    int channels;
    int sample_rate;
    float volume;
    int started;           // 设备 start/stop 状态
} MaPlayer;

/* 重新统计队列字节（互斥锁内调用；定义在 data_callback 之后） */
static size_t mbt_adev_recount(MaPlayer *p);

static void mbt_adev_data_callback(ma_device *pDevice, void *pOutput,
                                   const void *pInput, ma_uint32 frameCount) {
    (void)pInput;
    MaPlayer *p = (MaPlayer *)pDevice->pUserData;
    ma_uint32 want = frameCount * (ma_uint32)p->channels * 2;
    ma_uint32 got = 0;
    ma_mutex_lock(&p->mutex);
    while (got < want && p->head) {
        MaChunk *c = p->head;
        ma_uint32 n = (ma_uint32)(c->len - c->pos);
        if (n > want - got) {
            n = want - got;
        }
        memcpy((uint8_t *)pOutput + got, c->data + c->pos, n);
        c->pos += n;
        got += n;
        if (c->pos >= c->len) {
            p->head = c->next;
            if (!p->head) {
                p->tail = NULL;
            }
            free(c->data);
            free(c);
        }
    }
    p->queued_bytes = mbt_adev_recount(p);
    p->played_bytes += got;
    ma_mutex_unlock(&p->mutex);
    // 音量在静音填充后统一施加（s16 样本逐个钳制乘 volume）
    if (got < want) {
        memset((uint8_t *)pOutput + got, 0, want - got);
    }
    if (p->volume != 1.0f) {
        int16_t *samples = (int16_t *)pOutput;
        ma_uint32 total = want / 2;
        for (ma_uint32 i = 0; i < total; i++) {
            int32_t v = (int32_t)(samples[i] * p->volume);
            if (v > 32767) v = 32767;
            if (v < -32768) v = -32768;
            samples[i] = (int16_t)v;
        }
    }
}

/* 重新统计队列字节（互斥锁内调用） */
static size_t mbt_adev_recount(MaPlayer *p) {
    size_t total = 0;
    for (MaChunk *c = p->head; c; c = c->next) {
        total += c->len - c->pos;
    }
    return total;
}

MaPlayer *mbt_adev_open(int32_t channels, int32_t sample_rate) {
    if (channels <= 0 || channels > 8 || sample_rate <= 0) {
        return NULL;
    }
    MaPlayer *p = (MaPlayer *)calloc(1, sizeof(MaPlayer));
    p->channels = channels;
    p->sample_rate = sample_rate;
    p->volume = 1.0f;
    if (ma_mutex_init(&p->mutex) != MA_SUCCESS) {
        free(p);
        return NULL;
    }
    ma_device_config cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_s16;
    cfg.playback.channels = (ma_uint32)channels;
    cfg.sampleRate = (ma_uint32)sample_rate;
    cfg.dataCallback = mbt_adev_data_callback;
    cfg.pUserData = p;
    // 无输出设备（CI/headless）时 ma_device_init 失败——返回哑设备
    // （started=0，push 静默丢弃），MoonBit 层照常推进状态机
    if (ma_device_init(NULL, &cfg, &p->device) != MA_SUCCESS) {
        p->started = -1; // 标记无设备
    }
    return p;
}

int32_t mbt_adev_has_device(MaPlayer *p) {
    return p && p->started == 0 ? 1 : 0;
}

int32_t mbt_adev_start(MaPlayer *p) {
    if (!p || p->started != 0) {
        return -1;
    }
    if (ma_device_start(&p->device) != MA_SUCCESS) {
        p->started = -1;
        return -1;
    }
    p->started = 1;
    return 0;
}

int32_t mbt_adev_pause(MaPlayer *p) {
    if (!p || p->started != 1) {
        return -1;
    }
    if (ma_device_stop(&p->device) != MA_SUCCESS) {
        return -1;
    }
    p->started = 0;
    return 0;
}

int32_t mbt_adev_is_started(MaPlayer *p) {
    return p && p->started == 1 ? 1 : 0;
}

/* 追加一段 PCM（s16 交错，len 字节）；0 成功 / -1 参数错或已关 */
int32_t mbt_adev_push(MaPlayer *p, const uint8_t *data, int32_t len) {
    if (!p || !data || len <= 0) {
        return -1;
    }
    MaChunk *c = (MaChunk *)malloc(sizeof(MaChunk));
    c->data = (uint8_t *)malloc((size_t)len);
    memcpy(c->data, data, (size_t)len);
    c->len = (size_t)len;
    c->pos = 0;
    c->next = NULL;
    ma_mutex_lock(&p->mutex);
    if (p->tail) {
        p->tail->next = c;
    } else {
        p->head = c;
    }
    p->tail = c;
    p->queued_bytes = mbt_adev_recount(p);
    ma_mutex_unlock(&p->mutex);
    return 0;
}

int64_t mbt_adev_queued_bytes(MaPlayer *p) {
    if (!p) {
        return 0;
    }
    ma_mutex_lock(&p->mutex);
    int64_t n = (int64_t)mbt_adev_recount(p);
    ma_mutex_unlock(&p->mutex);
    return n;
}

/* 设备累计消费字节（seek/重播时作位置基准由 MoonBit 层记录差值） */
int64_t mbt_adev_played_bytes(MaPlayer *p) {
    if (!p) {
        return 0;
    }
    ma_mutex_lock(&p->mutex);
    int64_t n = p->played_bytes;
    ma_mutex_unlock(&p->mutex);
    return n;
}

/* 清空待播队列（stop/seek 用） */
void mbt_adev_clear(MaPlayer *p) {
    if (!p) {
        return;
    }
    ma_mutex_lock(&p->mutex);
    while (p->head) {
        MaChunk *c = p->head;
        p->head = c->next;
        free(c->data);
        free(c);
    }
    p->tail = NULL;
    p->queued_bytes = 0;
    ma_mutex_unlock(&p->mutex);
}

void mbt_adev_set_volume(MaPlayer *p, float v) {
    if (p) {
        p->volume = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
    }
}

float mbt_adev_get_volume(MaPlayer *p) {
    return p ? p->volume : 0.0f;
}

void mbt_adev_close(MaPlayer *p) {
    if (!p) {
        return;
    }
    if (p->started == 1) {
        ma_device_stop(&p->device);
    }
    if (p->started >= 0) {
        ma_device_uninit(&p->device);
    }
    ma_mutex_uninit(&p->mutex);
    mbt_adev_clear(p);
    free(p);
}
