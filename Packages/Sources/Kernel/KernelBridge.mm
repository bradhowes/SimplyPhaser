// Copyright © 2022, 2024 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>
#import <os/log.h>

#import "C++/Kernel.hpp"
#import "Kernel.h"

// Implementation of KernelBridge is in the Kernel package so it can consume the C++ files that are here. There is a
// KernelBridge package which exposes the KernelBridge to Swift code and adds the protocols it adopts.

@implementation KernelBridge {
  Kernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName samplesPerFilterUpdate:(int)count {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String), count);
  }

  return self;
}

- (void)setRenderingFormat:(NSInteger)busCount format:(AVAudioFormat*)format
         maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  kernel_->setRenderingFormat(busCount, format, maxFramesToRender);
}

- (void)deallocateRenderResources { kernel_->deallocateRenderResources(); }

- (AUInternalRenderBlock)internalRenderBlock {
  __block auto dsp = kernel_;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    return dsp->processAndRender(timestamp, frameCount, outputBusNumber, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (AUImplementorValueObserver)parameterValueObserverBlock {
  __block auto dsp = kernel_;
  return ^(AUParameter* parameter, AUValue value) {
    dsp->setParameterValuePending(parameter.address, value);
  };
}

- (AUImplementorValueProvider)parameterValueProviderBlock {
  __block auto dsp = kernel_;
  return ^AUValue(AUParameter* address) {
    return dsp->getParameterValuePending(address.address);
  };
}

@end
