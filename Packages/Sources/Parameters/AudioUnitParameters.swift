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
  public func usePreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].preset)
    }
  }

  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree

  public var rate: AUParameter { parameters[.rate] }
  public var depth: AUParameter { parameters[.depth] }
  public var intensity: AUParameter { parameters[.intensity] }
  public var dry: AUParameter { parameters[.dry] }
  public var wet: AUParameter { parameters[.wet] }
  public var odd90: AUParameter { parameters[.odd90] }

  /**
   Create a new AUParameterTree for the defined filter parameters.
   */
  override public init() {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
  }

  /**
   Installs three closures in the tree based on the given parameter handler
   - one for providing values
   - one for accepting new values from other sources
   - and one for obtaining formatted string values

   - parameter parameterHandler the object to use to handle the AUParameterTree requests
   */
  public func setParameterHandler(_ parameterHandler: AUParameterHandler) {
    parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
    parameterTree.implementorValueProvider = { parameterHandler.get($0) }
    parameterTree.implementorStringFromValueCallback = { param, value in
      let formatted = self.formatValue(ParameterAddress(rawValue: param.address), value: param.value)
      os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
             param.address, param.value, formatted)
      return formatted
    }
  }
}

extension AudioUnitParameters {

  private var missingParameter: AUParameter { fatalError() }

  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  public func valueFormatter(_ address: ParameterAddress) -> (AUValue) -> String {
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

  public func formatValue(_ address: ParameterAddress?, value: AUValue) -> String {
    guard let address = address else { return "?" }
    let format = formatting(address)
    return String(format: format, value)
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ preset: FilterPreset) {
    self.rate.value = preset.rate
    self.depth.value = preset.depth
    self.intensity.value = preset.intensity
    self.dry.value = preset.dry
    self.wet.value = preset.wet
    self.odd90.value = preset.odd90
  }
}

extension AudioUnitParameters {
  private func formatting(_ address: ParameterAddress) -> String {
    switch address {
    case .rate: return "%.2f"
    case .depth, .intensity: return "%.2f"
    case .dry, .wet, .odd90: return "%.0f"
    default: return "?"
    }
  }
}
