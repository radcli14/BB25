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
            
            /*let session = SpatialTrackingSession()
            let config = SpatialTrackingSession.Configuration(
                tracking:[],
                sceneUnderstanding:[
                    //.occlusion,
                    .physics,
                    .collision,
                    .shadow
            ])
            await session.run(config)*/
            
            resetScene(in: content)
        
        } update: { content in
            switch camera {
            case .virtual: content.camera = .virtual
            case .spatialTracking: content.camera = .spatialTracking
            }
            
            if requestReset {
                resetScene(in: content)
            }
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
            scene.setScale(4 * .one, relativeTo: nil)
            scene.setupPhysics()
            
            content.add(anchor)
            
            let _ = content.subscribe(to: SceneEvents.Update.self, on: nil, componentType: nil) { event in
                //correctWheelRotations(in: scene)
                applyForces(in: scene)
            }
            
            requestReset = false
        }
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
        #if os(iOS)
        .overlay(alignment: .topLeading) {
            Button("Camera") {
                camera = camera == .spatialTracking ? .virtual : .spatialTracking
                requestReset = true
            }
            .disabled(requestReset)
        }
        #endif
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
    
    func correctWheelRotations(in scene: Entity) {
        guard let rightWheel = scene.rightWheel else { return }
        let matrix = rightWheel.transformMatrix(relativeTo: scene.chassis)
        let transform = Transform(matrix: matrix)
        //scene.rightWheel?.transform = Transform(roll: angle)
        //transform.rotation = simd_quatf(angle: transform.rotation.angle, axis: .init(x: 1, y: 0, z: 0))
        //var rotation = rightWheel.convert(transform: transform, to: scene.chassis).rotation
        let q = simd_quatf(angle: .pi / 2, axis: .init(1, 0, 0))
        //transform.rotation = simd_mul(transform.rotation, q)
        //transform.rotation = q
        //scene.rightWheel?.transform = transform
        
        print("wheel transform: \n - original: \(transform.rotation.angle)\n - rotated: \(simd_mul(transform.rotation, q).angle)")
    }
    
    func applyForces(in scene: Entity) {

        let rightForce = BoEBotProperties.forceGainFactor * Float(fwd || ccw ? 1 : rev || cw ? -1 : 0)
        let leftForce = BoEBotProperties.forceGainFactor * Float(fwd || cw ? 1 : rev || ccw ? -1 : 0)

        scene.chassis?.addForce(.init(rightForce, 0, 0), at: BoEBotProperties.rightWheelPosition, relativeTo: scene.chassis)
        scene.chassis?.addForce(.init(leftForce, 0, 0), at: BoEBotProperties.leftWheelPosition, relativeTo: scene.chassis)
    }
    
}

#Preview {
    ContentView(camera: .virtual)
}
