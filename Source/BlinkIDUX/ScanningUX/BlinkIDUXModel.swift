//
//  BlinkIDUXModel.swift
//  DocumentVerificationUX
//
//  Created by Jura Skrlec on 19.02.2025..
//

import AVFoundation
import Foundation
import CoreImage
import Combine
import SwiftUI

#if canImport(BlinkIDVerify)
import BlinkIDVerify
#elseif canImport(BlinkID)
import BlinkID
#endif

/// A view model that manages the user experience flow for document scanning.
/// Handles camera preview, document detection, user guidance, and scanning state transitions.
@MainActor
public final class BlinkIDUXModel: ScanningViewModel<BlinkIDScanningResult, UIEvent, ReticleStateMachine, BlinkIDScanningAlertType>, PassportAnimatable {

    /// The result of the document verification capture process.
    /// Contains the captured document images and associated data.
    @Published public var result: BlinkIDResultState?

    @Published var passportState = PassportAnimationState()

    private var cancellables = Set<AnyCancellable>()

    public init(analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>, uxSettings: ScanningUXSettings = ScanningUXSettings()) {
        super.init(analyzer: analyzer, uxSettings: uxSettings, reticleStateMachine: ReticleStateMachine(), firstSideFinishedText: "mb_accessibility_success_first_side_scanned".localizedString, scanFinishedText: "mb_accessibility_success_document_scanned".localizedString)

        startEventHandling()
        camera.$status
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Protocol Implementation
    
    public override func processAnalyzerResult() async {
        let result = await analyzer.result()
        if let scanningResult = result as? ScanningResult<BlinkIDScanningResult, BlinkIDScanningAlertType> {
            switch scanningResult {
            case .completed(let scanningResult):
                await finishScan()
                self.result = BlinkIDResultState(scanningResult: scanningResult)
            case .interrupted(let alertType):
                self.alertType = alertType
            case .cancelled:
                showLicenseErrorAlert = true
            case .ended:
                self.result = BlinkIDResultState(scanningResult: nil)
            }
        }
    }
    
    public override func timeoutAlertDismised() {
        super.timeoutAlertDismised()
        passportState.reset()
    }
    
    // - MARK: - Handle UIEvents

    private func startEventHandling() {
        eventHandlingTask = Task {
            for await events in await analyzer.events.stream {
                if events.contains(.requestDocumentSide(side: .back)) {
                    firstSideScanned(frontFlipImage: Image.frontIdImage, backFlipImage: Image.backIdImage, flipState: .flip, nextState: .back)
                    cancelTooltipTimer()
                }
                else if events.contains(.requestDocumentSide(side: .passport(.none))) {
                    passportSideScanned(.none)
                    cancelTooltipTimer()
                }
                else if events.contains(.requestDocumentSide(side: .passport(.right90))) {
                    passportSideScanned(.right90)
                    cancelTooltipTimer()
                }
                else if events.contains(.requestDocumentSide(side: .passport(.left90))) {
                    passportSideScanned(.left90)
                    cancelTooltipTimer()
                }
                else if events.contains(.requestDocumentSide(side: .passportBarcode)) {
                    passportWithBarcodeSideScanned()
                    cancelTooltipTimer()
                }
                else if events.contains(.requestDocumentSide(side: .barcode)) {
                    self.setReticleState(.barcode, force: true)
                    startTooltipTimer()
                } else if events.contains(.wrongSide) {
                    self.setReticleState(.error("mb_scanning_wrong_side"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSidePassportWithBarcode) {
                    self.setReticleState(.error("mb_instructions_scan_barcode_last_page"))
                    currentErrorMessage = .flipside
                } else if events.contains(.wrongSidePassport(passportOrientation: .none)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_top"))
                    currentErrorMessage = .flipside
                }
                else if events.contains(.wrongSidePassport(passportOrientation: .left90)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_left"))
                    currentErrorMessage = .flipside
                }
                else if events.contains(.wrongSidePassport(passportOrientation: .right90)) {
                    self.setReticleState(.error("mb_scanning_wrong_page_right"))
                    currentErrorMessage = .flipside
                }
                else if events.contains(.tooClose) {
                    self.setReticleState(.error("mb_move_farther"))
                    currentErrorMessage = .movefarther
                } else if events.contains(.tooFar) {
                    self.setReticleState(.error("mb_move_closer"))
                    currentErrorMessage = .movecloser
                } else if events.contains(.tooCloseToEdge) {
                    self.setReticleState(.error("mb_move_farther"))
                    currentErrorMessage = .movefarther
                } else if events.contains(.tilt) {
                    self.setReticleState(.error("mb_keep_document_parallel"))
                    currentErrorMessage = .aligndocument
                } else if events.contains(.glare) {
                    self.setReticleState(.error("mb_glare_detected"))
                    currentErrorMessage = .eliminateglare
                } else if events.contains(.blur) {
                    self.setReticleState(.error("mb_blur_detected"))
                    currentErrorMessage = .eliminateblur
                } else if events.contains(.notFullyVisible) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                    currentErrorMessage = .keepvisible
                } else if events.contains(.occlusion) {
                    self.setReticleState(.error("mb_document_not_fully_visible"))
                    currentErrorMessage = .keepvisible
                } else if events.contains(.tooDark) {
                    self.setReticleState(.error("mb_increase_lighting_intensity"))
                    currentErrorMessage = .increaselighting
                } else if events.contains(.tooBright) {
                    self.setReticleState(.error("mb_decrease_lighting_intensity"))
                    currentErrorMessage = .decreaselighting
                } else if events.contains(.facePhotoNotFullyVisible) {
                    self.setReticleState(.error("mb_face_photo_not_fully_visible"))
                    currentErrorMessage = .keepvisible
                } else {
                    self.setReticleState(reticleStateMachine.fallbackState)
                }
            }
        }
    }
}
