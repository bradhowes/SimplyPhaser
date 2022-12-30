// Copyright © 2022 Brad Howes. All rights reserved.

import AudioUnit

/// Collection of parameters values that define a filter preset.
public struct Configuration {
  public let rate: AUValue
  public let depth: AUValue
  public let intensity: AUValue
  public let dry: AUValue
  public let wet: AUValue
  public let odd90: AUValue

  init(rate: AUValue, depth: AUValue, intensity: AUValue, dry: AUValue, wet: AUValue, odd90: AUValue) {
    self.rate = rate
    self.depth = depth
    self.intensity = intensity
    self.dry = dry
    self.wet = wet
    self.odd90 = odd90
  }
}
