// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>

#import "Biquad.h"
#import "fxobjects.h"

#define SamplesEqual(A, B) XCTAssertEqualWithAccuracy(A, B, _epsilon)

@interface BiquadTests : XCTestCase
@property float epsilon;
@end

@implementation BiquadTests

- (void)setUp {
  _epsilon = 0.0001;
}

- (void)testDefaultCoefficients {
  Biquad::Coefficients<double> zeros;
  SamplesEqual(0.0, zeros.a0);
  SamplesEqual(0.0, zeros.a1);
  SamplesEqual(0.0, zeros.a2);
  SamplesEqual(0.0, zeros.b1);
  SamplesEqual(0.0, zeros.b2);
}

- (void)testCoefficients {
  auto coefficients = Biquad::Coefficients<double>()
  .A0(1.0)
  .A1(2.0)
  .A2(3.0)
  .B1(4.0)
  .B2(5.0);
  SamplesEqual(1.0, coefficients.a0);
  SamplesEqual(2.0, coefficients.a1);
  SamplesEqual(3.0, coefficients.a2);
  SamplesEqual(4.0, coefficients.b1);
  SamplesEqual(5.0, coefficients.b2);
}

- (void)testNOP {
  Biquad::Coefficients<double> zeros;
  Biquad::Direct<double> foo(zeros);
  SamplesEqual(0.0, foo.transform(0.0));
  SamplesEqual(0.0, foo.transform(10.0));
  SamplesEqual(0.0, foo.transform(20.0));
  SamplesEqual(0.0, foo.transform(30.0));
}

- (void)testLPF2Coefficients {
  // Test values taken from https://www.earlevel.com/main/2013/10/13/biquad-calculator-v2/
  double sampleRate = 44100.0;
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::LPF2(sampleRate, 3000.0, 0.707);
  SamplesEqual(0.03478485, coefficients.a0);
  SamplesEqual(0.06956969, coefficients.a1);
  SamplesEqual(0.03478485, coefficients.a2);
  SamplesEqual(-1.40745716, coefficients.b1);
  SamplesEqual(0.54659654, coefficients.b2);
}

- (void)testHPF2Coefficients {
  // Test values taken from https://www.earlevel.com/main/2013/10/13/biquad-calculator-v2/
  double sampleRate = 44100.0;
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::HPF2(sampleRate, 3000.0, 0.707);
  SamplesEqual(0.73851343, coefficients.a0);
  SamplesEqual(-1.47702685, coefficients.a1);
  SamplesEqual(0.73851343, coefficients.a2);
  SamplesEqual(-1.40745716, coefficients.b1);
  SamplesEqual(0.54659654, coefficients.b2);
}

- (void)testReset {
  double sampleRate = 44100.0;
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::LPF1(sampleRate, 8000.0);
  Biquad::Direct<double> filter(coefficients);
  SamplesEqual(0.00000, filter.transform(0.0));
  SamplesEqual(0.39056, filter.transform(1.0));
  filter.reset();
  SamplesEqual(0.00000, filter.transform(0.0));
}

- (void)testLPF {
  double sampleRate = 44100.0;
  double frequency = 8000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::LPF1(sampleRate, frequency);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kLPF1;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * Pirkle::kPi / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

- (void)testLPF2 {
  double sampleRate = 44100.0;
  double frequency = 4000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::LPF2(sampleRate, frequency, 0.707);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kLPF2;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * Pirkle::kPi / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

- (void)testHPF2 {
  double sampleRate = 44100.0;
  double frequency = 8000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::HPF2(sampleRate, frequency, 0.707);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kHPF2 ;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * Pirkle::kPi / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

- (void)testHPF {
  double sampleRate = 44100.0;
  double frequency = 8000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::HPF1(sampleRate, frequency);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kHPF1;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * Pirkle::kPi / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

- (void)testAPF1 {
  double sampleRate = 44100.0;
  double frequency = 4000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::APF1(sampleRate, frequency);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kAPF1;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * M_PI / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

- (void)testAPF2 {
  double sampleRate = 44100.0;
  double frequency = 4000.0;
  
  Biquad::Coefficients coefficients = Biquad::Coefficients<double>::APF2(sampleRate, frequency, 0.707);
  Biquad::Direct<double> filter(coefficients);
  Pirkle::AudioFilterParameters params;
  params.algorithm = Pirkle::filterAlgorithm::kAPF2;
  params.fc = frequency;
  Pirkle::AudioFilter pirkle;
  pirkle.setParameters(params);
  
  for (int counter = 0; counter < 7200; ++counter) {
    double input = std::sin(counter/10.0 * M_PI / 180.0 );
    double output1 = filter.transform(input);
    double output2 = pirkle.processAudioSample(input);
    SamplesEqual(output1, output2);
  }
}

@end
