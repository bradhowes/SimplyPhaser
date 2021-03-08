// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <vector>

#import "Biquad.h"
#import "DSP.h"

template <typename F, typename IteratorA, typename IteratorB>
void zip(F func, IteratorA aPos, IteratorA aEnd, IteratorB bPos, IteratorB bEnd) {
    while (aPos != aEnd && bPos != bEnd) {
        auto& a = *aPos++;
        auto& b = *bPos++;
        func(a, b);
    }
}

template <typename T>
class PhaseShifter {
public:
    using AllPassFilter = Biquad::Direct;

    struct Band {
        double frequencyMin;
        double frequencyMax;
    };

    using FrequencyBands = std::vector<Band>;

    inline static FrequencyBands ideal = {
        Band{16.0, 1600.0},
        Band{33.0, 3300.0},
        Band{48.0, 4800.0},
        Band{98.0, 9800.0},
        Band{160.0, 16000.0},
        Band{260.0, 20480.0}
    };

    inline static FrequencyBands nationalSemiconductor = {
        Band{32.0, 1500.0},
        Band{68.0, 3400.0},
        Band{96.0, 4800.0},
        Band{212.0, 10000.0},
        Band{320.0, 16000.0},
        Band{636.0, 20480.0}
    };

    PhaseShifter(const FrequencyBands& bands) : bands_(bands), filters_(bands_.size(), AllPassFilter())
    {}

    PhaseShifter() : PhaseShifter(ideal) {}

    void initialize(double sampleRate) {
        sampleRate_ = sampleRate;
        updateCoefficients(0.0);
    }

    void reset() {
        for (auto& filter : filters_) {
            filter.reset();
        }
    }

    T value(T modulation, T input);

private:

    void updateCoefficients(T modulation) {
        assert(filters_.size() == bands_.size());
        double sampleRate = sampleRate_;
        zip([sampleRate, modulation](AllPassFilter& filter, const Band& band) {
            double frequency = DSP::unipolarModulation(modulation, band.frequencyMin, band.frequencyMax);
            filter.setCoefficients(Biquad::Coefficients::APF1(sampleRate, frequency));
        }, filters_.begin(), filters_.end(), bands_.begin(), bands_.end());
    }

    const FrequencyBands& bands_;
    double sampleRate_;
    std::vector<AllPassFilter> filters_;
};
