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
  Kernel(std::string name, int samplesPerFilterUpdate) noexcept :
  super(), samplesPerFilterUpdate_{samplesPerFilterUpdate}, name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    lfo_.setWaveform(LFOWaveform::triangle);
    registerParameter(depth_);
    registerParameter(intensity_);
    registerParameter(dry_);
    registerParameter(wet_);
    registerParameter(odd90_);
  }

  /**
   Update kernel and buffers to support the given format.

   @param busCount the number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) noexcept {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValuePending(AUParameterAddress address, AUValue value) noexcept;

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   @param duration the number of samples to adjust over
   */
  AUAudioFrameCount setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValuePending(AUParameterAddress address) const noexcept;

private:

  void initialize(int channelCount, double sampleRate) noexcept {
    lfo_.setSampleRate(sampleRate);
    phaseShifters_.reserve(channelCount);
    phaseShifters_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      phaseShifters_.emplace_back(DSPHeaders::PhaseShifter<AUValue>::ideal, sampleRate, intensity_.get(),
                                  samplesPerFilterUpdate_);
    }
  }

  AUAudioFrameCount doParameterEvent(const AUParameterEvent& event, AUAudioFrameCount duration) noexcept {
    return setRampedParameterValue(event.parameterAddress, event.value, duration);
  }

  void doRenderingStateChanged(bool rendering) noexcept {}

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
    auto odd90 = odd90_.get();
    if (frameCount == 1) {
      auto depth = depth_.frameValue();
      auto evenModDepth = lfo_.value() * depth;
      auto oddModDepth = odd90 ? (lfo_.quadPhaseValue() * depth) : evenModDepth;
      lfo_.increment();
      writeSample(ins, outs, intensity_.frameValue(), evenModDepth, oddModDepth, wet_.frameValue(), dry_.frameValue());
    } else {
      auto depth = depth_.get();
      auto intensity = intensity_.get();
      auto wet = wet_.get();
      auto dry = dry_.get();

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
