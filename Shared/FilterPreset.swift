// Copyright © 2021 Brad Howes. All rights reserved.

import Foundation
import AudioUnit

public struct FilterPreset {
    let rate: AUValue
    let depth: AUValue
    let intensity: AUValue
    let dryMix: AUValue
    let wetMix: AUValue
    let odd90: AUValue
}
