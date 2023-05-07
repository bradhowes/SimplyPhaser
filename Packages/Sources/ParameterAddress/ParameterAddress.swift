import AudioUnit.AUParameters
import AUv3Support

/**
 These are the unique addresses for the runtime parameters used by the audio unit.
 */
@objc public enum ParameterAddress: UInt64, CaseIterable {
  case rate
  case depth
  case intensity
  case dry
  case wet
  case odd90
};

extension ParameterAddress {

  /// Obtain a ParameterDefinition for a parameter address enum.
  public var parameterDefinition: ParameterDefinition {
    switch self {
    case .rate: return .defFloat("rate", localized: "Rate", address: ParameterAddress.rate, range: 0.01...8,
                                 unit: .hertz, logScale: true)
    case .depth: return .defPercent("depth", localized: "Depth", address: ParameterAddress.depth, minValue: 0.1)
    case .intensity: return .defPercent("intensity", localized: "Intensity", address: ParameterAddress.intensity,
                                        minValue: 0.1, maxValue: 99.0)
    case .dry: return .defPercent("dry", localized: "Dry", address: ParameterAddress.dry)
    case .wet: return .defPercent("wet", localized: "Wet", address: ParameterAddress.wet)
    case .odd90: return .defBool("odd90", localized: "Odd 90°", address: ParameterAddress.odd90)
    }
  }
}

extension AUParameter {
  public var parameterAddress: ParameterAddress? { .init(rawValue: self.address) }
}

/// Allow enum values to serve as AUParameterAddress values.
extension ParameterAddress: ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { UInt64(self.rawValue) }
}

public extension ParameterAddressHolder {

  func setParameterAddress(_ address: ParameterAddress) { parameterAddress = address.rawValue }

  var parameterAddress: ParameterAddress? {
    let raw: AUParameterAddress = parameterAddress
    return ParameterAddress(rawValue: raw)
  }
}

extension ParameterAddress: CustomStringConvertible {
  public var description: String { "<ParameterAddress: '\(parameterDefinition.identifier)' \(rawValue)>" }
}
