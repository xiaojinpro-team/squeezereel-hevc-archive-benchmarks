#!/usr/bin/env bash
# Full-reference metrics of an encode against its source.
# usage: metrics.sh <test.mov> <ref.mov> <label> [outdir=results/raw]
# Writes <outdir>/<label>.{psnr,ssim}.txt and <label>.vmaf_{hd,4k}.json
#  - PSNR/SSIM per plane at yuv444p12le (12-bit scale: numbers are ~24 dB above 8-bit-scale figures)
#  - VMAF: vmaf_v0.6.1 (1080p model) and vmaf_4k_v0.6.1, every 5th frame, luma at 10-bit
# Both inputs have their timestamps reset: libx265 outputs with B-frames can start at a non-zero pts.
set -euo pipefail
test=${1:?test}; ref=${2:?ref}; label=${3:?label}; out=${4:-results/raw}; mkdir -p "$out"
fix="setpts=PTS-STARTPTS,setparams=colorspace=bt709:color_primaries=bt709:color_trc=bt709:range=tv"
ffmpeg -hide_banner -threads 4 -i "$test" -i "$ref" -filter_complex \
  "[0:v]setpts=PTS-STARTPTS,format=yuv444p12le[t];[1:v]${fix},format=yuv444p12le[r];[t][r]psnr" -f null - > "$out/$label.psnr.txt" 2>&1
ffmpeg -hide_banner -threads 4 -i "$test" -i "$ref" -filter_complex \
  "[0:v]setpts=PTS-STARTPTS,format=yuv444p12le[t];[1:v]${fix},format=yuv444p12le[r];[t][r]ssim" -f null - > "$out/$label.ssim.txt" 2>&1
for m in hd:vmaf_v0.6.1 4k:vmaf_4k_v0.6.1; do
  tag=${m%%:*}; model=${m#*:}
  ffmpeg -hide_banner -threads 4 -i "$test" -i "$ref" -filter_complex \
    "[0:v]setpts=PTS-STARTPTS,format=yuv444p10le[t];[1:v]${fix},format=yuv444p10le[r];[t][r]libvmaf=model=version=${model}:n_subsample=5:n_threads=4:log_fmt=json:log_path=$out/$label.vmaf_${tag}.json" -f null - > "$out/$label.vmaf_${tag}.log" 2>&1
done
grep -ho "PSNR y.*" "$out/$label.psnr.txt" || true
grep -ho "SSIM Y.*" "$out/$label.ssim.txt" || true
