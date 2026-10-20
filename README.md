# HEVC archive benchmarks: 4:4:4 vs 4:2:2, x265 vs VideoToolbox, 12-bit, HEVC with alpha

Reproducible benchmarks for archiving **ProRes 4444** camera masters as H.265/HEVC. Sources: ARRI ProRes 4444 footage from a studio green-screen project (3840x2160, 25 fps, 12-bit 4:4:4, about 880 Mbps), plus ProRes 4444 clips with a real alpha channel.

- Web version with the same tables: https://squeezereel.com/en/benchmarks/hevc-444-vs-422-prores-4444-green-screen (中文: https://squeezereel.com/zh/benchmarks/hevc-444-vs-422-prores-4444-green-screen)
- Tool used for the archive lanes: [SqueezeReel](https://squeezereel.com) (smartenc 0.2.24 / 0.2.25) plus plain ffmpeg 9.0.2 and x265 4.3 (8/10/12-bit)
- No frames or crops from the footage are published here (client material). All numbers are measurements against the source.

## TL;DR

1. **4:4:4 chroma gave no measurable chroma benefit.** Chroma PSNR/SSIM of x265 4:4:4 and VideoToolbox 4:2:2 are within 0.25 dB, even on a saturated red backdrop. The 4:4:4 lane wins on **luma** (+0.9 to +1.5 dB PSNR, VMAF about +1.2) and on **keying edges** (36% to 47% fewer matte edge mismatches), at 7 to 14x the file size.
2. **x265 `medium` is about as good as `slower` for matte quality and about 10x faster** (3 to 3.8 fps vs 0.35 fps on an M4 Mac mini, 6 threads), at about 60% of the size. VMAF-min is 0.4 to 0.7 lower.
3. **12-bit (main444-12) is not worth making the default**: 26% to 32% more bytes, 5% to 27% slower, +0.15 dB luma PSNR.
4. **HEVC with Alpha works on macOS.** `hevc_videotoolbox -pix_fmt bgra -alpha_quality 1.0` kept the alpha plane bit-exact on both test clips at about 12x compression; Apple's avconvert preset reaches about 22x but soft-edge alpha deviates by up to 37 to 42/255.
5. **libx265 cannot write an alpha layer** in the Homebrew x265 4.3 build (ffmpeg: "Loaded libx265 does not support alpha layer encoding").

## Method

- **Lanes.** A = `hevc_videotoolbox` 4:2:2 10-bit, `-q:v 65`, GOP 50 (macOS only). B = `libx265` main444-10, crf 16, `aq-mode=3`, keyint 50, preset as stated. B12 = main444-12 with the same settings.
- **Pixel path.** 12-bit 4:4:4 source converted with bt709 in/out matrix, primaries and transfer pinned. ffmpeg 9 mislabels ProRes 4444 as GBR, so every command forces `setparams=colorspace=bt709...` first.
- **Metrics.** PSNR/SSIM per plane at yuv444p12le (numbers sit about 24 dB above 8-bit-scale figures). VMAF with libvmaf 1080p model (`vmaf_v0.6.1`) and `vmaf_4k_v0.6.1`, every 5th frame, luma at 10-bit. Timestamps are reset on both inputs, because libx265 output with B-frames can start at a non-zero pts.
- **Matte test.** Key the source and every encode with the same `chromakey` settings (flat teal / light green / red backdrop, similarity 0.03 to 0.05) and compare alpha mattes: matte PSNR, mismatch share (alpha difference above 25/255), edge band (8 px around the source matte boundary), soft-alpha area (source alpha between 5 and 250). Only the backdrop is keyed; hair against a dark background is not covered.
- **Alpha test.** RGB composited over mid-grey (raw RGBA comparison is meaningless where alpha = 0), alpha plane compared directly (share of pixels differing by more than 2/255, PSNR, max difference). Decoding by ffmpeg software decode; Apple AVFoundation used to confirm native alpha decoding.
- **Hardware.** Rounds 1 to 3: Apple M4 Mac mini, 10 cores, 16 GB, x265 at 6 threads, one encode at a time, normal desktop load. Round 4: Apple M2 Max MacBook Pro.
- **Samples.** S1 static subject, 20 s. S2 moving subject with curly hair, 20 s. S3 shortest clip, 3.84 s. S4 saturated red backdrop, 12.44 s whole clip. T1, T2: 8.33 s ProRes 4444 text-graphic clips with alpha (about 2.1% and 1.2% soft pixels).

## Round 1: 4:2:2 fast lane vs 4:4:4 slow lane (preset slower)

| Sample / lane | Speed | Size | Ratio | VMAF mean / min (1080p) | PSNR Y/U/V dB | SSIM Y/U/V | Matte edge mismatch | Soft alpha mismatch |
|---|---|---|---|---|---|---|---|---|
| S1 A VT 4:2:2 | 41 fps | 3.83 MB | 588x | 95.1 / 93.5 | 51.4/54.4/52.3 | .9933/.9969/.9951 | 3.59% | 15.2% |
| S1 B x265 slower | 0.35 fps | 50.1 MB | 45x | 96.3 / 95.3 | 52.7/54.6/52.4 | .9948/.9969/.9951 | 2.25% | 9.7% |
| S2 A | 40 fps | 4.59 MB | 478x | 95.3 / 93.9 | 50.5/53.2/52.4 | .9915/.9958/.9952 | 2.92% | 15.2% |
| S2 B | 0.32 fps | 65.1 MB | 34x | 96.4 / 95.6 | 51.9/53.3/52.4 | .9937/.9958/.9951 | 1.88% | 10.1% |
| S3 A | 38 fps | 1.04 MB | 396x | 96.1 / 93.6 | 51.9/55.9/56.7 | .9942/.9980/.9984 | 5.25% | 0.9% |
| S3 B | 0.35 fps | 7.41 MB | 55x | 97.4 / 95.8 | 53.3/56.3/57.1 | .9955/.9980/.9985 | 2.79% | 0.5% |

Extrapolation to 414 clips (about 980 GB, 2.35 h of footage): VT lane 10.1 GB measured; slower about 25 to 130 GB and about 7 days nonstop. The samples are on the easy end (flat backdrop, locked camera), so expect the high end.

## Round 2: libx265 4:4:4 presets (crf 16, aq-mode 3)

| Sample / preset | Speed | Size | VMAF mean / min | Edge mismatch |
|---|---|---|---|---|
| S3 slower | 0.35 fps | 7.41 MB | 97.4 / 95.8 | 2.79% |
| S3 slow | 1.14 fps | 7.39 MB | 97.8 / 96.0 | 2.82% |
| S3 medium | 3.8 fps | 4.17 MB | 97.3 / 95.6 | 2.92% |
| S1 slower | 0.35 fps | 50.1 MB | 96.3 / 95.3 | 2.25% |
| S1 medium | 3.44 fps | 29.9 MB | 96.3 / 94.5 | 2.24% |
| S2 slower | 0.32 fps | 65.1 MB | 96.4 / 95.6 | 1.88% |
| S2 medium | 2.96 fps | 40.1 MB | 96.4 / 95.1 | 1.74% |

Full 414-clip run at medium: about 18 hours, 15 to 80 GB (estimate).

## Round 3: 12-bit and a saturated-backdrop clip (preset medium)

| Sample / lane | Speed | Size | VMAF mean / min | PSNR Y/U/V | SSIM Y/U/V | Edge mismatch | Soft alpha mismatch |
|---|---|---|---|---|---|---|---|
| S1 A | ~40 fps | 3.8 MB | 95.12 / 93.48 | 51.41/54.42/52.31 | .9933/.9969/.9951 | 3.59% | 15.2% |
| S1 B10 | 3.44 fps | 29.9 MB | 96.26 / 94.53 | 52.25/54.37/52.41 | .9942/.9968/.9951 | 2.24% | 9.7% |
| S1 B12 | 3.28 fps | 39.5 MB | 96.34 / 94.56 | 52.41/54.43/52.48 | .9944/.9968/.9952 | 1.89% | 8.3% |
| S2 A | ~40 fps | 4.6 MB | 95.33 / 93.87 | 50.46/53.23/52.44 | .9915/.9958/.9952 | 2.92% | 15.2% |
| S2 B10 | 2.96 fps | 40.1 MB | 96.36 / 95.11 | 51.29/53.07/52.39 | .9927/.9956/.9951 | 1.74% | 9.4% |
| S2 B12 | 2.55 fps | 50.7 MB | 96.40 / 95.24 | 51.47/53.10/52.48 | .9930/.9956/.9951 | 1.57% | 8.5% |
| S4 A | ~40 fps | 2.5 MB | 92.66 / 91.84 | 49.64/53.05/52.74 | .9895/.9955/.9953 | 4.05% | 9.7% |
| S4 B10 | 2.51 fps | 28.6 MB | 94.48 / 92.81 | 50.35/52.81/52.96 | .9907/.9953/.9955 | 2.94% | 6.7% |
| S4 B12 | 1.83 fps | 36.2 MB | 94.68 / 92.87 | 50.50/52.87/53.04 | .9911/.9953/.9955 | 2.57% | 5.7% |

On S4, 4:4:4 vs 4:2:2 chroma PSNR differs by only -0.24 dB (U) and +0.22 dB (V). Limits: S4 is one clip and the subjects are small in frame; no high-frequency coloured-detail clip was tested.

## Round 4: HEVC with Alpha on macOS

| Sample / lane | Speed | Size | Ratio | RGB over grey PSNR R/G/B | Alpha PSNR | Alpha mismatch (>2/255), non-empty area | Soft-edge area | Max alpha diff |
|---|---|---|---|---|---|---|---|---|
| T1 VT alpha_quality 0.9 | ~45 fps | 10.46 MB | 14.0x | 56.4/60.4/64.3 | 69.2 dB | 0.21% | 1.5% | 6 |
| T1 VT alpha_quality 1.0 | ~44 fps | 12.62 MB | 11.6x | 56.5/60.5/64.5 | lossless | 0% | 0% | 0 |
| T1 avconvert preset | ~12 fps | 6.65 MB | 22.1x | 60.3/60.4/60.1 | 59.4 dB | 7.07% | 37.0% | 37 |
| T2 VT alpha_quality 0.9 | ~41 fps | 6.67 MB | 14.8x | 59.2/63.0/66.4 | 71.4 dB | 0.23% | 1.6% | 7 |
| T2 VT alpha_quality 1.0 | ~42 fps | 8.22 MB | 12.0x | 59.3/63.1/66.7 | lossless | 0% | 0% | 0 |
| T2 avconvert preset | ~14 fps | 4.19 MB | 23.5x | 62.9/62.9/62.7 | 61.6 dB | 7.77% | 38.4% | 42 |

- Apple AVFoundation reports `ContainsAlphaChannel = 1` and decodes alpha 0 to 255 matching the source; QuickLook makes thumbnails.
- `ffprobe` shows only `yuv420p` (alpha is an auxiliary layer). ffmpeg software decode returns alpha; `-hwaccel videotoolbox` returns nv12 and drops it.
- The ffmpeg VideoToolbox files tag the colour matrix as GBR although the stream is YCbCr; Apple's avconvert preset tags bt709 correctly. Check import into your editor before relying on the ffmpeg path.
- Output is 8-bit 4:2:0 plus alpha (Apple encoder limit), from a 12-bit 4:4:4 source.
- Limits: both clips are text graphics, not hair-like semi-transparent content. Of 16 clips flagged as having alpha, 10 had a fully opaque alpha plane.

## Issues found in the archive tooling

- libx265 archive output carried a 0.08 s (2 frame) empty edit list because `-avoid_negative_ts make_zero` is used together with B-frames; dropping it restores start time 0. The offset also made the tool's own VMAF gate score 20.6 instead of about 97.
- `--preset` was ignored for the libx265 archive path (slower/slow/medium gave byte-identical files).
- `verify` without `--purpose archive` skipped the quality gate and still reported success.

## Reproduce

Requirements: ffmpeg 9.x with libx265 (main444-10 and main444-12 builds), libvmaf, optionally hevc_videotoolbox on macOS; Python 3 with numpy and scipy; Swift for `alpha_check.swift`.

```bash
# 1. encode (choose preset / bit depth)
scripts/encode_vt.sh   source.mov out/A.mov 65
scripts/encode_x265.sh source.mov out/B10.mov medium 10
scripts/encode_x265.sh source.mov out/B12.mov medium 12

# 2. metrics (PSNR / SSIM / VMAF)
scripts/metrics.sh out/B10.mov source.mov B10 results/raw

# 3. keying fidelity (pick --key from a backdrop pixel; tune --similarity by eye)
python3 scripts/matte_compare.py --ref source.mov --test out/A.mov out/B10.mov out/B12.mov --key 0x45877b --similarity 0.05

# all of the above in one go (set W/H for non-4K sources)
scripts/run_chroma_round.sh source.mov work 0x45877b 0.05 medium

# alpha round (macOS)
scripts/alpha_encode.sh   alpha_source.mov out/alpha.mov 1.0
python3 scripts/alpha_stats.py --ref alpha_source.mov --test out/alpha.mov
scripts/alpha_rgb_metrics.sh out/alpha.mov alpha_source.mov
swiftc -O scripts/alpha_check.swift -o alpha_check && ./alpha_check out/alpha.mov
```

Raw numbers per round are in `results/*.csv`. The scripts were smoke-tested on a synthetic ProRes 4444 clip.

---

# 中文版

用 H.265/HEVC 归档 **ProRes 4444** 摄影机母版的可复现基准测试。素材:某棚拍绿幕项目的 ARRI ProRes 4444(3840x2160、25 fps、12-bit 4:4:4,约 880 Mbps),以及带真实 alpha 的 ProRes 4444 片段。

- 网页版(同样的表):https://squeezereel.com/zh/benchmarks/hevc-444-vs-422-prores-4444-green-screen(English: https://squeezereel.com/en/benchmarks/hevc-444-vs-422-prores-4444-green-screen)
- 归档档位使用的工具:[轻舟 SqueezeReel](https://squeezereel.com)(smartenc 0.2.24 / 0.2.25),以及 ffmpeg 9.0.2 与 x265 4.3
- 本仓库不含素材画面或裁切图(客户素材);所有数字都是相对源文件的实测值。

## 结论摘要

1. **4:4:4 的色度没有可测的收益。** x265 4:4:4 与 VideoToolbox 4:2:2 的色度 PSNR/SSIM 相差不到 0.25 dB,饱和红幕上也一样。4:4:4 赢在**亮度**(PSNR +0.9 到 +1.5 dB,VMAF 约 +1.2)和**抠像边缘**(蒙版边缘不一致少 36% 到 47%),代价是体积 7 到 14 倍。
2. **x265 `medium` 的抠像质量与 `slower` 持平,速度约快 10 倍**(M4 Mac mini、6 线程:3 到 3.8 fps 对 0.35 fps),体积约 60%,VMAF 最小值低 0.4 到 0.7。
3. **12-bit(main444-12)不值得作默认:**多 26% 到 32% 体积、慢 5% 到 27%,亮度 PSNR 只高 0.15 dB。
4. **macOS 上 HEVC with Alpha 可行。**`hevc_videotoolbox -pix_fmt bgra -alpha_quality 1.0` 在两条样本上 alpha 位精确无损,约 12 倍压缩;Apple avconvert 预设约 22 倍,但软边 alpha 最大偏差 37 到 42/255。
5. **libx265 写不了 alpha 层:**Homebrew x265 4.3 编译时没带支持(ffmpeg 报 "Loaded libx265 does not support alpha layer encoding")。

## 方法

- 档位:A = `hevc_videotoolbox` 4:2:2 10-bit,`-q:v 65`;B = `libx265` main444-10,crf 16,`aq-mode=3`;B12 = 同参数 main444-12。
- 像素路径:12-bit 4:4:4 源,固定 bt709 矩阵/基色/传输。ffmpeg 9 会把 ProRes 4444 误标为 GBR,所以每条命令先强制 `setparams`。
- 指标:PSNR/SSIM 在 yuv444p12le 下逐平面计算(数值比 8-bit 标尺高约 24 dB);VMAF 用 1080p 与 4K 两个模型,每 5 帧取 1 帧;两路输入都重置时间戳。
- 抠像测试:对源和各档用同一组 `chromakey` 参数出 alpha 蒙版再比较(蒙版 PSNR、不一致占比、边缘带、软 alpha 区域)。只键了背景色,深色背景前的发丝不在覆盖范围。
- alpha 测试:RGB 贴灰底比较,alpha 平面直接比较;解码用 ffmpeg 软解,并用 Apple AVFoundation 确认原生解码。
- 硬件:第 1 到 3 轮 Apple M4 Mac mini;第 4 轮 Apple M2 Max MacBook Pro。
- 样本:S1 静止 20 s;S2 卷发动作 20 s;S3 最短片 3.84 s;S4 饱和红幕 12.44 s;T1、T2 带 alpha 的图文片段 8.33 s。

结果表与英文版相同(见上方四轮表格),原始数字在 `results/*.csv`。

## 已知问题(归档工具)

- libx265 归档输出多出 0.08 s(2 帧)空编辑列表,原因是 `-avoid_negative_ts make_zero` 与 B 帧同用,去掉后起点回到 0;该偏移还会让工具自带的 VMAF 闸口误判。
- `--preset` 对 libx265 归档路径无效。
- `verify` 不带 `--purpose archive` 时跳过质量闸口仍报成功。

## 复现

见上方 Reproduce 一节的命令。脚本在合成 ProRes 4444 片段上做过冒烟测试。

## License

MIT
