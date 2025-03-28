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
public final class ScanningUXModel: ScanningViewModel<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType> {
    
    /// The result of the document verification capture process.
    /// Contains the captured document images and associated data.
    @Published public var captureResult: BlinkIDVerifyCaptureResultState?
    
    private var cancellables = Set<AnyCancellable>()
    
    public override init(analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>, shouldShowIntroductionAlert: Bool = true) {
        super.init(analyzer: analyzer, shouldShowIntroductionAlert: shouldShowIntroductionAlert)
        startEventHandling()
        camera.$status
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Protocol Implementation
    
    public override func analyze() async {
        Task {
            await processAnalyzerResult()
        }

        for await frame in await camera.sampleBuffer {
            await analyzer.analyze(image: CameraFrame(buffer: MBSampleBufferWrapper(cmSampleBuffer: frame.buffer), roi: roi, orientation: camera.orientation.toCameraFrameVideoOrientation()))
        }
    }
    
    public override func processAnalyzerResult() async {
        let result = await analyzer.result()
        if let scanningResult = result as? ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType> {
            switch scanningResult {
            case .completed(let completedResult):
                finishScan()
                captureResult = BlinkIDVerifyCaptureResultState(captureResult: completedResult)
            case .interrupted(let alertType):
                self.alertType = alertType
                showScanningAlert = true
            case .cancelled:
                showLicenseErrorAlert = true
            case .ended:
                captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
            }
        }
    }
    
    public override func licenseErrorAlertDismised() {
        captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
    }
    
    public override func scanningDidCancel() {
        super.scanningDidCancel()
        captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
    }
    
    public override func timeoutAlertDismised() {
        self.reticleState = .front
        restartScanning()
        Task {
            await self.analyze()
        }
    }
    
    override func closeButtonTapped() {
        Task {
            await self.analyzer.end()
        }
        captureResult = BlinkIDVerifyCaptureResultState(captureResult: nil)
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
                    self.setReticleState(.error("mb_scanning_wrong_side"))
                } else if events.contains(.tooClose) {
                    self.setReticleState(.error("mb_move_farther"))
                } else if events.contains(.tooFar) {
                    self.setReticleState(.error("mb_move_closer"))
                } else if events.contains(.tooCloseToEdge) {
                    self.setReticleState(.error("mb_document_too_close_to_edge"))
                } else if events.contains(.tilt) {
                    self.setReticleState(.error("mb_keep_document_parallel"))
                } else if events.contains(.blur) {
                    self.setReticleState(.error("mb_blur_detected"))
                } else if events.contains(.glare) {
                    self.setReticleState(.error("mb_glare_detected"))
                } else if events.contains(.notFullyVisible) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                } else if events.contains(.occlusion) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                }
            }
        }
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
    
    // - MARK: Animations

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
}
