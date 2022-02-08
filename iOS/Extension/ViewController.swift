// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import Knob_iOS
import ParameterAddress
import Parameters
import UI
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
  private let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private var viewConfig: AUAudioUnitViewConfiguration!
  private var parameterObserverToken: AUParameterObserverToken?
  private var keyValueObserverToken: NSKeyValueObservation?

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

  private var controls = [ParameterAddress : [AUParameterEditor]]()
  private var audioUnit: FilterAudioUnit? {
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

    editingViewTopConstraint.constant = 0
    editingBackgroundBottomConstraint.constant = view.frame.midY

    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardAppearing(_:)),
                                           name: UIApplication.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDisappearing(_:)),
                                           name: UIApplication.keyboardWillHideNotification, object: nil)

    editingBackground.layer.cornerRadius = 8.0
    editingContainerView.isHidden = true

    addTapGesture(rateTapEdit)
    addTapGesture(depthTapEdit)
    addTapGesture(intensityTapEdit)
    addTapGesture(dryTapEdit)
    addTapGesture(wetTapEdit)

    let knobColor = UIColor(named: "knob")!

    for control in [rateControl, depthControl, intensityControl] {
      if let control = control {
        control.progressColor = knobColor
        control.indicatorColor = knobColor
        control.trackLineWidth = 10
        control.progressLineWidth = 8
        control.indicatorLineWidth = 8
      }
    }

    for control in [dryControl, wetControl] {
      if let control = control {
        control.progressColor = knobColor
        control.indicatorColor = knobColor
        control.trackLineWidth = 8
        control.progressLineWidth = 6
        control.indicatorLineWidth = 6
      }
    }
  }

  @IBAction func handleKeyboardAppearing(_ notification: NSNotification) {
    os_log(.info, log: log, "handleKeyboardAppearing BEGIN")

    guard let info = notification.userInfo else {
      os_log(.error, log: log, "handleKeyboardAppearing END - no userInfo dict")
      return
    }

    guard let keyboardFrameEnd = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
      os_log(.error, log: log, "handleKeyboardAppearing END - no userInfo entry for %{public}s",
             UIResponder.keyboardFrameEndUserInfoKey)
      return
    }

    let keyboardFrame = keyboardFrameEnd.cgRectValue
    let localKeyboardFrame = view.convert(keyboardFrame, from: view.window)
    os_log(.info, log: log, "handleKeyboardAppearing - height: %f", localKeyboardFrame.height)


    self.editingBackgroundBottomConstraint.constant = -self.editingBackground.frame.height
    view.layoutIfNeeded()

    UIView.animate(withDuration: 0.4, delay: 0.0) {
      if localKeyboardFrame.height < 100 {
        self.editingBackgroundBottomConstraint.constant = self.view.frame.midY
      } else {
        self.editingBackgroundBottomConstraint.constant = localKeyboardFrame.height + 20
      }
      self.view.layoutIfNeeded()
    }
  }

  @IBAction func handleKeyboardDisappearing(_ notification: NSNotification) {
    view.layoutIfNeeded()
    UIView.animate(withDuration: 0.4, delay: 0.0) {
      if !self.isEditing {
        self.editingBackgroundBottomConstraint.constant = -self.editingBackground.frame.height
      } else {
        self.editingBackgroundBottomConstraint.constant = self.view.frame.midY
      }
      self.view.layoutIfNeeded()
    }
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

    (controls[address] ?? []).forEach { $0.controlChanged(source: control) }

    os_log(.debug, log: log, "controlChanged END")
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

    os_log(.info, log: log, "createAudioUnit END")
    return audioUnit
  }
}

extension ViewController {

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")

    guard parameterObserverToken == nil else { return }
    guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit value") }
    guard let paramTree = audioUnit.parameterTree else { fatalError("logic error -- nil parameterTree") }

    keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      self.performOnMain { self.updateDisplay() }
    }

    let parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] _, _ in
      guard let self = self else { return }
      self.performOnMain { self.updateDisplay() }
    })

    self.parameterObserverToken = parameterObserverToken

    controls[.rate] = [FloatParameterEditor(
      parameterObserverToken: parameterObserverToken, parameter: parameters[.rate],
      formatter: parameters.valueFormatter(.rate), rangedControl: rateControl, label: rateValueLabel
    )]
    controls[.depth] = [FloatParameterEditor(
      parameterObserverToken: parameterObserverToken, parameter: parameters[.depth],
      formatter: parameters.valueFormatter(.depth), rangedControl: depthControl, label: depthValueLabel
    )]
    controls[.intensity] = [FloatParameterEditor(
      parameterObserverToken: parameterObserverToken, parameter: parameters[.intensity],
      formatter: parameters.valueFormatter(.intensity), rangedControl: intensityControl, label: intensityValueLabel
    )]
    controls[.dry] = [FloatParameterEditor(
      parameterObserverToken: parameterObserverToken, parameter: parameters[.dry],
      formatter: parameters.valueFormatter(.dry), rangedControl: dryControl, label: dryValueLabel
    )]
    controls[.wet] = [FloatParameterEditor(
      parameterObserverToken: parameterObserverToken, parameter: parameters[.wet],
      formatter: parameters.valueFormatter(.wet), rangedControl: wetControl, label:  wetValueLabel
    )]
    controls[.odd90] = [BooleanParameterEditor(
      parameterObserverToken: parameterObserverToken,parameter: parameters[.odd90], booleanControl: odd90Control
    )]

    // Let us manage view configuration changes
    audioUnit.viewConfigurationManager = self
  }

  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      (controls[address] ?? []).forEach { $0.parameterChanged() }
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

extension ViewController: UITextFieldDelegate {

  @IBAction func beginEditing(sender: UITapGestureRecognizer) {
    os_log(.info, log: log, "beginEditing - %d", view.tag)

    guard let view = sender.view,
          let address = view.parameterAddress,
          let param = controls[address]?.first?.parameter
    else {
      fatalError("misconfigured UI element")
    }

    isEditing = true


    editingContainerView.setParameterAddress(address)
    editingLabel.text = param.displayName
    editingValue.text = "\(param.value)"
    editingValue.becomeFirstResponder()
    editingValue.delegate = self

    editingContainerView.alpha = 1.0
    editingContainerView.isHidden = false

    os_log(.info, log: log, "starting animation")
    UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
      self.controlsView.alpha = 0.40
      self.editingContainerView.alpha = 1.0
    } completion: { _ in
      self.controlsView.alpha = 0.40
      os_log(.info, log: self.log, "done animation")
    }
  }

  private func endEditing() {
    os_log(.info, log: log, "endEditing - %d", editingContainerView.tag)
    guard let address = editingContainerView.parameterAddress else { fatalError("misconfigured editingContainerView") }

    isEditing = false
    editingValue.resignFirstResponder()

    os_log(.info, log: log, "starting animation")
    UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
      self.editingContainerView.alpha = 0.0
      self.controlsView.alpha = 1.0
    } completion: { _ in
      self.editingContainerView.alpha = 0.0
      self.controlsView.alpha = 1.0
      self.editingContainerView.isHidden = true
      if let stringValue = self.editingValue.text,
         let value = Float(stringValue) {
        (self.controls[address] ?? []).forEach { $0.setEditedValue(value) }
      }
      os_log(.info, log: self.log, "done animation")
    }
  }

  override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if !editingContainerView.isHidden {
      endEditing()
    }
    super.touchesBegan(touches, with: event)
  }

  private func addTapGesture(_ view: UIView) {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(beginEditing))
    gesture.numberOfTouchesRequired = 1
    gesture.numberOfTapsRequired = 1
    view.addGestureRecognizer(gesture)
    view.isUserInteractionEnabled = true
  }

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    os_log(.info, log: log, "textFieldShouldReturn")
    endEditing()
    return false
  }

  public func textFieldDidEndEditing(_ textField: UITextField) {
    os_log(.info, log: log, "textFieldDidEndEditing")
    if textField.isFirstResponder {
      endEditing()
    }
  }
}
