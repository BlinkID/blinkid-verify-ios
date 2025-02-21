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
    private let licenseKey = "sRwDAAEpY29tLm1pY3JvYmxpbmsuRG9jdW1lbnRWZXJpZmljYXRpb25TYW1wbGUBKWNvbS5taWNyb2JsaW5rLkRvY3VtZW50VmVyaWZpY2F0aW9uU2FtcGxl/cT+zgvB/gf4RsGV/1+mBYlGn+3Vzqyuyqb8SYgyT8hnZPe3O1npglqaCuqP8uWstgH6Kwsg1I0px/Z/83ox59L25kNnXz0ZIG0/vSw8M0vZ3COws1lM4mPKWlZWqu3OyXAos4ihVawoV3Gyzmg="
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
            print("tu")
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
        let analyzer = await BlinkIDVerifyAnalyzer(sdk: sdkInstance, eventStream: BlinkIDVerifyEventStream())
        
        if customScan {
            let scanningUxModel = CustomScanningViewModel(analyzer: analyzer)
            scanningUxModel.$captureResult
                .sink { [weak self] captureResult in
                    if let captureResult {
                        if let captureRes = captureResult.captureResult {
                            self?.state = .success(captureRes)
                        }
                        else {
                            self?.state = .home
                        }
                }
                .store(in: &cancellables)
            
            state = .scanCustom(scanningUxModel)
        } else {
            let scanningUxModel = ScanningUXModel(analyzer: analyzer)
            scanningUxModel.$captureResult
                .sink { [weak self] captureResultState in
                    if let captureResultState = captureResultState {
                        switch captureResultState {
                        case .result(let captureResult):
                            self?.state = .success(captureResult)
                        case .empty:
                            self?.state = .home
                        }
                    }
                }
                .store(in: &cancellables)
            
            state = .scanBuiltin(scanningUxModel)
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
