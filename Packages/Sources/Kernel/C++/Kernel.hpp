// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "BoolParameter.hpp"
#import "DelayBuffer.hpp"
#import "EventProcessor.hpp"
#import "MillisecondsParameter.hpp"
#import "LFO.hpp"
#import "PercentageParameter.hpp"
#import "PhaseShifter.hpp"

/**
 The audio processing kernel that transforms audio samples into those with a phased effect.
 */
class Kernel : public EventProcessor<Kernel> {
public:
  using super = EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(const std::string& name) : super(os_log_create(name.c_str(), "Kernel"))
  {
    lfo_.setWaveform(LFOWaveform::triangle);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
    super::startProcessing(format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value);

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const;

private:

  void initialize(int channelCount, double sampleRate) {
    lfo_.setSampleRate(sampleRate);
    phaseShifters_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      phaseShifters_.emplace_back(PhaseShifter<AUValue>::ideal, sampleRate, intensity_.internal(), 20);
    }
  }

  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration);

  void setParameterFromEvent(const AUParameterEvent& event) {
    if (event.rampDurationSampleFrames == 0) {
      setParameterValue(event.parameterAddress, event.value);
    } else {
      setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
    }
  }

  void doRendering(std::vector<AUValue*>& ins, std::vector<AUValue*>& outs, AUAudioFrameCount frameCount) {

    // Advance by frames in outer loop so we can ramp values when they change without having to save/restore state.
    for (int frame = 0; frame < frameCount; ++frame) {

      auto depth = depth_.frameValue();
      auto intensity = intensity_.frameValue();

      auto evenMod = lfo_.value();
      auto oddMod = odd90_ ? lfo_.quadPhaseValue() : evenMod;

      lfo_.increment();

      auto dry = dry_.frameValue();
      auto wet = wet_.frameValue();

      for (int channel = 0; channel < ins.size(); ++channel) {
        auto inputSample = *ins[channel]++;
        auto& shifter = phaseShifters_[channel];
        shifter.setIntensity(intensity);
        auto filteredSample = shifter.process(((channel & 1) ? oddMod : evenMod) * depth, inputSample);
        *outs[channel]++ = dry * inputSample + wet * filteredSample;
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  PercentageParameter<AUValue> depth_;
  PercentageParameter<AUValue> intensity_;
  PercentageParameter<AUValue> dry_;
  PercentageParameter<AUValue> wet_;
  BoolParameter odd90_;

  std::vector<PhaseShifter<AUValue>> phaseShifters_;
  LFO<AUValue> lfo_;
};
