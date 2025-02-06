//  Created by Toni Krešo on 06.12.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import SwiftUI

struct OnboardingAlertView: View {
    @ObservedObject private var viewModel: ScanningUXModel
    @State private var orientation = UIDevice.current.orientation
    @State private var contentHeight: CGFloat = 40
    private let theme = BlinkIDVerifyTheme.shared
    
    init(viewModel: ScanningUXModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if orientation.isPortrait || orientation == .unknown {
                VStack(alignment: .center) { bodyContent }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .accessibilitySortPriority(2)
            } else {
                HStack(alignment: .center) { bodyContent }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .accessibilitySortPriority(2)
            }
            Divider()
            Button {
                viewModel.dismissAlert()
            } label: {
                Text("Done")
                    .bold()
                    .font(theme.alertButtonFont)
                    .foregroundStyle(theme.alertButtonColor)
            }
            .padding(.vertical, 10)
            .accessibilitySortPriority(1)
        }
        .background(theme.alertBackgroundColor)
        .clipShape(
            RoundedRectangle(cornerRadius: 14.0)
        )
        .padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onRotate { newOrientation in
            if !newOrientation.isFlat {
                orientation = newOrientation
            }
        }
    }
    
    var bodyContent: Group< some View > {
        Group {
            if !isPortrait {
                image
            }
            
            ScrollView {
                VStack(alignment: isPortrait ? .center : .leading, spacing: 10) {
                    titleText
                    if isPortrait {
                        image
                    }
                    descriptionText
                }
                .overlay(
                    GeometryReader { geo in
                        Color.clear.preference(key: HeightPreferenceKey.self, value: geo.size.height)
                    })
            }
            .frame(maxHeight: contentHeight, alignment: .center)
            .onPreferenceChange(HeightPreferenceKey.self) {
                contentHeight = $0
            }
        }
    }
    
    var isPortrait: Bool {
        orientation.isPortrait || orientation == .unknown
    }
    
    var titleText: some View {
        Text("Keep all the details visible")
            .bold()
            .font(theme.alertTitleFont)
            .multilineTextAlignment(isPortrait ? .center : .leading)
            .foregroundStyle(theme.alertTitleColor)
            .accessibilitySortPriority(2)
    }
    
    var descriptionText: some View {
        Text("Make sure you keep the document well lit. All document fields should be visible on the camera screen.")
            .font(theme.alertDescriptionFont)
            .multilineTextAlignment(isPortrait ? .center : .leading)
            .foregroundStyle(theme.alertDescriptionColor)
            .accessibilitySortPriority(1)
    }
    
    var image: some View {
        Image.allDetailsVisibleImage
            .resizable()
            .scaledToFit()
            .frame(width: 220)
            .accessibilityHidden(true)
    }
}
