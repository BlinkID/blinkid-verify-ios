//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import Foundation
import BlinkIDVerify
import CoreImage
import UIKit

/// Represents different sides of a document during the scanning process.
public enum DocumentSide: Sendable {
    /// Front side of the document
    case front
    /// Back side of the document
    case back
    /// Barcode region of the document
    case barcode
}

/// Manages the stream of UI events during document verification.
public actor BlinkIDVerifyEventStream: EventStream {
    private let events: AsyncStream<[UIEvent]>
    private let continuation: AsyncStream<[UIEvent]>.Continuation
    
    public init() {
        var continuation: AsyncStream<[UIEvent]>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
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
    private let captureSession: CaptureSession
    private let eventStream: BlinkIDVerifyEventStream
    private let translator: ScanningUXTranslator = ScanningUXTranslator()
    private var scanningDone = false
    private var paused = false
    private var resultContinuation: CheckedContinuation<ScanningResult?, Never>?
    private var stepTimeoutDuration: TimeInterval
    private var timerTask: Task<Void, Never>?
    
    /// Creates a new document verification analyzer.
    /// - Parameters:
    ///   - sdk: The document verification SDK instance
    ///   - captureSessionSettings: Settings for the capture session
    ///   - eventStream: Stream to receive UI events during scanning
    public init(
        sdk: BlinkIDVerifySdk,
        captureSessionSettings: CaptureSessionSettings = CaptureSessionSettings(capturePolicy: .video),
        eventStream: BlinkIDVerifyEventStream,
        stepTimeoutDuration: TimeInterval = 15.0
    ) async {
        self.captureSession = await sdk.createScanningSession(sessionSettings: captureSessionSettings)
        self.eventStream = eventStream
        self.stepTimeoutDuration = 10.0
    }
    
    /// Processes a camera frame for document analysis.
    /// - Parameter image: The camera frame to analyze
    public func analyze(image: CameraFrame) async {
        guard !paused else { return }
        
        if timerTask == nil {
            startTimer(stepTimeoutDuration)
        }
        
        let inputImage = InputImage(cameraFrame: image)
        
        do {
            let result = try await captureSession.process(inputImage: inputImage)
            
            let events = translator.translate(
                resultCompleteness: result.resultCompleteness,
                frameAnalysisResult: result.frameAnalysisResult,
                session: self.captureSession
                )
            
            if events.contains(.requestDocumentSide(side: .back)) {
                timerTask?.cancel()
            }
                    
            await eventStream.send(events)

            if result.resultCompleteness.overallFlowFinished {
                guard !scanningDone else { return }
                scanningDone = true
                Task { @ProcessingActor in
                    let sessionResult = captureSession.getResult()
                    
                    await finishScanning(with: .completed(sessionResult))
                }
            }
        } catch {
            resultContinuation?.resume(returning: .cancelled)
        }
    }
    
    private func finishScanning(with result: ScanningResult) {
        timerTask?.cancel()
        timerTask = nil
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
    
    /// Cancels the current document scanning session.
    public func cancel() {
        self.captureSession.cancelActiveProcessing()
    }
    
    /// Ends the current document scanning session.
    public func end() {
        pause()
        resultContinuation?.resume(returning: nil)
        resultContinuation = nil
    }
    
    /// Returns the final result of the scanning session.
    public func result() async -> ScanningResult? {
        await withCheckedContinuation { continuation in
            self.resultContinuation = continuation
        }
    }
    
    /// Pauses the document analysis.
    public func pause() {
        self.paused = true
        self.cancel()
        timerTask?.cancel()
    }
    
    /// Resumes the document analysis after being paused.
    public func resume() {
        guard paused else { return }
        
        paused = false
        startTimer(stepTimeoutDuration)
    }
    
    /// Restarts the document analysis after being paused.
    public func restart() {
        translator.resetState()
        resume()
    }
    
    /// Stream of UI events generated during document analysis.
    nonisolated public var events: any EventStream {
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
                    await timerFired()
                }
            }
        }
    }
    
    private func timerFired() {
        self.paused = true
        self.cancel()
        resultContinuation?.resume(returning: .timeout)
        resultContinuation = nil
        captureSession.restart()
    }
}
