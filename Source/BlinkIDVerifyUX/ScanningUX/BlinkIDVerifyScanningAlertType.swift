//  Created by Toni Krešo on 25.02.2025..
//  Copyright (c) Microblink. All rights reserved.
//  This code is provided for use as-is and may not be copied, modified, or redistributed.
//

/// Scanning alert type
public enum BlinkIDVerifyScanningAlertType: Sendable, AlertTypeProtocol {
    /// Scanning session timed out.
    case timeout
    
    public var title: String {
        switch self {
        case .timeout:
            return "mb_recognition_timeout_dialog_title".localizedString
        }
    }
    
    public var description: String {
        switch self {
        case .timeout:
            return "mb_recognition_timeout_dialog_message".localizedString
        }
    }
}
