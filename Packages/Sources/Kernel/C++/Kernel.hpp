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

@import ParameterAddress;

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
    registerParameters({rate_, depth_, intensity_, dry_, wet_, odd90_});
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
    lfo_.setWaveform(LFOWaveform::triangle);
    phaseShifters_.reserve(channelCount);
    phaseShifters_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      phaseShifters_.emplace_back(DSPHeaders::PhaseShifter<AUValue>::ideal,
                                  sampleRate,
                                  intensity_.getImmediate(),
                                  samplesPerFilterUpdate_);
    }
  }

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

  int samplesPerFilterUpdate_;
  DSPHeaders::Parameters::Float rate_{ParameterAddressRate};
  DSPHeaders::Parameters::Percentage depth_{ParameterAddressDepth};
  DSPHeaders::Parameters::Percentage intensity_{ParameterAddressIntensity};
  DSPHeaders::Parameters::Percentage dry_{ParameterAddressDry};
  DSPHeaders::Parameters::Percentage wet_{ParameterAddressWet};
  DSPHeaders::Parameters::Bool odd90_{ParameterAddressOdd90};
  DSPHeaders::LFO<AUValue> lfo_{rate_};
  std::vector<DSPHeaders::PhaseShifter<AUValue>> phaseShifters_{};
  std::string name_;
  os_log_t log_;
};
