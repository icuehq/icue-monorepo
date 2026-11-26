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

    var onCaptured: (([Float]?) -> Void)?
    var onTrackingFrame: (([String: Any]) -> Void)?
    var onAttendanceComplete: (([String: Any]) -> Void)?
    /// Attendance was cancelled with nothing scanned, or its scans were discarded.
    var onAttendanceCancelled: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sampleBufferQueue = DispatchQueue(label: "school.icue.face.camera", qos: .userInitiated)
    private let ciContext = CIContext()
    private var isProcessingFrame = false
    // True while the cancel dialog is open: no frames are analysed, so the count cannot change.
    private var isPaused = false

    private let overlayView = BoundingBoxOverlayView()
    private let statusPill = UILabel()
    private let countLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let cameraFlipButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let shutterButton = UIButton(type: .custom)
    private let flashOverlay = UIView()

    private var presentRecords: [String: [String: Any]] = [:] // personId -> record map
    private var presentHitsMap: [String: Int] = [:]
    private var capturedPhotos: [String] = []
    private var sessionStartTime = Date()

    private static let COLOR_BG_DARK = UIColor(red: 11/255.0, green: 20/255.0, blue: 34/255.0, alpha: 0.8)
    private static let COLOR_ACCENT_CYAN = UIColor(red: 0/255.0, green: 229/255.0, blue: 255/255.0, alpha: 1.0)
    private static let COLOR_ACCENT_GREEN = UIColor(red: 0/255.0, green: 230/255.0, blue: 118/255.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCamera()
        setupUI()
        if isAttendance { prepareScanFeedback() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        releaseScanFeedback()
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
            statusPill.isHidden = false
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
            statusPill.isHidden = false
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

        // Live attendance shows its present count large in the header instead of the pill.
        countLabel.isHidden = mode != .liveAttendance
        if mode == .liveAttendance { updateAttendanceCount(present: 0, total: profiles.count) }

        // Title + subtitle form one block; the count is centred on that block, right after it.
        // The title wraps to two lines if the row is tight so the count never reaches the buttons.
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textBlock = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textBlock.axis = .vertical
        textBlock.spacing = 2
        textBlock.setContentHuggingPriority(.required, for: .horizontal)
        textBlock.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let rowSpacer = UIView()
        rowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let titleStack = UIStackView(arrangedSubviews: [textBlock, countLabel, rowSpacer])
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 12
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
        // Attendance has no close button: helpers tapped it thinking it saved the scans.
        // They leave through Cancel or Finish at the bottom instead.
        closeButton.isHidden = isAttendance
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
        statusPill.isHidden = mode == .liveAttendance
        view.addSubview(statusPill)

        // Action / Finish Button
        actionButton.setTitle(finishTitle(0), for: .normal)
        actionButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = IcueFaceCameraViewController.COLOR_ACCENT_GREEN
        actionButton.layer.cornerRadius = 22
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.isHidden = (mode != .liveAttendance && mode != .multiPhotoAttendance)
        actionButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
        view.addSubview(actionButton)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        cancelButton.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cancelButton.layer.cornerRadius = 22
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.isHidden = !isAttendance
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        view.addSubview(cancelButton)

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

            titleStack.centerYAnchor.constraint(equalTo: cameraFlipButton.centerYAnchor),
            titleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: cameraFlipButton.leadingAnchor, constant: -12),

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
            // Shifted right so Cancel fits on its left; the pair stays centred.
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 56),
            actionButton.widthAnchor.constraint(equalToConstant: 180),
            actionButton.heightAnchor.constraint(equalToConstant: 44),

            cancelButton.bottomAnchor.constraint(equalTo: actionButton.bottomAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: -12),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private var isAttendance: Bool { mode == .liveAttendance || mode == .multiPhotoAttendance }

    private func finishTitle(_ scanned: Int) -> String {
        scanned > 0 ? "✓ Finish (\(scanned))" : "✓ Finish"
    }

    /// One beep and one firm tap when new students are marked present, so a helper on a moving
    /// bus knows to move on without reading the screen. Once per frame. A heavy impact is
    /// lighter than the full call vibration (`kSystemSoundID_Vibrate`), which cannot be softened.
    private func scanFeedback() {
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
        scanHaptic.impactOccurred()
        scanHaptic.prepare()
    }

    private let scanHaptic = UIImpactFeedbackGenerator(style: .heavy)

    private var beepPlayer: AVAudioPlayer?
    private var previousAudioCategory: AVAudioSession.Category?

    /// `.playback` plays through the silent switch (like Android's alarm stream) and mixes with
    /// other audio; the host app's audio category is restored when the camera closes.
    private func prepareScanFeedback() {
        let session = AVAudioSession.sharedInstance()
        previousAudioCategory = session.category
        try? session.setCategory(.playback, options: [.mixWithOthers])
        beepPlayer = try? AVAudioPlayer(data: IcueFaceCameraViewController.beepWav())
        beepPlayer?.volume = 0.8
        beepPlayer?.prepareToPlay()
        scanHaptic.prepare()
    }

    private func releaseScanFeedback() {
        beepPlayer = nil
        if let category = previousAudioCategory {
            try? AVAudioSession.sharedInstance().setCategory(category)
            previousAudioCategory = nil
        }
    }

    /// One 150 ms beep at 1.8 kHz (cuts through engine noise), as an in-memory 16-bit mono WAV,
    /// so no sound file has to ship with the SDK.
    private static func beepWav() -> Data {
        let rate = 44_100
        var samples: [Int16] = []
        func tone(_ milliseconds: Int) {
            let count = rate * milliseconds / 1000
            for index in 0..<count {
                // 5 ms fade in and out, so the beep does not click.
                let envelope = min(1.0, Double(min(index, count - index)) / 220.0)
                let value = sin(2 * Double.pi * 1800 * Double(index) / Double(rate))
                samples.append(Int16(value * envelope * Double(Int16.max) * 0.9))
            }
        }
        tone(150)

        var data = Data()
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append32(36 + byteCount); data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append32(16); append16(1); append16(1)
        append32(UInt32(rate)); append32(UInt32(rate * 2)); append16(2); append16(16)
        data.append(contentsOf: Array("data".utf8)); append32(byteCount)
        for sample in samples { withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) } }
        return data
    }

    private func studentsText(_ count: Int) -> String {
        count == 1 ? "1 student" : "\(count) students"
    }

    private func updateAttendanceCount(present: Int, total: Int) {
        actionButton.setTitle(finishTitle(present), for: .normal)
        countLabel.attributedText = NSAttributedString(
            string: "\(present)/\(total)",
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 28, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
        )
    }

    private func getHeaderTitle() -> String {
        switch mode {
        case .capture: return "STUDENT ENROLLMENT"
        case .liveAttendance: return "TRANSPORT ATTENDANCE"
        case .multiPhotoAttendance: return "MULTI-GROUP ATTENDANCE"
        case .tracking: return "STUDENT ATTENDANCE SCAN"
        }
    }

    private func getInitialStatusText() -> String {
        switch mode {
        case .capture:
            return " ⚠️ Position student face in frame "
        case .liveAttendance:
            return " LIVE ATTENDANCE • 0/\(profiles.count) PRESENT (0%) "
        case .multiPhotoAttendance:
            return " MULTI-PHOTO • 0 PHOTO(S) • 0/\(profiles.count) PRESENT "
        case .tracking:
            return " ATTENDANCE • SCANNING CLASSROOM "
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
        guard !isPaused, !isProcessingFrame, let engine = self.engine else { return }
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
                            self.statusPill.text = faceErr.code == "MULTIPLE_FACES" ? " ⚠️ Multiple faces detected " : faceErr.code == "POOR_FACE" ? " ⚠️ Face the camera directly " : " ⚠️ Position student face in frame "
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

                    DispatchQueue.main.async {
                        self.overlayView.update(boxes: boxes, frameSize: image.size)
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
                    var newlyScanned = 0

                    for res in results {
                        if res.matched, let personId = res.personId {
                            let hits = (self.presentHitsMap[personId] ?? 0) + 1
                            self.presentHitsMap[personId] = hits
                            // Two separate frames must agree before a student is marked present.
                            if hits >= 2 {
                                if self.presentRecords[personId] == nil {
                                    newlyScanned += 1
                                    self.presentRecords[personId] = [
                                        "personId": personId,
                                        "score": Double(res.score),
                                        "confidenceScore": Double(res.score),
                                        "sessionStartTimeMs": nowMs,
                                        "timestampMillis": nowMs
                                    ]
                                }
                            }
                        }
                    }

                    let newStudents = newlyScanned
                    DispatchQueue.main.async {
                        self.overlayView.update(boxes: boxes, frameSize: image.size)
                        let count = self.presentRecords.count
                        let total = self.profiles.count
                        self.updateAttendanceCount(present: count, total: total)
                        if newStudents > 0 { self.scanFeedback() }

                        if self.autoFinish && !self.isPaused && count >= total && total > 0 {
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
                        self.statusPill.text = " MULTI-PHOTO • \(photos) PHOTO(S) • \(count)/\(total) PRESENT "
                        self.actionButton.setTitle(self.finishTitle(count), for: .normal)
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
        }
        dismiss(animated: true)
    }

    /// Nothing scanned: close at once. Otherwise ask, so a mistaken tap never loses the scans.
    /// A custom popup, not the system alert: a big count first, then three full-width buttons
    /// stacked in order of safety, so the safe choice is the biggest and the first one read.
    @objc private func handleCancel() {
        let scanned = presentRecords.count
        if scanned == 0 {
            cancelAttendance()
            return
        }
        isPaused = true

        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = UIColor(red: 16/255.0, green: 27/255.0, blue: 43/255.0, alpha: 1.0)
        card.layer.cornerRadius = 28
        card.layer.borderWidth = 1
        card.layer.borderColor = IcueFaceCameraViewController.COLOR_ACCENT_CYAN.withAlphaComponent(0.2).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false

        let countText = UILabel()
        countText.text = "\(scanned)"
        countText.font = UIFont.systemFont(ofSize: 56, weight: .bold)
        countText.textColor = IcueFaceCameraViewController.COLOR_ACCENT_GREEN
        countText.textAlignment = .center

        let scannedText = UILabel()
        scannedText.text = scanned == 1 ? "student scanned" : "students scanned"
        scannedText.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        scannedText.textColor = .white
        scannedText.textAlignment = .center

        let question = UILabel()
        question.text = "Submit their attendance?"
        question.font = UIFont.systemFont(ofSize: 15)
        question.textColor = UIColor.white.withAlphaComponent(0.65)
        question.textAlignment = .center

        let red = UIColor(red: 1.0, green: 82/255.0, blue: 82/255.0, alpha: 1.0)
        let submit = popupButton("✓  Submit \(studentsText(scanned))",
                                 fill: UIColor(red: 0, green: 161/255.0, blue: 82/255.0, alpha: 1.0),
                                 text: .white, border: nil) { [weak self, weak overlay] in
            overlay?.removeFromSuperview()
            self?.finishAttendance()
        }
        let discard = popupButton("Discard all scans", fill: .clear, text: red, border: red) { [weak self, weak overlay] in
            overlay?.removeFromSuperview()
            self?.cancelAttendance()
        }
        let keep = popupButton("Keep scanning", fill: .clear,
                               text: IcueFaceCameraViewController.COLOR_ACCENT_CYAN, border: nil) { [weak self, weak overlay] in
            overlay?.removeFromSuperview()
            self?.isPaused = false
        }

        let stack = UIStackView(arrangedSubviews: [countText, scannedText, question, submit, discard, keep])
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(2, after: countText)
        stack.setCustomSpacing(20, after: question)
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        overlay.addSubview(card)
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            card.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 20),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            card.widthAnchor.constraint(equalTo: overlay.widthAnchor, constant: -40).withPriority(.defaultHigh),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
        ])
    }

    /// A full-width, 56 pt popup button: big enough to hit on a moving bus.
    private func popupButton(_ title: String, fill: UIColor, text: UIColor, border: UIColor?,
                             onTap: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { _ in onTap() })
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        button.setTitleColor(text, for: .normal)
        button.backgroundColor = fill
        button.layer.cornerRadius = 16
        if let border = border {
            button.layer.borderWidth = 1.5
            button.layer.borderColor = border.cgColor
        }
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return button
    }

    private func cancelAttendance() {
        stopCamera()
        onAttendanceCancelled?()
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
            "unrecognizedFaceCount": 0,
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

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}

internal class BoundingBoxOverlayView: UIView {
    private var boundingBoxes: [IcueBoundingBox] = []
    private var frameSize: CGSize = .zero

    func update(boxes: [IcueBoundingBox], frameSize: CGSize) {
        self.boundingBoxes = boxes
        self.frameSize = frameSize
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), frameSize.width > 0, frameSize.height > 0 else { return }

        let scaleX = rect.width / frameSize.width
        let scaleY = rect.height / frameSize.height

        for box in boundingBoxes {
            let boxRect = CGRect(
                x: CGFloat(box.left) * scaleX,
                y: CGFloat(box.top) * scaleY,
                width: CGFloat(box.right - box.left) * scaleX,
                height: CGFloat(box.bottom - box.top) * scaleY
            )
            let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 8.0)
            path.lineWidth = 3.0
            UIColor.systemGreen.setStroke()
            path.stroke()
        }
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
