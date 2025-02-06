//  Created by Toni Krešo on 22.11.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case allFieldsVisible, harshLight, keepStill
    
    var id: Int { rawValue }
    
    var image: Image {
        switch self {
        case .allFieldsVisible:
            return Image.allFieldsVisibleImage
        case .harshLight:
            return Image.harshLightImage
        case .keepStill:
            return Image.keepStillImage
        }
    }
    
    var title: String {
        switch self {
        case .allFieldsVisible:
            return "Keep all the fields visible"
        case .harshLight:
            return "Watch out for harsh light"
        case .keepStill:
            return "Keep still while scanning"
        }
    }
    
    var description: String {
        switch self {
        case .allFieldsVisible:
            return "Make sure you aren’t covering parts of the document with a finger, including the bottom lines. Also, watch out for hologram reflections that go over the document fields."
        case .harshLight:
            return "Avoid direct harsh light because it reflects from the document and can make parts of the document unreadable. If you can’t read data on the document, it won’t be visible to the camera either."
        case .keepStill:
            return "Try to keep the phone and document still while scanning. Moving either can blur the image and make data on the document unreadable."
        }
    }
}
