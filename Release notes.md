# Release notes

## 3.14.2

### Bugfixes
- Fixed issue with verify request affected by endpoint API changes

## 3.14.1

### Improvements
- Added the option to use the front-facing camera for scanning. You can select front-facing camera through `ScanningUXSettings` property of `ScanningUXModel` and `BlinkIDUXModel`.
- Added haptics to the scanning process. Haptics can be disabled in `ScanningUXSettings`

### Breaking API Changes
- Removed `shouldShowIntroductionAlert` and `showHelpButton` from `ScanningUXModel` and `BlinkIDUXModel` init. They are now included in the `ScanningUXSettings` property.
- Added `ScanningUXSettings` to `ScanningUXModel` and `BlinkIDUXModel` init

## 3.14.0

### What's New
- Update to BlinkID v7.4 for document capturing and extraction
- Improved document coverage globally with new document version support and new document types
- Improved data extraction accuracy for Quebec and Ontario Healthcare cards

### Bugfixes
- Fixed document number extraction from Canada/Nunavut barcodes
- Fixed core data concurrency crash when using com.apple.CoreData.ConcurrencyDebug flag

#### Platform API changes
- Complete scanning instruction messages revamp - the scanning session is now more stable and cleaner, which ensures a better scanning experience
- Added "Demo" overlay for the demo licenses (non-production)
- Added "Powered by Microblink" overlay option for licenses with this enabled
- Added a separate timeout timer for the Barcode step
- Updated help screens with new illustrations
- Updated "Need help?" tooltip triggers
- Updated translations for Croatian language
- `dependentsInfo` in `VizResult` is now nullable
- Fixed data match overall result

#### Breaking API changes
- Removed `stepTimeoutDuration` from `BlinkIDVerifyAnalyzer` init as it is stored in `CaptureSessionSettings`
  - fix by setting `stepTimeoutDuration` in `CaptureSessionSettings`, remove from `BlinkIDVerifyAnalyzer` init

## 3.9.1

- Bug fixes:
    - Fix `lastName` BlinkID extraction 

## 3.9.0

### BlinkID integration
- *BlinkID SDK* is now fully integrated into BlinkID Verify SDK. 
    - All BlinkID-specific functionalities, like document extraction, may now be used in a session completely independent of the Verify session.
    - There is no need to declare BlinkID dependencies as all of the files are automatically included.

### API changes:
- added UI localization for 22 additional languages

## 3.8.1

- Fix nested package results:
    - Correct issues with returning results when the package is embedded inside another framework
- Implement timeout error for downloads:
    - Introduce a specific `timeout` error to handle cases where resource downloads exceed the expected duration.
- Extend download timeout duration:
    - Increase the default timeout from 3 to 30 seconds to better support weak internet connections.

## 3.8.0

- BlinkIDVerify initial release
