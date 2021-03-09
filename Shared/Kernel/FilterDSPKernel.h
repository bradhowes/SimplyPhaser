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
    : super(os_log_create(name.c_str(), "FilterDSPKernel")), lfo_()
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
        phaseShifter_.clear();
        for (auto index = 0; index < channelCount; ++index) {
            phaseShifter_.push_back(PhaseShifter<double>());
            auto& filter = phaseShifter_.back();
            filter.initialize(sampleRate, intensity_);
        }
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
                break;
            case FilterParameterAddressDepth:
                tmp = value / 100.0;
                if (tmp == depth_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "depth - %f", tmp);
                depth_ = tmp;
                break;
            case FilterParameterAddressIntensity:
                tmp = value / 100.0;
                if (tmp == intensity_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "intensity - %f", tmp);
                intensity_ = tmp;
                intensityChanged();
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
        auto lfoState = lfo_.saveState();
        for (int channel = 0; channel < ins.size(); ++channel) {
            auto& inputs = ins[channel];
            auto& outputs = outs[channel];
            if (channel > 0) lfo_.restoreState(lfoState);
            auto& shifterNew{phaseShifter_[channel]};
            for (int frame = 0; frame < frameCount; ++frame) {
                auto inputSample = inputs[frame];
                auto outputSample = shifterNew.process(lfo_.valueAndIncrement() * depth_, inputSample);
                outputs[frame] = dryMix_ * inputSample + wetMix_ * outputSample;
            }
        }
    }

    void intensityChanged() {
        for (auto& filter : phaseShifter_) {
            filter.setIntensity(intensity_);
        }
    }

    void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

    double rate_;
    double depth_;
    double intensity_;
    double dryMix_;
    double wetMix_;

    LFO<double> lfo_;

    std::vector<PhaseShifter<double>> phaseShifter_;
};
