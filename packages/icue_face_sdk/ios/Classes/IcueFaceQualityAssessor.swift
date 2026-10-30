import Foundation
import UIKit
import MLKitFaceDetection

public enum IcueFaceQualityStatus: String {
    case ok = "OK"
    case tooSmall = "TOO_SMALL"
    case blurry = "BLURRY"
    case extremePose = "EXTREME_POSE"
}

public struct IcueFaceQualityResult {
    public let status: IcueFaceQualityStatus
    public let blurScore: Float
    public let isValid: Bool
}

public class IcueFaceQualityAssessor {
    public static let DEFAULT_MIN_FACE_SIZE: CGFloat = 24.0
    public static let DEFAULT_BLUR_THRESHOLD: Float = 80.0
    public static let MAX_YAW_ANGLE: Float = 35.0
    public static let MAX_PITCH_ANGLE: Float = 25.0

    /**
     * Assesses the quality of a face crop using bounding box size, head pose angles,
     * and grayscale Laplacian variance blur estimation with resolution-adaptive thresholding.
     */
    public static func assessQuality(
        image: UIImage,
        face: Face,
        minFaceSize: CGFloat = DEFAULT_MIN_FACE_SIZE,
        minBlurThreshold: Float = DEFAULT_BLUR_THRESHOLD
    ) -> IcueFaceQualityResult {
        let frame = face.frame
        if frame.width < minFaceSize || frame.height < minFaceSize {
            return IcueFaceQualityResult(status: .tooSmall, blurScore: 0.0, isValid: false)
        }

        if face.hasHeadEulerAngleY && abs(face.headEulerAngleY) > MAX_YAW_ANGLE {
            return IcueFaceQualityResult(status: .extremePose, blurScore: 0.0, isValid: false)
        }

        if face.hasHeadEulerAngleX && abs(face.headEulerAngleX) > MAX_PITCH_ANGLE {
            return IcueFaceQualityResult(status: .extremePose, blurScore: 0.0, isValid: false)
        }

        let blurScore = calculateLaplacianVariance(image: image)
        let faceWidth = Float(frame.width)
        let adaptiveScale = max(0.25, min(1.0, faceWidth / 112.0))
        let effectiveBlurThreshold = minBlurThreshold * adaptiveScale

        if blurScore < effectiveBlurThreshold {
            return IcueFaceQualityResult(status: .blurry, blurScore: blurScore, isValid: false)
        }

        return IcueFaceQualityResult(status: .ok, blurScore: blurScore, isValid: true)
    }

    /**
     * Calculates variance of 3x3 Laplacian operator on grayscale pixel buffer.
     */
    public static func calculateLaplacianVariance(image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.0 }
        let width = cgImage.width
        let height = cgImage.height
        if width < 3 || height < 3 { return 0.0 }

        var rawBytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.0 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Convert to grayscale
        var gray = [Float](repeating: 0.0, count: width * height)
        for i in 0..<(width * height) {
            let r = Float(rawBytes[i * 4])
            let g = Float(rawBytes[i * 4 + 1])
            let b = Float(rawBytes[i * 4 + 2])
            gray[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        var sum: Double = 0.0
        var sqSum: Double = 0.0
        var count: Int = 0

        for y in 1..<(height - 1) {
            let rowOffset = y * width
            let prevRowOffset = (y - 1) * width
            let nextRowOffset = (y + 1) * width

            for x in 1..<(width - 1) {
                let center = gray[rowOffset + x]
                let up = gray[prevRowOffset + x]
                let down = gray[nextRowOffset + x]
                let left = gray[rowOffset + x - 1]
                let right = gray[rowOffset + x + 1]

                let laplacian = Double(up + down + left + right - 4.0 * center)
                sum += laplacian
                sqSum += laplacian * laplacian
                count += 1
            }
        }

        if count == 0 { return 0.0 }

        let mean = sum / Double(count)
        let variance = (sqSum / Double(count)) - (mean * mean)
        return Float(max(0.0, variance))
    }
}
