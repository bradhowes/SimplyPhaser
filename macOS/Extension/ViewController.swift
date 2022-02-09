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

  var controls = [ParameterAddress : AUParameterEditor]()

  public var audioUnit: FilterAudioUnit? {
    didSet {
      performOnMain {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }

    let knobColor = NSColor(named: "knob")!

    for control in [rateControl, depthControl, intensityControl] {
      if let control = control {
        control.progressColor = knobColor
        control.indicatorColor = knobColor
        control.trackLineWidth = 10
        control.progressLineWidth = 8
        control.indicatorLineWidth = 8
        control.target = self
        control.action = #selector(handleKnobValueChanged(_:))
      }
    }

    for control in [dryMixControl, wetMixControl] {
      if let control = control {
        control.progressColor = knobColor
        control.indicatorColor = knobColor
        control.trackLineWidth = 8
        control.progressLineWidth = 6
        control.indicatorLineWidth = 6
        control.target = self
        control.action = #selector(handleKnobValueChanged(_:))
      }
    }

    for control in [odd90Control] {
      if let control = control {
        control.wantsLayer = true
        control.layer?.backgroundColor = knobColor.cgColor
        control.layer?.masksToBounds = true
        control.layer?.cornerRadius = 10
      }
    }
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

    controls[address]?.controlChanged(source: control)
  }

  override public func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
}

extension ViewController: AUAudioUnitFactory {

  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.

   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "createAudioUnit BEGIN - %{public}s", componentDescription.description)

    let kernel = KernelBridge(Bundle.main.auBaseName)
    parameters.setParameterHandler(kernel)

    let audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    self.audioUnit = audioUnit

    audioUnit.setParameters(parameters)
    audioUnit.setKernel(kernel)
    audioUnit.currentPresetMonitor = self

    os_log(.info, log: log, "createAudioUnit END")
    return audioUnit
  }
}

extension ViewController: CurrentPresetMonitor {

  public func currentPresetChanged(_ value: AUAudioUnitPreset?) {
    if value == nil {
      DispatchQueue.main.async { self.updateDisplay() }
    }
  }
}

extension ViewController {

  override public func viewWillTransition(to newSize: NSSize) {
    os_log(.debug, log: log, "viewWillTransition: %f x %f", newSize.width, newSize.height)
  }

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")

    guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit value") }

    controls[.rate] = FloatParameterEditor(parameter: parameters[.rate], formatter: parameters.valueFormatter(.rate),
                                           rangedControl: rateControl, label: rateValueLabel)
    controls[.depth] = FloatParameterEditor(parameter: parameters[.depth], formatter: parameters.valueFormatter(.depth),
                                            rangedControl: depthControl, label: depthValueLabel)
    controls[.intensity] = FloatParameterEditor(parameter: parameters[.intensity],
                                                formatter: parameters.valueFormatter(.intensity),
                                                rangedControl: intensityControl, label: intensityValueLabel)
    controls[.dry] = FloatParameterEditor(parameter: parameters[.dry], formatter: parameters.valueFormatter(.dry),
                                          rangedControl: dryMixControl, label: dryMixValueLabel)
    controls[.wet] = FloatParameterEditor(parameter: parameters[.wet], formatter: parameters.valueFormatter(.wet),
                                          rangedControl: wetMixControl, label:  wetMixValueLabel)
    controls[.odd90] = BooleanParameterEditor(parameter: parameters[.odd90], booleanControl: odd90Control)

    // Let us manage view configuration changes
    audioUnit.viewConfigurationManager = self
  }

  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      controls[address]?.parameterChanged()
    }
  }

  private func performOnMain(_ operation: @escaping () -> Void) {
    (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
  }
}

extension ViewController: AudioUnitViewConfigurationManager {

  public func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet {
    var indexSet = IndexSet()
    for (index, viewConfiguration) in available.enumerated() {
      if viewConfiguration.width > 0 && viewConfiguration.height > 0 {
        indexSet.insert(index)
      }
    }
    return indexSet
  }

  public func selectViewConfiguration(_ viewConfiguration: AUAudioUnitViewConfiguration) {

  }
}
