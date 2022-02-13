// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>
#import <os/log.h>

#import "C++/Kernel.hpp"
#import "Kernel.h"

// Implementation of KernelBridge is in the Kernel package so it can consume the C++ files that are here. There is a
// KernelBridge package which exposes the KernelBridge to Swift code and adds the protocols it adopts.

@implementation KernelBridge {
  os_log_t log_;
  Kernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->log_ = os_log_create([appExtensionName UTF8String], "KernelBridge");
    os_log_info(log_, "init");
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
  }

  return self;
}

- (void)setRenderingFormat:(AVAudioFormat*)format maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  os_log_info(log_, "setRenderingFormat BEGIN");
  kernel_->setRenderingFormat(format, maxFramesToRender);
  os_log_info(log_, "setRenderingFormat END");
}

- (void)renderingStopped {
  os_log_info(log_, "renderingStopped BEGIN");
  kernel_->renderingStopped();
  os_log_info(log_, "renderingStopped END");
}

- (AUInternalRenderBlock)internalRenderBlock {
  os_log_info(log_, "internalRenderBlock");
  auto& kernel = *kernel_;
  auto& log = log_;
  NSInteger bus = 0;

  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    os_log_info(log_, "internalRenderBlock - calling processAndRender");
    return kernel.processAndRender(timestamp, frameCount, bus, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state { kernel_->setBypass(state); }

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

@end
