// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>

#import "C++/Kernel.hpp"
#import "Kernel.h"

// Implementation of KernelBridge is in the Kernel package so it can consume the C++ files that are here. There is a
// KernelBridge package which exposes the KernelBridge to Swift code and adds the protocols it adopts.

@implementation KernelBridge {
  Kernel* kernel_;
  AUAudioFrameCount maxFramesToRender_;
  os_log_t log_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
    self->maxFramesToRender_ = 0;
    self->log_ = os_log_create(appExtensionName.UTF8String, "KernelBridge");
  }

  return self;
}

- (void)setRenderingFormat:(AVAudioFormat*)format maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  kernel_->setRenderingFormat(format, maxFramesToRender);
  maxFramesToRender_ = maxFramesToRender;
}

- (void)renderingStopped { kernel_->renderingStopped(); }

- (AUInternalRenderBlock)internalRenderBlock {
  auto& kernel = *kernel_;
//  auto& log = log_;
  auto maxFramesToRender = maxFramesToRender_;
  NSInteger bus = 0;

//  os_log_with_type(log, OS_LOG_TYPE_INFO, "transportStateBlock");
//
//  if (transportStateBlock != nullptr) {
//    AUHostTransportStateFlags flags = 0;
//    double currentSamplePosition = 0.0;
//    double cycleStartBeatPosition = 0.0;
//    double cycleEndBeatPosition = 0.0;
//    transportStateBlock(&flags, &currentSamplePosition, &cycleStartBeatPosition, &cycleEndBeatPosition);
//    os_log_with_type(log, OS_LOG_TYPE_INFO, "transport: %ld", flags);
//  } else {
//    os_log_with_type(log, OS_LOG_TYPE_INFO, "nil transportStateBlock");
//  }
//
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    // My reading of the flags is that they should all be zero on input for normal rendering.
    if (*flags != 0) return 0;
    if (frameCount > maxFramesToRender) return kAudioUnitErr_TooManyFramesToProcess;
    if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
    return kernel.processAndRender(timestamp, frameCount, bus, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

@end
