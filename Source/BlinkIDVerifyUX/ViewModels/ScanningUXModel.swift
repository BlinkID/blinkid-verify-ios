//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import AVFoundation
import Foundation
import CoreImage
import BlinkIDVerify
import Combine
import SwiftUI

/// A view model that manages the user experience flow for document scanning.
/// Handles camera preview, document detection, user guidance, and scanning state transitions.
@MainActor
public final class ScanningUXModel: ObservableObject {
    
    /// The result of the document verification capture process.
    /// Contains the captured document images and associated data.
    @Published public var captureResult: BlinkIDVerifyCaptureResultState?
    
    /// Defines the region of interest for document detection in the camera preview.
    /// Used to constrain the area where the document should be positioned.
    @Published public var roi: RegionOfInterest = RegionOfInterest()
    
    let camera: Camera = Camera()
    let analyzer: any CameraFrameAnalyzer
    
    /// Handle stream of `UIEvents`
    private var eventHandlingTask: Task<Void, Never>?
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isTorchOn: Bool = false {
        didSet {
            camera.isTorchEnabled = isTorchOn
            torchImage = isTorchOn ? Image(systemName: "bolt.fill") : Image(systemName: "bolt.slash.fill")
            torchHint = isTorchOn ? "Turn flashlight on" : "Turn flashlight off"
        }
    }
    
    // cancel button
    let cancelImage = Image(systemName: "xmark")
    let cancelLabel = "Cancel"
    let cancelHint = "Cancel scanning procedure"
    
    // flashlight button

    @Published var torchImage = Image(systemName: "bolt.slash.fill")
    let torchLabel = "Torch"
    @Published var torchHint = "Turn flashlight on" // Enum
        
    // help button
    let helpImage = Image(systemName: "questionmark.circle.fill")
    let helpLabel = "Help"
    let helpHint = "Open scanning onboarding help"
    @Published var showSheet = false
    
    // introduction alert
    let shouldShowIntroductionAlert: Bool
    @Published var showIntroductionAlert = false
    
    // timeout alert
    @Published var showTimeoutAlert: Bool = false {
        didSet {
            if showTimeoutAlert {
                pauseScanning()
            } else {
                timeoutAlertDismised()
            }
        }
    }
    
    // license error alert
    @Published var showLicenseErrorAlert: Bool = false {
        didSet {
            if showLicenseErrorAlert {
                pauseScanning()
            } else {
                licenseErrorAlertDismised()
            }
        }
    }
    
    // flip card image
    @Published var showCardImage: Bool = false
    @Published var cardImage = Image.frontIdImage
    @Published var flipCardDegrees: Double = 180.0
    @Published var flipCardScale: Double = 1.0
    private let flipCardDuration = 1.0
    
    // success image
    @Published var showSuccessImage: Bool = false
    @Published var successImage = Image.checkmarkImage
    @Published var successImageScale: Double = 0.0
    private let successImageAnimationDuration = 0.586
    
    // ripple animation
    @Published var showRippleView: Bool = false
    @Published var rippleViewScale: Double = 0.0
    @Published var rippleViewOpacity: Double = 1.0
    private let rippleViewAnimationDuration = 0.45
    
    // reticle logic
    @Published var reticleState: ReticleState = .front
    private var lastReticleStateChange: TimeInterval = Date().timeIntervalSince1970
    private var timer: Timer?
    
    /// Initializes a new scanning UX model with the specified document analyzer.
    /// - Parameter analyzer: The analyzer responsible for processing camera frames and detecting documents.
    /// - Parameter shouldShowIntroductionAlert: Whether introduction alert will be shown on appear
    public init(analyzer: any CameraFrameAnalyzer, shouldShowIntroductionAlert: Bool = false) {
        self.analyzer = analyzer
        self.shouldShowIntroductionAlert = shouldShowIntroductionAlert
        startEventHandling()
        camera.$status
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    /// Pauses the document scanning process.
    /// Stops analyzing new frames.
    func pauseScanning() {
        Task {
            await analyzer.pause()
        }
    }
    
    /// Resumes the document scanning process after being paused.
    /// Restarts frame analysis.
    func resumeScanning() {
        Task {
            await analyzer.resume()
            await camera.start()
        }
    }
    
    /// Restarts the document scanning process after being paused.
    /// Restarts frame analysis.
    func restartScanning() {
        Task {
            await analyzer.restart()
            await camera.start()
        }
    }
    
    func closeButtonTapped() {
        Task {
            await analyzer.end()
        }
    }
    
    func helpButtonTapped() {
        pauseScanning()
        showSheet.toggle()
    }
    
    func presentAlert() {
        pauseScanning()
        withAnimation {
            showIntroductionAlert = true
        }
    }
    
    func dismissAlert() {
        withAnimation {
            showIntroductionAlert = false
        }
        UIAccessibility.post(notification: .screenChanged, argument: ReticleState.front.text)
        resumeScanning()
    }
    
    private func firstSideScanned() {
        pauseScanning()
        
        let remainingTime = calculateRemainingTime()
        
        if remainingTime > 0 {
            timer?.invalidate()
            Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.animateFirstSideScanned()
                }
            }
        } else {
            Task {
                await animateFirstSideScanned()
            }
        }
    }
    
    // - MARK: Analyze
    /// Initiates the document analysis process.
    /// Continuously processes camera frames until a valid document is captured or scanning is cancelled.
    public func analyze() async {
        
        Task {
            let result = await analyzer.result()
            switch result {
            case .completed(let completedResult):
                finishScan()
                if let result = completedResult as? BlinkIDVerifyCaptureResult {
                    captureResult = BlinkIDVerifyCaptureResultState(captureResult: result)
                }
            case .cancelled:
                showLicenseErrorAlert = true
            case .timeout:
                showTimeoutAlert = true
            case .none:
                captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
            }
        }
        
        for await frame in await camera.sampleBuffer {
            await analyzer.analyze(image: CameraFrame(buffer: MBSampleBufferWrapper(cmSampleBuffer: frame.buffer), roi: roi, orientation: camera.orientation.toCameraFrameVideoOrientation()))
        }
    }
    
    public func timeoutAlertDismised() {
        self.reticleState = .front
        restartScanning()
        Task {
            await self.analyze()
        }
    }
    
    public func licenseErrorAlertDismised() {
        captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
    }
    
    /// Completes the scanning process.
    /// Stops frame analysis and triggers success animations.
    public func finishScan() {
        pauseScanning()
        
        let remainingTime = calculateRemainingTime()
        
        if remainingTime > 0 {
            timer?.invalidate()
            Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { [weak self] _ in
                Task {
                    await self?.animateSuccess()
                }
            }
        } else {
            animateSuccess()
        }
    }
    
    private func calculateRemainingTime() -> Double {
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - lastReticleStateChange
        return self.reticleState.duration - elapsedTime
    }
    
    private func animateFirstSideScanned() async {
        showSuccessImage = true
        setReticleState(.inactive, force: true)
        
        withAnimation(.easeOutExpo(duration: successImageAnimationDuration)) {
            successImageScale = 1.0
        }
        
        try? await Task.sleep(for: .seconds(successImageAnimationDuration))
        
        withAnimation(.linear(duration: 0.2)) {
            showSuccessImage = false
        }
        
        try? await Task.sleep(for: .seconds(0.2))
        
        // Reset and prepare for card flip
        successImageScale = 0.0
        setReticleState(.flip, force: true)
        showCardImage = true
        
        withAnimation(.easeIn(duration: flipCardDuration/2)) {
            flipCardScale = 0.9
        }
        
        withAnimation(.easeInOut(duration: flipCardDuration)) {
            flipCardDegrees = 0.0
        }
        
        try? await Task.sleep(for: .seconds(flipCardDuration/2))
        
        cardImage = Image.backIdImage
        
        withAnimation(.easeOut(duration: flipCardDuration/2)) {
            flipCardScale = 1.0
        }
        
        try? await Task.sleep(for: .seconds(flipCardDuration/2 + 0.2))
        
        showCardImage = false
        cardImage = Image.frontIdImage
        flipCardDegrees = 180.0
        resumeScanning()
        setReticleState(.back, force: true)
    }
    
    private func animateSuccess() {
        showSuccessImage = true
        self.setReticleState(.inactive, force: true)
        
        withAnimation(.easeOutExpo(duration: successImageAnimationDuration)) {
            successImageScale = 1.0
        }
        
        self.showRippleView = true
        withAnimation(.easeOut(duration: rippleViewAnimationDuration)) {
            self.rippleViewScale = 10.0
            self.rippleViewOpacity = 0.0
        }
    }
    
    /// Notifies the model that scanning was cancelled by the user.
    /// Cleans up resources and resets the scanning state.
    public func scanningDidCancel() {
        captureResult = nil
    }
    
    private func setReticleState(_ state: ReticleState, force: Bool = false) {
        let currentTime = Date().timeIntervalSince1970
        guard (currentTime - lastReticleStateChange >= self.reticleState.duration) || force else { return }
        
        timer?.invalidate()
        
        lastReticleStateChange = currentTime
        reticleState = state
        
        if state.shouldExpire {
            timer = Timer.scheduledTimer(withTimeInterval: state.duration, repeats: false) { [weak self] _ in
                Task {
                    await self?.setReticleState(.detecting)
                }
            }
        }
    }
    
    // - MARK: - Handle UIEvents
    
    private func startEventHandling() {
        eventHandlingTask = Task {
            for await events in await analyzer.events.stream {
                if events.contains(.requestDocumentSide(side: .back)) {
                    firstSideScanned()
                } else if events.contains(.requestDocumentSide(side: .barcode)) {
                    self.setReticleState(.barcode, force: true)
                } else if events.contains(.wrongSide) {
                    self.setReticleState(.error("Flip the document"))
                } else if events.contains(.tooClose) {
                    self.setReticleState(.error("Move farther"))
                } else if events.contains(.tooFar) {
                    self.setReticleState(.error("Move closer"))
                } else if events.contains(.tooCloseToEdge) {
                    self.setReticleState(.error("Move the document from the edge"))
                } else if events.contains(.tilt) {
                    self.setReticleState(.error("Keep document parallel with the phone"))
                } else if events.contains(.blur) {
                    self.setReticleState(.error("Keep document and phone still"))
                } else if events.contains(.glare) {
                    self.setReticleState(.error("Tilt or move document to remove reflection"))
                } else if events.contains(.notFullyVisible) {
                    self.setReticleState(.error("Keep document fully visible"))
                } else if events.contains(.occlusion) {
                    self.setReticleState(.error("Keep document fully visible"))
                }
            }
        }
    }
    
    func stopEventHandling() {
        eventHandlingTask?.cancel()
    }
}

extension Bundle {
    static var frameworkBundle: Bundle {
#if SWIFT_PACKAGE
        return .module
#else
        return Bundle(for: ScanningUXModel.self)
#endif
    }
}

extension AVCaptureVideoOrientation {
    public func toCameraFrameVideoOrientation() -> CameraFrameVideoOrientation {
        switch self {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            @unknown default: return .portrait
        }
    }

    public static func fromCameraFrameVideoOrientation(_ orientation: CameraFrameVideoOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
            case .portrait: return .portrait
            case .portraitUpsideDown: return .portraitUpsideDown
            case .landscapeLeft: return .landscapeLeft
            case .landscapeRight: return .landscapeRight
            @unknown default: return .portrait
        }
    }
}
