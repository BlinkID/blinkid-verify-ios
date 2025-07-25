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
public struct ScanningUXView: View, ScanningUXProtocol {
    typealias GenericContentView = AnyView
    typealias ScanResult = BlinkIDVerifyCaptureResult
    typealias AlertType = BlinkIDVerifyScanningAlertType
    typealias UXModel = ScanningUXModel

    @ObservedObject var viewModel: ScanningUXModel
            
    let theme = BlinkIDVerifyTheme.shared
        
    public init(viewModel: ScanningUXModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        MainView(reticleState: $viewModel.reticleState, isTorchOn: $viewModel.isTorchOn, showToast: $viewModel.isToastVisible, showSheet: $viewModel.showSheet, showScanningAlert: $viewModel.showScanningAlert, showLicenseErrorAlert: $viewModel.showLicenseErrorAlert)
    }
}
