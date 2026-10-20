# Changelog

## 2026-10-20 — initial release
- Round 1: VideoToolbox HEVC 4:2:2 vs libx265 4:4:4 (preset slower) on ProRes 4444 green-screen footage (S1–S3).
- Round 2: libx265 4:4:4 preset comparison (slower / slow / medium).
- Round 3: main444-12 vs main444-10 at medium, plus a saturated-backdrop clip (S4).
- Round 4: HEVC with Alpha on macOS (VideoToolbox alpha_quality 0.9 / 1.0, Apple avconvert preset); libx265 alpha not available (T1, T2).
- Scripts for encoding, PSNR/SSIM/VMAF, chroma-key matte comparison, alpha fidelity; per-round CSV results.
