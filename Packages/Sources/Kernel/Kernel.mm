#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, duration); break;
    case ParameterAddressDepth: depth_.set(value, duration); break;
    case ParameterAddressIntensity: intensity_.set(value, duration); break;
    case ParameterAddressDry: dry_.set(value, duration); break;
    case ParameterAddressWet: wet_.set(value, duration); break;
    case ParameterAddressOdd90: odd90_.set(value); break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequency();
    case ParameterAddressDepth: return depth_.get();
    case ParameterAddressIntensity: return intensity_.get();
    case ParameterAddressDry: return dry_.get();
    case ParameterAddressWet: return wet_.get();
    case ParameterAddressOdd90: return odd90_.get();
  }
  return 0.0;
}
