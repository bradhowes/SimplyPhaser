// Copyright © 2021 Brad Howes. All rights reserved.

import UIKit
import SimplyPhaserFramework

final class MainViewController: UIViewController {
  
  private let audioUnitManager = AudioUnitManager(interfaceName: "MainInterface")
  
  @IBOutlet weak var reviewButton: UIButton!
  @IBOutlet weak var playButton: UIButton!
  @IBOutlet weak var bypassButton: UIButton!
  @IBOutlet weak var containerView: UIView!
  @IBOutlet weak var presetSelection: UISegmentedControl!
  
  private var filterViewController: FilterViewController?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let delegate = UIApplication.shared.delegate as? AppDelegate else { fatalError() }
    delegate.setMainViewController(self)
    
    let version = Bundle.main.releaseVersionNumber
    reviewButton.setTitle(version, for: .normal)
    
    audioUnitManager.delegate = self
    
    presetSelection.setTitleTextAttributes([.foregroundColor : UIColor.white], for: .normal)
    presetSelection.setTitleTextAttributes([.foregroundColor : UIColor.black], for: .selected)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    presetSelection.selectedSegmentIndex = 0
    usePreset()
    
    let showedAlertKey = "showedInitialAlert"
    guard UserDefaults.standard.bool(forKey: showedAlertKey) == false else { return }
    UserDefaults.standard.set(true, forKey: showedAlertKey)
    let alert = UIAlertController(title: "AUv3 Component Installed",
                                  message: nil, preferredStyle: .alert)
    alert.message =
      """
The AUv3 component 'SimplyPhaser' is now available on your device and can be used in other AUv3 host apps such as GarageBand and AUM.

You can continue to use this app to experiment, but you do not need to have it running in order to access the AUv3 component in other apps.

If you delete this app from your device, the AUv3 component will no longer be available for use in other host applications.
"""
    alert.addAction(
      UIAlertAction(title: "OK", style: .default, handler: { _ in })
    )
    present(alert, animated: true)
  }
  
  public func stopPlaying() {
    audioUnitManager.cleanup()
  }
  
  @IBAction private func togglePlay(_ sender: UIButton) {
    let isPlaying = audioUnitManager.togglePlayback()
    let titleText = isPlaying ? "Stop" : "Play"
    playButton.setTitle(titleText, for: .normal)
    playButton.setTitleColor(isPlaying ? .systemRed : .systemTeal, for: .normal)
  }
  
  @IBAction private func toggleBypass(_ sender: UIButton) {
    let wasBypassed = audioUnitManager.audioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    audioUnitManager.audioUnit?.shouldBypassEffect = isBypassed
    
    let titleText = isBypassed ? "Resume" : "Bypass"
    bypassButton.setTitle(titleText, for: .normal)
    bypassButton.setTitleColor(isBypassed ? .systemYellow : .systemTeal, for: .normal)
  }
  
  @IBAction private func visitAppStore(_ sender: UIButton) {
    let appStoreId = Bundle.main.appStoreId
    guard let url = URL(string: "https://itunes.apple.com/app/id\(appStoreId)") else {
      fatalError("Expected a valid URL")
    }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
  
  @IBAction func usePreset(_ sender: UISegmentedControl? = nil) {
    audioUnitManager.audioUnit?.currentPreset =
      audioUnitManager.audioUnit?.factoryPresets[presetSelection.selectedSegmentIndex]
  }
  
  @IBAction private func reviewApp(_ sender: UIButton) {
    AppStore.visitAppStore()
  }
}

extension MainViewController: AudioUnitManagerDelegate {
  
  func connected() {
    connectFilterView()
  }
}

extension MainViewController {
  
  private func connectFilterView() {
    let viewController = audioUnitManager.viewController
    filterViewController = viewController
    guard let filterView = viewController.view else { fatalError("no view found from audio unit") }
    containerView.addSubview(filterView)
    filterView.pinToSuperviewEdges()
    
    addChild(viewController)
    view.setNeedsLayout()
    containerView.setNeedsLayout()
  }
}
