import Foundation
import UIKit
import CoreGraphics
import CoreImage

internal class IcueYuvConverter {

    static func imageFromPath(_ path: String, mirrorHorizontally: Bool = false) -> UIImage? {
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return fixOrientation(image: image, mirrorHorizontally: mirrorHorizontally)
    }

    static func imageFromNv21(
        bytes: Data,
        width: Int,
        height: Int,
        rotationDegrees: Int = 0,
        mirrorHorizontally: Bool = false
    ) -> UIImage? {
        let frameSize = width * height
        guard bytes.count >= frameSize else { return nil }

        let yData = bytes.subdata(in: 0..<frameSize)
        let uvData = bytes.count >= frameSize + (frameSize / 2) ? bytes.subdata(in: frameSize..<(frameSize + frameSize / 2)) : nil

        var rgbBytes = [UInt8](repeating: 0, count: width * height * 4)

        yData.withUnsafeBytes { yRawPointer in
            guard let yPointer = yRawPointer.bindMemory(to: UInt8.self).baseAddress else { return }

            if let uvData = uvData {
                uvData.withUnsafeBytes { uvRawPointer in
                    guard let uvPointer = uvRawPointer.bindMemory(to: UInt8.self).baseAddress else { return }

                    for j in 0..<height {
                        let pY = j * width
                        let pUV = (j / 2) * width

                        for i in 0..<width {
                            let yVal = Int(yPointer[pY + i])
                            let uvIdx = pUV + (i & ~1)
                            let vVal = Int(uvPointer[uvIdx]) - 128
                            let uVal = Int(uvPointer[uvIdx + 1]) - 128

                            let r = min(max(yVal + Int(1.370705 * Double(vVal)), 0), 255)
                            let g = min(max(yVal - Int(0.337633 * Double(uVal) + 0.698001 * Double(vVal)), 0), 255)
                            let b = min(max(yVal + Int(1.732446 * Double(uVal)), 0), 255)

                            let rgbIdx = (pY + i) * 4
                            rgbBytes[rgbIdx] = UInt8(r)
                            rgbBytes[rgbIdx + 1] = UInt8(g)
                            rgbBytes[rgbIdx + 2] = UInt8(b)
                            rgbBytes[rgbIdx + 3] = 255
                        }
                    }
                }
            } else {
                for i in 0..<(width * height) {
                    let yVal = yPointer[i]
                    let rgbIdx = i * 4
                    rgbBytes[rgbIdx] = yVal
                    rgbBytes[rgbIdx + 1] = yVal
                    rgbBytes[rgbIdx + 2] = yVal
                    rgbBytes[rgbIdx + 3] = 255
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(rgbBytes) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        let rawImage = UIImage(cgImage: cgImage)
        return applyRotationAndMirroring(image: rawImage, rotationDegrees: rotationDegrees, mirrorHorizontally: mirrorHorizontally)
    }

    static func imageFromYuv420(
        yBytes: Data,
        uBytes: Data,
        vBytes: Data,
        width: Int,
        height: Int,
        yRowStride: Int,
        uRowStride: Int,
        vRowStride: Int,
        uPixelStride: Int,
        vPixelStride: Int,
        rotationDegrees: Int,
        mirrorHorizontally: Bool
    ) -> UIImage? {
        var rgbBytes = [UInt8](repeating: 0, count: width * height * 4)

        yBytes.withUnsafeBytes { yRaw in
            uBytes.withUnsafeBytes { uRaw in
                vBytes.withUnsafeBytes { vRaw in
                    guard let yPtr = yRaw.bindMemory(to: UInt8.self).baseAddress,
                          let uPtr = uRaw.bindMemory(to: UInt8.self).baseAddress,
                          let vPtr = vRaw.bindMemory(to: UInt8.self).baseAddress else { return }

                    for row in 0..<height {
                        let yRowStart = row * yRowStride
                        let uRowStart = (row / 2) * uRowStride
                        let vRowStart = (row / 2) * vRowStride

                        for col in 0..<width {
                            let yVal = Int(yPtr[yRowStart + col])
                            let uVal = Int(uPtr[uRowStart + (col / 2) * uPixelStride]) - 128
                            let vVal = Int(vPtr[vRowStart + (col / 2) * vPixelStride]) - 128

                            let r = min(max(yVal + Int(1.370705 * Double(vVal)), 0), 255)
                            let g = min(max(yVal - Int(0.337633 * Double(uVal) + 0.698001 * Double(vVal)), 0), 255)
                            let b = min(max(yVal + Int(1.732446 * Double(uVal)), 0), 255)

                            let outIdx = (row * width + col) * 4
                            rgbBytes[outIdx] = UInt8(r)
                            rgbBytes[outIdx + 1] = UInt8(g)
                            rgbBytes[outIdx + 2] = UInt8(b)
                            rgbBytes[outIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(rgbBytes) as CFData),
              let cgImage = CGImage(
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              ) else {
            return nil
        }

        let rawImage = UIImage(cgImage: cgImage)
        return applyRotationAndMirroring(image: rawImage, rotationDegrees: rotationDegrees, mirrorHorizontally: mirrorHorizontally)
    }

    private static func fixOrientation(image: UIImage, mirrorHorizontally: Bool) -> UIImage {
        guard mirrorHorizontally || image.imageOrientation != .up else { return image }
        return applyRotationAndMirroring(image: image, rotationDegrees: 0, mirrorHorizontally: mirrorHorizontally)
    }

    private static func applyRotationAndMirroring(
        image: UIImage,
        rotationDegrees: Int,
        mirrorHorizontally: Bool
    ) -> UIImage {
        guard rotationDegrees != 0 || mirrorHorizontally || image.imageOrientation != .up else { return image }

        var radians = CGFloat(rotationDegrees) * .pi / 180.0
        if image.imageOrientation == .right {
            radians += .pi / 2
        } else if image.imageOrientation == .left {
            radians -= .pi / 2
        } else if image.imageOrientation == .down {
            radians += .pi
        }

        var newSize = image.size
        if rotationDegrees == 90 || rotationDegrees == 270 {
            newSize = CGSize(width: image.size.height, height: image.size.width)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }

        context.translateBy(x: newSize.width / 2.0, y: newSize.height / 2.0)
        context.rotate(by: radians)
        if mirrorHorizontally {
            context.scaleBy(x: -1.0, y: 1.0)
        }

        image.draw(in: CGRect(x: -image.size.width / 2.0, y: -image.size.height / 2.0, width: image.size.width, height: image.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage ?? image
    }
}
