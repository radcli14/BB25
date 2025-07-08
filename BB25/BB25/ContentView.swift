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
                applyForces(in: scene)
            }
            
            requestReset = false
        }
    }
    
    // MARK: - Controls
    
    struct ControlState {
        var linear = 0.0  // Positive = forward
        var angular = 0.0  // Positive = counterclockwise
        
        mutating func update(with value: DragGesture.Value, in geometry: GeometryProxy) {
            linear = -2.0 * (value.translation.height) / geometry.size.height
            angular = -2.0 * (value.translation.width) / geometry.size.width
            print("\n\nlinear = \(linear)\nangular = \(angular)\ngeometry: \(geometry.size)\ntranslation = \(value.translation)")
        }
        
        mutating func reset() {
            linear = 0.0
            angular = 0.0
        }
        
        var isActive: Bool {
            angular != 0 || linear != 0
        }
        
        var rightForce: Float {
            BoEBotProperties.forceGainFactor * Float(linear + angular)
        }
        
        var leftForce: Float {
            BoEBotProperties.forceGainFactor * Float(linear - angular)
        }
    }
    @State var controlState = ControlState()

    /// The control overlay for forward, reverse, counter-clockwise, and clockwise motion
    var controls: some View {
        ZStack {
            VStack(spacing: 64) {
                Image(systemName: "arrow.up")
                Image(systemName: "arrow.down")
            }
            HStack(spacing: 64) {
                Image(systemName: "arrow.counterclockwise")
                Image(systemName: "arrow.clockwise")
            }
        }
        .font(.largeTitle)
        .padding()
        .background {
            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 44)
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(.secondary)
                        .frame(width: 44, height: 44)
                        .offset(
                            x: -0.5 * controlState.angular * geometry.size.width,
                            y: -0.5 * controlState.linear * geometry.size.height
                        )
                }
                .gesture(controlDragGesture(in: geometry))
            }
        }
        .padding()
        .padding(.bottom)
    }
    
    func controlDragGesture(in geometry: GeometryProxy)-> some Gesture {
        DragGesture()
            .onChanged { dragValue in controlState.update(with: dragValue, in: geometry) }
            .onEnded { _ in controlState.reset() }
    }

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
