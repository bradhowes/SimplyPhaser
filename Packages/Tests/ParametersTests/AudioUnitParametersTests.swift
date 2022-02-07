import AUv3Support
import XCTest
@testable import Parameters
import Kernel

class MockParameterHandler: AUParameterHandler {
  var mapping = [AUParameterAddress: AUValue]()
  func set(_ parameter: AUParameter, value: AUValue) { mapping[parameter.address] = value }
  func get(_ parameter: AUParameter) -> AUValue { mapping[parameter.address] ?? 0.0 }
}

final class AudioUnitParametersTests: XCTestCase {

  func testOne() throws {
  }

  func testTwo() throws {
  }
}
