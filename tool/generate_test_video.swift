import AVFoundation
import Foundation

// Generates test/fixtures/test_video.mp4: 12 s, 160x90 H.264 at 10 fps, with a
// silent AAC track. The audio track matters: VLC on iOS and Android stalls at
// 0.25 s when it plays a video without audio over HTTP, so remote source
// tests need it. Usage: swift tool/generate_test_video.swift <output.mp4>
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: output)
let width = 160, height = 90, fps: Int32 = 10, frames = 120
let sampleRate = 44100, audioChunk = 1024
let audioFrames = sampleRate * frames / Int(fps)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height
])
let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
    sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: sampleRate, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32000
])
writer.add(input)
writer.add(audio)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

var pcmFormat = AudioStreamBasicDescription(
    mSampleRate: Float64(sampleRate), mFormatID: kAudioFormatLinearPCM,
    mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
    mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
    mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
var audioFormat: CMAudioFormatDescription?
CMAudioFormatDescriptionCreate(allocator: nil, asbd: &pcmFormat, layoutSize: 0, layout: nil,
    magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormat)

// Silence: `count` zeroed 16-bit mono samples starting at sample `start`.
func silence(start: Int, count: Int) -> CMSampleBuffer {
    let bytes = count * 2
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: bytes,
        blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: bytes,
        flags: 0, blockBufferOut: &block)
    guard let block, let audioFormat else { fatalError("Could not allocate silent audio") }
    CMBlockBufferFillDataBytes(with: 0, blockBuffer: block, offsetIntoDestination: 0, dataLength: bytes)
    var sample: CMSampleBuffer?
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block,
        formatDescription: audioFormat, sampleCount: count,
        presentationTimeStamp: CMTime(value: Int64(start), timescale: Int32(sampleRate)),
        packetDescriptions: nil, sampleBufferOut: &sample)
    guard let sample else { fatalError("Could not create audio sample at \(start)") }
    return sample
}

func videoFrame(_ frame: Int) -> CVPixelBuffer {
    guard let pool = adapter.pixelBufferPool else { fatalError("Writer has no pixel buffer pool") }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
    guard let pixelBuffer = buffer else { fatalError("Could not allocate frame \(frame)") }
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { fatalError("Frame \(frame) has no pixels") }
    let data = base.assumingMemoryBound(to: UInt8.self)
    let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
    for y in 0..<height {
        for x in 0..<width {
            let offset = y * stride + x * 4
            data[offset] = 255
            data[offset + 1] = UInt8(x * 255 / width)
            data[offset + 2] = UInt8(frame * 255 / frames)
            data[offset + 3] = UInt8(y * 255 / height)
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    return pixelBuffer
}

// Both inputs are fed as they become ready so the writer can interleave them.
let group = DispatchGroup()
var frame = 0
group.enter()
input.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
    while input.isReadyForMoreMediaData && frame < frames {
        guard adapter.append(videoFrame(frame), withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
            fatalError("Could not encode frame: \(String(describing: writer.error))")
        }
        frame += 1
    }
    if frame == frames { input.markAsFinished(); frame += 1; group.leave() }
}
var sample = 0
group.enter()
audio.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
    while audio.isReadyForMoreMediaData && sample < audioFrames {
        let count = min(audioChunk, audioFrames - sample)
        guard audio.append(silence(start: sample, count: count)) else {
            fatalError("Could not encode audio: \(String(describing: writer.error))")
        }
        sample += count
    }
    if sample == audioFrames { audio.markAsFinished(); sample += 1; group.leave() }
}
group.notify(queue: .main) {
    writer.finishWriting {
        if writer.status != .completed { fatalError("Encoding failed: \(String(describing: writer.error))") }
        print(output.path)
        exit(0)
    }
}
dispatchMain()
