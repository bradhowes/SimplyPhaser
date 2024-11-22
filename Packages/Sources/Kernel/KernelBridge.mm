// Copyright © 2022, 2024 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>
#import <os/log.h>

#import "C++/Kernel.hpp"
#import "Kernel.h"

// Implementation of KernelBridge is in the Kernel package so it can consume the C++ files that are here. There is a
// KernelBridge package which exposes the KernelBridge to Swift code and adds the protocols it adopts.

@implementation KernelBridge {
  Kernel* kernel_;
  int samplesPerFilterUpdate_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
    self->samplesPerFilterUpdate_ = 10;
  }
  return self;
}

- (void)setRenderingFormat:(NSInteger)busCount
                    format:(AVAudioFormat*)format
         maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  kernel_->setRenderingFormat(busCount, format, maxFramesToRender, samplesPerFilterUpdate_);
}

- (void)deallocateRenderResources { kernel_->deallocateRenderResources(); }

- (AUInternalRenderBlock)internalRenderBlock {
  __block auto kernel = kernel_;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    return kernel->processAndRender(timestamp, frameCount, outputBusNumber, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (AUImplementorValueObserver)parameterValueObserverBlock {
  __block auto kernel = kernel_;
  return ^(AUParameter* parameter, AUValue value) {
    kernel->setParameterValue(parameter.address, value);
  };
}

- (AUImplementorValueProvider)parameterValueProviderBlock {
  __block auto kernel = kernel_;
  return ^AUValue(AUParameter* address) {
    return kernel->getParameterValue(address.address);
  };
}

@end
