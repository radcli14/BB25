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
    
    @State var requestReset = false
    
    @State private var anchor: AnchorEntity?
    
    @State private var controlState = JoyStick.ControlState()
    
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
            if requestReset {
                switch camera {
                case .virtual: content.camera = .virtual
                case .spatialTracking: content.camera = .spatialTracking
                }
                resetScene(in: content)
            }
        }
        .realityViewCameraControls(.orbit)
        .navigationTitle("BB25")
        .toolbar {
            ToolbarItem {
                Button("Reset", systemImage: "arrow.counterclockwise") {
                    requestReset = true
                }
                .disabled(requestReset)
            }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem {
                Button("Camera", systemImage: "camera") {
                    camera = camera == .spatialTracking ? .virtual : .spatialTracking
                    requestReset = true
                }
                .disabled(requestReset)
            }
        }
        #endif
        .overlay(alignment: .bottom) {
            JoyStick(controlState: $controlState)
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
                applyForces(in: scene)
            }
            
            requestReset = false
        }
    }
    
    // MARK: - Controls
    
    func applyForces(in scene: Entity) {
        if controlState.isActive {
            scene.chassis?.addForce(.init(controlState.rightForce, 0, 0), at: BoEBotProperties.rightWheelPosition, relativeTo: scene.chassis)
            scene.chassis?.addForce(.init(controlState.leftForce, 0, 0), at: BoEBotProperties.leftWheelPosition, relativeTo: scene.chassis)
        }
    }
    
}

#Preview {
    NavigationStack {
        ContentView(camera: .virtual)
    }
}
