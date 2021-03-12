// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation
import AudioUnit
import os

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {

    public func beginRequest(with context: NSExtensionContext) {
    }

    private let log = Logging.logger("FilterParameters")

    public func requestViewController(completionHandler: @escaping (ViewController?) -> Void) {
        completionHandler(loadViewController())
    }

    /**
     Create a new FilterAudioUnit instance to run in an AVu3 container.

     - parameter componentDescription: descriptions of the audio environment it will run in
     - returns: new FilterAudioUnit
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        os_log(.info, log: log, "creating new audio unit")
        componentDescription.log(log, type: .debug)
        let audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
        return audioUnit
    }

    private func loadViewController() -> FilterViewController {
        let bundle = Bundle.main

        os_log(.info, log: log, "loadViewController - %{public}s", bundle.auExtensionName)
        guard let url = bundle.auExtensionUrl else { fatalError("Could not obtain extension bundle URL") }

        os_log(.info, log: log, "path: %{public}s", url.path)
        guard let extensionBundle = Bundle(url: url) else { fatalError("Could not get app extension bundle") }

        #if os(iOS)

        let storyboard = Storyboard(name: "MainInterface", bundle: extensionBundle)
        guard let controller = storyboard.instantiateInitialViewController() as? FilterViewController else {
            fatalError("Unable to instantiate FilterViewController")
        }
        return controller

        #elseif os(macOS)

        os_log(.info, log: log, "creating new FilterViewController")
        let controller = FilterViewController(nibName: "FilterViewController", bundle: extensionBundle)
        os_log(.info, log: log, "done")
        return controller

        #endif
    }
}
