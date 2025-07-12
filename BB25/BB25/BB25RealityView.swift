//
//  BB25RealityView.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/3/25.
//

import SwiftUI
import RealityKit

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
            viewModel.resetScene(onComplete: content.add) // Adds the anchor captured in the closure
            
            let _ = content.subscribe(to: SceneEvents.Update.self, on: nil, componentType: nil) { event in
                viewModel.applyForces() // Sets the forces at each frame update
                viewModel.updatePhysics() // Updates physics simulation based on selected mode
            }
        
        } update: { content in
            if case .requested = viewModel.resetState {
                switch viewModel.camera {
                case .virtual: content.camera = .virtual
                case .spatialTracking: content.camera = .spatialTracking
                }
                viewModel.resetScene(onComplete: content.add)
                if viewModel.physics == .muJoCo {
                    viewModel.resetSimulation()
                }
            }
        }
        .realityViewCameraControls(.orbit)
        .navigationTitle("BB25")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(viewModel.physics.rawValue).font(.headline)
                    Text("Physics Engine").font(.caption2)
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
#if os(iOS)
                cameraMenu
#endif
                physicsMenu
                resetButton
            }
        }
        .overlay(alignment: .bottom) {
            JoyStick(controlState: $viewModel.controlState)
        }
        .ignoresSafeArea(.all)
    }
    
    var cameraMenu: some View {
        Menu {
            ForEach(CameraType.allCases, id: \.self) { camera in
                Button {
                    viewModel.camera = camera
                    viewModel.resetState = .requested
                } label: {
                    Text(viewModel.camera == camera ? "⭐ \(camera.rawValue) ⭐" : camera.rawValue)
                }
            }
        } label: {
            Label("Camera", systemImage: "camera")
        }
        .disabled(!viewModel.isReady)
    }
    
    var physicsMenu: some View {
        Menu {
            ForEach(Physics.allCases, id: \.self) { physics in
                Button {
                    viewModel.physics = physics
                    viewModel.resetState = .requested
                } label: {
                    Text(viewModel.physics == physics ? "⭐ \(physics.rawValue) ⭐" : physics.rawValue)
                }
            }
        } label: {
            Label("Physics", systemImage: "atom")
        }
        .disabled(!viewModel.isReady)
    }
    
    var resetButton: some View {
        Button("Reset", systemImage: "arrow.counterclockwise", action: viewModel.resetButtonAction)
            .disabled(!viewModel.isReady)
    }
}

#Preview {
    NavigationStack {
        BB25RealityView(camera: .virtual)
    }
}
