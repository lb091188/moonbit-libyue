// 实时频谱分析（纯 MoonBit、零 C、零 libavfilter）：把推给设备的 PCM 旁路
// 一份进样本环，加 Hann 窗做 radix-2 复数 FFT（虚部置 0 的实数输入形态），
// 幅值转 dB 后按对数频段分桶，交给组件画条。
//
// 取样点在**解码/重采样之后、入队之前**，所以它比耳朵听到的快一个队列深度
// （`ap_high_water` 40000 字节 ≈ 0.23 秒）。补偿方式不动音频线程：绘制时按
// 设备队列里还压着多少帧，回看同样多的样本再算——环里本来就留着这段历史。
//
// 倍速下喂进来的是重采样后的流（与耳朵听到的一致），回看帧数与设备口径同源。

///|
/// FFT 点数（2 的幂；44.1kHz 下约 23 毫秒窗口，30fps 刷新足够跟住节奏）。
let sp_window : Int = 1024

///|
/// 样本环的回看深度（帧）：覆盖设备队列高水位还有余量。
let sp_lookback : Int = 16384

///|
/// 分带下界/上界（Hz）：上界再与奈奎斯特取小。
let sp_fmin : Double = 40.0
let sp_fmax : Double = 16000.0

///|
/// dB 归一区间：满幅正弦约 -6 dB，`sp_db_floor` 以下视为无声。
let sp_db_floor : Double = -80.0

///|
/// 一个频谱分析器：样本环 + 平滑后的频段电平。
pub(all) struct Spectrum {
  ring : Array[Double]
  cap : Int
  mut fed : Int
  bands : Int
  levels : Array[Double]
  re : Array[Double]
  im : Array[Double]
}

///|
/// 建分析器。`bands` 是画出来的条数（对数分带）。
pub fn Spectrum::make(bands? : Int = 24) -> Spectrum {
  let cap = sp_window + sp_lookback
  {
    ring: Array::make(cap, 0.0),
    cap,
    fed: 0,
    bands,
    levels: Array::make(bands, 0.0),
    re: Array::make(sp_window, 0.0),
    im: Array::make(sp_window, 0.0),
  }
}

///|
/// 清账（seek / 回起点时用）：电平归零、喂入计数重来，避免把上一段的尾巴
/// 接进新位置的窗口。
pub fn Spectrum::reset(self : Spectrum) -> Unit {
  self.fed = 0
  for i = 0; i < self.bands; i = i + 1 {
    self.levels[i] = 0.0
  }
}

///|
/// 喂一段 s16 交错 PCM（小端），多声道取平均下混成单声道。
pub fn Spectrum::feed(self : Spectrum, pcm : Bytes, channels : Int) -> Unit {
  let ch = if channels <= 0 { 1 } else { channels }
  let frames = pcm.length() / (ch * 2)
  let mut f = 0
  while f < frames {
    let mut acc = 0.0
    let base = f * ch * 2
    let mut c = 0
    while c < ch {
      acc = acc + s16_at(pcm, base + c * 2)
      c = c + 1
    }
    self.ring[self.fed % self.cap] = acc / ch.to_double()
    self.fed = self.fed + 1
    f = f + 1
  }
}

///|
/// s16 小端样本 → [-1, 1]。
fn s16_at(b : Bytes, at : Int) -> Double {
  let lo = b[at].to_int()
  let hi = b[at + 1].to_int()
  let mut v = lo + (hi << 8)
  if v >= 32768 { v = v - 65536 }
  v.to_double() / 32768.0
}

///|
/// 就地 radix-2 FFT（Cooley-Tukey，先位反转再逐级蝶形）。`n` 必须是 2 的幂。
fn spectrum_fft(re : Array[Double], im : Array[Double]) -> Unit {
  let n = re.length()
  let mut j = 0
  for i = 1; i < n; i = i + 1 {
    let mut bit = n >> 1
    while (j & bit) != 0 && bit > 0 {
      j = j ^ bit
      bit = bit >> 1
    }
    j = j | bit
    if i < j {
      let tr = re[i]
      re[i] = re[j]
      re[j] = tr
      let ti = im[i]
      im[i] = im[j]
      im[j] = ti
    }
  }
  let mut len = 2
  while len <= n {
    let half = len >> 1
    let step = 0.0 - 2.0 * @math.PI / len.to_double()
    let wr = @math.cos(step)
    let wi = @math.sin(step)
    let mut start = 0
    while start < n {
      let mut cr = 1.0
      let mut ci = 0.0
      let mut k = 0
      while k < half {
        let a = start + k
        let b = a + half
        let vr = re[b] * cr - im[b] * ci
        let vi = re[b] * ci + im[b] * cr
        re[b] = re[a] - vr
        im[b] = im[a] - vi
        re[a] = re[a] + vr
        im[a] = im[a] + vi
        let nr = cr * wr - ci * wi
        ci = cr * wi + ci * wr
        cr = nr
        k = k + 1
      }
      start = start + len
    }
    len = len * 2
  }
}

///|
/// 取当前该画的电平：`back_frames` 是设备队列里还压着的帧数（往回看那么多个
/// 样本），`rate` 是采样率。返回内部数组的副本。数据还不够一个窗口时给上一次
/// 的结果（刚 seek 完的短暂空档不闪回零）。
pub fn Spectrum::levels(
  self : Spectrum,
  back_frames : Int,
  rate : Int,
) -> Array[Double] {
  let back = if back_frames < 0 { 0 } else { back_frames }
  let end = self.fed - back
  if end < sp_window || rate <= 0 {
    return self.levels.copy()
  }
  let n = sp_window
  let denom = (n - 1).to_double()
  let mut i = 0
  while i < n {
    let idx = (end - n + i) % self.cap
    let s = self.ring[idx]
    // Hann 窗：两端压到 0，避免截断处的频谱泄漏把相邻频段抬起来
    let w = 0.5 - 0.5 * @math.cos(2.0 * @math.PI * i.to_double() / denom)
    self.re[i] = s * w
    self.im[i] = 0.0
    i = i + 1
  }
  spectrum_fft(self.re, self.im)
  let nyq = rate.to_double() / 2.0
  let hi = if sp_fmax < nyq { sp_fmax } else { nyq }
  let span = @math.log10(hi / sp_fmin)
  let peaks : Array[Double] = Array::make(self.bands, 0.0)
  let bin_hz = rate.to_double() / n.to_double()
  let mut k = 1
  while k < n / 2 {
    let f = k.to_double() * bin_hz
    if f >= sp_fmin && f <= hi {
      let mag = (self.re[k] * self.re[k] + self.im[k] * self.im[k]).sqrt() /
        n.to_double()
      let db = 20.0 * @math.log10(mag + 1.0e-9)
      let norm = sp_clamp01((db - sp_db_floor) / (0.0 - sp_db_floor))
      let band_f = @math.log10(f / sp_fmin) / span * self.bands.to_double()
      let band_i =
        if band_f < 0.0 { 0 } else if band_f >= self.bands.to_double() {
          self.bands - 1
        } else {
          band_f.to_int()
        }
      if norm > peaks[band_i] {
        peaks[band_i] = norm
      }
    }
    k = k + 1
  }
  // 快起慢落： rise 直接吃七成，fall 每拍退一成八，条子才有「呼吸」而不是一团糊
  let mut b = 0
  while b < self.bands {
    let prev = self.levels[b]
    let v = peaks[b]
    self.levels[b] = if v > prev {
      prev + (v - prev) * 0.7
    } else {
      prev - prev * 0.18
    }
    b = b + 1
  }
  self.levels.copy()
}

///|
/// 钳到 [0, 1]。
fn sp_clamp01(v : Double) -> Double {
  if v != v || v < 0.0 {
    0.0
  } else if v > 1.0 {
    1.0
  } else {
    v
  }
}
