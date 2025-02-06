//  Created by Toni Krešo on 20.09.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import AVFoundation
import SwiftUI
import Swift
import BlinkIDVerify

/// Main scanning view.
/// This view consists of `CameraView` and `Reticle`.
///
/// For `UIEvent` stream, and UX logic, see ``ScanningUXModel``.
public struct ScanningUXView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var viewModel: ScanningUXModel
            
    private static let reticleDiameter = 88.0
    private let theme = BlinkIDVerifyTheme.shared
        
    public init(viewModel: ScanningUXModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.camera.status == .unauthorized {
                CameraPermissionView()
            } else {
                GeometryReader { geometry in
                    ZStack {
                        CameraView(camera: viewModel.camera)
                            .statusBarHidden(true)
                            .ignoresSafeArea()
                        VStack(spacing: 8) {
                            ReticleView()
                            Spacer()
                        }
                        .offset(y: geometry.size.height / 2 - Self.reticleDiameter / 2)
                        VStack {
                            HStack {
                                CancelButton()
                                Spacer()
                                if viewModel.camera.isTorchSupported {
                                    TorchButton()
                                }
                            }
                            Spacer()
                            HStack {
                                Spacer()
                                HelpButton()
                            }
                        }
                        .disabled(viewModel.showIntroductionAlert)
                        .padding()
                        
                        if viewModel.showIntroductionAlert {
                            OnboardingAlertView(viewModel: viewModel)
                                .zIndex(1)
                                .transition(.offset(y: geometry.size.height))
                        }
                    }
                }
                .onChange(of: viewModel.reticleState) { newValue in
                    if let text = newValue.text {
                        UIAccessibility.post(notification: .announcement, argument: text)
                    }
                }
                .sheet(isPresented: $viewModel.showSheet) {
                    OnboardingSheetView()
                        .presentationDetents([.height(600)])
                        .onAppear {
                            viewModel.pauseScanning()
                        }
                        .onDisappear {
                            viewModel.resumeScanning()
                        }
                }
                .alert(isPresented: $viewModel.showTimeoutAlert) {
                    Alert(
                        title: Text("Scan unsuccessful"),
                        message: Text("Unable to read the document. Please try again."),
                        dismissButton: .default(Text("Retry"))
                    )
                }
                .alert("Scanning not available", isPresented: $viewModel.showLicenseErrorAlert) {
                    Button("Cancel", role: .cancel) { }
                }
                .onAppear {
                    if viewModel.shouldShowIntroductionAlert {
                        viewModel.presentAlert()
                    } else {
                        UIAccessibility.post(notification: .screenChanged, argument: ReticleState.front.text)
                    }
                }
            }
        }
        .task {
            // Start the capture pipeline.
            await viewModel.camera.start()
            await viewModel.analyze()
        }
        .onDisappear {
            viewModel.stopEventHandling()
            Task {
                await viewModel.camera.stop()
            }
        }
    }
    
    private func scaleForRotation(_ rotation: Double) -> CGFloat {
        let scaleFactor = Swift.abs(cos(rotation * .pi / 180))
        return 0.3 + 0.7 * scaleFactor
    }
}

extension ScanningUXView {
    @ViewBuilder
    private func ReticleView() -> some View {
        ZStack {
            Reticle(diameter: Self.reticleDiameter, reticleState: $viewModel.reticleState)
            if viewModel.showCardImage {
                viewModel.cardImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: 60)
                    .rotation3DEffect(.degrees(viewModel.flipCardDegrees), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(viewModel.flipCardScale)
            }
            if viewModel.showRippleView {
                Circle()
                    .fill(.white)
                    .frame(height: Self.reticleDiameter)
                    .scaleEffect(viewModel.rippleViewScale)
                    .opacity(viewModel.rippleViewOpacity)
            }
            if viewModel.showSuccessImage {
                viewModel.successImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: Self.reticleDiameter)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .scaleEffect(viewModel.successImageScale)
            }
        }
        .frame(height: Self.reticleDiameter)
        if let text = viewModel.reticleState.text {
            MessageContainer(text: text)
                .accessibilityHidden(true)
        }
    }
    
    @ViewBuilder
    private func CancelButton() -> some View {
        Button {
            viewModel.closeButtonTapped()
        } label: {
            viewModel.cancelImage
                .toolbarButton()
        }
        .accessibilityLabel(viewModel.cancelLabel)
        .accessibilityHint(viewModel.cancelHint)
        .accessibilitySortPriority(3)
        .accessibilityHidden(viewModel.showIntroductionAlert)
    }
    
    @ViewBuilder
    private func TorchButton() -> some View {
        Button {
            viewModel.isTorchOn.toggle()
        } label: {
            viewModel.torchImage
                .toolbarButton(isOn: $viewModel.isTorchOn)
        }
        .accessibilityLabel(viewModel.torchLabel)
        .accessibilityHint(viewModel.torchHint)
        .accessibilitySortPriority(2)
        .accessibilityHidden(viewModel.showIntroductionAlert)
    }
    
    private func HelpButton() -> some View {
        Button {
            viewModel.helpButtonTapped()
        } label: {
            viewModel.helpImage
                .font(.largeTitle)
                .imageScale(.medium)
                .symbolRenderingMode(.palette)
                .foregroundStyle(theme.helpButtonForegroundColor, theme.helpButtonBackgroundColor)
        }
        .accessibilityLabel(viewModel.helpLabel)
        .accessibilityHint(viewModel.helpHint)
        .accessibilitySortPriority(1)
        .accessibilityHidden(viewModel.showIntroductionAlert)
    }
}
