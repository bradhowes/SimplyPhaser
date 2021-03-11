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

    PhaseShifter(const FrequencyBands& bands, int samplesPerFilterUpdate = 1)
    : bands_(bands), samplesPerFilterUpdate_{samplesPerFilterUpdate}, filters_(bands_.size(), AllPassFilter())
    {}

    PhaseShifter() : PhaseShifter(ideal) {}

    void initialize(double sampleRate, double intensity) {
        sampleRate_ = sampleRate;
        intensity_ = intensity;
        updateCoefficients(0.0);
    }

    void setIntensity(double intensity) {
        intensity_ = intensity;
    }

    void reset() {
        for (auto& filter : filters_) {
            filter.reset();
        }
    }

    T process(T modulation, T input) {

        // With samplersPerFilterUpdate_ == 1, this replicates the phaser processing described in
        // "Designing Audio Effect Plugins in C++" by Will C. Pirkle (2019).
        //
        if (sampleCounter_ >= samplesPerFilterUpdate_) {
            updateCoefficients(modulation);
            sampleCounter_ = 0;
        }

        // Calculate gamma values
        std::vector<T> gammas(1, 1.0);
        std::for_each(filters_.rbegin(), filters_.rend(), [& gammas](auto& filter) {
            gammas.push_back(filter.gainValue() * gammas.back());
        });

        // Calculate weighted state sum to submit to filtering
        T alpha0 = 1.0 / (1.0 + intensity_ * gammas.back());
        gammas.pop_back();
        T weightedSum = 0.0;
        std::for_each(filters_.begin(), filters_.end(), [&gammas, &weightedSum](auto& filter) {
            auto gamma = gammas.back();
            gammas.pop_back();
            weightedSum += gamma * filter.storageComponent();
        });

        // Finally, apply the filters in series
        T output = alpha0 * (input + intensity_ * weightedSum);
        for (auto& filter : filters_) {
            output = filter.transform(output);
        }

        ++sampleCounter_;
        return output;
    }

private:

    void updateCoefficients(T modulation) {
        assert(filters_.size() == bands_.size());
        double sampleRate = sampleRate_;
        zip([sampleRate, modulation](AllPassFilter& filter, const Band& band) {
            double frequency = DSP::bipolarModulation(modulation, band.frequencyMin, band.frequencyMax);
            filter.setCoefficients(Biquad::Coefficients<T>::APF1(sampleRate, frequency));
        }, filters_.begin(), filters_.end(), bands_.begin(), bands_.end());
    }

    const FrequencyBands& bands_;
    double sampleRate_;
    double intensity_;
    int samplesPerFilterUpdate_;
    int sampleCounter_{0};
    std::vector<AllPassFilter> filters_;
};
