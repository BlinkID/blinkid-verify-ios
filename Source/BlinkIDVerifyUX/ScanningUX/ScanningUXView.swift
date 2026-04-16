//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import SwiftUI
import BlinkIDVerify

/// Main scanning view.
/// This view consists of `CameraView` and `Reticle`.
///
/// For `UIEvent` stream, and UX logic, see ``ScanningUXModel``.
public struct ScanningUXView: View, ScanningUXProtocol, PassportAnimatableView {
    typealias GenericContentView = AnyView
    typealias ScanResult = BlinkIDVerifyCaptureResult
    typealias AlertType = BlinkIDVerifyScanningAlertType
    typealias UXModel = ScanningUXModel
    typealias EventType = UIEvent
    typealias ReticleStateMachineType = ReticleStateMachine
    typealias OnboardingStepType = OnboardingStep

    @ObservedObject var viewModel: ScanningUXModel
            
    let theme = BlinkIDVerifyTheme.shared
        
    public init(viewModel: ScanningUXModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        MainView(reticleStateMachine: viewModel.reticleStateMachine, isTorchOn: $viewModel.isTorchOn, showToast: $viewModel.isToastVisible, showSheet: $viewModel.showSheet, showLicenseErrorAlert: $viewModel.showLicenseErrorAlert, onboardingAlertTitle: "mb_onboarding_dialog_title", onboardingAlertDescription: "mb_onboarding_dialog_message", onboardingAlertImage: Image.allDetailsVisibleImage, timeoutAlertDescription: "mb_recognition_timeout_dialog_message".localizedString, flashlightWarningMessage: "mb_flashlight_warning_message".localizedString)
    }
}

// Override the ReticleView implementation in BlinkIDUXView, we have some custom things for BlinkID
extension ScanningUXView {
    @ViewBuilder
    func ReticleView(reticleStateMachine: ReticleStateMachineType) -> GenericContentView {
        AnyView(
            Group {
                VStack {
                    ZStack {
                        Reticle<ReticleStateMachineType>(diameter: Self.reticleDiameter, reticleStateMachine: reticleStateMachine)
                        if viewModel.showCardImage,
                           let cardImage = viewModel.cardImage {
                            cardImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .rotation3DEffect(.degrees(viewModel.flipCardDegrees), axis: (x: 0, y: 1, z: 0))
                                .scaleEffect(viewModel.flipCardScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showRippleView {
                            Circle()
                                .fill(.white)
                                .frame(height: Self.reticleDiameter)
                                .scaleEffect(viewModel.rippleViewScale)
                                .opacity(viewModel.rippleViewOpacity)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showSuccessImage {
                            viewModel.successImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: Self.reticleDiameter)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, .white)
                                .scaleEffect(viewModel.successImageScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.passportState.showAnimation {
                            if let orientation = viewModel.passportState.orientation {
                                switch orientation {
                                case .none:
                                    PassportAnimationView()
                                case .left90:
                                    PassportAnimationRotatedBy90LeftView()
                                case .right90:
                                    PassportAnimationRotatedBy90RightView()
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    
                    MessageContainer<ReticleStateMachineType>(theme: self.theme, stateMachine: viewModel.reticleStateMachine)
                }
            }
        )
    }
}
