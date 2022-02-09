// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import Knob_iOS
import ParameterAddress
import Parameters
import os.log

extension UIView: TagHolder {}

extension UISwitch: AUParameterValueProvider, BooleanControl {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  public let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private var viewConfig: AUAudioUnitViewConfiguration!

  @IBOutlet private weak var controlsView: View!

  @IBOutlet private weak var rateControl: Knob!
  @IBOutlet private weak var rateValueLabel: Label!
  @IBOutlet private weak var rateTapEdit: UIView!

  @IBOutlet private weak var depthControl: Knob!
  @IBOutlet private weak var depthValueLabel: Label!
  @IBOutlet private weak var depthTapEdit: UIView!

  @IBOutlet private weak var intensityControl: Knob!
  @IBOutlet private weak var intensityValueLabel: Label!
  @IBOutlet private weak var intensityTapEdit: UIView!

  @IBOutlet private weak var dryControl: Knob!
  @IBOutlet private weak var dryValueLabel: Label!
  @IBOutlet private weak var dryTapEdit: UIView!

  @IBOutlet private weak var wetControl: Knob!
  @IBOutlet private weak var wetValueLabel: Label!
  @IBOutlet private weak var wetTapEdit: UIView!

  @IBOutlet private weak var odd90Control: Switch!

  private lazy var controls: [ParameterAddress: (Knob, Label, UIView)] = [
    .rate: (rateControl, rateValueLabel, rateTapEdit),
    .depth: (depthControl, depthValueLabel, depthTapEdit),
    .intensity: (intensityControl, intensityValueLabel, intensityTapEdit),
    .dry: (dryControl, dryValueLabel, dryTapEdit),
    .wet: (wetControl, wetValueLabel, wetTapEdit)
  ]

  // Holds all of the other editing views and is used to end editing when tapped.
  @IBOutlet private weak var editingContainerView: View!
  // Background that contains the label and value editor field. Always appears just above the keyboard view.
  @IBOutlet private weak var editingBackground: UIView!
  // Shows the name of the value being edited
  @IBOutlet private weak var editingLabel: Label!
  // Shows the name of the value being edited
  @IBOutlet private weak var editingValue: UITextField!

  // The top constraint of the editingView. Set to 0 when loaded, but otherwise not used.
  @IBOutlet private weak var editingViewTopConstraint: NSLayoutConstraint!
  // The bottom constraint of the editingBackground that controls the vertical position of the editor
  @IBOutlet private weak var editingBackgroundBottomConstraint: NSLayoutConstraint!

  private var editors = [ParameterAddress : AUParameterEditor]()
  private var audioUnit: FilterAudioUnit? {
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
    let knobColor = UIColor(named: "knob")!

    let valueEditor = ValueEditor(containerView: editingContainerView, backgroundView: editingBackground,
                                  parameterName: editingLabel, parameterValue: editingValue,
                                  containerViewTopConstraint: editingViewTopConstraint,
                                  backgroundViewBottomConstraint: editingBackgroundBottomConstraint,
                                  controlsView: controlsView)

    for (parameterAddress, (knob, label, tapEdit)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor
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
      editor.setValueEditor(valueEditor: valueEditor, tapToEdit: tapEdit)
    }

    editors[.odd90] = BooleanParameterEditor(parameter: parameters[.odd90], booleanControl: odd90Control)
  }

  @IBAction public func handleKnobValueChange(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError("misconfigured knob tag") }
    controlChanged(control, address: address)
  }

  @IBAction public func handleOdd90Change(_ control: Switch) {
    controlChanged(control, address: .odd90)
  }

  private func controlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    os_log(.debug, log: log, "controlChanged BEGIN - %d %f", address.rawValue, control.value)

    guard let audioUnit = audioUnit else {
      os_log(.debug, log: log, "controlChanged END - nil audioUnit")
      return
    }

    // When user changes something and a factory preset was active, clear it.
    if let preset = audioUnit.currentPreset, preset.number >= 0 {
      os_log(.debug, log: log, "controlChanged - clearing currentPreset")
      audioUnit.currentPreset = nil
    }

    editors[address]?.controlChanged(source: control)

    os_log(.debug, log: log, "controlChanged END")
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

//  override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//    if !editingContainerView.isHidden {
//      endEditing()
//    }
//    super.touchesBegan(touches, with: event)
//  }

}
