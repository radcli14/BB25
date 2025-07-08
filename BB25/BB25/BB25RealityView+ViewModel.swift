//
//  BB25RealityView+ViewModel.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/8/25.
//

import Foundation
import RealityKit
import BB25_3D_Assets

extension BB25RealityView {
    enum CameraType {
        case virtual, spatialTracking
    }
    
    @Observable
    class ViewModel {
        var camera: CameraType = .virtual
        var requestReset = false
        var anchor: AnchorEntity?
        var controlState = JoyStick.ControlState()
    }
}

extension BB25RealityView.ViewModel {
    func resetButtonAction() {
        requestReset = true
    }
    
    func cameraButtonAction() {
        camera = camera == .spatialTracking ? .virtual : .spatialTracking
        requestReset = true
    }
    
    // Creates a new anchor and adds the robot scene to it. Since the main body is async, there is a callback to send the anchor back to the RealityView content after it is prepared.
    func resetScene(onComplete: @escaping (AnchorEntity) -> Void) {
        DispatchQueue.main.async {
            self.anchor?.removeFromParent()
            
            switch self.camera {
            case .virtual:
                self.anchor = AnchorEntity(world: .zero)
                let perspectiveCamera = PerspectiveCamera()
                perspectiveCamera.camera.fieldOfViewInDegrees = 69
                perspectiveCamera.look(at: .init(-0.25, 0, 0.25), from: .init(0.75, 1, 1.25), relativeTo: nil)
                self.anchor?.addChild(perspectiveCamera)
            case .spatialTracking:
                self.anchor = AnchorEntity(.plane(.horizontal, classification: .any,  minimumBounds: SIMD2<Float>(0.2, 0.2)))
            }
            
            guard let anchor = self.anchor, let scene = try? Entity.load(named: "Scene", in: BB25_3D_Assets.bB25_3D_AssetsBundle) else {
                self.requestReset = false
                return
            }
                
            scene.setParent(anchor)
            scene.setScale(4 * .one, relativeTo: nil)
            scene.setupPhysics()
            
            self.requestReset = false
            
            onComplete(anchor)
        }
    }

    /// Sets the forces at each frame update
    func applyForces() {
        if controlState.isActive {
            anchor?.chassis?.addForce(.init(controlState.rightForce, 0, 0), at: BoEBotProperties.rightWheelPosition, relativeTo: anchor?.chassis)
            anchor?.chassis?.addForce(.init(controlState.leftForce, 0, 0), at: BoEBotProperties.leftWheelPosition, relativeTo: anchor?.chassis)
        }
    }
}
