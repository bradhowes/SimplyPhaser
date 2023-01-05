// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DSPHeaders/BoolParameter.hpp"
#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/DelayBuffer.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/MillisecondsParameter.hpp"
#import "DSPHeaders/LFO.hpp"
#import "DSPHeaders/PercentageParameter.hpp"
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
  Kernel(std::string name) noexcept : super(), name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    os_log_debug(log_, "constructor");
    lfo_.setWaveform(LFOWaveform::triangle);
  }

  /**
   Update kernel and buffers to support the given format.

   @param busCount the number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) noexcept {
    os_log_info(log_, "setRenderingFormat BEGIN");
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
    os_log_info(log_, "setRenderingFormat END");
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value) noexcept {
    setRampedParameterValue(address, value, AUAudioFrameCount(50));
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   @param duration the number of samples to adjust over
   */
  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const noexcept;

private:

  void initialize(int channelCount, double sampleRate) noexcept {
    os_log_info(log_, "initialize BEGIN - %d %f", channelCount, sampleRate);
    lfo_.setSampleRate(sampleRate);
    phaseShifters_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      phaseShifters_.emplace_back(DSPHeaders::PhaseShifter<AUValue>::ideal, sampleRate, intensity_.get(), 20);
    }
    os_log_info(log_, "initialize END");
  }

  void setParameterFromEvent(const AUParameterEvent& event) noexcept {
    setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
  }

  void doRenderingStateChanged(bool rendering) noexcept {
    if (!rendering) {
      depth_.stopRamping();
      intensity_.stopRamping();
      dry_.stopRamping();
      wet_.stopRamping();
      lfo_.stopRamping();
    }
  }

  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
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

  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  DSPHeaders::LFO<AUValue> lfo_;
  DSPHeaders::Parameters::PercentageParameter<> depth_;
  DSPHeaders::Parameters::PercentageParameter<> intensity_;
  DSPHeaders::Parameters::PercentageParameter<> dry_;
  DSPHeaders::Parameters::PercentageParameter<> wet_;
  DSPHeaders::Parameters::BoolParameter<> odd90_;
  std::vector<DSPHeaders::PhaseShifter<AUValue>> phaseShifters_;
  std::string name_;
  os_log_t log_;
};
