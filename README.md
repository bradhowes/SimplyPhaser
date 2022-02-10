![CI](https://github.com/bradhowes/SimplyPhaser/workflows/CI/badge.svg?branch=main)
[![Swift 5.5](https://img.shields.io/badge/Swift-5.5-orange.svg?style=flat)](https://swift.org)
[![AUv3](https://img.shields.io/badge/AUv3-green.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

![](Media/image.png)

# About SimplyPhaser

This is full-featured AUv3 effect that acts like the phaser stomp boxes of old. It is for both iOS and macOS
platforms. When configured, it will build an app for each platform and embed in the app an app extension
containing the AUv3 component. The apps are designed to load the component and use it to demonstrate how it
works by playing a sample audio file and routing it through the effect.

<div align="center">
  <a href="https://www.youtube.com/watch?v=vH6bEQEkcdo"><img src="https://img.youtube.com/vi/vH6bEQEkcdo/0.jpg"
                                                             alt="SimplyPhaser in GarageBand" style="width:100%;"></a>
</div>

Additional features and info:

* uses an Objective-C++ kernel for audio sample manipulation in the render thread
* provides a *very* tiny Objective-C interface to the kernel for access with Swift
* uses Swift for all UI and all audio unit work not associated with rendering

The code was developed in Xcode 12.4 on macOS 11.2.1. I have tested on both macOS and iOS devices primarily in
GarageBand, but also using test hosts on both devices as well as the excellent
[AUM](https://apps.apple.com/us/app/aum-audio-mixer/id1055636344) app on iOS.

Finally, it passes all
[auval](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/AudioUnitDevelopmentFundamentals/AudioUnitDevelopmentFundamentals.html)
tests:

```
% auval -v aufx phzr BRay
```

## Phaser Algorithm

This effect is based on a design described in the excellent book
["Designing Audio Effects Plugins in C++"](https://www.amazon.com/Designing-Audio-Effect-Plugins-C-dp-1138591939/dp/1138591939/ref=dp_ob_title_bk)
by [Will Pirkle](https://www.willpirkle.com). His design uses six all-pass filters to do the phase shifting in 6 overlapping bands ranging from 16Hz to 20kHz.
In the book, he mentions that his design was "derived from the analog ciruit in the _National Semiconductor (NSC) Audio/Radio Handbook_, a 1970s source of old
App Notes from National Semiconductor... The NSC design used six 1st order all-pass stages that were modulated from a common LFO."

You can find Pirkle's implementation in the [fxobjects.h](https://github.com/bradhowes/SimplyPhaser/blob/9f06b552f06b301a14b65400cbc8b57a319a271b/Shared/Kernel/Pirkle/fxobjects.h#L3537) file. Note that the effect 
uses my own C++ implementation that I think is a bit more straightforward. There are unit tests that compare the two for implementation correctness.

## Demo Targets

The macOS and iOS apps are simple hosts that demonstrate the functionality of the AUv3 component. In the AUv3
world, an app serves as a delivery mechanism for an app extension like AUv3. When the app is installed, the
operating system will also install and register any app extensions found in the app.

The `SimplyPhaser` apps attempt to instantiate the AUv3 component and wire it up to an audio file player and the
output speaker. When it runs, you can play the sample file and manipulate the filter settings -- cutoff
frequency in the horizontal direction and resonance in the vertical. You can control these settings either by
touching on the graph and moving the point or by using the sliders to change their associated values. The
sliders are somewhat superfluous but they act on the AUv3 component via the AUPropertyTree much like an external
MIDI controller might do.

## Code Layout

Each OS ([macOS](macOS) and [iOS](iOS)) have the same code layout:

* `App` -- code and configury for the application that hosts the AUv3 app extension
* `Extension` -- code and configury for the extension itself
* `Framework` -- code configury for the framework that contains the shared code by the app and the extension

The [Shared](Shared) folder holds all of the code that is used by the above products. In it you will find

* [LFO](Shared/Kernel/LFO.h) -- simple low-frequency oscillator that varies the delay amount
* [FilterKernel](Shared/Kernel/FilterKernel.h) -- another C++ class that does the rendering of audio samples by sending them through the filter.
* [FilterAudioUnit](Shared/FilterAudioUnit.swift) -- the actual AUv3 AudioUnit written in Swift.
* [FilterViewController](Shared/User%20Interface/FilterViewController.swift) -- a custom view controller that
works with both UIView and NSView views to show the effect's controls. Note that this works in both macOS and
iOS, but that may not be for the best.

Additional supporting files can be found in [Support](Shared/Support).

## Rolling Your Own

> :warning: You are free to use the code according to [LICENSE.md](LICENSE.md), but you must not replicate
> someone's UI, icons, samples, or any other assets if you are going to distribute your effect on the App Store.

Feel free to fork and do as you please. If you have improvements, I would definitely welcome your feedback. If you are interested in working out your own AUv3
plugins have a look at my [AUv3Template](https://github.com/bradhowes/AUv3Template) project which tries to offer a good place to start.
