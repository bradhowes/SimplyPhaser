// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation
import os

/**
 Address definitions for AUParameter settings.
 */
@objc public enum FilterParameterAddress: UInt64, CaseIterable {
    case rate = 0
    case depth
    case intensity
    case dryMix
    case wetMix
    case odd90
}

private extension Array where Element == AUParameter {
    subscript(index: FilterParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject {

    private let log = Logging.logger("FilterParameters")

    static public let maxDelayMilliseconds: AUValue = 15.0

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
        AUParameterTree.createParameter(withIdentifier: "odd90", name: "Odd 90", address: .odd90, min: 0, max: 1, unit: .boolean)
    ]

    public let factoryPresetValues:[(name: String, preset: FilterPreset)] = [
        ("Gently Sweeps", FilterPreset(rate: 0.04, depth: 50,intensity: 75, dryMix: 50, wetMix: 50, odd90: 0)),
        ("Slo-Jo", FilterPreset(rate: 0.10, depth: 100,intensity: 90, dryMix: 50, wetMix: 50, odd90: 1)),
        ("Psycho Phase", FilterPreset(rate: 1.0, depth: 40, intensity: 90, dryMix: 0, wetMix: 100, odd90: 1)),
        ("Phaser Blast", FilterPreset(rate: 1.0, depth: 100, intensity: 90, dryMix: 0, wetMix: 100, odd90: 0)),
        ("Noxious", FilterPreset(rate: 20.0, depth: 30, intensity: 75, dryMix: 0, wetMix: 100, odd90: 1))
    ]

    /// AUParameterTree created with the parameter definitions for the audio unit
    public let parameterTree: AUParameterTree

    public var rate: AUParameter { parameters[.rate] }
    public var depth: AUParameter { parameters[.depth] }
    public var intensity: AUParameter { parameters[.intensity] }
    public var dryMix: AUParameter { parameters[.dryMix] }
    public var wetMix: AUParameter { parameters[.wetMix] }
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

    public subscript(address: FilterParameterAddress) -> AUParameter { parameters[address] }

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

    public func formatValue(_ address: FilterParameterAddress?, value: AUValue) -> String {
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
