// Native macOS check that a movie carries and decodes an alpha channel (AVFoundation, no ffmpeg involved).
// build: swiftc -O alpha_check.swift -o alpha_check      usage: ./alpha_check <file.mov>
import AVFoundation
import CoreMedia
import CoreVideo
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let asset = AVURLAsset(url: url)
guard let t = asset.tracks(withMediaType: .video).first else { print("no video track"); exit(1) }
for fd in t.formatDescriptions as! [CMFormatDescription] {
  print("ContainsAlphaChannel:", CMFormatDescriptionGetExtension(fd, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel) as Any)
}
let r = try AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: t, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
r.add(out); r.startReading()
var n = 0, amin = 255, amax = 0
var asum = 0.0
while let sb = out.copyNextSampleBuffer() {
  guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
  CVPixelBufferLockBaseAddress(pb, .readOnly)
  let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
  let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
  var s = 0.0
  for y in stride(from: 0, to: h, by: 16) { for x in stride(from: 0, to: w, by: 16) { let a = Int(base[y*bpr + x*4 + 3]); amin = min(amin, a); amax = max(amax, a); s += Double(a) } }
  asum += s / Double((h/16)*(w/16)); CVPixelBufferUnlockBaseAddress(pb, .readOnly); n += 1
}
print("frames:", n, "alpha min/max:", amin, amax, "mean:", n > 0 ? asum/Double(n) : -1)
