//  Created by Toni Krešo on 13.11.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import BlinkIDVerify

final class ScanningUXTranslator {
    
    private var backSideDispatched: Bool = false
    private var barcodeDispatched: Bool = false
    private var barcodeStepNeeded: Bool = false
    private var reticleLocked: Bool = false
    private var barcodeTimerTask: Task<Void, Never>?
    
    func translate(resultCompleteness: ResultCompleteness, frameAnalysisResult: FrameAnalysisResult, session: CaptureSession) -> [UIEvent] {
        var events: [UIEvent] = []
        
        if resultCompleteness.frontSideFinished && !backSideDispatched {
            backSideDispatched = true
            events.append(.requestDocumentSide(side: .back))
        }
        if frameAnalysisResult.hasBarcodeReadingIssue && !barcodeDispatched {
            reticleLocked = true
            if barcodeTimerTask == nil {
                startBarcodeScanTimer(session: session)
            }
            if barcodeStepNeeded {
                barcodeDispatched = true
                events.append(.requestDocumentSide(side: .barcode))
            }
        }
        
        guard !reticleLocked else {
            return events
        }
        
        switch frameAnalysisResult.processingStatus {
        case .scanningWrongSide, .awaitingOtherSide:
            events.append(.wrongSide)
        case .success, .detectionFailed, .unsupportedClass, .unsupportedByLicense, .unknown:
            break
        default:
            events.append(.notFullyVisible)
        }
        
        switch frameAnalysisResult.detectionStatus {
        case .cameraTooFar:
            events.append(.tooFar)
        case .cameraTooClose:
            events.append(.tooClose)
        case .cameraAngleTooSteep:
            events.append(.tilt)
        case .documentTooCloseToCameraEdge:
            events.append(.tooCloseToEdge)
        case .documentPartiallyVisible:
            events.append(.notFullyVisible)
        default:
            break
        }
        
        if frameAnalysisResult.blurDetected {
            events.append(.blur)
        }
        if frameAnalysisResult.glareDetected {
            events.append(.glare)
        }
        if frameAnalysisResult.occlusionDetected {
            events.append(.occlusion)
        }
        if frameAnalysisResult.tiltDetected {
            events.append(.tilt)
        }
        
        return events
    }
    
    deinit {
        barcodeTimerTask?.cancel()
        barcodeTimerTask = nil
    }
    
    private func startBarcodeScanTimer(session: CaptureSession) {
        barcodeTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(3.0 * 1_000_000_000))
            if !Task.isCancelled {
                self?.barcodeStepNeeded = true
                Task { @ProcessingActor in
                    session.setAllowBarcodeStep(true)
                }
            }
        }
    }
    
    func resetState() {
        backSideDispatched = false
        barcodeDispatched = false
        barcodeStepNeeded = false
        reticleLocked = false
        barcodeTimerTask?.cancel()
        barcodeTimerTask = nil
    }
}
