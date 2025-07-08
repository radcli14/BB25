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
            }
        
        } update: { content in
            if viewModel.requestReset {
                switch viewModel.camera {
                case .virtual: content.camera = .virtual
                case .spatialTracking: content.camera = .spatialTracking
                }
                viewModel.resetScene(onComplete: content.add)
            }
        }
        .realityViewCameraControls(.orbit)
        .navigationTitle("BB25")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Reset", systemImage: "arrow.counterclockwise", action: viewModel.resetButtonAction)
                    .disabled(viewModel.requestReset)
#if os(iOS)
                Spacer()
                Button("Camera", systemImage: "camera", action: viewModel.cameraButtonAction)
                    .disabled(viewModel.requestReset)
#endif
            }
        }
        .overlay(alignment: .bottom) {
            JoyStick(controlState: $viewModel.controlState)
        }
        .ignoresSafeArea(.all)
    }
}

#Preview {
    NavigationStack {
        BB25RealityView(camera: .virtual)
    }
}
