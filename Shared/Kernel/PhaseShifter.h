// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
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
    using AllPassFilter = Biquad::CanonicalTranspose<T>;

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

    PhaseShifter(const FrequencyBands& bands, T sampleRate, T intensity, int samplesPerFilterUpdate = 10)
    : bands_(bands), sampleRate_{sampleRate}, intensity_{intensity}, samplesPerFilterUpdate_{samplesPerFilterUpdate},
    filters_(bands_.size(), AllPassFilter()), gammas_(bands.size() + 1, 1.0)
    {
        updateCoefficients(0.0);
    }

    void setIntensity(double intensity) {
        intensity_ = intensity;
    }

    void reset() {
        sampleCounter_ = 0;
        for (auto& filter : filters_) {
            filter.reset();
        }
    }

    T process(T modulation, T input) {

        // With samplersPerFilterUpdate_ == 1, this replicates the phaser processing described in
        // "Designing Audio Effect Plugins in C++" by Will C. Pirkle (2019).
        //
        if (sampleCounter_++ >= samplesPerFilterUpdate_) {
            updateCoefficients(modulation);
            sampleCounter_ = 1;
        }

        // Calculate gamma values
        for (auto index = 1; index <= filters_.size(); ++index) {
            gammas_[index] = filters_[filters_.size() - index].gainValue() * gammas_[index - 1];
        }

        // Calculate weighted state sum to submit to filtering
        T weightedSum = 0.0;
        for (auto index = 0; index < filters_.size(); ++index) {
            weightedSum += gammas_[filters_.size() - index - 1] * filters_[index].storageComponent();
        }

        // Finally, apply the filters in series
        T output = (input + intensity_ * weightedSum) / (1.0 + intensity_ * gammas_.back());
        for (auto& filter : filters_) {
            output = filter.transform(output);
        }

        return output;
    }

private:

    void updateCoefficients(T modulation) {
        assert(filters_.size() == bands_.size());
        for (auto index = 0; index < filters_.size(); ++index) {
            auto const& band = bands_[index];
            double frequency = DSP::bipolarModulation(modulation, band.frequencyMin, band.frequencyMax);
            filters_[index].setCoefficients(Biquad::Coefficients<T>::APF1(sampleRate_, frequency));
        }
    }

    const FrequencyBands& bands_;
    double sampleRate_;
    double intensity_;
    int samplesPerFilterUpdate_;
    int sampleCounter_{0};
    std::vector<AllPassFilter> filters_;
    std::vector<double> gammas_;

    os_log_t log_ = os_log_create("PhaseShifter", "SimplyPhaserKernel");
};
