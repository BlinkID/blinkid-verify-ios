//
//  PassportAnimationViews.swift
//  DocumentVerificationUX
//
//  Shared passport animation SwiftUI views.
//

import SwiftUI

// MARK: - Passport Animation Values
typealias AnimationOffset = (x: CGFloat, y: CGFloat)

struct PassportAnimationValues {
    var opacity: Double = 1.0
    var offsetY: CGFloat = 0
    static let offsets: AnimationOffset = (x: 32, y: 32)
}

// MARK: - Protocol for views with passport animation support
@MainActor
protocol PassportAnimatableView {
    associatedtype PassportVM: PassportAnimatable
    var viewModel: PassportVM { get }
}

extension PassportAnimatableView where Self: View {

    @ViewBuilder
    func PassportAnimationView() -> some View {
        VStack(spacing: 0) {
            // Top passport image
            viewModel.passportState.toImage
                .opacity(viewModel.passportState.topImageOpacity)

            ZStack(alignment: .center) {
                // Bottom passport image
                viewModel.passportState.fromImage
                    .opacity(viewModel.passportState.bottomImageOpacity)

                // Highlight image that slides
                viewModel.passportState.highlightImage
                    .offset(y: -viewModel.passportState.highlightOffset)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(y: -PassportAnimationValues.offsets.y)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        viewModel.passportState.highlightDistance = geometry.size.height / 2
                    }
            }
        )
    }

    @ViewBuilder
    func PassportAnimationRotatedBy90LeftView() -> some View {
        PassportAnimationView()
            .rotationEffect(.degrees(-90))
            .offset(x: PassportAnimationValues.offsets.x, y: -PassportAnimationValues.offsets.y)
    }

    @ViewBuilder
    func PassportAnimationRotatedBy90RightView() -> some View {
        PassportAnimationView()
            .rotationEffect(.degrees(90))
            .offset(x: -PassportAnimationValues.offsets.x, y: -PassportAnimationValues.offsets.y)
    }
}
