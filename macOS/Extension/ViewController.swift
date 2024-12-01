// Copyright © 2022, 2024 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Kernel
import KernelBridge
import Knob_macOS
import ParameterAddress
import Parameters
import os.log

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log: OSLog = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private var viewConfig: AUAudioUnitViewConfiguration!
  private var versionTagValue: String = ""

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

  @IBOutlet private weak var versionTag: NSTextField!

  private lazy var controls: [ParameterAddress: (Knob, Label)] = [
    .rate: (rateControl, rateValueLabel),
    .depth: (depthControl, depthValueLabel),
    .intensity: (intensityControl, intensityValueLabel),
    .dry: (dryMixControl, dryMixValueLabel),
    .wet: (wetMixControl, wetMixValueLabel)
  ]

  var editors = [AUParameterEditor]()
  var editorMap = [ParameterAddress : AUParameterEditor]()

  public var audioUnit: FilterAudioUnit? {
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

  override func viewDidAppear() {
    versionTag.text = versionTagValue
  }

  override func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)

    os_log(.debug, log: log, "controlChanged END")
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension ViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension ViewController: AUAudioUnitFactory {
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    try DispatchQueue.main.sync {
      let bundle = InternalConstants.bundle
      let parameters = Parameters()
      let kernel = KernelBridge(bundle.auBaseName)
      let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                        parameters: parameters, kernel: kernel,
                                                        viewConfigurationManager: self)
      self.audioUnit = audioUnit
      self.versionTagValue = bundle.versionTag

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

    let knobColor = NSColor.knobProgress

    for (parameterAddress, (knob, label)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor

      knob.target = self
      knob.action = #selector(handleKnobChanged(_:))

      let editor = FloatParameterEditor(parameter: parameterTree[parameterAddress],
                                        formatting: parameterTree[parameterAddress],
                                        rangedControl: knob, label: label)
      editor.delegate = self
      editors.append(editor)
      editorMap[parameterAddress] = editor
    }

    let editor = BooleanParameterEditor(parameter: parameterTree[.odd90], booleanControl: odd90Control)
    odd90Control.setTint(knobColor)
    odd90Control.target = self
    odd90Control.action = #selector(handleSwitchChanged(_:))
    editor.delegate = self
    editors.append(editor)
    editorMap[.odd90] = editor
  }

  @objc func handleKnobChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  @objc func handleSwitchChanged(_ control: Switch) {
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
