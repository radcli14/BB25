//
//  ContentView.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/3/25.
//

import SwiftUI
import RealityKit
import BB25_3D_Assets

struct ContentView: View {
    
    enum CameraType {
        case virtual, spatialTracking
    }
    @State var camera: CameraType = .virtual
    
    @State var fwd = false
    @State var rev = false
    @State var ccw = false
    @State var cw = false
    
    @State var requestReset = false
    
    @State private var anchor: AnchorEntity?
    
    var body: some View {
        RealityView { content in
            switch camera {
            case .virtual: content.camera = .virtual
            case .spatialTracking: content.camera = .spatialTracking
            }
            
            resetScene(in: content)
            

        } update: { content in
            switch camera {
            case .virtual: content.camera = .virtual
            case .spatialTracking: content.camera = .spatialTracking
            }
            
            if requestReset {
                resetScene(in: content)
            }
            print("update... requestReset: \(requestReset), [\(fwd), \(rev), \(ccw), \(cw)]")
        }
        .realityViewCameraControls(.orbit)
        .overlay(alignment: .bottom) {
            controls
        }
        .ignoresSafeArea(.all)
    }
    
    // Creates a new anchor and adds the robot scene to it
    func resetScene(in content: RealityViewCameraContent) {
        DispatchQueue.main.async {
            anchor?.removeFromParent()
            
            switch camera {
            case .virtual:
                anchor = AnchorEntity(world: .zero)
            case .spatialTracking:
                anchor = AnchorEntity(.plane(.horizontal, classification: .any,  minimumBounds: SIMD2<Float>(0.2, 0.2)))
            }
            
            guard let anchor, let scene = try? Entity.load(named: "Scene", in: BB25_3D_Assets.bB25_3D_AssetsBundle) else {
                requestReset = false
                return
            }
                
            scene.setParent(anchor)
            setupPhysics(in: scene)
            
            content.add(anchor)
            
            let _ = content.subscribe(to: SceneEvents.Update.self, on: nil, componentType: nil) { event in
                if let motion = scene.findEntity(named: "Chassis")?.components[PhysicsMotionComponent.self] {
                    var velocity = motion.linearVelocity
                    velocity.x = fwd ? 0.5 : rev ? -0.5 : 0
                    var angular = motion.angularVelocity
                    angular.z = ccw ? 0.5 : cw ? -0.5 : 0
                    scene.findEntity(named: "Chassis")?.components.set(
                        PhysicsMotionComponent(linearVelocity: velocity, angularVelocity: angular)
                    )
                }
            }
            
            requestReset = false
        }
    }
    
    func setupPhysics(in scene: Entity) {
        
        // Make sure the physics entities have a common parent with simulation and joints components
        var simulation = PhysicsSimulationComponent()
        simulation.gravity = .init(0, 0, -9.80665)
        let root = scene.findEntity(named: "Root")
        root?.components.set(simulation)
        root?.components.set(PhysicsJointsComponent())
        
        // Create attachment pins on the chassis and wheels
        let lateral = simd_quatf(from: [1, 0, 0], to: [0, 1, 0])
        let chassis = scene.findEntity(named: "Chassis")
        let rearPin = chassis?.pins.set(
            named: "rear",
            position: .init(-0.130752, 0, 0.0127),
            orientation: lateral
        )
        let rightPin = chassis?.pins.set(
            named: "right",
            position: .init(-0.04645, -0.0555, 0.035),
            orientation: lateral
        )
        let leftPin = chassis?.pins.set(
            named: "right",
            position: .init(-0.04645, 0.0555, 0.035),
            orientation: lateral
        )
        
        let rearWheel = scene.findEntity(named: "RearWheel")
        let rearWheelPin = rearWheel?.pins.set(
            named: "rearWheel",
            position: .zero,
            orientation: lateral
        )
        
        if let rearPin, let rearWheelPin {
            let rearJoint = PhysicsFixedJoint(pin0: rearPin, pin1: rearWheelPin)
            do {
                try rearJoint.addToSimulation()
            } catch {
                print("Failed to add rear fixed joint to simulation")
            }
        }
         
        let rightWheelPin = scene.rightWheel?.pins.set(
            named: "rightWheel",
            position: .init(0, 0, 0),
            orientation: simd_quatf(from: [1, 0, 0], to: [0, 0, -1])
        )

        let leftWheelPin = scene.leftWheel?.pins.set(
            named: "leftWheel",
            position: .init(0, 0, 0),
            orientation: simd_quatf(from: [1, 0, 0], to: [0, 0, 1])
        )
        
        addRevoluteJoint(between: rightPin, and: rightWheelPin)
        addRevoluteJoint(between: leftPin, and: leftWheelPin)
        
        //let physics = chassis?.components[PhysicsBodyComponent.self]
        //print("roots: \(root), physics: \(physics?.massProperties)")
    }
    
    /// The control overlay for forward, reverse, counter-clockwise, and clockwise motion
    var controls: some View {
        VStack(spacing: 12) {
            Text("BB25")
                .font(.title.weight(.black))
            ZStack {
                VStack(spacing: 36) {
                    heldButton("FWD", systemImage: "arrow.up", isHeld: $fwd)
                    heldButton("REV", systemImage: "arrow.down", isHeld: $rev)
                }
                HStack {
                    heldButton("CCW", systemImage: "arrow.counterclockwise", isHeld: $ccw)
                    Spacer()
                    heldButton("CW   ", systemImage: "arrow.clockwise", isHeld: $cw)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Reset") {
                requestReset = true
            }
            .disabled(requestReset)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .padding()
        .padding(.bottom)
    }
    
    /// A button that activates a `isHeld` boolean on long press, that uses a conventional `title` and `systemImage` to form a label
    func heldButton(_ title: String, systemImage: String, isHeld: Binding<Bool>) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(isHeld.wrappedValue ? .red : .blue)
            .fontWeight(isHeld.wrappedValue ? .black : .semibold)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .onLongPressGesture(
                minimumDuration: 0.01) {
                    
                } onPressingChanged: { isPressed in
                    withAnimation {
                        isHeld.wrappedValue = isPressed
                    }
                }
    }
    
    func addRevoluteJoint(between pin0: GeometricPin?, and pin1: GeometricPin?) {
        if let pin0, let pin1 {
            let frontJoint = PhysicsRevoluteJoint(pin0: pin0, pin1: pin1, checksForInternalCollisions: false)
            do {
                try frontJoint.addToSimulation()
            } catch {
                print("Failed to add right wheel revolute joint to simulation")
            }
        } else {
            print("addRevoluteJoint: Received null: \(pin0) \(pin1)")
        }
    }
}

#Preview {
    ContentView(camera: .virtual)
}
