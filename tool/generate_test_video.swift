import AVFoundation
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 160, height = 90, fps: Int32 = 10, frames = 120
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width, AVVideoHeightKey: height
])
let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
    sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
for frame in 0..<frames {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adapter.pixelBufferPool!, &buffer)
    let pixelBuffer = buffer!
    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    let data = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
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
    guard adapter.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps)) else {
        fatalError("Could not encode frame: \(String(describing: writer.error))")
    }
}
input.markAsFinished()
writer.finishWriting {
    if writer.status != .completed { fatalError("Encoding failed: \(String(describing: writer.error))") }
    print(output.path)
    exit(0)
}
dispatchMain()
