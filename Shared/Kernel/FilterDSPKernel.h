// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DelayBuffer.h"
#import "FilterFramework/FilterFramework-Swift.h"
#import "KernelEventProcessor.h"
#import "LFO.h"
#import "PhaseShifter.h"
#import "fxobjects.h"

class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    using super = KernelEventProcessor<FilterDSPKernel>;
    friend super;

    FilterDSPKernel(const std::string& name)
    : super(os_log_create(name.c_str(), "FilterDSPKernel")), lfo_(), left_(), right_()
    {
        lfo_.setWaveform(LFOWaveform::triangle);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
        super::startProcessing(format, maxFramesToRender);
        initialize(format.channelCount, format.sampleRate);
    }

    void initialize(int channelCount, double sampleRate) {
        phaseShifters_.clear();

        for (auto index = 0; index < channelCount; ++index) {
            phaseShifters_.push_back(Pirkle::PhaseShifter());
            auto& filter = phaseShifters_.back();
            filter.reset(sampleRate);
        }

        updateParameters();

//        lfo_.initialize(sampleRate, rate_);
//        left_.initialize(sampleRate);
//        right_.initialize(sampleRate);

    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value) {
        double tmp;
        switch (address) {
            case FilterParameterAddressRate:
                if (value == rate_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "rate - %f", value);
                rate_ = value;
                lfo_.setFrequency(rate_);
                updateParameters();
                break;
            case FilterParameterAddressDepth:
                tmp = value / 100.0;
                if (tmp == depth_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "depth - %f", tmp);
                depth_ = tmp;
                updateParameters();
                break;
            case FilterParameterAddressIntensity:
                tmp = value / 100.0;
                if (tmp == intensity_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "intensity - %f", tmp);
                intensity_ = tmp;
                updateParameters();
                break;
            case FilterParameterAddressDryMix:
                tmp = value / 100.0;
                if (tmp == dryMix_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "dryMix - %f", tmp);
                dryMix_ = tmp;
                break;
            case FilterParameterAddressWetMix:
                tmp = value / 100.0;
                if (tmp == wetMix_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "wetMix - %f", tmp);
                wetMix_ = tmp;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const {
        switch (address) {
            case FilterParameterAddressRate: return rate_;
            case FilterParameterAddressDepth: return depth_ * 100.0;
            case FilterParameterAddressIntensity: return intensity_ * 100.0;
            case FilterParameterAddressDryMix: return dryMix_ * 100.0;
            case FilterParameterAddressWetMix: return wetMix_ * 100.0;
        }
        return 0.0;
    }

private:

    void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

    void doRendering(std::vector<AUValue const*> ins, std::vector<AUValue*> outs, AUAudioFrameCount frameCount) {
        for (int channel = 0; channel < ins.size(); ++channel) {
            auto& inputs = ins[channel];
            auto& outputs = outs[channel];
            for (int frame = 0; frame < frameCount; ++frame) {
                // auto lfoValue = lfo_.valueAndIncrement();
                AUValue inputSample = inputs[frame];
                AUValue outputSample = phaseShifters_[channel].processAudioSample(inputSample);
                outputs[frame] = outputSample;
            }
        }
    }

    void updateParameters() {
        Pirkle::PhaseShifterParameters params;
        params.lfoRate_Hz = rate_;
        params.lfoDepth_Pct = depth_ * 100.0;
        params.intensity_Pct = intensity_ * 100.0;
        params.quadPhaseLFO = false;
        for (auto& filter : phaseShifters_) {
            filter.setParameters(params);
        }
    }

    void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

    double rate_;
    double depth_;
    double intensity_;
    double dryMix_;
    double wetMix_;

    LFO<double> lfo_;
    PhaseShifter<double> left_;
    PhaseShifter<double> right_;

    std::vector<Pirkle::PhaseShifter> phaseShifters_;
};
