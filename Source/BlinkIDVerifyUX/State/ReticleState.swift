//  Created by Toni Krešo on 13.11.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

enum ReticleState: Equatable {
    case front
    case back
    case barcode
    case detecting
    case flip
    case error(String)
    case inactive
    
    var text: String? {
        switch self {
        case .front:
            return "Scan the front side of a document"
        case .back:
            return "Scan the back side of a document"
        case .barcode:
            return "Scan the barcode"
        case .flip:
            return "Flip to the back side"
        case .error(let message):
            return message
        case .detecting, .inactive:
            return nil
        }
    }
    
    var duration: Double {
        switch self {
        case .front, .back, .barcode:
            1.0
        case .detecting:
            1.5
        case .error(_):
            2.0
        case .flip, .inactive:
            0.0
        }
    }
    
    var shouldExpire: Bool {
        switch self {
        case .front, .back, .detecting, .inactive, .flip, .barcode:
            return false
        case .error(_):
            return true
        }
    }
}
