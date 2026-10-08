// ffmpeg 动态链 FFI 的薄 stub：只做句柄/字符串转换，无业务逻辑。
// 依赖系统 libavformat/libavcodec/libswscale/libavutil（动态链，pkg-config
// 提供头文件与链接参数，由主仓库 scripts/prebuild.py 注入）。

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/imgutils.h>
#include "moonbit.h"

typedef struct VfFmt {
    AVFormatContext *fmt;
    int vstream; // 视频流索引，-1 无
    int astream; // 音频流索引，-1 无
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
    f->fmt = NULL;
    if (avformat_open_input(&f->fmt, path, NULL, NULL) == 0) {
        if (avformat_find_stream_info(f->fmt, NULL) >= 0) {
            f->vstream = av_find_best_stream(f->fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
            f->astream = av_find_best_stream(f->fmt, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
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
        av_frame_unref(d->frame);
        return 1;
    }
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
