// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/DelayBuffer.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/LFO.hpp"
#import "DSPHeaders/Parameters/Bool.hpp"
#import "DSPHeaders/Parameters/Milliseconds.hpp"
#import "DSPHeaders/Parameters/Percentage.hpp"
#import "DSPHeaders/PhaseShifter.hpp"

/**
 The audio processing kernel that transforms audio samples into those with a phased effect.
 */
class Kernel : public DSPHeaders::EventProcessor<Kernel> {
public:
  using super = DSPHeaders::EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(std::string name) noexcept :
  super(), name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    lfo_.setWaveform(LFOWaveform::triangle);
    registerParameter(depth_);
    registerParameter(intensity_);
    registerParameter(dry_);
    registerParameter(wet_);
    registerParameter(odd90_);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   @param samplesPerFilterUpdate the number of samples between phaser parameter updates
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender,
                          int samplesPerFilterUpdate) noexcept {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate, samplesPerFilterUpdate);
  }

private:

  void initialize(int channelCount, double sampleRate, int samplesPerFilterUpdate) noexcept {
    samplesPerFilterUpdate_ = samplesPerFilterUpdate;
    lfo_.setSampleRate(sampleRate);
    phaseShifters_.reserve(channelCount);
    phaseShifters_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      phaseShifters_.emplace_back(DSPHeaders::PhaseShifter<AUValue>::ideal,
                                  sampleRate,
                                  intensity_.getImmediate(),
                                  samplesPerFilterUpdate_);
    }
  }

  /**
   Set a paramete value from within the render loop.

   @param address the parameter to change
   @param value the new value to use
   @param duration the ramping duration to transition to the new value
   */
  bool doSetImmediateParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Set a paramete value from the UI via the parameter tree. Will be recognized and handled in the next render pass.

   @param address the parameter to change
   @param value the new value to use
   */
  bool doSetPendingParameterValue(AUParameterAddress address, AUValue value) noexcept;

  /**
   Get the paramete value last set in the render thread. NOTE: this does not account for any ramping that might be in
   effect.

   @param address the parameter to access
   @returns parameter value
   */
  AUValue doGetImmediateParameterValue(AUParameterAddress address) const noexcept;

  /**
   Get the paramete value last set by the UI / parameter tree. NOTE: this does not account for any ramping that might
   be in effect.

   @param address the parameter to access
   @returns parameter value
   */
  AUValue doGetPendingParameterValue(AUParameterAddress address) const noexcept;

  void writeSample(DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs, AUValue intensity, AUValue evenModDepth,
                   AUValue oddModDepth, AUValue wetMix, AUValue dryMix) noexcept {
    for (int channel = 0; channel < ins.size(); ++channel) {
      auto inputSample = *ins[channel]++;
      auto& shifter = phaseShifters_[channel];
      shifter.setIntensity(intensity);
      auto filteredSample = shifter.process(((channel & 1) ? oddModDepth : evenModDepth), inputSample);
      *outs[channel]++ = wetMix * filteredSample + dryMix * inputSample;
    }
  }

  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
    auto odd90 = odd90_.getImmediate();
    if (frameCount == 1) {
      auto depth = depth_.frameValue();
      auto evenModDepth = lfo_.value() * depth;
      auto oddModDepth = odd90 ? (lfo_.quadPhaseValue() * depth) : evenModDepth;
      lfo_.increment();
      writeSample(ins, outs, intensity_.frameValue(), evenModDepth, oddModDepth, wet_.frameValue(), dry_.frameValue());
    } else {
      auto depth = depth_.frameValue();
      auto intensity = intensity_.frameValue();
      auto wet = wet_.frameValue();
      auto dry = dry_.frameValue();

      // Special-casing when odd90 is enabled. Probably not worth it.
      if (odd90) {
        while (frameCount-- > 0) {
          auto evenModDepth = lfo_.value() * depth;
          auto oddModDepth = lfo_.quadPhaseValue() * depth;
          lfo_.increment();
          writeSample(ins, outs, intensity, evenModDepth, oddModDepth, wet, dry);
        }
      } else {
        while (frameCount-- > 0) {
          auto evenModDepth = lfo_.value() * depth;
          lfo_.increment();
          writeSample(ins, outs, intensity, evenModDepth, evenModDepth, wet, dry);
        }
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  int samplesPerFilterUpdate_;
  DSPHeaders::LFO<AUValue> lfo_;
  DSPHeaders::Parameters::Percentage depth_;
  DSPHeaders::Parameters::Percentage intensity_;
  DSPHeaders::Parameters::Percentage dry_;
  DSPHeaders::Parameters::Percentage wet_;
  DSPHeaders::Parameters::Bool odd90_;
  std::vector<DSPHeaders::PhaseShifter<AUValue>> phaseShifters_{};
  std::string name_;
  os_log_t log_;
};
