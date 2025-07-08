//
//  BB25RealityView.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/3/25.
//

import SwiftUI
import RealityKit
import BB25_3D_Assets

struct BB25RealityView: View {
    @State var viewModel = BB25RealityView.ViewModel()
    
    init(camera: BB25RealityView.CameraType = .virtual) {
        viewModel.camera = camera
    }
    
    var body: some View {
        RealityView { content in
            switch viewModel.camera {
            case .virtual: content.camera = .virtual
            case .spatialTracking: content.camera = .spatialTracking
            }
            
            resetScene(in: content)
        
        } update: { content in
            if viewModel.requestReset {
                switch viewModel.camera {
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
                    viewModel.requestReset = true
                }
                .disabled(viewModel.requestReset)
            }
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem {
                Button("Camera", systemImage: "camera") {
                    viewModel.camera = viewModel.camera == .spatialTracking ? .virtual : .spatialTracking
                    viewModel.requestReset = true
                }
                .disabled(viewModel.requestReset)
            }
        }
        #endif
        .overlay(alignment: .bottom) {
            JoyStick(controlState: $viewModel.controlState)
        }
        .ignoresSafeArea(.all)
    }
    
    // Creates a new anchor and adds the robot scene to it
    func resetScene(in content: RealityViewCameraContent) {
        DispatchQueue.main.async {
            viewModel.anchor?.removeFromParent()
            
            switch viewModel.camera {
            case .virtual:
                viewModel.anchor = AnchorEntity(world: .zero)
            case .spatialTracking:
                viewModel.anchor = AnchorEntity(.plane(.horizontal, classification: .any,  minimumBounds: SIMD2<Float>(0.2, 0.2)))
            }
            
            guard let anchor = viewModel.anchor, let scene = try? Entity.load(named: "Scene", in: BB25_3D_Assets.bB25_3D_AssetsBundle) else {
                viewModel.requestReset = false
                return
            }
                
            scene.setParent(anchor)
            scene.setScale(4 * .one, relativeTo: nil)
            scene.setupPhysics()
            
            content.add(anchor)
            
            let _ = content.subscribe(to: SceneEvents.Update.self, on: nil, componentType: nil) { event in
                applyForces(in: scene)
            }
            
            viewModel.requestReset = false
        }
    }
    
    // MARK: - Controls
    
    func applyForces(in scene: Entity) {
        if viewModel.controlState.isActive {
            scene.chassis?.addForce(.init(viewModel.controlState.rightForce, 0, 0), at: BoEBotProperties.rightWheelPosition, relativeTo: scene.chassis)
            scene.chassis?.addForce(.init(viewModel.controlState.leftForce, 0, 0), at: BoEBotProperties.leftWheelPosition, relativeTo: scene.chassis)
        }
    }
    
}

#Preview {
    NavigationStack {
        BB25RealityView(camera: .virtual)
    }
}
