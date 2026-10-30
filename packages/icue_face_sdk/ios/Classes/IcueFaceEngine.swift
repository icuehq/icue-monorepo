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

    public toMap() -> [String: Any?] {
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

    public toMap() -> [String: Any?] {
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

    func extractEmbedding(image: UIImage) throws -> [Float] {
        return try queue.sync {
            try checkState()
            let faces = try detectFacesInternal(image: image, requireLandmarks: true)
            if faces.isEmpty {
                throw IcueFaceException(code: "NO_FACE", message: "No face detected")
            }
            if faces.count > 1 {
                throw IcueFaceException(code: "MULTIPLE_FACES", message: "Multiple faces detected. Expected exactly one.")
            }

            let cropped = cropAndAlignFace(image: image, face: faces[0])
            return try runInference(faceImage: cropped)
        }
    }

    func recognize(
        image: UIImage,
        profiles: [IcueFaceProfile],
        mode: String,
        maxFaces: Int,
        threshold: Float
    ) throws -> [IcueRecognitionResult] {
        return try queue.sync {
            try checkState()
            try requireThrow(maxFaces > 0, "maxFaces must be greater than zero")
            try requireThrow(threshold.isFinite && threshold >= -1.0 && threshold <= 1.0, "threshold must be finite between -1 and 1")

            let allFaces = try detectFacesInternal(image: image, requireLandmarks: true)
            let validFaces = allFaces.filter { face in
                let cropped = cropAndAlignFace(image: image, face: face)
                let quality = IcueFaceQualityAssessor.assessQuality(image: cropped, face: face)
                return quality.isValid
            }
            let faces = validFaces.isEmpty ? allFaces : validFaces

            if mode == "single" && allFaces.count != 1 {
                let code = allFaces.isEmpty ? "NO_FACE" : "MULTIPLE_FACES"
                throw IcueFaceException(code: code, message: "Expected exactly one face. Found \(allFaces.count)")
            }

            let processFaces = Array(faces.prefix(maxFaces))
            if processFaces.isEmpty { return [] }

            var liveEmbeddings: [[Float]] = []
            for face in processFaces {
                let cropped = cropAndAlignFace(image: image, face: face)
                let liveEmbedding = try runInference(faceImage: cropped)
                liveEmbeddings.append(liveEmbedding)
            }

            if profiles.isEmpty {
                return processFaces.map { face in
                    IcueRecognitionResult(personId: nil, score: -1.0, matched: false, boundingBox: faceToBoundingBox(face))
                }
            }

            struct CandidateMatch {
                let faceIdx: Int
                let profileIdx: Int
                let score: Float
            }

            var candidates: [CandidateMatch] = []
            for fIdx in 0..<processFaces.count {
                let liveEmb = liveEmbeddings[fIdx]
                for pIdx in 0..<profiles.count {
                    let score = IcueFaceEngine.cosineSimilarity(liveEmb, profiles[pIdx].embedding)
                    candidates.append(CandidateMatch(faceIdx: fIdx, profileIdx: pIdx, score: score))
                }
            }

            candidates.sort { $0.score > $1.score }

            var assignedFace = [Bool](repeating: false, count: processFaces.count)
            var assignedProfile = [Bool](repeating: false, count: profiles.count)
            var faceResults = [IcueRecognitionResult?](repeating: nil, count: processFaces.count)

            for candidate in candidates {
                if assignedFace[candidate.faceIdx] || assignedProfile[candidate.profileIdx] { continue }
                if candidate.score >= threshold {
                    assignedFace[candidate.faceIdx] = true
                    assignedProfile[candidate.profileIdx] = true
                    let matchedProfile = profiles[candidate.profileIdx]
                    faceResults[candidate.faceIdx] = IcueRecognitionResult(
                        personId: matchedProfile.personId,
                        score: candidate.score,
                        matched: true,
                        boundingBox: faceToBoundingBox(processFaces[candidate.faceIdx])
                    )
                }
            }

            for fIdx in 0..<processFaces.count {
                if faceResults[fIdx] == nil {
                    var bestScore: Float = -1.0
                    for pIdx in 0..<profiles.count {
                        let score = IcueFaceEngine.cosineSimilarity(liveEmbeddings[fIdx], profiles[pIdx].embedding)
                        if score > bestScore { bestScore = score }
                    }
                    faceResults[fIdx] = IcueRecognitionResult(
                        personId: nil,
                        score: bestScore,
                        matched: false,
                        boundingBox: faceToBoundingBox(processFaces[fIdx])
                    )
                }
            }

            return faceResults.compactMap { $0 }
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

    private func cropAndAlignFace(image: UIImage, face: Face) -> UIImage {
        if let leftEye = face.landmark(ofType: .leftEye)?.position,
           let rightEye = face.landmark(ofType: .rightEye)?.position {
            if let aligned = alignToCanonicalEyes(
                image: image,
                leftEye: CGPoint(x: leftEye.x, y: leftEye.y),
                rightEye: CGPoint(x: rightEye.x, y: rightEye.y)
            ) {
                return aligned
            }
        }
        return cropBoundingBoxFace(image: image, frame: face.frame)
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

    private func cropBoundingBoxFace(image: UIImage, frame: CGRect) -> UIImage {
        let marginX = frame.width * 0.15
        let marginY = frame.height * 0.15

        let cropRect = CGRect(
            x: max(0, frame.origin.x - marginX),
            y: max(0, frame.origin.y - marginY),
            width: min(image.size.width - frame.origin.x + marginX, frame.width + marginX * 2),
            height: min(image.size.height - frame.origin.y + marginY, frame.height + marginY * 2)
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage)
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
