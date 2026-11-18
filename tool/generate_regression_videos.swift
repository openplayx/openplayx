import AVFoundation
import Foundation

// Usage: swift tool/generate_regression_videos.swift
// Derive both fixtures from the project's original generated video.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let asset = AVURLAsset(url: root.appendingPathComponent("test/fixtures/test_video.mp4"))
for (name, seconds, audio) in [("test_video_short.mp4", 5, true), ("test_video_no_audio.mp4", 12, false)] {
    let composition = AVMutableComposition()
    for type in audio ? [AVMediaType.video, .audio] : [.video] {
        let source = asset.tracks(withMediaType: type).first!
        let target = composition.addMutableTrack(withMediaType: type, preferredTrackID: kCMPersistentTrackID_Invalid)!
        try target.insertTimeRange(CMTimeRange(start: .zero, duration: CMTime(seconds: Double(seconds), preferredTimescale: 600)), of: source, at: .zero)
    }
    let output = root.appendingPathComponent("test/fixtures/\(name)")
    try? FileManager.default.removeItem(at: output)
    let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)!
    exporter.outputURL = output
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    let done = DispatchSemaphore(value: 0)
    exporter.exportAsynchronously { done.signal() }
    done.wait()
    guard exporter.status == .completed else { fatalError("Export failed: \(String(describing: exporter.error))") }
    print(output.lastPathComponent)
}
