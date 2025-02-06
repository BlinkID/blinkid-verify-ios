// Created by Toni Krešo on 13.01.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI
import BlinkIDVerifyUX

struct ContentView: View {
    @EnvironmentObject var viewModel: BlinkIDVerifyViewModel
    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
        case .home:
            HomeScreen()
        case .error(let error):
            Text(error)
        case .success(let captureResult):
            CaptureResultView(captureResult: captureResult)
        case .scanBuiltin(let viewModel):
            ScanningUXView(viewModel: viewModel)
        case .scanCustom(let viewModel):
            CustomUIScanningView(viewModel: viewModel)
        case .serverSuccess(let verificationResult):
            VerificationResultView(verificationResult: verificationResult)
        }
        
    }
    
    @ViewBuilder
    private func HomeScreen() -> some View {
        VStack(spacing: 30) {
            Button {
                Task {
                    await viewModel.performScan()
                }
            } label: {
                Text("DocVer UI")
            }

            Button {
                Task {
                    await viewModel.performScan(customScan: true)
                }
            } label: {
                Text("Custom UI")
            }

        }
        .padding()
    }
}

#Preview {
    ContentView()
}
