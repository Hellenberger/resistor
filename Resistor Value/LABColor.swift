//
//  LABColor.swift
//  Resistor Value
//
//  Created by Howard Ellenberger on 3/14/25.
//

import Foundation
import UIKit

public struct LABColor {
    let L: CGFloat
    let A: CGFloat
    let B: CGFloat
    let name: String
    
    init(L: CGFloat, A: CGFloat, B: CGFloat, name: String = "") {
        self.L = L
        self.A = A
        self.B = B
        self.name = name
    }
    
    init(from uiColor: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        // Convert RGB to XYZ (sRGB color space)
        let rLinear = r > 0.04045 ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92
        let gLinear = g > 0.04045 ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92
        let bLinear = b > 0.04045 ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92
        
        // sRGB to XYZ transformation matrix
        let x = rLinear * 0.4124564 + gLinear * 0.3575761 + bLinear * 0.1804375
        let y = rLinear * 0.2126729 + gLinear * 0.7151522 + bLinear * 0.0721750
        let z = rLinear * 0.0193339 + gLinear * 0.1191920 + bLinear * 0.9503041
        
        // Convert XYZ to LAB (D65 illuminant)
        let xn: CGFloat = 0.95047  // D65 illuminant
        let yn: CGFloat = 1.00000
        let zn: CGFloat = 1.08883
        
        let xr = x / xn
        let yr = y / yn
        let zr = z / zn
        
        let fx = xr > 0.008856 ? pow(xr, 1.0/3.0) : (7.787 * xr + 16.0/116.0)
        let fy = yr > 0.008856 ? pow(yr, 1.0/3.0) : (7.787 * yr + 16.0/116.0)
        let fz = zr > 0.008856 ? pow(zr, 1.0/3.0) : (7.787 * zr + 16.0/116.0)
        
        self.L = 116.0 * fy - 16.0
        self.A = 500.0 * (fx - fy)
        self.B = 200.0 * (fy - fz)
        self.name = ""
    }
    
    func toUIColor() -> UIColor {
        // Convert LAB back to XYZ
        let fy = (L + 16.0) / 116.0
        let fx = A / 500.0 + fy
        let fz = fy - B / 200.0
        
        let xr = fx > 0.206897 ? pow(fx, 3.0) : (fx - 16.0/116.0) / 7.787
        let yr = fy > 0.206897 ? pow(fy, 3.0) : (fy - 16.0/116.0) / 7.787
        let zr = fz > 0.206897 ? pow(fz, 3.0) : (fz - 16.0/116.0) / 7.787
        
        // D65 illuminant
        let x = xr * 0.95047
        let y = yr * 1.00000
        let z = zr * 1.08883
        
        // XYZ to sRGB transformation matrix
        let r = x * 3.2404542 + y * -1.5371385 + z * -0.4985314
        let g = x * -0.9692660 + y * 1.8760108 + z * 0.0415560
        let b = x * 0.0556434 + y * -0.2040259 + z * 1.0572252
        
        // Convert to gamma-corrected sRGB
        let rFinal = r > 0.0031308 ? 1.055 * pow(r, 1.0/2.4) - 0.055 : 12.92 * r
        let gFinal = g > 0.0031308 ? 1.055 * pow(g, 1.0/2.4) - 0.055 : 12.92 * g
        let bFinal = b > 0.0031308 ? 1.055 * pow(b, 1.0/2.4) - 0.055 : 12.92 * b
        
        return UIColor(
            red: max(0, min(1, rFinal)),
            green: max(0, min(1, gFinal)),
            blue: max(0, min(1, bFinal)),
            alpha: 1.0
        )
    }
    
    func distance(to other: LABColor) -> Double {
        let deltaL = Double(L - other.L)
        let deltaA = Double(A - other.A)
        let deltaB = Double(B - other.B)
        
        // CIE76 Delta E formula
        return sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB)
    }
}
