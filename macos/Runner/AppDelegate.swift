import Cocoa
import AVFoundation
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard
      let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "cuebox/waveform",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "extractWaveform" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let peakCount = args["peakCount"] as? Int
        else {
          result(FlutterError(code: "bad_args", message: "Missing path/peakCount", details: nil))
          return
        }
        extractWaveform(path: path, peakCount: peakCount, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// 用 AVFoundation 解码音频（flac/mp3/m4a/wav 等）并提取 RMS 峰值（0..1）。
private func extractWaveform(
  path: String,
  peakCount: Int,
  result: @escaping FlutterResult
) {
  let count = min(max(peakCount, 32), 4096)
  DispatchQueue.global(qos: .userInitiated).async {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    guard
      let reader = try? AVAssetReader(asset: asset),
      let track = asset.tracks(withMediaType: .audio).first
    else {
      DispatchQueue.main.async { result(nil) }
      return
    }

    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    reader.add(output)
    reader.startReading()

    let duration = CMTimeGetSeconds(asset.duration)
    let sampleRate = 44100.0
    let totalSamples = duration > 0 ? Int64(duration * sampleRate) : 0
    var sums = [Double](repeating: 0, count: count)
    var sampleCounts = [Int](repeating: 0, count: count)
    var sampleIndex: Int64 = 0

    while let sampleBuffer = output.copyNextSampleBuffer() {
      guard
        let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer),
        CMBlockBufferIsRangeContiguous(blockBuffer, atOffset: 0, length: 0) != false
      else { continue }
      let length = CMBlockBufferGetDataLength(blockBuffer)
      var data = [UInt8](repeating: 0, count: length)
      CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)

      var i = 0
      while i + 1 < length {
        let sample = Int16(bitPattern: UInt16(data[i]) | (UInt16(data[i + 1]) << 8))
        let norm = Double(sample) / 32768.0
        let idx: Int
        if totalSamples > 0 {
          idx = min(count - 1, Int((sampleIndex * Int64(count)) / totalSamples))
        } else {
          idx = Int(sampleIndex % Int64(count))
        }
        sums[idx] += norm * norm
        sampleCounts[idx] += 1
        sampleIndex += 1
        i += 2
      }
    }
    reader.cancelReading()

    var rms = [Double](repeating: 0, count: count)
    var last = 0.0
    for i in 0..<count {
      if sampleCounts[i] > 0 {
        rms[i] = (sums[i] / Double(sampleCounts[i])).squareRoot()
        last = rms[i]
      } else {
        rms[i] = last
      }
    }
    var smooth = [Double](repeating: 0, count: count)
    for i in 0..<count {
      let a = i > 0 ? rms[i - 1] : rms[i]
      let b = rms[i]
      let c = i < count - 1 ? rms[i + 1] : rms[i]
      smooth[i] = (a + 2 * b + c) / 4
    }
    DispatchQueue.main.async { result(smooth) }
  }
}
