//
//  CameraFrameAnalyzer.swift
//  DocumentVerification
//
//  Created by Jura Skrlec on 09.12.2024..
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

import Foundation
import AVFoundation
import CoreVideo
import BlinkIDVerify

/// Result of a document scanning session.
@ProcessingActor
public enum ScanningResult: Sendable {
    /// Scanning completed successfully with captured document data
    case completed(any CaptureResult)
    /// Scanning was cancelled by the user or system
    case cancelled
    /// Scanning session timed out
    case timeout
}

/// Protocol for streaming events during document processing.
public protocol EventStream: Sendable {
    /// Asynchronous stream of UI events
    var stream: AsyncStream<[UIEvent]> { get async }
}

/// A protocol that represents the interface to the features of Microblink's analyzer.
public protocol CameraFrameAnalyzer : Sendable {
    
    /// Analyze the ``CameraFrame``
    func analyze(image: CameraFrame) async
    
    /// Cancel ``CameraFrame`` analyzation.
    func cancel() async
    
    /// Pause ``CameraFrame`` analyzation.
    func pause() async
    
    /// Resume ``CameraFrame`` analyzation.
    func resume() async
    
    /// Restart ``CameraFrame`` analyzation.
    func restart() async
    
    /// End ``CameraFrame`` analyzation.
    func end() async
    
    /// Get analyzer result when analyzer is finished.
    func result() async -> ScanningResult?
    
    /// Get stream of UI Events. 
    var events: any EventStream { get }
}
