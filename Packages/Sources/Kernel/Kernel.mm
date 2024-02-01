#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

AUAudioFrameCount Kernel::setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, duration); return duration;
    case ParameterAddressDepth: depth_.set(value, duration); return duration;
    case ParameterAddressIntensity: intensity_.set(value, duration); return duration;
    case ParameterAddressDry: dry_.set(value, duration); return duration;
    case ParameterAddressWet: wet_.set(value, duration); return duration;
    case ParameterAddressOdd90: odd90_.set(value, 0); return 0;
  }
}

void Kernel::setParameterValuePending(AUParameterAddress address, AUValue value) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequencyPending(value); break;
    case ParameterAddressDepth: depth_.setPending(value); break;
    case ParameterAddressIntensity: intensity_.setPending(value); break;
    case ParameterAddressDry: dry_.setPending(value);
    case ParameterAddressWet: wet_.setPending(value);
    case ParameterAddressOdd90: odd90_.setPending(value);
  }
  return 0.0;
}

AUValue Kernel::getParameterValuePending(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequencyPending();
    case ParameterAddressDepth: return depth_.getPending();
    case ParameterAddressIntensity: return intensity_.getPending();
    case ParameterAddressDry: return dry_.getPending();
    case ParameterAddressWet: return wet_.getPending();
    case ParameterAddressOdd90: return odd90_.get();
  }
  return 0.0;
}
