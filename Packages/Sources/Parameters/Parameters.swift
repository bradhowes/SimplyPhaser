// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Foundation
import ParameterAddress
import os.log

private extension Array where Element == AUParameter {
  subscript(index: ParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject, ParameterSource {

  private let log = Shared.logger("AudioUnitParameters")

  /// Array of AUParameter entities created from ParameterAddress value definitions.
  public let parameters: [AUParameter] = ParameterAddress.allCases.map { $0.parameterDefinition.parameter }

  /// Array of 2-tuple values that pair a factory preset name and its definition
  public let factoryPresetValues: [(name: String, preset: Configuration)] = [
    ("Gently Sweeps", .init(rate: 0.04, depth: 50,intensity: 75, dry: 50, wet: 50, odd90: 0)),
    ("Slo-Jo", .init(rate: 0.10, depth: 100,intensity: 90, dry: 50, wet: 50, odd90: 1)),
    ("Psycho Phase", .init(rate: 1.0, depth: 40, intensity: 90, dry: 0, wet: 100, odd90: 1)),
    ("Phaser Blast", .init(rate: 1.0, depth: 100, intensity: 90, dry: 0, wet: 100, odd90: 0)),
    ("Noxious", .init(rate: 20.0, depth: 30, intensity: 75, dry: 0, wet: 100, odd90: 1))
  ]

  /// Array of `AUAudioUnitPreset` for the factory presets.
  public var factoryPresets: [AUAudioUnitPreset] {
    factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name ) }
  }

  /// Apply a factory preset -- user preset changes are handled by changing AUParameter values through the audio unit's
  /// `fullState` attribute.
  public func useFactoryPreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].preset)
    }
  }

  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree

  /**
   Create a new AUParameterTree for the defined filter parameters.
   */
  override public init() {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    installParameterValueFormatter()
  }
}

extension AudioUnitParameters {

  private var missingParameter: AUParameter { fatalError() }

  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  private func installParameterValueFormatter() {
    parameterTree.implementorStringFromValueCallback = { param, valuePtr in
      let value: AUValue
      if let valuePtr = valuePtr {
        value = valuePtr.pointee
      } else {
        value = param.value
      }
      return param.displayValueFormatter(value)
    }
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  private func setValues(_ configuration: Configuration) {
    self[.rate].value = configuration.rate
    self[.depth].value = configuration.depth
    self[.intensity].value = configuration.intensity
    self[.dry].value = configuration.dry
    self[.wet].value = configuration.wet
    self[.odd90].value = configuration.odd90
  }
}

extension AUParameter: AUParameterFormatting {

  /// Obtain string to use to separate a formatted value from its units name
  public var unitSeparator: String { parameterAddress == .rate ? " " : "" }
  /// Obtain the suffix to apply to a formatted value
  public var suffix: String { makeFormattingSuffix(from: unitName) }
  /// Obtain the format to use in String(format:value) when formatting a values
  public var stringFormatForDisplayValue: String {
    switch self.parameterAddress {
    case .depth, .dry, .wet: return "%.0f"
    default: return "%.2f"
    }
  }
}
