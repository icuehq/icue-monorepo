import Foundation
import UIKit
import MLKitFaceDetection
import MLKitVision
import TensorFlowLite

public struct IcueFaceSdkConfig {
    public let accelerator: String // "cpu", "gpu", "npu"
    public let numThreads: Int

    public init(accelerator: String = "cpu", numThreads: Int = 4) {
        self.accelerator = accelerator
        self.numThreads = max(1, min(numThreads, 8))
    }
}

public struct IcueBoundingBox {
    public let left: Float
    public let top: Float
    public let right: Float
    public let bottom: Float
    public let trackingId: Int?

    public func toMap() -> [String: Any?] {
        return [
            "left": Double(left),
            "top": Double(top),
            "right": Double(right),
            "bottom": Double(bottom),
            "trackingId": trackingId
        ]
    }
}

public struct IcueFaceProfile {
    public let personId: String
    public let embedding: [Float]

    public init?(personId: String, embedding: [Float]) {
        guard !personId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              embedding.count == 192,
              embedding.allSatisfy({ $0.isFinite }) else {
            return nil
        }
        self.personId = personId
        self.embedding = IcueFaceEngine.l2Normalize(embedding)
    }
}

public struct IcueRecognitionResult {
    public let personId: String?
    public let score: Float
    public let matched: Bool
    public let boundingBox: IcueBoundingBox

    public func toMap() -> [String: Any?] {
        return [
            "personId": personId,
            "score": Double(score),
            "matched": matched,
            "boundingBox": boundingBox.toMap()
        ]
    }
}

internal class IcueFaceEngine {
    static let SDK_VERSION = "0.2.0"
    static let MODEL_ASSET = "mobilefacenet.tflite"
    static let INPUT_SIZE = 112
    static let EMBEDDING_SIZE = 192

    static let AMBIGUITY_MARGIN: Float = 0.05
    static let CANONICAL_LEFT_EYE_X: CGFloat = 38.2946
    static let CANONICAL_LEFT_EYE_Y: CGFloat = 51.6963
    static let CANONICAL_RIGHT_EYE_X: CGFloat = 73.5318
    static let CANONICAL_RIGHT_EYE_Y: CGFloat = 51.5014
    static let CANONICAL_NOSE_X: CGFloat = 56.0252
    static let CANONICAL_NOSE_Y: CGFloat = 71.7366
    static let CANONICAL_LEFT_MOUTH_X: CGFloat = 41.5493
    static let CANONICAL_LEFT_MOUTH_Y: CGFloat = 92.3655
    static let CANONICAL_RIGHT_MOUTH_X: CGFloat = 70.7299
    static let CANONICAL_RIGHT_MOUTH_Y: CGFloat = 92.2041

    private let queue = DispatchQueue(label: "school.icue.face.engine", qos: .userInitiated)
    private var interpreter: Interpreter?
    private var detector: FaceDetector?
    private var isClosed = false

    func initialize(config: IcueFaceSdkConfig, bundle: Bundle = Bundle(for: IcueFaceEngine.self)) throws {
        try queue.sync {
            if interpreter != nil { return }

            guard let modelPath = bundle.path(forResource: "mobilefacenet", ofType: "tflite", inDirectory: "Assets") ??
                                  bundle.path(forResource: "mobilefacenet", ofType: "tflite") ??
                                  Bundle.main.path(forResource: "mobilefacenet", ofType: "tflite") else {
                throw IcueFaceException(code: "MODEL_INVALID", message: "Unable to locate mobilefacenet.tflite asset")
            }

            var options = Interpreter.Options()
            options.threadCount = config.numThreads

            do {
                let inter = try Interpreter(modelPath: modelPath, options: options)
                try inter.allocateTensors()
                self.interpreter = inter
            } catch {
                throw IcueFaceException(code: "INIT_FAILED", message: "Failed to initialize LiteRT interpreter: \(error.localizedDescription)")
            }

            let detectorOptions = FaceDetectorOptions()
            detectorOptions.performanceMode = .accurate
            detectorOptions.landmarkMode = .all
            detectorOptions.classificationMode = .none
            detectorOptions.contourMode = .none
            detectorOptions.isTrackingEnabled = true

            self.detector = FaceDetector.faceDetector(options: detectorOptions)
            self.isClosed = false
        }
    }

    func getInfo() -> [String: Any] {
        return [
            "sdkVersion": IcueFaceEngine.SDK_VERSION,
            "modelName": IcueFaceEngine.MODEL_ASSET,
            "embeddingSize": IcueFaceEngine.EMBEDDING_SIZE
        ]
    }

    func extractEmbedding(image original: UIImage) throws -> [Float] {
        let image = IcueFaceEngine.upright(original)
        return try queue.sync {
            try checkState()
            let faces = try detectFacesInternal(image: image, requireLandmarks: true)
            if faces.isEmpty {
                throw IcueFaceException(code: "NO_FACE", message: "No face detected")
            }
            if faces.count > 1 {
                throw IcueFaceException(code: "MULTIPLE_FACES", message: "Multiple faces detected. Expected exactly one.")
            }

            let face = faces[0]
            if (face.hasHeadEulerAngleY && abs(face.headEulerAngleY) > 35) ||
                (face.hasHeadEulerAngleX && abs(face.headEulerAngleX) > 25) {
                throw IcueFaceException(code: "POOR_FACE", message: "Face is turned away. Use a front-facing photo.")
            }
            guard let aligned = alignFace(image: image, face: face) else {
                throw IcueFaceException(code: "POOR_FACE", message: "Eyes not clearly visible. Use a clearer front-facing photo.")
            }
            return try runInference(faceImage: aligned)
        }
    }

    func recognize(
        image: UIImage,
        profiles: [IcueFaceProfile],
        mode: String,
        maxFaces: Int,
        threshold: Float
    ) throws -> [IcueRecognitionResult] {
        let image = IcueFaceEngine.upright(image)
        return try queue.sync {
            try checkState()
            try requireThrow(maxFaces > 0, "maxFaces must be greater than zero")
            try requireThrow(threshold.isFinite && threshold >= -1.0 && threshold <= 1.0, "threshold must be finite between -1 and 1")

            let allFaces = try detectFacesInternal(image: image, requireLandmarks: true)
            if mode == "single" && allFaces.count != 1 {
                let code = allFaces.isEmpty ? "NO_FACE" : "MULTIPLE_FACES"
                throw IcueFaceException(code: code, message: "Expected exactly one face. Found \(allFaces.count)")
            }

            // Faces without eyes, too small, turned away or blurred are not recognized.
            var processFaces: [Face] = []
            var alignedFaces: [UIImage] = []
            for face in allFaces where face.frame.width >= 30 && face.frame.height >= 30 {
                guard processFaces.count < maxFaces, let aligned = alignFace(image: image, face: face) else { continue }
                if IcueFaceQualityAssessor.assessQuality(image: aligned, face: face).isValid {
                    processFaces.append(face)
                    alignedFaces.append(aligned)
                }
            }
            if processFaces.isEmpty { return [] }

            if profiles.isEmpty {
                return processFaces.map { face in
                    IcueRecognitionResult(personId: nil, score: -1.0, matched: false, boundingBox: faceToBoundingBox(face))
                }
            }

            let profileEmbeddings = profiles.map { IcueFaceEngine.l2Normalize($0.embedding) }
            var scores: [[Float]] = []
            for aligned in alignedFaces {
                let liveEmbedding = try runInference(faceImage: aligned)
                scores.append(profileEmbeddings.map { IcueFaceEngine.cosineSimilarity(liveEmbedding, $0) })
            }
            let assignment = IcueFaceEngine.assign(
                scores: scores,
                threshold: threshold,
                margin: IcueFaceEngine.AMBIGUITY_MARGIN
            )

            return processFaces.indices.map { fIdx in
                let profileIdx = assignment[fIdx]
                let matched = profileIdx >= 0
                return IcueRecognitionResult(
                    personId: matched ? profiles[profileIdx].personId : nil,
                    score: matched ? scores[fIdx][profileIdx] : (scores[fIdx].max() ?? -1.0),
                    matched: matched,
                    boundingBox: faceToBoundingBox(processFaces[fIdx])
                )
            }
        }
    }

    /// Same rule as Android's `FaceAssignment`: a face gets only its own best profile, and only
    /// when it clears [threshold], beats its runner-up by [margin], and no face scores it higher.
    static func assign(scores: [[Float]], threshold: Float, margin: Float) -> [Int] {
        var assigned = [Int](repeating: -1, count: scores.count)
        var owner: [Int: Int] = [:]
        for (face, row) in scores.enumerated() {
            var best = -1
            var bestScore: Float = -1
            var runnerUp: Float = -1
            for (profile, score) in row.enumerated() {
                if score > bestScore {
                    runnerUp = bestScore
                    bestScore = score
                    best = profile
                } else if score > runnerUp {
                    runnerUp = score
                }
            }
            if best < 0 || bestScore < threshold || bestScore - runnerUp < margin { continue }
            if let rival = owner[best] {
                if scores[rival][best] >= bestScore { continue }
                assigned[rival] = -1
            }
            owner[best] = face
            assigned[face] = best
        }
        return assigned
    }

    /// Redraws [image] with `.up` orientation so ML Kit landmarks and `cgImage` pixels agree.
    static func upright(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    func detectFaces(image: UIImage) throws -> [IcueBoundingBox] {
        return try queue.sync {
            try checkState()
            let faces = try detectFacesInternal(image: image, requireLandmarks: false)
            return faces.map { faceToBoundingBox($0) }
        }
    }

    func compareEmbeddings(first: [Float], second: [Float]) -> Float {
        return IcueFaceEngine.cosineSimilarity(first, second)
    }

    func close() {
        queue.sync {
            isClosed = true
            interpreter = nil
            detector = nil
        }
    }

    private func checkState() throws {
        if isClosed {
            throw IcueFaceException(code: "CLOSED", message: "SDK is closed")
        }
        if interpreter == nil || detector == nil {
            throw IcueFaceException(code: "NOT_INITIALIZED", message: "SDK is not initialized")
        }
    }

    private func detectFacesInternal(image: UIImage, requireLandmarks: Bool) throws -> [Face] {
        guard let detector = self.detector else {
            throw IcueFaceException(code: "NOT_INITIALIZED", message: "Face detector is not initialized")
        }

        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation

        var detectedFaces: [Face]? = nil
        var detectError: Error? = nil

        let semaphore = DispatchSemaphore(value: 0)
        detector.process(visionImage) { faces, error in
            detectedFaces = faces
            detectError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = detectError {
            throw IcueFaceException(code: "DETECTION_FAILED", message: "ML Kit face detection failed: \(error.localizedDescription)")
        }

        return detectedFaces ?? []
    }

    /// The 112x112 eye-aligned face, or nil when ML Kit found no eyes.
    private func alignFace(image: UIImage, face: Face) -> UIImage? {
        guard let first = face.landmark(ofType: .leftEye)?.position,
              let second = face.landmark(ofType: .rightEye)?.position else { return nil }
        // ML Kit's leftEye is the subject's left, on the image's right; order by x for the template.
        let a = CGPoint(x: first.x, y: first.y)
        let b = CGPoint(x: second.x, y: second.y)
        return a.x <= b.x
            ? alignToCanonicalEyes(image: image, leftEye: a, rightEye: b)
            : alignToCanonicalEyes(image: image, leftEye: b, rightEye: a)
    }

    private func alignToCanonicalEyes(image: UIImage, leftEye: CGPoint, rightEye: CGPoint) -> UIImage? {
        let targetLeft = CGPoint(x: IcueFaceEngine.CANONICAL_LEFT_EYE_X, y: IcueFaceEngine.CANONICAL_LEFT_EYE_Y)
        let targetRight = CGPoint(x: IcueFaceEngine.CANONICAL_RIGHT_EYE_X, y: IcueFaceEngine.CANONICAL_RIGHT_EYE_Y)

        let dxSrc = rightEye.x - leftEye.x
        let dySrc = rightEye.y - leftEye.y
        let srcDist = sqrt(dxSrc * dxSrc + dySrc * dySrc)
        guard srcDist > 0 else { return nil }

        let dxDst = targetRight.x - targetLeft.x
        let dyDst = targetRight.y - targetLeft.y
        let dstDist = sqrt(dxDst * dxDst + dyDst * dyDst)

        let scale = dstDist / srcDist
        let angle = atan2(dyDst, dxDst) - atan2(dySrc, dxSrc)

        let targetSize = CGSize(width: IcueFaceEngine.INPUT_SIZE, height: IcueFaceEngine.INPUT_SIZE)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext(), let cgImage = image.cgImage else {
            UIGraphicsEndImageContext()
            return nil
        }

        context.translateBy(x: targetLeft.x, y: targetLeft.y)
        context.rotate(by: angle)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -leftEye.x, y: -leftEye.y)

        // Draw CGImage right side up in CGContext coordinates
        context.translateBy(x: 0, y: image.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(cgImage, in: CGRect(origin: .zero, size: image.size))

        let aligned = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return aligned
    }

    private func runInference(faceImage: UIImage) throws -> [Float] {
        guard let inter = self.interpreter else {
            throw IcueFaceException(code: "NOT_INITIALIZED", message: "Interpreter is nil")
        }

        let resized = resizeImage(faceImage, targetSize: CGSize(width: IcueFaceEngine.INPUT_SIZE, height: IcueFaceEngine.INPUT_SIZE))
        guard let pixelData = getNormalizedRGBData(from: resized) else {
            throw IcueFaceException(code: "INFERENCE_FAILED", message: "Failed to extract RGB pixels from face bitmap")
        }

        do {
            try inter.copy(pixelData, toInputAt: 0)
            try inter.invoke()
            let outputTensor = try inter.output(at: 0)
            let rawData = outputTensor.data
            let floatArray = rawData.withUnsafeBytes { pointer in
                Array(UnsafeBufferPointer(start: pointer.bindMemory(to: Float.self).baseAddress, count: IcueFaceEngine.EMBEDDING_SIZE))
            }
            return IcueFaceEngine.l2Normalize(floatArray)
        } catch {
            throw IcueFaceException(code: "INFERENCE_FAILED", message: "LiteRT inference error: \(error.localizedDescription)")
        }
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        if image.size == targetSize { return image }
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? image
    }

    private func getNormalizedRGBData(from image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let width = IcueFaceEngine.INPUT_SIZE
        let height = IcueFaceEngine.INPUT_SIZE

        var rawBytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawBytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var floatBuffer = [Float](repeating: 0, count: width * height * 3)
        var floatIdx = 0

        for i in 0..<(width * height) {
            let r = Int(rawBytes[i * 4])
            let g = Int(rawBytes[i * 4 + 1])
            let b = Int(rawBytes[i * 4 + 2])

            floatBuffer[floatIdx] = (Float(r) - 127.5) / 128.0
            floatBuffer[floatIdx + 1] = (Float(g) - 127.5) / 128.0
            floatBuffer[floatIdx + 2] = (Float(b) - 127.5) / 128.0
            floatIdx += 3
        }

        return Data(bytes: floatBuffer, count: floatBuffer.count * MemoryLayout<Float>.size)
    }

    static func l2Normalize(_ vector: [Float]) -> [Float] {
        var normSquare: Float = 0.0
        for val in vector {
            normSquare += val * val
        }
        let norm = sqrt(max(normSquare, 1e-10))
        return vector.map { $0 / norm }
    }

    static func cosineSimilarity(_ vec1: [Float], _ vec2: [Float]) -> Float {
        guard vec1.count == vec2.count else { return 0.0 }
        var dot: Float = 0.0
        for i in 0..<vec1.count {
            dot += vec1[i] * vec2[i]
        }
        return dot
    }

    private func faceToBoundingBox(_ face: Face) -> IcueBoundingBox {
        return IcueBoundingBox(
            left: Float(face.frame.origin.x),
            top: Float(face.frame.origin.y),
            right: Float(face.frame.origin.x + face.frame.size.width),
            bottom: Float(face.frame.origin.y + face.frame.size.height),
            trackingId: face.hasTrackingID ? face.trackingID : nil
        )
    }
}

public struct IcueFaceException: Error {
    public let code: String
    public let message: String
}

private func requireThrow(_ condition: Bool, _ message: String, code: String = "INVALID_ARGUMENT") throws {
    if !condition {
        throw IcueFaceException(code: code, message: message)
    }
}
