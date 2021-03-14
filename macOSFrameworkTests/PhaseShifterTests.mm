// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>

#import "fxobjects.h"
#import "LFO.h"
#import "PhaseShifter.h"

#define SamplesEqual(A, B) XCTAssertEqualWithAccuracy(A, B, _epsilon)

@interface PhaseShifterTests : XCTestCase
@property float epsilon;
@end

@implementation PhaseShifterTests

- (void)setUp {
    _epsilon = 0.0001;
    self.continueAfterFailure = false;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testPhaseShifters {
    double sampleRate = 44100.0;
    double lfoFrequency = 0.2;
    Pirkle::PhaseShifter phaseShifterOld;
    phaseShifterOld.reset(sampleRate);

    auto params = phaseShifterOld.getParameters();
    params.intensity_Pct = 100.0;
    params.lfoDepth_Pct = 100.0;
    params.lfoRate_Hz = lfoFrequency;
    params.quadPhaseLFO = false;
    phaseShifterOld.setParameters(params);

    LFO<double> lfo(sampleRate, lfoFrequency, LFOWaveform::triangle);
    PhaseShifter<double> phaseShifterNew{PhaseShifter<double>::ideal, sampleRate, 1.0, 1};

    for (int counter = 0; counter < 7200; ++counter) {
        double input = std::sin(counter/10.0 * M_PI / 180.0 );
        double output1 = phaseShifterOld.processAudioSample(input);
        double modulator = lfo.valueAndIncrement();
        double output2 = phaseShifterNew.process(modulator, input);
        SamplesEqual(output1, output2);
    }
}

- (void)doPhaseShifting {
    double sampleRate = 44100.0;
    double lfoFrequency = 0.2;
    LFO<double> lfo(sampleRate, lfoFrequency, LFOWaveform::triangle);
    PhaseShifter<double> phaseShifter{PhaseShifter<double>::ideal, sampleRate, 1.0, 20};

    for (int counter = 0; counter < 44100; ++counter) {
        double input = std::sin(counter/100.0 * M_PI / 180.0 );
        double modulator = lfo.valueAndIncrement();
        phaseShifter.process(modulator, input);
    }
}

- (void)testPerformanceExample {
    [self measureBlock:^{
        [self testPhaseShifters];
    }];
}


@end
