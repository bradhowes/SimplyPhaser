// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>
#import <os/log.h>

#import "C++/Kernel.hpp"
#import "Kernel.h"

// Implementation of KernelBridge is in the Kernel package so it can consume the C++ files that are here. There is a
// KernelBridge package which exposes the KernelBridge to Swift code and adds the protocols it adopts.

@implementation KernelBridge {
  Kernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
  }

  return self;
}

- (void)setRenderingFormat:(NSInteger)busCount format:(AVAudioFormat*)format
         maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  kernel_->setRenderingFormat(busCount, format, maxFramesToRender);
}

- (void)deallocateRenderResources { kernel_->deallocateRenderResources(); }

- (AUInternalRenderBlock)internalRenderBlock:(nullable AUHostTransportStateBlock)tsb {
  __block auto kernel = kernel_;
  __block auto transportStateBlock = tsb;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger outputBusNumber, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    if (transportStateBlock) {
      AUHostTransportStateFlags flags;
      transportStateBlock(&flags, NULL, NULL, NULL);
      bool rendering = flags & AUHostTransportStateMoving;
      kernel->setRendering(rendering);
    }
    return kernel->processAndRender(timestamp, frameCount, outputBusNumber, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

@end
