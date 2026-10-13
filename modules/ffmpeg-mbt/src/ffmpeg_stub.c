// ffmpeg 动态链 FFI 的薄 stub：只做句柄/字符串转换，无业务逻辑。
// 依赖系统 libavformat/libavcodec/libswscale/libavutil（动态链，pkg-config
// 提供头文件与链接参数，由主仓库 scripts/prebuild.py 注入）。
//
// Windows 分支：ffmpeg 后端随各自媒体线落地时再接（与 prebuild 的
// 非 Linux 降级口径一致）。这里给「全错误降级实现」——全部 FFI 符号
// 在场（链接不断），语义上恒失败：vf_open 恒不成功、解码器恒 NULL，
// MoonBit 侧据此报「FFI 打开失败」，调用方（gui-media player_t）走
// on_error 语义化降级。

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "moonbit.h"

#ifdef _WIN32

/* Windows：ffmpeg 后端未接。句柄结构只保留探测所需字段。 */
typedef struct VfFmt {
    int ok;      // 恒 0：没有媒体后端
    int vstream;
    int astream;
    int sstream;
} VfFmt;

typedef struct VfDec {
    int width;
    int height;
    double last_pts;
} VfDec;

typedef struct VfADec {
    int out_ch;
    int out_rate;
} VfADec;

typedef struct VfSDec {
    double last_pts;
    double last_end;
} VfSDec;

int32_t vf_version(void) {
    return 0;
}

VfFmt *vf_open(const char *path) {
    (void)path;
    VfFmt *f = (VfFmt *)malloc(sizeof(VfFmt));
    f->ok = 0;
    f->vstream = -1;
    f->astream = -1;
    f->sstream = -1;
    return f;
}

int32_t vf_ok(VfFmt *f) {
    return f && f->ok ? 1 : 0;
}

void vf_close(VfFmt *f) {
    free(f);
}

int32_t vf_video_stream(VfFmt *f) {
    return f ? f->vstream : -1;
}

int32_t vf_audio_stream(VfFmt *f) {
    return f ? f->astream : -1;
}

int32_t vf_subtitle_stream(VfFmt *f) {
    return f ? f->sstream : -1;
}

VfDec *vf_no_decoder(void) {
    return NULL;
}

VfADec *vf_no_audio_decoder(void) {
    return NULL;
}

int32_t vf_stream_width(VfFmt *f) {
    (void)f;
    return 0;
}

int32_t vf_stream_height(VfFmt *f) {
    (void)f;
    return 0;
}

double vf_duration_s(VfFmt *f) {
    (void)f;
    return 0.0;
}

VfDec *vf_open_video_decoder(VfFmt *f, int32_t out_w, int32_t out_h) {
    (void)f;
    (void)out_w;
    (void)out_h;
    return NULL;
}

void vf_close_decoder(VfDec *d) {
    free(d);
}

int32_t vf_dec_width(VfDec *d) {
    return d ? d->width : 0;
}

int32_t vf_dec_height(VfDec *d) {
    return d ? d->height : 0;
}

int32_t vf_decode_next(VfDec *d, uint8_t *out, int32_t out_len) {
    (void)d;
    (void)out;
    (void)out_len;
    return -1;
}

double vf_frame_pts_s(VfDec *d) {
    return d ? d->last_pts : -1.0;
}

double vf_stream_fps(VfFmt *f) {
    (void)f;
    return 0.0;
}

int32_t vf_seek_s(VfDec *d, double t_s) {
    (void)d;
    (void)t_s;
    return -1;
}

void vf_close_audio_decoder(VfADec *d) {
    free(d);
}

VfADec *vf_open_audio_decoder(VfFmt *f) {
    (void)f;
    return NULL;
}

int32_t vf_adec_channels(VfADec *d) {
    return d ? d->out_ch : 0;
}

int32_t vf_adec_rate(VfADec *d) {
    return d ? d->out_rate : 0;
}

int32_t vf_decode_pcm(VfADec *d, uint8_t *out, int32_t out_len) {
    (void)d;
    (void)out;
    (void)out_len;
    return -1;
}

int32_t vf_aseek_s(VfADec *d, double t_s) {
    (void)d;
    (void)t_s;
    return -1;
}

void vf_sub_close(VfSDec *d) {
    free(d);
}

VfSDec *vf_sub_open(const char *path) {
    (void)path;
    return NULL;
}

int32_t vf_sub_ok(VfSDec *d) {
    return d ? 1 : 0;
}

int32_t vf_sub_next(VfSDec *d, char *out, int32_t out_len) {
    (void)d;
    if (out == NULL || out_len < 1) {
        return -1;
    }
    out[0] = '\0';
    return 0;
}

double vf_sub_pts_s(VfSDec *d) {
    return d ? d->last_pts : -1.0;
}

double vf_sub_end_s(VfSDec *d) {
    return d ? d->last_end : -1.0;
}

#else /* _WIN32 */

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/imgutils.h>
#include <stdio.h>
#include <stdlib.h>
#include "moonbit.h"

typedef struct VfFmt {
    AVFormatContext *fmt;
    int vstream; // 视频流索引，-1 无
    int astream; // 音频流索引，-1 无
    int sstream; // 字幕流索引，-1 无
} VfFmt;

typedef struct VfDec {
    AVFormatContext *fmt;
    AVCodecContext *codec;
    AVFrame *frame;
    AVPacket *pkt;
    struct SwsContext *sws;
    int vstream;
    int width;
    int height;
    double last_pts; // 最近一次 vf_decode_next 成功帧的 pts（秒）；-1=未知
} VfDec;

/* 音频解码器：swr 统一重采样输出 s16 交错 */
typedef struct VfADec {
    AVFormatContext *fmt;
    AVCodecContext *codec;
    AVFrame *frame;
    AVPacket *pkt;
    struct SwrContext *swr;
    int astream;
    int out_ch;
    int out_rate;
} VfADec;

/* 字幕解码器：整条读成「起始秒 + 文本」，文本按 rect 原样拼接 */
typedef struct VfSDec {
    AVFormatContext *fmt;
    AVCodecContext *codec;
    AVSubtitle sub;
    AVPacket *pkt;
    int sstream;
    double last_pts; // 最近一条的起始秒；-1=未知
    double last_end; // 最近一条的结束秒（起始 + end_display_time）
} VfSDec;

/* 版本（构建期链接确认 + 运行时探测） */
int32_t vf_version(void) {
    return (int32_t)avformat_version();
}

/* 打开容器并定位媒体流。失败不返回 NULL：返回哑句柄（fmt=NULL），
 * 由 vf_ok 探测——FFI 侧避免 NULL/Option 语义不确定。 */
VfFmt *vf_open(const char *path) {
    VfFmt *f = (VfFmt *)malloc(sizeof(VfFmt));
    f->vstream = -1;
    f->astream = -1;
    f->sstream = -1;
    f->fmt = NULL;
    if (avformat_open_input(&f->fmt, path, NULL, NULL) == 0) {
        if (avformat_find_stream_info(f->fmt, NULL) >= 0) {
            f->vstream = av_find_best_stream(f->fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
            f->astream = av_find_best_stream(f->fmt, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
            f->sstream = av_find_best_stream(f->fmt, AVMEDIA_TYPE_SUBTITLE, -1, -1, NULL, 0);
        }
    }
    return f;
}

/* 打开是否成功（fmt 有效） */
int32_t vf_ok(VfFmt *f) {
    return f && f->fmt ? 1 : 0;
}

void vf_close(VfFmt *f) {
    if (f) {
        avformat_close_input(&f->fmt);
        free(f);
    }
}

int32_t vf_video_stream(VfFmt *f) {
    return f ? f->vstream : -1;
}

/* 音频流索引（-1 无） */
int32_t vf_audio_stream(VfFmt *f) {
    return f ? f->astream : -1;
}

/* 字幕流索引（-1 无） */
int32_t vf_subtitle_stream(VfFmt *f) {
    return f ? f->sstream : -1;
}

/* 未开解码器的哑句柄（NULL）：惰性开解码器时作 Demuxer 字段占位 */
VfDec *vf_no_decoder(void) {
    return NULL;
}

VfADec *vf_no_audio_decoder(void) {
    return NULL;
}

/* 视频流原生尺寸 */
int32_t vf_stream_width(VfFmt *f) {
    if (f && f->vstream >= 0) {
        return f->fmt->streams[f->vstream]->codecpar->width;
    }
    return 0;
}

int32_t vf_stream_height(VfFmt *f) {
    if (f && f->vstream >= 0) {
        return f->fmt->streams[f->vstream]->codecpar->height;
    }
    return 0;
}

/* 时长（秒，AV_TIME_BASE 分之 duration）；未知给 0 */
double vf_duration_s(VfFmt *f) {
    if (f && f->fmt->duration != AV_NOPTS_VALUE) {
        return (double)f->fmt->duration / (double)AV_TIME_BASE;
    }
    return 0.0;
}

/* 打开视频解码器（含 RGBA 输出的 sws 上下文）；失败 NULL */
void vf_close_decoder(VfDec *d);

VfDec *vf_open_video_decoder(VfFmt *f, int32_t out_w, int32_t out_h) {
    if (!f || f->vstream < 0) {
        return NULL;
    }
    AVStream *st = f->fmt->streams[f->vstream];
    const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) {
        return NULL;
    }
    VfDec *d = (VfDec *)malloc(sizeof(VfDec));
    d->fmt = f->fmt;
    d->vstream = f->vstream;
    d->codec = NULL;
    d->frame = NULL;
    d->pkt = NULL;
    d->sws = NULL;
    d->width = 0;
    d->height = 0;
    d->last_pts = -1.0;
    d->codec = avcodec_alloc_context3(codec);
    if (avcodec_parameters_to_context(d->codec, st->codecpar) < 0) {
        avcodec_free_context(&d->codec);
        d->codec = NULL;
        return d;
    }
    if (avcodec_open2(d->codec, codec, NULL) < 0) {
        avcodec_free_context(&d->codec);
        d->codec = NULL;
        return d;
    }
    d->width = out_w > 0 ? out_w : d->codec->width;
    d->height = out_h > 0 ? out_h : d->codec->height;
    // 单边指定时另一边按源宽高比补齐(ffmpeg -1 语义):否则 480 宽+
    // 源高会把 16:9 视频解码成竖长拉伸帧,后续 letterbox 无从校正
    if (out_w > 0 && out_h <= 0 && d->codec->width > 0) {
        d->height = (int)((double)d->codec->height * out_w / d->codec->width + 0.5);
    } else if (out_h > 0 && out_w <= 0 && d->codec->height > 0) {
        d->width = (int)((double)d->codec->width * out_h / d->codec->height + 0.5);
    }
    if (d->width < 1) {
        d->width = 1;
    }
    if (d->height < 1) {
        d->height = 1;
    }
    d->frame = av_frame_alloc();
    d->pkt = av_packet_alloc();
    d->sws = sws_getContext(
        d->codec->width, d->codec->height, d->codec->pix_fmt,
        d->width, d->height, AV_PIX_FMT_RGBA,
        SWS_BILINEAR, NULL, NULL, NULL);
    if (!d->frame || !d->pkt || !d->sws) {
        vf_close_decoder(d);
        d = (VfDec *)malloc(sizeof(VfDec));
        d->fmt = f->fmt;
        d->vstream = f->vstream;
        d->codec = NULL;
        d->frame = NULL;
        d->pkt = NULL;
        d->sws = NULL;
        d->width = 0;
        d->height = 0;
        d->last_pts = -1.0;
        return d;
    }
    return d;
}

void vf_close_decoder(VfDec *d) {
    if (d) {
        if (d->sws) {
            sws_freeContext(d->sws);
        }
        if (d->frame) {
            av_frame_free(&d->frame);
        }
        if (d->pkt) {
            av_packet_free(&d->pkt);
        }
        if (d->codec) {
            avcodec_free_context(&d->codec);
        }
        free(d);
    }
}

int32_t vf_dec_width(VfDec *d) {
    return d ? d->width : 0;
}

int32_t vf_dec_height(VfDec *d) {
    return d ? d->height : 0;
}

/* 解码下一帧为 RGBA 写进 out（容量须 >= w*h*4）。
 * 返回：1=拿到一帧；0=流结束；-1=错误 */
int32_t vf_decode_next(VfDec *d, uint8_t *out, int32_t out_len) {
    if (!d) {
        return -1;
    }
    while (1) {
        int ret = av_read_frame(d->fmt, d->pkt);
        if (ret == AVERROR_EOF) {
            return 0;
        }
        if (ret < 0) {
            return -1;
        }
        if (d->pkt->stream_index != d->vstream) {
            av_packet_unref(d->pkt);
            continue;
        }
        if (avcodec_send_packet(d->codec, d->pkt) < 0) {
            av_packet_unref(d->pkt);
            return -1;
        }
        av_packet_unref(d->pkt);
        ret = avcodec_receive_frame(d->codec, d->frame);
        if (ret == AVERROR(EAGAIN)) {
            continue;
        }
        if (ret == AVERROR_EOF) {
            return 0;
        }
        if (ret < 0) {
            return -1;
        }
        uint8_t *dst[4] = { out, NULL, NULL, NULL };
        int dst_linesize[4] = { d->width * 4, 0, 0, 0 };
        sws_scale(d->sws, (const uint8_t *const *)d->frame->data, d->frame->linesize,
                  0, d->frame->height, dst, dst_linesize);
        // 帧时间戳（秒）：best_effort 优先（容错丢 pts 的包），流时间基换算
        int64_t ts = d->frame->best_effort_timestamp;
        if (ts == AV_NOPTS_VALUE) {
            ts = d->frame->pts;
        }
        AVStream *st = d->fmt->streams[d->vstream];
        d->last_pts = ts == AV_NOPTS_VALUE
                          ? -1.0
                          : (double)ts * av_q2d(st->time_base);
        av_frame_unref(d->frame);
        return 1;
    }
}

/* 最近一次 vf_decode_next 成功帧的 pts（秒）；未解/未知 -1 */
double vf_frame_pts_s(VfDec *d) {
    return d ? d->last_pts : -1.0;
}

/* 视频流帧率（avg_frame_rate 优先，r_frame_rate 回退；未知 0） */
double vf_stream_fps(VfFmt *f) {
    if (!f || f->vstream < 0) {
        return 0.0;
    }
    AVStream *st = f->fmt->streams[f->vstream];
    AVRational r = st->avg_frame_rate;
    if (r.num <= 0 || r.den <= 0) {
        r = st->r_frame_rate;
    }
    if (r.num <= 0 || r.den <= 0) {
        return 0.0;
    }
    return av_q2d(r);
}

/* 跳转到指定秒（视频流时间基）；0 成功 / -1 失败 */
int32_t vf_seek_s(VfDec *d, double t_s) {
    if (!d) {
        return -1;
    }
    AVStream *st = d->fmt->streams[d->vstream];
    int64_t ts = (int64_t)(t_s * (double)st->time_base.den / (double)st->time_base.num);
    if (avformat_seek_file(d->fmt, d->vstream, INT64_MIN, ts, ts, 0) < 0) {
        return -1;
    }
    avcodec_flush_buffers(d->codec);
    d->last_pts = -1.0; // 旧位置的 pts 不得误导下一帧的时间轴判断
    return 0;
}

/* -------------------------------------------------------------------------
 * 音频解码器（swr 统一输出 s16 交错，采样率/声道保持源）
 * ------------------------------------------------------------------------- */

void vf_close_audio_decoder(VfADec *d) {
    if (d) {
        if (d->swr) {
            swr_free(&d->swr);
        }
        if (d->frame) {
            av_frame_free(&d->frame);
        }
        if (d->pkt) {
            av_packet_free(&d->pkt);
        }
        if (d->codec) {
            avcodec_free_context(&d->codec);
        }
        free(d);
    }
}

/* 打开音频解码器；失败返回 NULL（MoonBit 侧以 vf_adec_channels<=0 探测） */
VfADec *vf_open_audio_decoder(VfFmt *f) {
    if (!f || f->astream < 0) {
        return NULL;
    }
    AVStream *st = f->fmt->streams[f->astream];
    const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) {
        return NULL;
    }
    VfADec *d = (VfADec *)calloc(1, sizeof(VfADec));
    d->fmt = f->fmt;
    d->astream = f->astream;
    d->codec = avcodec_alloc_context3(codec);
    if (!d->codec ||
        avcodec_parameters_to_context(d->codec, st->codecpar) < 0 ||
        avcodec_open2(d->codec, codec, NULL) < 0) {
        vf_close_audio_decoder(d);
        return NULL;
    }
    d->out_ch = d->codec->ch_layout.nb_channels;
    d->out_rate = d->codec->sample_rate;
    d->frame = av_frame_alloc();
    d->pkt = av_packet_alloc();
    if (swr_alloc_set_opts2(&d->swr,
                            &d->codec->ch_layout, AV_SAMPLE_FMT_S16, d->out_rate,
                            &d->codec->ch_layout, d->codec->sample_fmt, d->out_rate,
                            0, NULL) < 0 ||
        !d->frame || !d->pkt || !d->swr || swr_init(d->swr) < 0) {
        vf_close_audio_decoder(d);
        return NULL;
    }
    return d;
}

int32_t vf_adec_channels(VfADec *d) {
    return d ? d->out_ch : 0;
}

int32_t vf_adec_rate(VfADec *d) {
    return d ? d->out_rate : 0;
}

/* 把当前解码帧转 s16 交错写进 out；返回写入 PCM 帧数（0=转换失败） */
static int32_t vf_aconvert(VfADec *d, uint8_t *out, int32_t out_len) {
    int dst_frames = out_len / (d->out_ch * 2);
    if (dst_frames <= 0) {
        return 0;
    }
    int got = swr_convert(d->swr, &out, dst_frames,
                          (const uint8_t **)d->frame->extended_data,
                          d->frame->nb_samples);
    return got > 0 ? got : 0;
}

/* 解码下一段 PCM（s16 交错）写进 out。
 * 返回：>0 = 写入帧数；0 = 流结束；-1 = 错误 */
int32_t vf_decode_pcm(VfADec *d, uint8_t *out, int32_t out_len) {
    if (!d || !d->codec) {
        return -1;
    }
    while (1) {
        int ret = avcodec_receive_frame(d->codec, d->frame);
        if (ret == 0) {
            int32_t frames = vf_aconvert(d, out, out_len);
            av_frame_unref(d->frame);
            if (frames > 0) {
                return frames;
            }
            continue;
        }
        if (ret == AVERROR(EAGAIN)) {
            ret = av_read_frame(d->fmt, d->pkt);
            if (ret == AVERROR_EOF) {
                // 尾部：冲刷解码器取残留帧（send 返回值忽略，重复冲刷无害）
                avcodec_send_packet(d->codec, NULL);
                continue;
            }
            if (ret < 0) {
                return -1;
            }
            if (d->pkt->stream_index != d->astream) {
                av_packet_unref(d->pkt);
                continue;
            }
            if (avcodec_send_packet(d->codec, d->pkt) < 0) {
                av_packet_unref(d->pkt);
                return -1;
            }
            av_packet_unref(d->pkt);
            continue;
        }
        if (ret == AVERROR_EOF) {
            return 0; // 冲刷完毕
        }
        if (ret < 0) {
            return -1;
        }
    }
}

/* 跳转到指定秒（音频流时间基）；0 成功 / -1 失败。
 * swr 重初始化以丢弃旧位置的重采样缓存，避免 seek 后残音。 */
int32_t vf_aseek_s(VfADec *d, double t_s) {
    if (!d || !d->codec) {
        return -1;
    }
    AVStream *st = d->fmt->streams[d->astream];
    int64_t ts = (int64_t)(t_s * (double)st->time_base.den / (double)st->time_base.num);
    if (avformat_seek_file(d->fmt, d->astream, INT64_MIN, ts, ts, 0) < 0) {
        return -1;
    }
    avcodec_flush_buffers(d->codec);
    if (d->swr) {
        swr_init(d->swr);
    }
    return 0;
}

/* -------------------------------------------------------------------------
 * 字幕解码（把整条字幕流读成「起始秒 + 文本」列表）
 *
 * 三条口径：
 * ① **另开一份容器读**——与视频/音频解码器共用 AVFormatContext 会互相推进读
 *    位置，把主时间轴搅乱；字幕是稀疏的、一次读完，重开一份最省事也最安全。
 * ② 文本按 rect 原样拼接（多条以 '\n' 分隔），**不清洗** ASS 的 {\an8} 与
 *    <c.xxx> 这类标记——语义处理归 MoonBit 层，C 只做搬运。
 * ③ 图形字幕（无 text 的 rect）与空条目直接跳过，不报成一条空字幕。
 * ------------------------------------------------------------------------- */

void vf_sub_close(VfSDec *d) {
    if (d) {
        avsubtitle_free(&d->sub);
        if (d->pkt) {
            av_packet_free(&d->pkt);
        }
        if (d->codec) {
            avcodec_free_context(&d->codec);
        }
        if (d->fmt) {
            avformat_close_input(&d->fmt);
        }
        free(d);
    }
}

/* 另开一份容器并定位字幕流、开解码器。没有字幕流或打不开时 NULL。 */
VfSDec *vf_sub_open(const char *path) {
    AVFormatContext *fmt = NULL;
    if (avformat_open_input(&fmt, path, NULL, NULL) < 0) {
        return NULL;
    }
    if (avformat_find_stream_info(fmt, NULL) < 0) {
        avformat_close_input(&fmt);
        return NULL;
    }
    int sstream = av_find_best_stream(fmt, AVMEDIA_TYPE_SUBTITLE, -1, -1, NULL, 0);
    if (sstream < 0) {
        avformat_close_input(&fmt);
        return NULL;
    }
    AVStream *st = fmt->streams[sstream];
    const AVCodec *codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) {
        avformat_close_input(&fmt);
        return NULL;
    }
    VfSDec *d = (VfSDec *)calloc(1, sizeof(VfSDec));
    d->fmt = fmt;
    d->sstream = sstream;
    d->pkt = av_packet_alloc();
    d->last_pts = -1.0;
    d->last_end = -1.0;
    d->codec = avcodec_alloc_context3(codec);
    if (!d->pkt || !d->codec ||
        avcodec_parameters_to_context(d->codec, st->codecpar) < 0 ||
        avcodec_open2(d->codec, codec, NULL) < 0) {
        vf_sub_close(d);
        return NULL;
    }
    return d;
}

/* 打开是否成功（NULL = 没有字幕流 / 解码器缺失 / 文件打不开） */
int32_t vf_sub_ok(VfSDec *d) {
    return d ? 1 : 0;
}

/* 解下一条字幕：文本写进 out（UTF-8，带尾零），返回写出的字节数（不含尾零）；
 * 0 = 流结束；-1 = 错误。起始秒随后用 vf_sub_pts_s 取（与 vf_frame_pts_s 同形）。 */
int32_t vf_sub_next(VfSDec *d, char *out, int32_t out_len) {
    if (!d || !d->codec || out == NULL || out_len < 1) {
        return -1;
    }
    out[0] = '\0';
    while (1) {
        int ret = av_read_frame(d->fmt, d->pkt);
        if (ret == AVERROR_EOF) {
            return 0;
        }
        if (ret < 0) {
            return -1;
        }
        if (d->pkt->stream_index != d->sstream) {
            av_packet_unref(d->pkt);
            continue;
        }
        AVStream *st = d->fmt->streams[d->sstream];
        double base = d->pkt->pts == AV_NOPTS_VALUE
                          ? 0.0
                          : (double)d->pkt->pts * av_q2d(st->time_base);
        // 包时长要在 unref 之前取（unref 会把 duration 清掉）
        double dur_pkt = d->pkt->duration > 0
                             ? (double)d->pkt->duration * av_q2d(st->time_base)
                             : 0.0;
        int got = 0;
        ret = avcodec_decode_subtitle2(d->codec, &d->sub, &got, d->pkt);
        av_packet_unref(d->pkt);
        if (ret < 0) {
            return -1;
        }
        if (!got) {
            continue;
        }
        int at = 0;
        for (int i = 0; i < d->sub.num_rects; i++) {
            AVSubtitleRect *r = d->sub.rects[i];
            // 有些文本字幕解码器（mov_text 即其一）只填 ass 字段、text 留空；
            // ass 是整行 ASS 对话（前九个逗号字段 + 文本），原样带出去，
            // 剥前缀与清洗标记归 MoonBit 层
            const char *txt = (r != NULL && r->text != NULL && r->text[0] != '\0')
                                  ? r->text
                                  : (r != NULL ? r->ass : NULL);
            if (txt == NULL || txt[0] == '\0') {
                continue;
            }
            int n = snprintf(out + at, out_len - at, at == 0 ? "%s" : "\n%s",
                             txt);
            if (n < 0 || n >= out_len - at) {
                break;
            }
            at += n;
        }
        // 起止时间 = 包 pts + 该条目的 start_display_time；时长取「包时长」与
        // 「end_display_time」里较短的那个——部分解码器（mov_text 即其一）不填
        // 条目时长、恒给 2000ms 默认值，照它读会让一条字幕压住下一条。
        d->last_pts = base + (double)d->sub.start_display_time / 1000.0;
        double dur_sub = (double)d->sub.end_display_time / 1000.0;
        double dur = dur_sub;
        if (dur_pkt > 0.0 && (dur_sub <= 0.0 || dur_pkt < dur_sub)) {
            dur = dur_pkt;
        }
        d->last_end = d->last_pts + (dur > 0.0 ? dur : 0.0);
        avsubtitle_free(&d->sub);
        if (at == 0) {
            continue; // 图形字幕或被截断成空的条目不算一条
        }
        return at;
    }
}

/* 最近一条字幕的起始秒；未读/未知 -1 */
double vf_sub_pts_s(VfSDec *d) {
    return d ? d->last_pts : -1.0;
}

/* 最近一条字幕的结束秒；未读/未知 -1（个别流不填时长，此时与起始同刻） */
double vf_sub_end_s(VfSDec *d) {
    return d ? d->last_end : -1.0;
}

#endif /* _WIN32 */
