import XCTest
@testable import Parameters

final class FilterPresetTests: XCTestCase {

  func testInit() throws {
    let a = FilterPreset(rate: 1.0, depth: 2.0, intensity: 3.0, dry: 5.0, wet: 6.0, odd90: 1.0)
    XCTAssertEqual(a.rate, 1.0)
    XCTAssertEqual(a.depth, 2.0)
    XCTAssertEqual(a.intensity, 3.0)
    XCTAssertEqual(a.dry, 5.0)
    XCTAssertEqual(a.wet, 6.0)
    XCTAssertEqual(a.odd90, 1.0)
  }
}
