// Copyright © 2021 Brad Howes. All rights reserved.

extension Color {
  
  convenience init(hex: String, alpha: CGFloat = 1.0) {
    var hexFormatted = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).uppercased()
    if hexFormatted.hasPrefix("#") {
      hexFormatted = String(hexFormatted.dropFirst())
    }
    
    precondition(hexFormatted.count == 6, "Invalid hex code used.")
    
    var rgbValue: UInt64 = 0
    Scanner(string: hexFormatted).scanHexInt64(&rgbValue)
    
    self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
              green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
              blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
              alpha: alpha)
  }
  
  
  /// Obtain a darker variation of the current color
  public var darker: Color {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    #if os(macOS)
    guard let hsb = usingColorSpace(.extendedSRGB) else { return self }
    #else
    let hsb = self
    #endif
    hsb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return Color(hue: hue, saturation: saturation, brightness: brightness * 0.8, alpha: alpha)
  }
  
  /// Obtain a lighter variation of the current color
  public var lighter: Color {
    var hue: CGFloat = 0
    var saturation: CGFloat = 0
    var brightness: CGFloat = 0
    var alpha: CGFloat = 0
    #if os(macOS)
    guard let hsb = usingColorSpace(.extendedSRGB) else { return self }
    #else
    let hsb = self
    #endif
    hsb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
    return Color(hue: hue, saturation: saturation, brightness: brightness * 1.2, alpha: alpha)
  }
}
