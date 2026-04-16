//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import Foundation
import BlinkIDVerify
import CoreImage
import UIKit

/// Manages the stream of UI events during document verification.
public actor BlinkIDVerifyEventStream: EventStream {
    private let events: AsyncStream<[UIEvent]>
    private let continuation: AsyncStream<[UIEvent]>.Continuation
    
    public init() {
        var continuation: AsyncStream<[UIEvent]>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }
    
    deinit {
        continuation.finish()
    }
    
    /// Sends UI events to the stream.
    /// - Parameter events: Array of UI events to be processed
    public func send(_ events: [UIEvent]) {
        continuation.yield(events)
    }
    
    /// The underlying async stream of UI events.
    public var stream: AsyncStream<[UIEvent]> {
        events
    }
}

/// Analyzes camera frames for document verification.
public actor BlinkIDVerifyAnalyzer: CameraFrameAnalyzer {
    
    public typealias Result = ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>
    public typealias Frame = CameraFrame
    public typealias Event = UIEvent
    
    private let blinkIdVerifySession: BlinkIDVerifySession
    private let eventStream: BlinkIDVerifyEventStream
    private let translator: BlinkIDVerifyUXTranslator = BlinkIDVerifyUXTranslator()
    private var scanningDone = false
    private var paused = false
    private var resultContinuation: CheckedContinuation<Result, Never>?
    public private(set) var stepTimeoutDuration: TimeInterval
    private var timerTask: Task<Void, Never>?
    private var unsupportedDocumentTimerTask: Task<Void, Never>?
    
    
    /// Creates a new document verification analyzer.
    /// - Parameters:
    ///   - sdk: The document verification SDK instance
    ///   - captureSessionSettings: Settings for the capture session
    ///   - eventStream: Stream to receive UI events during scanning
    public init(
        sdk: BlinkIDVerifySdk,
        blinkIdVerifySessionSettings: BlinkIDVerifySessionSettings = BlinkIDVerifySessionSettings(),
        eventStream: BlinkIDVerifyEventStream
    ) async throws {
        self.blinkIdVerifySession = try await sdk.createScanningSession(sessionSettings: blinkIdVerifySessionSettings)
        // Change this
        self._sessionNumber = await blinkIdVerifySession.getSessionNumber()
        self.eventStream = eventStream
        self.stepTimeoutDuration = blinkIdVerifySessionSettings.stepTimeoutDuration
    }
    
    private let _sessionNumber: Int
        
    nonisolated public var sessionNumber: Int {
        return _sessionNumber
    }
    
    /// Processes a camera frame for document analysis.
    /// - Parameter image: The camera frame to analyze
    public func analyze(image: Frame) async {
        guard !paused else { return }
        
        if timerTask == nil {
            startTimer(stepTimeoutDuration)
        }
        
        let inputImage = InputImage(cameraFrame: image)
        
        do {
            let result = try await blinkIdVerifySession.process(inputImage: inputImage)
            
            let events = translator.translate(frameProcessResult: result)
            
            if events.contains(.unsupportedDocument) {
                startUnsupportedDocumentScanTimer()
            } else {
                unsupportedDocumentTimerTask?.cancel()
            }
            
            if events.contains(UIEvent.requestDocumentSide(side: .barcode)) {
                timerTask?.cancel()
                startTimer(stepTimeoutDuration)
                Task { @ProcessingActor in
                    blinkIdVerifySession.allowBarcodeStep()
                }
            }
                    
            await eventStream.send(events)

            if result.processResult?.resultCompleteness.scanningStatus == .documentScanned {
                guard !scanningDone else { return }
                scanningDone = true
                Task { @ProcessingActor in
                    let sessionResult = blinkIdVerifySession.getResult()
                    await finishScanning(with: .completed(sessionResult))
                }
            }
        } catch {
            resultContinuation?.resume(returning: .cancelled)
        }
    }
    
    private func finishScanning(with result: ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>) {
        timerTask?.cancel()
        unsupportedDocumentTimerTask?.cancel()
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
    
    /// Cancels the current document scanning session.
    public func cancel() {
        self.blinkIdVerifySession.cancelActiveProcessing()
    }
    
    /// Returns the final result of the scanning session.
    public func result() async -> ScanningResult<BlinkIDVerifyCaptureResult, BlinkIDVerifyScanningAlertType>  {
        await withCheckedContinuation { continuation in
            self.resultContinuation = continuation
        }
    }
    
    /// Pauses the document analysis.
    public func pause() {
        self.paused = true
        self.cancel()
        timerTask?.cancel()
        unsupportedDocumentTimerTask?.cancel()
    }
    
    /// Resumes the document analysis after being paused.
    public func resume() {
        guard paused else { return }
        self.blinkIdVerifySession.resumeActiveProcessing()
        
        paused = false
        startTimer(stepTimeoutDuration)
    }
    
    /// Restarts the document analysis after being paused.
    public func restart() {
        Task { @ProcessingActor in
            try self.blinkIdVerifySession.reset()
        }
        translator.resetState()
        self.resume()
    }
    
    /// Ends the current document scanning session.
    public func end() {
        pause()
        resultContinuation?.resume(returning: .ended)
        resultContinuation = nil
    }
    
    /// Stream of UI events generated during document analysis.
    nonisolated public var events: any EventStream<UIEvent> {
        eventStream
    }
    
    private func startTimer(_ interval: TimeInterval) {
        guard interval > 0.0 else { return }
        timerTask = Task() { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let nanoseconds = UInt64(interval * Double(NSEC_PER_SEC))
                try? await Task.sleep(nanoseconds: nanoseconds)
                if !Task.isCancelled {
                    await scanInterrupted(with: .timeout)
                }
            }
        }
    }
    
    private func startUnsupportedDocumentScanTimer() {
        guard unsupportedDocumentTimerTask == nil ||
              unsupportedDocumentTimerTask?.isCancelled == true else { return }

        unsupportedDocumentTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            if !Task.isCancelled {
                await self?.scanInterrupted(with: .unsupportedDocument)
            }
        }
    }
    
    private func scanInterrupted(with alertType: BlinkIDVerifyScanningAlertType) {
        pause()
        resultContinuation?.resume(returning: .interrupted(alertType))
        resultContinuation = nil
        
        Task {
            await PingManager.shared.sendPinglets()
        }
    }
}
