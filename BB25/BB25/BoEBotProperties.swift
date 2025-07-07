//
//  BoEBotProperties.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/7/25.
//

import Foundation

struct BoEBotProperties {
    static let wheelForwardOffset: Float = -0.04645
    static let wheelLateralOffset: Float = 0.0555
    static let wheelVerticalOffset: Float = 0.035
    static let forceGainFactor: Float = 0.1
    
    static let chassisCenter = SIMD3<Float>(x: -0.06, y: 0, z: 0.05)
    
    static let chassisBoxDimensions = SIMD3<Float>(x: 0.12, y: 0.01, z: 0.05)
    
    static let rightWheelPosition = SIMD3<Float>(wheelForwardOffset, -wheelLateralOffset, wheelVerticalOffset)
    
    static let leftWheelPosition = SIMD3<Float>(wheelForwardOffset, wheelLateralOffset, wheelVerticalOffset)
    
    static let rearWheelPosition = SIMD3<Float>(-0.130752, 0, 0.0127)
}
