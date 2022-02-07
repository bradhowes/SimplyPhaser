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
    case .rate: return .defFloat("rate", localized: "Rate", address: ParameterAddress.rate,
                                 range: 0.01...20, unit: .hertz, logScale: true)
    case .depth: return .defPercent("depth", localized: "Depth", address: ParameterAddress.depth)
    case .intensity: return .defFloat("intensity", localized: "Intensity", address: ParameterAddress.intensity)
    case .dry: return .defPercent("dry", localized: "Dry", address: ParameterAddress.dry)
    case .wet: return .defPercent("wet", localized: "Wet", address: ParameterAddress.wet)
    case .odd90: return .defBool("odd90", localized: "Odd 90°", address: ParameterAddress.odd90)
    }
  }
}

/// Allow enum values to serve as AUParameterAddress values.
extension ParameterAddress: ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { UInt64(self.rawValue) }
}

/// Allow UI elements with a `tag` to hold ParameterAddress values
public extension TagHolder {
  func setParameterAddress(_ address: ParameterAddress) { tag = Int(address.rawValue) }
  var parameterAddress: ParameterAddress? { tag >= 0 ? ParameterAddress(rawValue: UInt64(tag)) : nil }
}
