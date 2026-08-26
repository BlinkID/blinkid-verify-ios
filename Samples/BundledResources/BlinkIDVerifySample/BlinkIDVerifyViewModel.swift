// Created by Toni Krešo on 13.01.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI
import Combine
import BlinkIDVerify
import BlinkIDVerifyUX

enum UIState {
    case loading
    case home
    case scanBuiltin(ScanningUXModel)
    case scanCustom(CustomScanningViewModel)
    case error(String)
    case success(BlinkIDVerifyCaptureResult)
    case serverSuccess(BlinkIDVerifyEndpointResponse)
}

@MainActor
final class BlinkIDVerifyViewModel: ObservableObject {
    private let licenseKey = "sRwDAAEpY29tLm1pY3JvYmxpbmsuRG9jdW1lbnRWZXJpZmljYXRpb25TYW1wbGUBCk1pY3JvYmxpbmsrTqiAFrB7/SM4U6JgO29Dkmhq3gruMihZLlJnEh/QG8PRg7HXf0UqJmNTfj1t/a0Wyeb5154oCkV9um6CYZkZN9ykklnaybi/Fg2iHNni5xGZbzu4FAMc+YXdbItRgGDCA3GHms3+"
    private var sdkInstance: BlinkIDVerifySdk?
    private var cancellables = Set<AnyCancellable>()
    @Published var state: UIState = .loading
    
    init() {
        Task {
            await initializeSdk()
        }
    }
    
    func initializeSdk() async {
        do {
            let settings = BlinkIDVerifySdkSettings(licenseKey: licenseKey, downloadResources: false, bundleURL: Bundle.main.bundleURL)
            sdkInstance = try await BlinkIDVerifySdk.createBlinkIDVerifySdk(withSettings: settings)
        } catch {
            state = .error(error.localizedDescription)
        }
        state = .home
    }
    
    func performScan(customScan: Bool = false) async {
        guard let sdkInstance = sdkInstance
        else {
            state = .error("Failed to perform scan due to missing sdk")
            return
        }
        let analyzer = try? await BlinkIDVerifyAnalyzer(sdk: sdkInstance, eventStream: BlinkIDVerifyEventStream())
        
        if let analyzer = analyzer {
            if customScan {
                let scanningUxModel = CustomScanningViewModel(analyzer: analyzer)
                scanningUxModel.$captureResult
                    .sink { [weak self] captureResult in
                        if let captureResult = captureResult {
                            self?.state = .success(captureResult)
                        } else {
                            self?.state = .home
                        }
                    }
                    .store(in: &cancellables)
                state = .scanCustom(scanningUxModel)
            } else {
                let scanningUxModel = ScanningUXModel(analyzer: analyzer)
                scanningUxModel.$captureResult
                    .sink { [weak self] captureResultState in
                        if let captureResultState {
                            if let captureResult = captureResultState.captureResult {
                                self?.state = .success(captureResult)
                            }
                            else {
                                self?.state = .home
                            }
                        }
                    }
                    .store(in: &cancellables)
                
                state = .scanBuiltin(scanningUxModel)
            }
        }
    }
    
    func processOnServer(result: BlinkIDVerifyCaptureResult) {
        state = .loading
        let docVerSettings = BlinkIDVerifyServiceSettings(verificationServiceBaseUrl: "us-east.verify.microblink.com", token: "<insert_your_token_here>")
        let docVerService = BlinkIDVerifyService(settings: docVerSettings)

        Task {
            do {
                var blinkIDVerifyRequest = result.toBlinkIDVerifyRequest()
                
                var options = BlinkIDVerifyProcessingOptions()
                options.returnFullDocumentImage = true
                options.returnFaceImage = true
                options.treatExpirationAsFraud = true
                options.screenMatchLevel = .level5
                options.photocopyMatchLevel = .level5
                options.barcodeAnomalyMatchLevel = .level4
                options.returnImageFormat = .jpg
                
                blinkIDVerifyRequest.options = options
                
                var useCase = BlinkIDVerifyProcessingUseCase()
                useCase.documentVerificationPolicy = .strict
                useCase.verificationContext = .inPerson
                useCase.manualReviewStrategy = .acceptedOnly
                blinkIDVerifyRequest.useCase = useCase
                
                let result = try await docVerService.verify(blinkIdVerifyRequest: blinkIDVerifyRequest)
                if let verificationResult = result {
                    state = .serverSuccess(verificationResult)
                } else {
                    state = .home
                }
            }
            catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
