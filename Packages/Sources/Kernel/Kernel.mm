#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

bool Kernel::doSetImmediateParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, duration); return true;
    case ParameterAddressDepth: depth_.setImmediate(value, duration); return true;
    case ParameterAddressIntensity: intensity_.setImmediate(value, duration); return true;
    case ParameterAddressDry: dry_.setImmediate(value, duration); return true;
    case ParameterAddressWet: wet_.setImmediate(value, duration); return true;
    case ParameterAddressOdd90: odd90_.setImmediate(value, 0); return true;
  }
}

bool Kernel::doSetPendingParameterValue(AUParameterAddress address, AUValue value) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequencyPending(value); return true;
    case ParameterAddressDepth: depth_.setPending(value); return true;
    case ParameterAddressIntensity: intensity_.setPending(value); return true;
    case ParameterAddressDry: dry_.setPending(value); return true;
    case ParameterAddressWet: wet_.setPending(value); return true;
    case ParameterAddressOdd90: odd90_.setPending(value);return true;
  }
  return false;
}

AUValue Kernel::doGetImmediateParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequency();
    case ParameterAddressDepth: return depth_.getImmediate();
    case ParameterAddressIntensity: return intensity_.getImmediate();
    case ParameterAddressDry: return dry_.getImmediate();
    case ParameterAddressWet: return wet_.getImmediate();
    case ParameterAddressOdd90: return odd90_.getImmediate();
  }
  return 0.0;
}

AUValue Kernel::doGetPendingParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequencyPending();
    case ParameterAddressDepth: return depth_.getPending();
    case ParameterAddressIntensity: return intensity_.getPending();
    case ParameterAddressDry: return dry_.getPending();
    case ParameterAddressWet: return wet_.getPending();
    case ParameterAddressOdd90: return odd90_.getPending();
  }
  return 0.0;
}
