import XCTest
@testable import Libraries

final class LibrariesTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Libraries().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
