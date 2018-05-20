import XCTest

#if !os(macOS)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(LibrariesTests.allTests),
    ]
}
#endif