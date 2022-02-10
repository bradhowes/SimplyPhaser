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
  public let factoryPresetValues: [(name: String, preset: FilterPreset)] = [
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

  public func valueFormatter(_ address: ParameterAddress) -> (AUValue) -> String {
    self[address].valueFormatter
  }

  private func installParameterValueFormatter() {
    parameterTree.implementorStringFromValueCallback = { param, valuePtr in
      let value: AUValue
      if let valuePtr = valuePtr {
        value = valuePtr.pointee
      } else {
        value = param.value
      }
      return String(format: param.stringFormatForValue, value) + param.suffix
    }
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  private func setValues(_ preset: FilterPreset) {
    self[.rate].value = preset.rate
    self[.depth].value = preset.depth
    self[.intensity].value = preset.intensity
    self[.dry].value = preset.dry
    self[.wet].value = preset.wet
    self[.odd90].value = preset.odd90
  }
}

extension AUParameter {

  /// Obtain string to use to separate a formatted value from its units name
  var unitSeparator: String { parameterAddress == .rate ? " " : "" }
  /// Obtain the suffix to apply to a formatted value
  var suffix: String { unitSeparator + (unitName ?? "") }
  /// Obtain the format to use in String(format:value) when formatting a values
  var stringFormatForValue: String {
    switch parameterAddress {
    case .rate, .depth, .intensity: return "%.2f"
    case .dry, .wet: return "%.0f"
    default: return "?"
    }
  }
  /// Obtain a closure that will format parameter values into a string
  var valueFormatter: (AUValue) -> String {
    { value in String(format: self.stringFormatForValue, value) + self.suffix }
  }
}
