//
//  Entity+Extensions.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/4/25.
//

import Foundation
import RealityKit

extension Entity {
    var chassis: HasPhysicsBody? {
        findEntity(named: "Chassis") as? HasPhysicsBody
    }
    
    var rightWheel: HasPhysicsBody? {
        findEntity(named: "RightHub") as? HasPhysicsBody
    }
    
    var leftWheel: HasPhysicsBody? {
        findEntity(named: "LeftHub") as? HasPhysicsBody
    }
    
    func setupWheelPin(named name: String, zDirection: Float) -> GeometricPin {
        components.set(PhysicsMotionComponent())
        let pin = pins.set(
            named: name,
            position: .init(0, 0, 0),
            orientation: simd_quatf(from: [1, 0, 0], to: [0, 0, zDirection])
        )
        return pin
    }
    
    var velocityInBodyFrame: SIMD3<Float> {
        guard let motion = components[PhysicsMotionComponent.self] else {
            return .zero
        }
        let worldFrameVelocity = motion.linearVelocity
        return convert(direction: worldFrameVelocity, from: nil)
    }
    
    var forwardSpeed: Float {
        velocityInBodyFrame.x
    }
    
    var angularVelocityInBodyFrame: SIMD3<Float> {
        guard let motion = components[PhysicsMotionComponent.self] else {
            return .zero
        }
        let worldFrameAngularVelocity = motion.angularVelocity
        return convert(direction: worldFrameAngularVelocity, from: nil)
    }
    
    var yawRate: Float {
        angularVelocityInBodyFrame.z
    }
}
