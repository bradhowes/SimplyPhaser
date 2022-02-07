// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation
import os

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject {
  
  private let log = Logging.logger("FilterParameters")
  
  /// AUParameter definitions for all user-modifiable parameters
  public let parameters: [AUParameter] = [
    AUParameterTree.createParameter(withIdentifier: "rate", name: "Rate", address: .rate,
                                    min: 0.02, max: 20.0, unit: .hertz),
    AUParameterTree.createParameter(withIdentifier: "depth", name: "Depth", address: .depth,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "intensity", name: "Intensity", address: .intensity,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "dry", name: "Dry", address: .dryMix,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "wet", name: "Wet", address: .wetMix,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "odd90", name: "Odd 90", address: .odd90, min: 0, max: 1,
                                    unit: .boolean)
  ]
  
  /// Predefined presets for the effect
  public let factoryPresetValues:[(name: String, preset: FilterPreset)] = [
    ("Gently Sweeps", FilterPreset(rate: 0.04, depth: 50,intensity: 75, dryMix: 50, wetMix: 50, odd90: 0)),
    ("Slo-Jo", FilterPreset(rate: 0.10, depth: 100,intensity: 90, dryMix: 50, wetMix: 50, odd90: 1)),
    ("Psycho Phase", FilterPreset(rate: 1.0, depth: 40, intensity: 90, dryMix: 0, wetMix: 100, odd90: 1)),
    ("Phaser Blast", FilterPreset(rate: 1.0, depth: 100, intensity: 90, dryMix: 0, wetMix: 100, odd90: 0)),
    ("Noxious", FilterPreset(rate: 20.0, depth: 30, intensity: 75, dryMix: 0, wetMix: 100, odd90: 1))
  ]
  
  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree
  
  /// Accessor for the rate parameter
  public var rate: AUParameter { parameters[.rate] }
  /// Accessor for the depth parameter
  public var depth: AUParameter { parameters[.depth] }
  /// Accessor for the intensity parameter
  public var intensity: AUParameter { parameters[.intensity] }
  /// Accessor for the dryMix parameter
  public var dryMix: AUParameter { parameters[.dryMix] }
  /// Accessor for the wetMix parameter
  public var wetMix: AUParameter { parameters[.wetMix] }
  /// Accessor for the odd90 parameter
  public var odd90: AUParameter { parameters[.odd90] }
  
  /**
   Create a new AUParameterTree for the defined filter parameters.
   
   Installs three closures in the tree:
   - one for providing values
   - one for accepting new values from other sources
   - and one for obtaining formatted string values
   
   - parameter parameterHandler the object to use to handle the AUParameterTree requests
   */
  init(parameterHandler: AUParameterHandler) {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    
    parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
    parameterTree.implementorValueProvider = { parameterHandler.get($0) }
    parameterTree.implementorStringFromValueCallback = { param, value in
      let formatted = self.formatValue(param.address.filterParameter, value: param.value)
      os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
             param.address, param.value, formatted)
      return formatted
    }
  }
}

extension AudioUnitParameters {
  
  /**
   Obtain the parameter using the parameter address as an index
   
   - parameter address: the parameter to return
   - returns: the AUParameter at the given address
   */
  public subscript(address: FilterParameterAddress) -> AUParameter { parameters[address] }
  
  /**
   Obtain a value-to-string formatting function for a given parameter.
   
   - parameter address: the parameter to format
   - returns: function that will convert a parameter value into a string
   */
  public func valueFormatter(_ address: FilterParameterAddress) -> (AUValue) -> String {
    let unitName = self[address].unitName ?? ""
    let separator: String = {
      switch address {
      case .rate: return " "
      default: return ""
      }
    }()
    
    let format: String = formatting(address)
    return { value in String(format: format, value) + separator + unitName }
  }
  
  /**
   Obtain a formatted value for a given parameter value
   
   - parameter address: the parameter to format
   - parameter value: the value to format
   - returns: the formatted string representation
   */
  public func formatValue(_ address: FilterParameterAddress?, value: AUValue) -> String {
    guard let address = address else { return "?" }
    return String(format: formatting(address), value)
  }
  
  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ preset: FilterPreset) {
    self.rate.value = preset.rate
    self.depth.value = preset.depth
    self.intensity.value = preset.intensity
    self.dryMix.value = preset.dryMix
    self.wetMix.value = preset.wetMix
    self.odd90.value = preset.odd90
  }
}

extension AudioUnitParameters {
  private func formatting(_ address: FilterParameterAddress) -> String {
    switch address {
    case .rate: return "%.2f"
    case .depth, .intensity: return "%.2f"
    case .dryMix, .wetMix: return "%.0f"
    case .odd90: return "%.0f"
    default: return "?"
    }
  }
}

private extension Array where Element == AUParameter {
  subscript(index: FilterParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}
