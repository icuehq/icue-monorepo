import UIKit
import AVFoundation
import Flutter
import MLKitFaceDetection
import MLKitVision

public enum CameraMode {
    case capture
    case tracking
    case liveAttendance
    case multiPhotoAttendance
}

internal class IcueFaceCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    var engine: IcueFaceEngine?
    var mode: CameraMode = .capture
    var lens: String = "front" // "front" or "back"
    var profiles: [IcueFaceProfile] = []
    var maxFaces: Int = 5
    var threshold: Float = 0.68
    var autoFinish: Bool = true
    var showMatchingPercentage: Bool = true
    var showDetectedLabel: Bool = true
    var showUnrecognizedLabel: Bool = true
    var unrecognizedLabel: String = "UNREGISTERED STUDENT"
    var type: String = "TRANSPORT"
    var fontSize: Float = 12.0 {
        didSet {
            overlayView.fontSize = CGFloat(fontSize > 0 ? fontSize : 12.0)
        }
    }
    var detectedLabelField: String = "ID"

    private var unrecognizedRecords: [[String: Any]] = []
    private var unrecognizedCount: Int = 0

    var onCaptured: (([Float]?) -> Void)?
    var onTrackingFrame: (([String: Any]) -> Void)?
    var onAttendanceComplete: (([String: Any]) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sampleBufferQueue = DispatchQueue(label: "school.icue.face.camera", qos: .userInitiated)
    private let ciContext = CIContext()
    private var isProcessingFrame = false

    private let overlayView = BoundingBoxOverlayView()
    private let statusPill = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let cameraFlipButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .custom)
    private let flashOverlay = UIView()

    private var presentRecords: [String: [String: Any]] = [:] // personId -> record map
    private var presentHitsMap: [String: Int] = [:]
    private var capturedPhotos: [String] = []
    private var sessionStartTime = Date()

    private static let COLOR_BG_DARK = UIColor(red: 11/255.0, green: 20/255.0, blue: 34/255.0, alpha: 0.8)
    private static let COLOR_ACCENT_CYAN = UIColor(red: 0/255.0, green: 229/255.0, blue: 255/255.0, alpha: 1.0)
    private static let COLOR_ACCENT_GREEN = UIColor(red: 0/255.0, green: 230/255.0, blue: 118/255.0, alpha: 1.0)
    private static let UNRECOGNIZED_STABILIZATION_MS: Int = 2200
    private static let UNRECOGNIZED_MIN_FRAMES: Int = 12

    private class UnrecognizedFaceTracker {
        var trackerId: String
        var trackingId: Int?
        var firstSeenMs: Int
        var lastSeenMs: Int
        var frameCount: Int
        var bestScore: Float
        var lastBox: IcueBoundingBox

        init(trackerId: String, trackingId: Int?, firstSeenMs: Int, lastSeenMs: Int, frameCount: Int, bestScore: Float, lastBox: IcueBoundingBox) {
            self.trackerId = trackerId
            self.trackingId = trackingId
            self.firstSeenMs = firstSeenMs
            self.lastSeenMs = lastSeenMs
            self.frameCount = frameCount
            self.bestScore = bestScore
            self.lastBox = lastBox
        }
    }

    private var unrecognizedTrackers: [UnrecognizedFaceTracker] = []

    private func centerDistance(_ b1: IcueBoundingBox, _ b2: IcueBoundingBox) -> Float {
        let cx1 = Float(b1.left + b1.right) / 2.0
        let cy1 = Float(b1.top + b1.bottom) / 2.0
        let cx2 = Float(b2.left + b2.right) / 2.0
        let cy2 = Float(b2.top + b2.bottom) / 2.0
        let dx = cx1 - cx2
        let dy = cy1 - cy2
        return sqrt(dx * dx + dy * dy)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        overlayView.fontSize = CGFloat(fontSize > 0 ? fontSize : 12.0)
        setupCamera()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        overlayView.frame = view.bounds
        flashOverlay.frame = view.bounds
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        let position: AVCaptureDevice.Position = (lens == "back") ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) ??
                           AVCaptureDevice.default(for: .video) else {
            statusPill.text = "Camera device unavailable"
            return
        }

        do {
            if position == .front {
                try device.lockForConfiguration()
                device.videoZoomFactor = 1.0
                device.unlockForConfiguration()
            }

            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            if let connection = output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if position == .front && connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = true
                }
            }

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            self.previewLayer = preview
            self.captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        } catch {
            statusPill.text = "Failed to open camera: \(error.localizedDescription)"
        }
    }

    private func setupUI() {
        overlayView.backgroundColor = .clear
        view.addSubview(overlayView)

        flashOverlay.backgroundColor = .white
        flashOverlay.alpha = 0.0
        view.addSubview(flashOverlay)

        // Top Gradient Scrim
        let topScrim = UIView()
        let topGradient = CAGradientLayer()
        topGradient.colors = [UIColor.black.withAlphaComponent(0.8).cgColor, UIColor.clear.cgColor]
        topGradient.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 160)
        topScrim.layer.addSublayer(topGradient)
        topScrim.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topScrim)

        // Header Titles
        titleLabel.text = getHeaderTitle()
        titleLabel.textColor = IcueFaceCameraViewController.COLOR_ACCENT_CYAN
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)

        subtitleLabel.text = "iCue School Vision · on-device"
        subtitleLabel.textColor = UIColor.lightGray
        subtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 2
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleStack)

        // Flip Camera Button
        cameraFlipButton.setTitle("🔄", for: .normal)
        cameraFlipButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        cameraFlipButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        cameraFlipButton.layer.cornerRadius = 20
        cameraFlipButton.translatesAutoresizingMaskIntoConstraints = false
        cameraFlipButton.addTarget(self, action: #selector(toggleCameraLens), for: .touchUpInside)
        view.addSubview(cameraFlipButton)

        // Close Button
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        view.addSubview(closeButton)

        // Status Pill
        statusPill.textColor = .white
        statusPill.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        statusPill.textAlignment = .center
        statusPill.numberOfLines = 1
        statusPill.backgroundColor = IcueFaceCameraViewController.COLOR_BG_DARK
        statusPill.layer.cornerRadius = 16
        statusPill.layer.borderWidth = 1.0
        statusPill.layer.borderColor = IcueFaceCameraViewController.COLOR_ACCENT_CYAN.withAlphaComponent(0.4).cgColor
        statusPill.clipsToBounds = true
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusPill.text = getInitialStatusText()
        view.addSubview(statusPill)

        // Action / Finish Button
        actionButton.setTitle("Finish Attendance", for: .normal)
        actionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = IcueFaceCameraViewController.COLOR_ACCENT_GREEN
        actionButton.layer.cornerRadius = 22
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isHidden = (mode != .liveAttendance && mode != .multiPhotoAttendance)
        actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        view.addSubview(actionButton)

        // Shutter Button (Capture mode)
        shutterButton.backgroundColor = .clear
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 4
        shutterButton.layer.borderColor = IcueFaceCameraViewController.COLOR_ACCENT_GREEN.cgColor
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.isHidden = (mode != .capture)

        let innerCircle = UIView()
        innerCircle.backgroundColor = IcueFaceCameraViewController.COLOR_ACCENT_GREEN
        innerCircle.layer.cornerRadius = 27
        innerCircle.isUserInteractionEnabled = false
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addSubview(innerCircle)

        NSLayoutConstraint.activate([
            innerCircle.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 54),
            innerCircle.heightAnchor.constraint(equalToConstant: 54)
        ])

        shutterButton.addTarget(self, action: #selector(handleShutterTap), for: .touchUpInside)
        view.addSubview(shutterButton)

        // Auto Layout
        NSLayoutConstraint.activate([
            topScrim.topAnchor.constraint(equalTo: view.topAnchor),
            topScrim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topScrim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topScrim.heightAnchor.constraint(equalToConstant: 140),

            titleStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            cameraFlipButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cameraFlipButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -10),
            cameraFlipButton.widthAnchor.constraint(equalToConstant: 40),
            cameraFlipButton.heightAnchor.constraint(equalToConstant: 40),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            statusPill.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 16),
            statusPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusPill.heightAnchor.constraint(equalToConstant: 32),
            statusPill.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusPill.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),

            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 180),
            actionButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func getHeaderTitle() -> String {
        switch mode {
        case .capture: return "STUDENT ENROLLMENT"
        case .liveAttendance:
            return (type == "TRANSPORT") ? "BUS TRANSPORT ATTENDANCE" : "LIVE CLASS ATTENDANCE"
        case .multiPhotoAttendance:
            return (type == "TRANSPORT") ? "BUS TRANSPORT ATTENDANCE" : "MULTI-GROUP ATTENDANCE"
        case .tracking:
            return (type == "TRANSPORT") ? "BUS TRANSPORT ATTENDANCE" : "STUDENT ATTENDANCE SCAN"
        }
    }

    private func getInitialStatusText() -> String {
        switch mode {
        case .capture:
            return " ⚠️ Position student face in frame "
        case .liveAttendance:
            let prefix = (type == "TRANSPORT") ? "BUS TRANSPORT" : "LIVE ATTENDANCE"
            return " \(prefix) • 0/\(profiles.count) PRESENT (0%) "
        case .multiPhotoAttendance:
            let prefix = (type == "TRANSPORT") ? "BUS TRANSPORT" : "MULTI-PHOTO"
            return " \(prefix) • 0 PHOTO(S) • 0/\(profiles.count) PRESENT "
        case .tracking:
            let prefix = (type == "TRANSPORT") ? "BUS TRANSPORT" : "ATTENDANCE"
            return " \(prefix) • SCANNING CLASSROOM "
        }
    }

    private func formatFaceLabel(
        matched: Bool,
        personId: String?,
        name: String? = nil,
        label: String? = nil,
        score: Float
    ) -> String {
        if matched {
            var parts: [String] = []
            if showDetectedLabel {
                let cleanName = (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? name : nil
                let cleanLabel = (label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? label : nil
                let cleanPersonId = (personId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? personId : nil

                let labelText: String?
                switch detectedLabelField.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                case "NAME":
                    labelText = cleanName ?? cleanLabel ?? cleanPersonId
                case "LABEL":
                    labelText = cleanLabel ?? cleanName ?? cleanPersonId
                case "NAME_AND_ID", "BOTH":
                    let displayName = cleanName ?? cleanLabel
                    if let dName = displayName, let pId = cleanPersonId {
                        labelText = "\(dName) (\(pId))"
                    } else {
                        labelText = displayName ?? cleanPersonId
                    }
                default:
                    labelText = cleanPersonId
                }

                if let text = labelText, !text.isEmpty {
                    parts.append(text)
                }
            }
            if showMatchingPercentage {
                parts.append("\(Int(score * 100))%")
            }
            return parts.joined(separator: " • ")
        } else {
            return showUnrecognizedLabel ? unrecognizedLabel : ""
        }
    }

    @objc private func toggleCameraLens() {
        lens = (lens == "front") ? "back" : "front"
        captureSession?.stopRunning()
        captureSession = nil
        previewLayer?.removeFromSuperlayer()
        setupCamera()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame, let engine = self.engine else { return }
        isProcessingFrame = true

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            isProcessingFrame = false
            return
        }

        let orientation: UIImage.Orientation = (lens == "back") ? .right : .leftMirrored
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }

            switch self.mode {
            case .capture:
                do {
                    let embedding = try engine.extractEmbedding(image: image)
                    DispatchQueue.main.async {
                        self.triggerFlashAnimation()
                        self.stopCamera()
                        self.onCaptured?(embedding)
                        self.dismiss(animated: true)
                    }
                } catch {
                    DispatchQueue.main.async {
                        if let faceErr = error as? IcueFaceException {
                            self.statusPill.text = faceErr.code == "MULTIPLE_FACES" ? " ⚠️ Multiple faces detected " : " ⚠️ Position student face in frame "
                        }
                    }
                }

            case .tracking:
                do {
                    let results = try engine.recognize(
                        image: image,
                        profiles: self.profiles,
                        mode: "multi",
                        maxFaces: self.maxFaces,
                        threshold: self.threshold
                    )
                    let boxes = try engine.detectFaces(image: image)

                    let recognitionsMap = results.map { $0.toMap() }
                    let facesMap = boxes.map { $0.toMap() }

                    let frameMap: [String: Any] = [
                        "type": "faces",
                        "faces": facesMap,
                        "recognitions": recognitionsMap,
                        "frameWidth": Int(image.size.width),
                        "frameHeight": Int(image.size.height),
                        "timestampMillis": Int(Date().timeIntervalSince1970 * 1000)
                    ]

                    let labels = results.map { res -> String in
                        self.formatFaceLabel(
                            matched: res.matched && res.personId != nil,
                            personId: res.personId,
                            name: res.name,
                            label: res.label,
                            score: res.score
                        )
                    }
                    let matchedList = results.map { $0.matched && $0.personId != nil }

                    DispatchQueue.main.async {
                        self.overlayView.update(boxes: boxes, labels: labels, matchedList: matchedList, frameSize: image.size)
                        let matchCount = results.filter { $0.matched }.count
                        let prefix = (self.type == "TRANSPORT") ? "BUS TRANSPORT" : "ATTENDANCE"
                        if self.profiles.isEmpty {
                            self.statusPill.text = " \(prefix) • TRACKING \(boxes.count) STUDENT(S) "
                        } else if boxes.isEmpty {
                            self.statusPill.text = " \(prefix) • SCANNING CLASSROOM "
                        } else {
                            self.statusPill.text = " \(prefix) • \(boxes.count) STUDENT(S) (\(matchCount) RECOGNIZED) "
                        }
                        self.onTrackingFrame?(frameMap)
                    }
                } catch {}

            case .liveAttendance:
                do {
                    let results = try engine.recognize(
                        image: image,
                        profiles: self.profiles,
                        mode: "multi",
                        maxFaces: self.maxFaces,
                        threshold: self.threshold
                    )
                    let boxes = try engine.detectFaces(image: image)

                    let nowMs = Int(Date().timeIntervalSince1970 * 1000)
                    var confirmedUnrecognized: IcueRecognitionResult?
                    var anyFaceScanning = false
                    var labels: [String] = []
                    var matchedList: [Bool] = []

                    for res in results {
                        if res.matched, let personId = res.personId {
                            let hits = (self.presentHitsMap[personId] ?? 0) + 1
                            self.presentHitsMap[personId] = hits
                            if res.score >= 0.75 || hits >= 2 {
                                let existing = self.presentRecords[personId]
                                let existingScore = (existing?["score"] as? Double) ?? 0.0
                                if existing == nil || Double(res.score) > existingScore {
                                    var record: [String: Any] = [
                                        "personId": personId,
                                        "score": Double(res.score),
                                        "confidenceScore": Double(res.score),
                                        "sessionStartTimeMs": nowMs,
                                        "timestampMillis": nowMs,
                                        "boundingBox": res.boundingBox.toMap()
                                    ]
                                    if let name = res.name { record["name"] = name }
                                    if let label = res.label { record["label"] = label }
                                    self.presentRecords[personId] = record
                                }
                            }

                            // Remove active unrecognized tracker near this face
                            self.unrecognizedTrackers.removeAll { t in
                                if let tid = res.boundingBox.trackingId, let tTid = t.trackingId, tid == tTid {
                                    return true
                                }
                                return self.centerDistance(t.lastBox, res.boundingBox) < 140.0
                            }

                            labels.append(
                                self.formatFaceLabel(
                                    matched: true,
                                    personId: personId,
                                    name: res.name,
                                    label: res.label,
                                    score: res.score
                                )
                            )
                            matchedList.append(true)
                        } else {
                            // Find or create tracker
                            var tracker: UnrecognizedFaceTracker? = self.unrecognizedTrackers.first { t in
                                if let tid = res.boundingBox.trackingId, let tTid = t.trackingId, tid == tTid {
                                    return true
                                }
                                return self.centerDistance(t.lastBox, res.boundingBox) < 140.0
                            }

                            if let existingTracker = tracker {
                                existingTracker.lastSeenMs = nowMs
                                existingTracker.frameCount += 1
                                existingTracker.bestScore = max(existingTracker.bestScore, res.score)
                                existingTracker.lastBox = res.boundingBox
                            } else {
                                let newTracker = UnrecognizedFaceTracker(
                                    trackerId: UUID().uuidString,
                                    trackingId: res.boundingBox.trackingId,
                                    firstSeenMs: nowMs,
                                    lastSeenMs: nowMs,
                                    frameCount: 1,
                                    bestScore: res.score,
                                    lastBox: res.boundingBox
                                )
                                self.unrecognizedTrackers.append(newTracker)
                                tracker = newTracker
                            }

                            let trackedDuration = nowMs - tracker!.firstSeenMs
                            if trackedDuration >= IcueFaceCameraViewController.UNRECOGNIZED_STABILIZATION_MS && tracker!.frameCount >= IcueFaceCameraViewController.UNRECOGNIZED_MIN_FRAMES {
                                confirmedUnrecognized = res
                                labels.append(self.unrecognizedLabel.isEmpty ? "NOT IN THIS BUS" : self.unrecognizedLabel)
                                matchedList.append(false)
                            } else {
                                anyFaceScanning = true
                                let scanText = (trackedDuration < 1200) ? "SCANNING... HOLD STILL" : "VERIFYING... HOLD STILL"
                                labels.append(scanText)
                                matchedList.append(false)
                            }
                        }
                    }

                    // Remove stale trackers for faces that left the frame
                    self.unrecognizedTrackers.removeAll { nowMs - $0.lastSeenMs > 1500 }
                    let frameUnrecognized = results.filter { !$0.matched || $0.personId == nil }.count
                    self.unrecognizedCount = max(self.unrecognizedCount, frameUnrecognized)

                    let recognitionsMap = results.map { $0.toMap() }
                    let facesMap = boxes.map { $0.toMap() }

                    let frameMap: [String: Any] = [
                        "type": "faces",
                        "faces": facesMap,
                        "recognitions": recognitionsMap,
                        "frameWidth": Int(image.size.width),
                        "frameHeight": Int(image.size.height),
                        "timestampMillis": nowMs
                    ]

                    DispatchQueue.main.async {
                        self.overlayView.update(boxes: boxes, labels: labels, matchedList: matchedList, frameSize: image.size)
                        let count = self.presentRecords.count
                        let total = self.profiles.count
                        let pct = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0
                        let prefix = (self.type == "TRANSPORT") ? "BUS TRANSPORT" : "LIVE ATTENDANCE"

                        if confirmedUnrecognized != nil {
                            let alertText = (self.type == "TRANSPORT") ? "NOT IN THIS BUS" : "UNREGISTERED STUDENT"
                            self.statusPill.text = " ⚠️ \(alertText) "
                        } else if anyFaceScanning && count == 0 {
                            self.statusPill.text = " 🔍 SCANNING FACE • HOLD STILL... "
                        } else {
                            self.statusPill.text = " \(prefix) • \(count)/\(total) PRESENT (\(pct)%) "
                        }

                        self.onTrackingFrame?(frameMap)

                        if let unrec = confirmedUnrecognized {
                            let photoPath = self.saveJpeg(image: image)
                            if let path = photoPath {
                                self.capturedPhotos.append(path)
                            }
                            var record: [String: Any] = [
                                "score": Double(unrec.score),
                                "confidenceScore": Double(unrec.score),
                                "boundingBox": unrec.boundingBox.toMap(),
                                "timestampMillis": nowMs
                            ]
                            if let path = photoPath {
                                record["sourceImagePath"] = path
                            }
                            if self.unrecognizedRecords.count < 100 {
                                self.unrecognizedRecords.append(record)
                            }
                            self.unrecognizedCount = max(self.unrecognizedCount, self.unrecognizedRecords.count)

                            self.finishAttendance()
                            return
                        }

                        if self.autoFinish && count >= total && total > 0 {
                            self.finishAttendance()
                        }
                    }
                } catch {}

            case .multiPhotoAttendance:
                do {
                    let boxes = try engine.detectFaces(image: image)
                    DispatchQueue.main.async {
                        self.overlayView.update(boxes: boxes, frameSize: image.size)
                        let count = self.presentRecords.count
                        let total = self.profiles.count
                        let photos = self.capturedPhotos.count
                        let prefix = (self.type == "TRANSPORT") ? "BUS TRANSPORT" : "MULTI-PHOTO"
                        self.statusPill.text = " \(prefix) • \(photos) PHOTO(S) • \(count)/\(total) PRESENT "
                    }
                } catch {}
            }
        }
    }

    private func triggerFlashAnimation() {
        UIView.animate(withDuration: 0.1, animations: {
            self.flashOverlay.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.flashOverlay.alpha = 0.0
            }
        }
    }

    @objc private func handleShutterTap() {
        // Manual shutter tap triggers frame capture
    }

    @objc private func handleClose() {
        stopCamera()
        if mode == .capture {
            onCaptured?(nil)
        } else if mode == .liveAttendance || mode == .multiPhotoAttendance {
            finishAttendance()
            return
        }
        dismiss(animated: true)
    }

    @objc private func handleAction() {
        if mode == .liveAttendance || mode == .multiPhotoAttendance {
            finishAttendance()
        }
    }

    private func finishAttendance() {
        stopCamera()

        let presentList = Array(presentRecords.values)
        let presentIds = Set(presentRecords.keys)
        let absentIds = profiles.map { $0.personId }.filter { !presentIds.contains($0) }

        let startMs = Int(sessionStartTime.timeIntervalSince1970 * 1000)
        let endMs = Int(Date().timeIntervalSince1970 * 1000)

        let result: [String: Any] = [
            "present": presentList,
            "absentPersonIds": absentIds,
            "unrecognizedFaceCount": max(unrecognizedCount, unrecognizedRecords.count),
            "unrecognizedFaces": unrecognizedRecords,
            "totalRosterCount": profiles.count,
            "sessionStartTimeMs": startMs,
            "sessionEndTimeMs": endMs,
            "sessionStartTimeMillis": startMs,
            "sessionEndTimeMillis": endMs,
            "mode": mode == .liveAttendance ? "liveStream" : "multiPhoto",
            "photosProcessed": capturedPhotos.count,
            "capturedImagePaths": capturedPhotos
        ]

        onAttendanceComplete?(result)
        dismiss(animated: true)
    }

    private func saveJpeg(image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.65) else { return nil }
        let filename = "icue_attendance_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}

internal class BoundingBoxOverlayView: UIView {
    private var boundingBoxes: [IcueBoundingBox] = []
    private var labels: [String] = []
    private var matchedList: [Bool] = []
    private var frameSize: CGSize = .zero
    var fontSize: CGFloat = 12.0

    func update(boxes: [IcueBoundingBox], labels: [String] = [], matchedList: [Bool] = [], frameSize: CGSize) {
        self.boundingBoxes = boxes
        self.labels = labels
        self.matchedList = matchedList
        self.frameSize = frameSize
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), frameSize.width > 0, frameSize.height > 0 else { return }

        let scaleX = rect.width / frameSize.width
        let scaleY = rect.height / frameSize.height

        for (index, box) in boundingBoxes.enumerated() {
            let boxRect = CGRect(
                x: CGFloat(box.left) * scaleX,
                y: CGFloat(box.top) * scaleY,
                width: CGFloat(box.right - box.left) * scaleX,
                height: CGFloat(box.bottom - box.top) * scaleY
            )
            let isMatched = (index < matchedList.count) ? matchedList[index] : true
            let strokeColor = isMatched ? UIColor(red: 0/255.0, green: 230/255.0, blue: 118/255.0, alpha: 1.0) : UIColor(red: 0/255.0, green: 229/255.0, blue: 255/255.0, alpha: 1.0)

            let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 8.0)
            path.lineWidth = 3.0
            strokeColor.setStroke()
            path.stroke()

            // Draw label badge if present
            if index < labels.count {
                let label = labels[index]
                if !label.isEmpty {
                    drawLabel(context: context, text: label, rect: boxRect, strokeColor: strokeColor)
                }
            }
        }
    }

    private func drawLabel(context: CGContext, text: String, rect: CGRect, strokeColor: UIColor) {
        let font = UIFont.boldSystemFont(ofSize: fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]

        let textSize = (text as NSString).size(withAttributes: textAttributes)
        let horizontalPadding: CGFloat = max(8.0, fontSize * 0.8)
        let verticalPadding: CGFloat = max(4.0, fontSize * 0.4)
        let badgeWidth = textSize.width + horizontalPadding * 2
        let badgeHeight = textSize.height + verticalPadding * 2

        let badgeX = min(max(rect.origin.x, 8), bounds.width - badgeWidth - 8)
        let preferredY = rect.origin.y - badgeHeight - 8
        let badgeY = preferredY >= 8 ? preferredY : rect.maxY + 8

        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6.0)

        // Dark background
        let bgColor = UIColor(red: 11/255.0, green: 20/255.0, blue: 34/255.0, alpha: 0.9)
        bgColor.setFill()
        badgePath.fill()

        // Border stroke
        strokeColor.withAlphaComponent(0.6).setStroke()
        badgePath.lineWidth = 1.0
        badgePath.stroke()

        // Text drawing
        let textPoint = CGPoint(x: badgeX + horizontalPadding, y: badgeY + verticalPadding)
        (text as NSString).draw(at: textPoint, withAttributes: textAttributes)
    }
}
