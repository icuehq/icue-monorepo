import Flutter
import UIKit

public class IcueFaceSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let CHANNEL_NAME = "icue_face_sdk"
    private static let TRACKING_CHANNEL_NAME = "icue_face_sdk/tracking"

    private let engine = IcueFaceEngine()
    private var trackingEventSink: FlutterEventSink?
    private var activeCameraController: IcueFaceCameraViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: registrar.messenger())
        let trackingChannel = FlutterEventChannel(name: TRACKING_CHANNEL_NAME, binaryMessenger: registrar.messenger())

        let instance = IcueFaceSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        trackingChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initialize(call, result: result)
        case "getInfo":
            getInfo(result: result)
        case "extractEmbedding":
            extractEmbedding(call, result: result)
        case "recognize":
            recognize(call, result: result)
        case "compareEmbeddings":
            compareEmbeddings(call, result: result)
        case "detectFaces":
            detectFaces(call, result: result)
        case "extractEmbeddingFromNv21":
            extractEmbeddingFromNv21(call, result: result)
        case "detectFacesInFrame":
            detectFacesInFrame(call, result: result)
        case "recognizeInFrame":
            recognizeInFrame(call, result: result)
        case "detectFacesInYuvFrame":
            detectFacesInYuvFrame(call, result: result)
        case "recognizeInYuvFrame":
            recognizeInYuvFrame(call, result: result)
        case "captureEmbeddingWithCamera":
            captureEmbeddingWithCamera(call, result: result)
        case "startFaceTracking":
            startFaceTracking(call, result: result)
        case "stopFaceTracking":
            stopFaceTracking(result: result)
        case "startLiveAttendance":
            startLiveAttendance(call, result: result)
        case "startMultiPhotoAttendance":
            startMultiPhotoAttendance(call, result: result)
        case "processAttendanceFromImages":
            processAttendanceFromImages(call, result: result)
        case "dispose":
            dispose(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.trackingEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.trackingEventSink = nil
        return nil
    }

    // MARK: - Method Channel Handlers

    private func initialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let accelerator = (args["accelerator"] as? String) ?? "cpu"
        let numThreads = (args["numThreads"] as? Int) ?? 4

        let config = IcueFaceSdkConfig(accelerator: accelerator, numThreads: numThreads)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.engine.initialize(config: config)
                DispatchQueue.main.async { result(nil) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "INIT_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func getInfo(result: @escaping FlutterResult) {
        result(engine.getInfo())
    }

    private func extractEmbedding(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath required", details: nil))
        }
        let mirror = (args["isFrontCamera"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromPath(imagePath, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "IMAGE_LOAD_FAILED", message: "Failed to load image at \(imagePath)", details: nil)) }
            }

            do {
                let embedding = try self.engine.extractEmbedding(image: image)
                let floatData = FlutterStandardTypedData(float32: Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size))
                DispatchQueue.main.async { result(floatData) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func recognize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath required", details: nil))
        }
        let profiles = parseProfiles(args["profiles"])
        let mode = (args["mode"] as? String) ?? "single"
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)
        let mirror = (args["isFrontCamera"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromPath(imagePath, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "IMAGE_LOAD_FAILED", message: "Failed to load image at \(imagePath)", details: nil)) }
            }

            do {
                let recognitions = try self.engine.recognize(image: image, profiles: profiles, mode: mode, maxFaces: maxFaces, threshold: threshold)
                let responseMap = recognitions.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "RECOGNITION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func compareEmbeddings(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let first = parseFloatArray(args["first"])
        let second = parseFloatArray(args["second"])

        let score = engine.compareEmbeddings(first: first, second: second)
        result(Double(score))
    }

    private func detectFaces(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePath required", details: nil))
        }
        let mirror = (args["isFrontCamera"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromPath(imagePath, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "IMAGE_LOAD_FAILED", message: "Failed to load image at \(imagePath)", details: nil)) }
            }

            do {
                let boxes = try self.engine.detectFaces(image: image)
                let responseMap = boxes.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "DETECTION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func extractEmbeddingFromNv21(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytesData = (args["nv21Bytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "nv21Bytes, width, height required", details: nil))
        }
        let rotation = (args["rotation"] as? Int) ?? 0
        let mirror = (args["isFrontCamera"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromNv21(bytes: bytesData, width: width, height: height, rotationDegrees: rotation, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "FRAME_CONVERSION_FAILED", message: "NV21 conversion failed", details: nil)) }
            }

            do {
                let embedding = try self.engine.extractEmbedding(image: image)
                let floatData = FlutterStandardTypedData(float32: Data(bytes: embedding, count: embedding.count * MemoryLayout<Float>.size))
                DispatchQueue.main.async { result(floatData) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "EXTRACTION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func detectFacesInFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytesData = (args["nv21Bytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "nv21Bytes, width, height required", details: nil))
        }
        let rotation = (args["rotation"] as? Int) ?? 0
        let mirror = (args["isFrontCamera"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromNv21(bytes: bytesData, width: width, height: height, rotationDegrees: rotation, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "FRAME_CONVERSION_FAILED", message: "NV21 conversion failed", details: nil)) }
            }

            do {
                let boxes = try self.engine.detectFaces(image: image)
                let responseMap = boxes.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "DETECTION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func recognizeInFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytesData = (args["nv21Bytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "nv21Bytes, width, height required", details: nil))
        }
        let rotation = (args["rotation"] as? Int) ?? 0
        let mirror = (args["isFrontCamera"] as? Bool) ?? false
        let profiles = parseProfiles(args["profiles"])
        let mode = (args["mode"] as? String) ?? "single"
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromNv21(bytes: bytesData, width: width, height: height, rotationDegrees: rotation, mirrorHorizontally: mirror) else {
                return DispatchQueue.main.async { result(FlutterError(code: "FRAME_CONVERSION_FAILED", message: "NV21 conversion failed", details: nil)) }
            }

            do {
                let recognitions = try self.engine.recognize(image: image, profiles: profiles, mode: mode, maxFaces: maxFaces, threshold: threshold)
                let responseMap = recognitions.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "RECOGNITION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func detectFacesInYuvFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let yData = (args["yBytes"] as? FlutterStandardTypedData)?.data,
              let uData = (args["uBytes"] as? FlutterStandardTypedData)?.data,
              let vData = (args["vBytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let yRowStride = args["yRowStride"] as? Int,
              let uRowStride = args["uRowStride"] as? Int,
              let vRowStride = args["vRowStride"] as? Int,
              let uPixelStride = args["uPixelStride"] as? Int,
              let vPixelStride = args["vPixelStride"] as? Int else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "YUV frame parameters required", details: nil))
        }
        let rotation = (args["rotationDegrees"] as? Int) ?? 0
        let mirror = (args["mirrorHorizontally"] as? Bool) ?? false

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromYuv420(
                yBytes: yData, uBytes: uData, vBytes: vData,
                width: width, height: height,
                yRowStride: yRowStride, uRowStride: uRowStride, vRowStride: vRowStride,
                uPixelStride: uPixelStride, vPixelStride: vPixelStride,
                rotationDegrees: rotation, mirrorHorizontally: mirror
            ) else {
                return DispatchQueue.main.async { result(FlutterError(code: "FRAME_CONVERSION_FAILED", message: "YUV420 conversion failed", details: nil)) }
            }

            do {
                let boxes = try self.engine.detectFaces(image: image)
                let responseMap = boxes.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "DETECTION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func recognizeInYuvFrame(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let yData = (args["yBytes"] as? FlutterStandardTypedData)?.data,
              let uData = (args["uBytes"] as? FlutterStandardTypedData)?.data,
              let vData = (args["vBytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let yRowStride = args["yRowStride"] as? Int,
              let uRowStride = args["uRowStride"] as? Int,
              let vRowStride = args["vRowStride"] as? Int,
              let uPixelStride = args["uPixelStride"] as? Int,
              let vPixelStride = args["vPixelStride"] as? Int else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "YUV frame parameters required", details: nil))
        }
        let rotation = (args["rotationDegrees"] as? Int) ?? 0
        let mirror = (args["mirrorHorizontally"] as? Bool) ?? false
        let profiles = parseProfiles(args["profiles"])
        let mode = (args["mode"] as? String) ?? "single"
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)

        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = IcueYuvConverter.imageFromYuv420(
                yBytes: yData, uBytes: uData, vBytes: vData,
                width: width, height: height,
                yRowStride: yRowStride, uRowStride: uRowStride, vRowStride: vRowStride,
                uPixelStride: uPixelStride, vPixelStride: vPixelStride,
                rotationDegrees: rotation, mirrorHorizontally: mirror
            ) else {
                return DispatchQueue.main.async { result(FlutterError(code: "FRAME_CONVERSION_FAILED", message: "YUV420 conversion failed", details: nil)) }
            }

            do {
                let recognitions = try self.engine.recognize(image: image, profiles: profiles, mode: mode, maxFaces: maxFaces, threshold: threshold)
                let responseMap = recognitions.map { $0.toMap() }
                DispatchQueue.main.async { result(responseMap) }
            } catch let err as IcueFaceException {
                DispatchQueue.main.async { result(FlutterError(code: err.code, message: err.message, details: nil)) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "RECOGNITION_FAILED", message: error.localizedDescription, details: nil)) }
            }
        }
    }

    private func captureEmbeddingWithCamera(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let lens = (args["lens"] as? String) ?? "front"

        DispatchQueue.main.async {
            guard let rootVc = self.getRootViewController() else {
                return result(FlutterError(code: "NO_UI", message: "Cannot find root view controller", details: nil))
            }

            let cameraVc = IcueFaceCameraViewController()
            cameraVc.engine = self.engine
            cameraVc.mode = .capture
            cameraVc.lens = lens
            cameraVc.modalPresentationStyle = .fullScreen

            cameraVc.onCaptured = { embedding in
                if let emb = embedding {
                    let floatData = FlutterStandardTypedData(float32: Data(bytes: emb, count: emb.count * MemoryLayout<Float>.size))
                    result(floatData)
                } else {
                    result(nil)
                }
            }

            rootVc.present(cameraVc, animated: true)
            self.activeCameraController = cameraVc
        }
    }

    private func startFaceTracking(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let profiles = parseProfiles(args["profiles"])
        let lens = (args["lens"] as? String) ?? "front"
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)
        let showMatchingPercentage = (args["showMatchingPercentage"] as? Bool) ?? true
        let showDetectedLabel = (args["showDetectedLabel"] as? Bool) ?? true
        let showUnrecognizedLabel = (args["showUnrecognizedLabel"] as? Bool) ?? true
        let unrecognizedLabel = (args["unrecognizedLabel"] as? String) ?? "UNREGISTERED STUDENT"

        DispatchQueue.main.async {
            guard let rootVc = self.getRootViewController() else {
                return result(FlutterError(code: "NO_UI", message: "Cannot find root view controller", details: nil))
            }

            let cameraVc = IcueFaceCameraViewController()
            cameraVc.engine = self.engine
            cameraVc.mode = .tracking
            cameraVc.lens = lens
            cameraVc.profiles = profiles
            cameraVc.maxFaces = maxFaces
            cameraVc.threshold = threshold
            cameraVc.showMatchingPercentage = showMatchingPercentage
            cameraVc.showDetectedLabel = showDetectedLabel
            cameraVc.showUnrecognizedLabel = showUnrecognizedLabel
            cameraVc.unrecognizedLabel = unrecognizedLabel
            cameraVc.modalPresentationStyle = .fullScreen

            cameraVc.onTrackingFrame = { frameMap in
                self.trackingEventSink?(frameMap)
            }

            rootVc.present(cameraVc, animated: true)
            self.activeCameraController = cameraVc
            result(nil)
        }
    }

    private func stopFaceTracking(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if let active = self.activeCameraController {
                active.dismiss(animated: true)
                self.activeCameraController = nil
            }
            self.trackingEventSink?(["type": "stopped"])
            result(nil)
        }
    }

    private func startLiveAttendance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let roster = parseProfiles(args["roster"])
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let lens = (args["lens"] as? String) ?? "front"
        let autoFinish = (args["autoFinish"] as? Bool) ?? true
        let showMatchingPercentage = (args["showMatchingPercentage"] as? Bool) ?? true
        let showDetectedLabel = (args["showDetectedLabel"] as? Bool) ?? true
        let showUnrecognizedLabel = (args["showUnrecognizedLabel"] as? Bool) ?? true
        let unrecognizedLabel = (args["unrecognizedLabel"] as? String) ?? "UNREGISTERED STUDENT"

        DispatchQueue.main.async {
            guard let rootVc = self.getRootViewController() else {
                return result(FlutterError(code: "NO_UI", message: "Cannot find root view controller", details: nil))
            }

            let cameraVc = IcueFaceCameraViewController()
            cameraVc.engine = self.engine
            cameraVc.mode = .liveAttendance
            cameraVc.lens = lens
            cameraVc.profiles = roster
            cameraVc.threshold = threshold
            cameraVc.maxFaces = maxFaces
            cameraVc.autoFinish = autoFinish
            cameraVc.showMatchingPercentage = showMatchingPercentage
            cameraVc.showDetectedLabel = showDetectedLabel
            cameraVc.showUnrecognizedLabel = showUnrecognizedLabel
            cameraVc.unrecognizedLabel = unrecognizedLabel
            cameraVc.modalPresentationStyle = .fullScreen

            cameraVc.onAttendanceComplete = { attendanceResult in
                result(attendanceResult)
            }

            rootVc.present(cameraVc, animated: true)
            self.activeCameraController = cameraVc
        }
    }

    private func startMultiPhotoAttendance(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "Arguments missing", details: nil))
        }
        let roster = parseProfiles(args["roster"])
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)
        let maxFaces = (args["maxFaces"] as? Int) ?? 5
        let lens = (args["lens"] as? String) ?? "front"
        let autoFinish = (args["autoFinish"] as? Bool) ?? true
        let showMatchingPercentage = (args["showMatchingPercentage"] as? Bool) ?? true
        let showDetectedLabel = (args["showDetectedLabel"] as? Bool) ?? true
        let showUnrecognizedLabel = (args["showUnrecognizedLabel"] as? Bool) ?? true
        let unrecognizedLabel = (args["unrecognizedLabel"] as? String) ?? "UNREGISTERED STUDENT"

        DispatchQueue.main.async {
            guard let rootVc = self.getRootViewController() else {
                return result(FlutterError(code: "NO_UI", message: "Cannot find root view controller", details: nil))
            }

            let cameraVc = IcueFaceCameraViewController()
            cameraVc.engine = self.engine
            cameraVc.mode = .multiPhotoAttendance
            cameraVc.lens = lens
            cameraVc.profiles = roster
            cameraVc.threshold = threshold
            cameraVc.maxFaces = maxFaces
            cameraVc.autoFinish = autoFinish
            cameraVc.showMatchingPercentage = showMatchingPercentage
            cameraVc.showDetectedLabel = showDetectedLabel
            cameraVc.showUnrecognizedLabel = showUnrecognizedLabel
            cameraVc.unrecognizedLabel = unrecognizedLabel
            cameraVc.modalPresentationStyle = .fullScreen

            cameraVc.onAttendanceComplete = { attendanceResult in
                result(attendanceResult)
            }

            rootVc.present(cameraVc, animated: true)
            self.activeCameraController = cameraVc
        }
    }

    private func processAttendanceFromImages(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePaths = args["imagePaths"] as? [String] else {
            return result(FlutterError(code: "INVALID_ARGUMENT", message: "imagePaths required", details: nil))
        }
        let roster = parseProfiles(args["roster"])
        let threshold = Float((args["threshold"] as? Double) ?? 0.68)
        let startTimeMs = Int(Date().timeIntervalSince1970 * 1000)

        DispatchQueue.global(qos: .userInitiated).async {
            var presentRecords: [String: [String: Any]] = [:]
            var unrecognizedCount = 0

            for path in imagePaths {
                guard let image = IcueYuvConverter.imageFromPath(path) else { continue }
                do {
                    let recognitions = try self.engine.recognize(image: image, profiles: roster, mode: "multi", maxFaces: 10, threshold: threshold)
                    let nowMs = Int(Date().timeIntervalSince1970 * 1000)

                    for rec in recognitions {
                        if rec.matched, let personId = rec.personId {
                            if presentRecords[personId] == nil {
                                presentRecords[personId] = [
                                    "personId": personId,
                                    "score": Double(rec.score),
                                    "confidenceScore": Double(rec.score),
                                    "timestampMillis": nowMs,
                                    "sourceImagePath": path
                                ]
                            }
                        } else {
                            unrecognizedCount += 1
                        }
                    }
                } catch {}
            }

            let presentList = Array(presentRecords.values)
            let presentIds = Set(presentRecords.keys)
            let absentIds = roster.map { $0.personId }.filter { !presentIds.contains($0) }
            let endTimeMs = Int(Date().timeIntervalSince1970 * 1000)

            let attendanceResult: [String: Any] = [
                "present": presentList,
                "absentPersonIds": absentIds,
                "unrecognizedFaceCount": unrecognizedCount,
                "totalRosterCount": roster.count,
                "sessionStartTimeMs": startTimeMs,
                "sessionEndTimeMs": endTimeMs,
                "sessionStartTimeMillis": startTimeMs,
                "sessionEndTimeMillis": endTimeMs,
                "mode": "batchImages",
                "photosProcessed": imagePaths.count,
                "capturedImagePaths": imagePaths
            ]

            DispatchQueue.main.async { result(attendanceResult) }
        }
    }

    private func dispose(result: @escaping FlutterResult) {
        engine.close()
        DispatchQueue.main.async {
            if let active = self.activeCameraController {
                active.dismiss(animated: true)
                self.activeCameraController = nil
            }
            result(nil)
        }
    }

    // MARK: - Helpers

    private func parseProfiles(_ rawProfiles: Any?) -> [IcueFaceProfile] {
        guard let list = rawProfiles as? [[String: Any]] else { return [] }
        return list.compactMap { dict -> IcueFaceProfile? in
            guard let personId = dict["personId"] as? String else { return nil }
            let embedding = parseFloatArray(dict["embedding"])
            guard embedding.count == 192 else { return nil }
            return IcueFaceProfile(personId: personId, embedding: embedding)
        }
    }

    private func parseFloatArray(_ raw: Any?) -> [Float] {
        if let floatData = raw as? FlutterStandardTypedData {
            return floatData.data.withUnsafeBytes { pointer in
                Array(UnsafeBufferPointer(start: pointer.bindMemory(to: Float.self).baseAddress, count: floatData.data.count / MemoryLayout<Float>.size))
            }
        }
        if let array = raw as? [Double] {
            return array.map { Float($0) }
        }
        if let array = raw as? [Float] {
            return array
        }
        if let array = raw as? [NSNumber] {
            return array.map { $0.floatValue }
        }
        return []
    }

    private func getRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
}
