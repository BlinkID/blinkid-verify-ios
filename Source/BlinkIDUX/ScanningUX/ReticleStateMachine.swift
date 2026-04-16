//  Created by Toni Krešo on 13.02.2026..
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import Combine
import Foundation

public class ReticleStateMachine: ReticleStateMachineProtocol {
    public typealias ReticleStateType = ReticleState
    
    @Published public var reticleState: ReticleState = .initialState
    public var fallbackState: ReticleState = .initialState
    public var lastReticleStateChange: TimeInterval = Date().timeIntervalSince1970
    public var eventCounter: [ReticleState : Int] = [:]
    public var reticleStateIsInterruptible: Bool = false
    private var lastPassportErrorOrientation: PassportOrientation? = nil
    
    public func resetCustomProperties() {
        lastPassportErrorOrientation = nil
    }
    
    public func calculateState(using mostFrequentState: ReticleState) -> ReticleState {
        if mostFrequentState == .error("mb_scanning_wrong_page_top") {
            lastPassportErrorOrientation = PassportOrientation.none
        } else if mostFrequentState == .error("mb_scanning_wrong_page_left") {
            lastPassportErrorOrientation = .left90
        } else if mostFrequentState == .error("mb_scanning_wrong_page_right") {
            lastPassportErrorOrientation = .right90
        }

        if case .passport(let message) = mostFrequentState {
            if message == "mb_instructions_scan_barcode_last_page".localizedString {
                return mostFrequentState
            } else {
                if let lastPassportErrorOrientation = lastPassportErrorOrientation {
                    switch lastPassportErrorOrientation {
                    case .none:
                        return ReticleState.passport("mb_top_page_instructions".localizedString)
                    case .left90:
                        return ReticleState.passport("mb_left_page_instructions".localizedString)
                    case .right90:
                        return ReticleState.passport("mb_right_page_instructions".localizedString)
                    }
                }
            }
        }
        return mostFrequentState
    }
    
    public func forcedState(state: ReticleState){
        if case .passport(let message) = state {
            if message == "mb_top_page_instructions" {
                lastPassportErrorOrientation = PassportOrientation.none
            } else if message == "mb_left_page_instructions" {
                lastPassportErrorOrientation = .left90
            } else if message == "mb_right_page_instructions" {
                lastPassportErrorOrientation = .right90
            }
        }
    }
}
