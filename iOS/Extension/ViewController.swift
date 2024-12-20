// Copyright © 2022, 2024 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import Knob_iOS
import ParameterAddress
import Parameters
import os.log

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  public let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

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

  @IBOutlet weak var versionTag: UILabel!

  private var editors = [AUParameterEditor]()
  private var editorMap = [ParameterAddress : AUParameterEditor]()

  private var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.createEditors()
        }
      }
    }
  }
}

public extension ViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    if audioUnit != nil {
      createEditors()
    }
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension ViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension ViewController: AUAudioUnitFactory {
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    try DispatchQueue.main.sync {
      os_log(.info, log: log, "createAudioUnit BEGIN")

      let bundle = InternalConstants.bundle
      let kernel = KernelBridge(bundle.auBaseName)
      let audioUnit = try FilterAudioUnitFactory.create(
        componentDescription: componentDescription,
        parameters: Parameters(),
        kernel: kernel,
        viewConfigurationManager: self
      )

      self.versionTag.text = bundle.versionTag
      self.audioUnit = audioUnit

      os_log(.info, log: log, "createAudioUnit END")
      return audioUnit
    }
  }
}

extension ViewController: AUParameterEditorDelegate {
  public func parameterEditorEditingDone(changed: Bool) {
    if changed {
      audioUnit?.clearCurrentPresetIfFactoryPreset()
    }
  }
}

// MARK: - Private

private extension ViewController {

  func createEditors() {
    guard let audioUnit,
          let parameterTree = audioUnit.parameterTree
    else {
      return
    }

    let knobColor = UIColor.knobProgress

    let valueEditor = ValueEditor(containerView: editingContainerView, backgroundView: editingBackground,
                                  parameterName: editingLabel, parameterValue: editingValue,
                                  containerViewTopConstraint: editingViewTopConstraint,
                                  backgroundViewBottomConstraint: editingBackgroundBottomConstraint,
                                  controlsView: controlsView)

    for (parameterAddress, (knob, label, tapEdit)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor

      knob.addTarget(self, action: #selector(handleKnobChanged(_:)), for: .valueChanged)

      let editor = FloatParameterEditor(parameter: parameterTree[parameterAddress],
                                        formatting: parameterTree[parameterAddress],
                                        rangedControl: knob, label: label)
      editor.delegate = self
      editors.append(editor)
      editorMap[parameterAddress] = editor
      editor.setValueEditor(valueEditor: valueEditor, tapToEdit: tapEdit)
    }

    let editor = BooleanParameterEditor(parameter: parameterTree[.odd90], booleanControl: odd90Control)
    odd90Control.addTarget(self, action: #selector(handleSwitchChanged(_:)), for: .valueChanged)
    editors.append(editor)
    editorMap[.odd90] = editor
  }

  @IBAction func handleKnobChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  @IBAction func handleSwitchChanged(_ control: Switch) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  func handleControlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    guard let audioUnit,
          let parameterTree = audioUnit.parameterTree
    else {
      return
    }

    os_log(.debug, log: log, "controlChanged BEGIN - %d %f %f", address.rawValue, control.value,
           parameterTree[address].value)

    guard let editor = editorMap[address] else {
      os_log(.debug, log: log, "controlChanged END - nil editor")
      return
    }

    if editor.differs {
      // When user changes something and a factory preset was active, clear it.
      if let preset = audioUnit.currentPreset, preset.number >= 0 {
        os_log(.debug, log: log, "controlChanged - clearing currentPreset")
        audioUnit.currentPreset = nil
      }
    }

    editor.controlChanged(source: control)
  }
}

private enum InternalConstants {
  private class EmptyClass {}
  static let bundle = Bundle(for: InternalConstants.EmptyClass.self)
}

extension Knob: @retroactive AUParameterValueProvider, @retroactive RangedControl {}

extension AUParameterTree {
  fileprivate subscript (_ parameter: ParameterAddress) -> AUParameter {
    guard let parameter = self.parameter(source: parameter) else {
      fatalError("Unexpected parameter address \(parameter)")
    }
    return parameter
  }
}
