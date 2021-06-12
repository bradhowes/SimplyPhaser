// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <vector>
#import <AudioToolbox/AudioToolbox.h>

#include "InputBuffer.h"

/**
 Base template class for DSP kernels that provides common functionality. It properly interleaves render events with
 parameter updates. It is expected that the template parameter defines the following methods which this class will
 invoke at the appropriate times but without any virtual dispatching.
 
 - doParameterEvent
 - doMIDIEvent
 - doRenderFrames
 
 */
template <typename T> class KernelEventProcessor {
public:
  
  /**
   Construct new instance.
   
   @param log the log identifier to use for our logging statements
   */
  KernelEventProcessor(os_log_t log) : log_{log}, derived_{*static_cast<T*>(this)} {}
  
  /**
   Set the bypass mode.
   
   @param bypass if true disable filter processing and just copy samples from input to output
   */
  void setBypass(bool bypass) { bypassed_ = bypass; }
  
  /**
   Begin processing with the given format and channel count.
   
   @param format the sample format to expect
   @param maxFramesToRender the maximum number of frames to expect on input
   */
  void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
    inputBuffer_.allocateBuffers(format, maxFramesToRender);
  }
  
  /**
   Stop processing. Free up any resources that were used during rendering.
   */
  void stopProcessing() { inputBuffer_.releaseBuffers(); }
  
  /**
   Process events and render a given number of frames. Events and rendering are interleaved if necessary so that
   event times align with samples.
   
   @param timestamp the timestamp of the first sample or the first event
   @param frameCount the number of frames to process
   @param inputBusNumber the bus to pull samples from
   @param output the buffer to hold the rendered samples
   @param realtimeEventListHead pointer to the first AURenderEvent (may be null)
   @param pullInputBlock the closure to call to obtain upstream samples
   */
  AUAudioUnitStatus processAndRender(AudioTimeStamp* timestamp, UInt32 frameCount, NSInteger inputBusNumber,
                                     AudioBufferList* output, AURenderEvent* realtimeEventListHead,
                                     AURenderPullInputBlock pullInputBlock)
  {
    AudioUnitRenderActionFlags actionFlags = 0;
    auto status = inputBuffer_.pullInput(&actionFlags, timestamp, frameCount, inputBusNumber, pullInputBlock);
    if (status != noErr) {
      os_log_with_type(log_, OS_LOG_TYPE_ERROR, "failed pullInput - %d", status);
      return status;
    }
    
    // If performing in-place operation, set output to use input buffers
    auto inPlace = output->mBuffers[0].mData == nullptr;
    if (inPlace) {
      AudioBufferList* input = inputBuffer_.mutableAudioBufferList();
      for (auto i = 0; i < output->mNumberBuffers; ++i) {
        output->mBuffers[i].mData = input->mBuffers[i].mData;
      }
    }
    
    setBuffers(inputBuffer_.mutableAudioBufferList(), output);
    render(timestamp, frameCount, realtimeEventListHead);
    clearBuffers();
    
    return noErr;
  }
  
protected:
  os_log_t log_;
  
private:
  
  void render(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events)
  {
    auto zero = AUEventSampleTime(0);
    auto now = AUEventSampleTime(timestamp->mSampleTime);
    auto framesRemaining = frameCount;
    
    // Keep working until all frames are processed
    while (framesRemaining > 0) {
      
      // No more events to interleave -- just process everything that is left
      if (events == nullptr) {
        renderFrames(framesRemaining, frameCount - framesRemaining);
        return;
      }
      
      // Determine the number of frames to process up until the next event time, and process them
      auto framesThisSegment = AUAudioFrameCount(std::max(events->head.eventSampleTime - now, zero));
      if (framesThisSegment > 0) {
        renderFrames(framesThisSegment, frameCount - framesRemaining);
        framesRemaining -= framesThisSegment;
        now += AUEventSampleTime(framesThisSegment);
      }
      
      // Process the events that are to happen now
      events = renderEventsUntil(now, events);
    }
  }
  
  void setBuffers(AudioBufferList const* inputs, AudioBufferList* outputs)
  {
    if (inputs == inputs_ && outputs_ == outputs) return;
    inputs_ = inputs;
    outputs_ = outputs;
    ins_.clear();
    outs_.clear();
    for (size_t channel = 0; channel < inputs->mNumberBuffers; ++channel) {
      ins_.emplace_back(static_cast<AUValue*>(inputs_->mBuffers[channel].mData));
      outs_.emplace_back(static_cast<AUValue*>(outputs_->mBuffers[channel].mData));
    }
  }
  
  void clearBuffers()
  {
    inputs_ = nullptr;
    outputs_ = nullptr;
    ins_.clear();
    outs_.clear();
  }
  
  AURenderEvent const* renderEventsUntil(AUEventSampleTime now, AURenderEvent const* event)
  {
    while (event != nullptr && event->head.eventSampleTime <= now) {
      switch (event->head.eventType) {
        case AURenderEventParameter:
        case AURenderEventParameterRamp:
          derived_.doParameterEvent(event->parameter);
          break;
          
        case AURenderEventMIDI:
          derived_.doMIDIEvent(event->MIDI);
          break;
          
        default:
          break;
      }
      event = event->head.next;
    }
    return event;
  }
  
  void renderFrames(AUAudioFrameCount frameCount, AUAudioFrameCount processedFrameCount)
  {
    if (bypassed_) {
      for (size_t channel = 0; channel < inputs_->mNumberBuffers; ++channel) {
        // In-place processing needs nothing to be done.
        if (inputs_->mBuffers[channel].mData == outputs_->mBuffers[channel].mData) {
          continue;
        }
        
        // Copy samples from input buffer to output buffer
        auto in = static_cast<AUValue*>(inputs_->mBuffers[channel].mData) + processedFrameCount;
        auto out = static_cast<AUValue*>(outputs_->mBuffers[channel].mData) + processedFrameCount;
        memcpy(out, in, frameCount * sizeof(AUValue));
      }
      return;
    }
    
    // Setup vectorized buffers for easier handling in C++. Here we assume that this will usually be done once for each
    // render call from Core Audio. If there are a lot of interleaved events, then moving this out to the `setBuffers`
    // routine probably makes sense, though it would require changes to `doRendering` to perform the offsetting with
    // `processedFrameCount`.
    for (size_t channel = 0; channel < inputs_->mNumberBuffers; ++channel) {
      ins_[channel] = static_cast<AUValue*>(inputs_->mBuffers[channel].mData) + processedFrameCount;
      outs_[channel] = static_cast<AUValue*>(outputs_->mBuffers[channel].mData) + processedFrameCount;
      outputs_->mBuffers[channel].mDataByteSize = sizeof(AUValue) * (processedFrameCount + frameCount);
    }
    
    derived_.doRendering(ins_, outs_, frameCount);
  }
  
  /// Reference to `this` but in its derived form.
  T& derived_;
  /// Input buffer manager for the audio buffers used during processing
  InputBuffer inputBuffer_;
  /// Pointer to array of buffers that hold the input data (one per channel)
  AudioBufferList const* inputs_ = nullptr;
  /// Pointer to array of buffers that hold the output data (one per channel)
  AudioBufferList* outputs_ = nullptr;
  /// Vector of AUValue arrays for input samples
  std::vector<AUValue const*> ins_;
  /// Vector of AUValue arrays for output samples
  std::vector<AUValue*> outs_;
  /// True if input buffers are copied as-is to output buffers
  bool bypassed_ = false;
};
