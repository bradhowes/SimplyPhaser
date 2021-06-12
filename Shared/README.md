# About

Contains code common to both iOS and macOS AUv3 extensions, and thus files here belong to both iOS and macOS
framework targets.

- [AudioUnitParameters](AudioUnitParameters.swift) -- Contains the AUParameter definitions for the runtime AU parameters that control the effect
- [FilterAudioUnit](FilterAudioUnit.swift) -- The actual AUv3 component, derived from `AUAudioUnit` class. Implements presets and
  configures the audio unit but actual audio processing is done in [SimplyPhaserKernel](Kernel/SimplyPhaserKernel.h) and friends.
- [Kernel](Kernel) -- Contains the Obj-C++ classes involved in audio processing.
- [User Interface](User%20Interface) -- Controller and graphical view that shows the settings and controls
- [Support](Support) -- Sundry files used elsewhere, including various class extensions.
