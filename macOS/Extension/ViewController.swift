// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Kernel
import KernelBridge
import Knob_macOS
import ParameterAddress
import Parameters
import os.log

extension NSSwitch: AUParameterValueProvider, BooleanControl, TagHolder {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log: OSLog = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private var viewConfig: AUAudioUnitViewConfiguration!
  // private var parameterObserverToken: AUParameterObserverToken?
  private var keyValueObserverToken: NSKeyValueObservation?
  private var hasActiveLabel = false

  @IBOutlet private weak var controlsView: NSView!

  @IBOutlet private weak var rateControl: Knob!
  @IBOutlet private weak var rateValueLabel: FocusAwareTextField!

  @IBOutlet private weak var depthControl: Knob!
  @IBOutlet private weak var depthValueLabel: FocusAwareTextField!

  @IBOutlet private weak var intensityControl: Knob!
  @IBOutlet private weak var intensityValueLabel: FocusAwareTextField!

  @IBOutlet private weak var wetMixControl: Knob!
  @IBOutlet private weak var wetMixValueLabel: FocusAwareTextField!

  @IBOutlet private weak var dryMixControl: Knob!
  @IBOutlet private weak var dryMixValueLabel: FocusAwareTextField!

  @IBOutlet private weak var odd90Control: NSSwitch!

  private lazy var controls: [ParameterAddress: (Knob, Label)] = [
    .rate: (rateControl, rateValueLabel),
    .depth: (depthControl, depthValueLabel),
    .intensity: (intensityControl, intensityValueLabel),
    .dry: (dryMixControl, dryMixValueLabel),
    .wet: (wetMixControl, wetMixValueLabel)
  ]

  var editors = [ParameterAddress : AUParameterEditor]()
  public var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.createEditors()
        }
      }
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    if audioUnit != nil {
      createEditors()
    }
  }

  private func createEditors() {
    let knobColor = NSColor(named: "knob")!

    for (parameterAddress, (knob, label)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor

      knob.target = self
      knob.action = #selector(handleKnobValueChanged(_:))

      if parameterAddress == .dry || parameterAddress == .wet {
        knob.trackLineWidth = 8
        knob.progressLineWidth = 6
        knob.indicatorLineWidth = 6
      } else {
        knob.trackLineWidth = 10
        knob.progressLineWidth = 8
        knob.indicatorLineWidth = 8
      }

      let editor = FloatParameterEditor(parameter: parameters[parameterAddress],
                                        formatter: parameters.valueFormatter(parameterAddress),
                                        rangedControl: knob, label: label)
      editors[parameterAddress] = editor
    }

    editors[.odd90] = BooleanParameterEditor(parameter: parameters[.odd90], booleanControl: odd90Control)

    odd90Control.wantsLayer = true
    odd90Control.layer?.backgroundColor = knobColor.cgColor
    odd90Control.layer?.masksToBounds = true
    odd90Control.layer?.cornerRadius = 10
  }

  @IBAction private func handleKnobValueChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    controlChanged(control, address: address)
  }

  @IBAction private func handleOdd90Changed(_ control: NSSwitch) {
    controlChanged(control, address: .odd90)
  }

  private func controlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    os_log(.info, log: log, "controlChanged BEGIN - %d %f", address.rawValue, control.value)

    guard let audioUnit = audioUnit else {
      os_log(.info, log: log, "controlChanged END - nil audioUnit")
      return
    }

    // When user changes something and a factory preset was active, clear it.
    if let preset = audioUnit.currentPreset, preset.number >= 0 {
      os_log(.info, log: log, "controlChanged - clearing currentPreset")
      audioUnit.currentPreset = nil
    }

    editors[address]?.controlChanged(source: control)
  }

  override public func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
}

extension ViewController: AudioUnitViewConfigurationManager {}

extension ViewController: CurrentPresetMonitor {

  public func currentPresetChanged(_ value: AUAudioUnitPreset?) {
    if value == nil {
      DispatchQueue.main.async { self.updateDisplay() }
    }
  }
}

extension ViewController: AUAudioUnitFactory {
  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                      parameters: parameters,
                                                      kernel: KernelBridge(Bundle.main.auBaseName),
                                                      currentPresetMonitor: self,
                                                      viewConfigurationManager: self)
    self.audioUnit = audioUnit
    return audioUnit
  }
}


extension ViewController {

  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      editors[address]?.parameterChanged()
    }
  }
}
