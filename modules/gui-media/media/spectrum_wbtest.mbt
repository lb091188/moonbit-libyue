///|
/// 造一段 s16 小端正弦 PCM（`channels`>1 时各声道同值交错）。
fn sp_sine(freq : Double, rate : Int, frames : Int, channels : Int) -> Bytes {
  let raw = FixedArray::make(frames * channels * 2, b'\x00')
  for f = 0; f < frames; f = f + 1 {
    let v = (24000.0 * @math.sin(
        2.0 * @math.PI * freq * f.to_double() / rate.to_double(),
      )).to_int()
    let u = if v < 0 { v + 65536 } else { v }
    for c = 0; c < channels; c = c + 1 {
      let at = (f * channels + c) * 2
      raw[at] = (u & 255).to_byte()
      raw[at + 1] = ((u >> 8) & 255).to_byte()
    }
  }
  Bytes::from_array(raw)
}

///|
/// 电平表里的最强条下标。
fn sp_argmax(lv : Array[Double]) -> Int {
  let mut best = 0
  for i = 1; i < lv.length(); i = i + 1 {
    if lv[i] > lv[best] {
      best = i
    }
  }
  best
}

///|
/// FFT 本体：全 1 输入（纯直流）只有 bin 0 有值，其余 bins 落在数值零附近。
test "radix-2 FFT：直流只点亮 bin 0" {
  let n = sp_window
  let re = Array::make(n, 1.0)
  let im = Array::make(n, 0.0)
  spectrum_fft(re, im)
  assert_true(re[0] > (n.to_double() - 0.001))
  let mut worst = 0.0
  for k = 1; k < n; k = k + 1 {
    let m = (re[k] * re[k] + im[k] * im[k]).sqrt()
    if m > worst {
      worst = m
    }
  }
  assert_true(worst < 1.0e-6)
}

///|
/// 单频正弦：能量落在 440 Hz 所属的对数频段，其余频段压得住。
test "频谱：440Hz 正弦落在对应频段" {
  let sp = Spectrum::make(bands=24)
  sp.feed(sp_sine(440.0, 44100, 1024, 1), 1)
  let lv = sp.levels(0, 44100)
  assert_eq(lv.length(), 24)
  let peak = sp_argmax(lv)
  // 24 段对数分带（40Hz..16kHz）里 440Hz 落在第 9 段附近
  assert_true(peak >= 8 && peak <= 10)
  assert_true(lv[peak] > 0.3)
  assert_true(lv[0] < 0.05)
  assert_true(lv[23] < 0.05)
}

///|
/// 双声道下混与单声道同形；回看帧数把窗口往前挪（模拟设备队列还压着声音）。
test "频谱：立体声下混与队列回看" {
  let mono = Spectrum::make(bands=24)
  mono.feed(sp_sine(1000.0, 44100, 1024, 1), 1)
  let st = Spectrum::make(bands=24)
  st.feed(sp_sine(1000.0, 44100, 1024, 2), 2)
  let a = mono.levels(0, 44100)
  let b = st.levels(0, 44100)
  assert_eq(sp_argmax(a), sp_argmax(b))
  assert_true(b[sp_argmax(b)] > 0.3)
  // 喂满两个窗口后回看一窗：算的应是前半段，仍然点亮同一频段
  let back = Spectrum::make(bands=24)
  back.feed(sp_sine(1000.0, 44100, 1024, 1), 1)
  back.feed(sp_sine(1000.0, 44100, 1024, 1), 1)
  let c = back.levels(1024, 44100)
  assert_true(c[sp_argmax(c)] > 0.3)
}

///|
/// 静音给零电平；数据不足一个窗口时保持上一次读数（seek 后不闪回零）；
/// reset 清账。
test "频谱：静音、不足窗与 reset" {
  let sp = Spectrum::make(bands=24)
  let zeros = Bytes::make(2048, b'\x00')
  sp.feed(zeros, 1)
  let lv = sp.levels(0, 44100)
  for v in lv {
    assert_true(v < 0.01)
  }
  sp.feed(sp_sine(440.0, 44100, 1024, 1), 1)
  let lit = sp.levels(0, 44100)
  assert_true(lit[sp_argmax(lit)] > 0.3)
  // 还不够一个窗口：读数保持，不清零
  let held = sp.levels(sp.fed + 10, 44100)
  assert_eq(held, lit)
  sp.reset()
  assert_eq(sp.fed, 0)
  let after = sp.levels(0, 44100)
  for v in after {
    assert_true(v < 0.01)
  }
}
