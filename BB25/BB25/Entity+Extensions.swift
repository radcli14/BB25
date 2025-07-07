//
//  Entity+Extensions.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/4/25.
//

import Foundation
import RealityKit

extension Entity {
    var root: Entity? {
        findEntity(named: "Root")
    }
    
    var lateral: simd_quatf {
        simd_quatf(from: [1, 0, 0], to: [0, 1, 0])
    }
    
    /// Start the simulation component, and create attachment pins on the chassis and wheels for the joints
    func setupPhysics() {
        setupSimulationAndJoints()
        buildChassis()
        buildWheels()
        buildJoints()
    }
    
    /// Make sure the physics entities have a common parent with simulation and joints components
    func setupSimulationAndJoints() {
        var simulation = PhysicsSimulationComponent()
        simulation.gravity = .init(0, 0, -9.80665)
        simulation.solverIterations = .init(positionIterations: 32, velocityIterations: 4)
        root?.components.set(simulation)
        root?.components.set(PhysicsJointsComponent())
    }
    
    // MARK: - Chassis
    
    var chassis: HasPhysicsBody? {
        findEntity(named: "Chassis") as? HasPhysicsBody
    }
    
    /// Create attachment pins on the chassis
    func buildChassis() {
        chassis?.components.set(PhysicsMotionComponent())
        chassis?.pins.set(
            named: "rear",
            position: .init(-0.130752, 0, 0.0127),
            orientation: lateral
        )
        chassis?.pins.set(
            named: "right",
            position: BoEBotProperties.rightWheelPosition,
            orientation: lateral
        )
        chassis?.pins.set(
            named: "left",
            position: BoEBotProperties.leftWheelPosition,
            orientation: lateral
        )
    }
    
    var rightPin: GeometricPin? {
        chassis?.pins.first(where: { $0.name == "right" })
    }
    
    var leftPin: GeometricPin? {
        chassis?.pins.first(where: { $0.name == "left" })
    }
    
    var rearPin: GeometricPin? {
        chassis?.pins.first(where: { $0.name == "rear" })
    }
    
    // MARK: - Wheels
    
    var rightWheel: HasPhysicsBody? {
        findEntity(named: "RightHub") as? HasPhysicsBody
    }
    
    var leftWheel: HasPhysicsBody? {
        findEntity(named: "LeftHub") as? HasPhysicsBody
    }
    
    var rearWheel: HasPhysicsBody? {
        findEntity(named: "RearWheel") as? HasPhysicsBody
    }
    
    /// Create attachment pins on the wheels
    func buildWheels() {
        let _ = rearWheel?.setupWheelPin(named: "rearWheel", zDirection: 1)
        let _ = rightWheel?.setupWheelPin(named: "rightWheel", zDirection: -1)
        let _ = leftWheel?.setupWheelPin(named: "leftWheel", zDirection: 1)
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
    
    var rightWheelPin: GeometricPin? {
        rightWheel?.pins.first(where: { $0.name == "rightWheel" })
    }
    
    var leftWheelPin: GeometricPin? {
        leftWheel?.pins.first(where: { $0.name == "leftWheel" })
    }
    
    var rearWheelPin: GeometricPin? {
        rearWheel?.pins.first(where: { $0.name == "rearWheel" })
    }
    
    
    // MARK: - States
    
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
    
    // MARK: - Joints
    
    func buildJoints() {
        addJoint(ofType: "Revolute", between: rightPin, and: rightWheelPin)
        addJoint(ofType: "Revolute", between: leftPin, and: leftWheelPin)
        addJoint(ofType: "Spherical", between: rearPin, and: rearWheelPin)
    }
    
    func addJoint(ofType jointType: String, between pin0: GeometricPin?, and pin1: GeometricPin?) {
        if let pin0, let pin1 {
            do {
                let joint: any PhysicsJoint = switch jointType {
                case "Revolute": PhysicsRevoluteJoint(pin0: pin0, pin1: pin1, checksForInternalCollisions: false)
                case "Spherical": PhysicsSphericalJoint(pin0: pin0, pin1: pin1, checksForInternalCollisions: false)
                default: throw NSError(domain: "", code: 0, userInfo: nil)
                }
                try joint.addToSimulation()
            } catch {
                print("Failed to add right wheel revolute joint to simulation")
            }
        } else {
            print("addRevoluteJoint: Received null: \(String(describing: pin0)) \(String(describing: pin1))")
        }
    }
}
