// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>

#import "../../Sources/Kernel/C++/Kernel.hpp"

@import ParameterAddress;

@interface KernelTests : XCTestCase

@end

@implementation KernelTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testKernelParams {
  Kernel* kernel = new Kernel("blah");
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel->setRenderingFormat(1, format, 100, 1);

  kernel->setParameterValue(ParameterAddressRate, 10.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressRate), 10.0, 0.001);

  kernel->setParameterValue(ParameterAddressDepth, 20.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressDepth), 20.0, 0.001);

  kernel->setParameterValue(ParameterAddressIntensity, 30.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressIntensity), 30.0, 0.001);

  kernel->setParameterValue(ParameterAddressDry, 40.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressDry), 40.0, 0.001);

  kernel->setParameterValue(ParameterAddressWet, 50.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressWet), 50.0, 0.001);

  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressOdd90), 0.0, 0.001);
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressOdd90), 1.0, 0.001);
}

@end
