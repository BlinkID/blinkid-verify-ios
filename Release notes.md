# Release notes

## 3.8.1

- Fix nested package results:
    - Correct issues with returning results when the package is embedded inside another framework
- Implement timeout error for downloads:
    - Introduce a specific `timeout` error to handle cases where resource downloads exceed the expected duration.
- Extend download timeout duration:
    - Increase the default timeout from 3 to 30 seconds to better support weak internet connections.

## 3.8.0

- BlinkIDVerify initial release
