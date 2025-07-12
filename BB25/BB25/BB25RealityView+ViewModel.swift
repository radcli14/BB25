//
//  BB25RealityView+ViewModel.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/8/25.
//

import Foundation
import RealityKit
import BB25_3D_Assets
import MuJoCo

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
        
        var model: MjModel?
        var data: MjData?
        
        init() {
            model = loadMuJoCoModel()
            data = model?.makeData()
            stepSimulation()
            //guard let model, let data else { return }
            //print("data: \(data?.time) \(data?.qpos)")
            //mj_step(model: model, data: data)
        }
    }
}

extension BB25RealityView.ViewModel {
    func loadMuJoCoModel(named modelName: String = "bb25_mujoco", ofType fileType: String = "xml") -> MjModel? {
        if let filepath = Bundle.main.path(forResource: modelName, ofType: fileType) {
            do {
                model = try MjModel(fromXMLPath: filepath)
                print("loadMuJoCoModel:\n\(String(describing: model?.name))")
                return model
            } catch {
                print("loadMuJoCoModel: Could not load \(modelName) because: \(error)")
            }
        } else {
            print("loadMuJoCoModel: \(modelName) was not found")
        }
        return nil
    }
    
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
    
    /// Steps the MuJoCo simulation and returns the current generalized coordinates
    func stepSimulation() -> [Double]? {
        guard let model = model, var data = data else {
            print("stepSimulation: Model or data not available")
            return nil
        }
        model.step(data: &data)
        return currentCoordinates
    }
    
    /// Reads the current generalized coordinates without stepping the simulation
    var currentCoordinates: [Double]? {
        guard let data else { return nil }
        let qpos = data.qpos.asDoubleArray
        print("Current time: \(data.time), qpos: \(qpos)")
        return qpos
    }
    
    /// Reads the current generalized velocities (qvel)
    func getCurrentVelocities() -> [Double]? {
        guard let data else { return nil }
        let qvel = data.qvel.asDoubleArray
        print("Current time: \(data.time), qvel: \(qvel)")
        return qvel
    }
    
    /// Applies control inputs to the simulation
    func applyControlInputs(controls: [Double]) {
        guard var data, controls.count == data.ctrl.count else {
            print("applyControlInputs: Invalid control input size")
            return
        }
        
        // Apply control inputs to the simulation
        for (index, control) in controls.enumerated() {
            data.ctrl[index] = control
        }
    }
    
    /// Resets the simulation to initial conditions
    func resetSimulation() {
        guard let model = model, var data = data else {
            print("resetSimulation: Model or data not available")
            return
        }
        
        model.reset(data: &data)
        print("Simulation reset to initial conditions")
    }
}

extension MjArray<Double> {
    var indices: Range<Int> {
        0..<count
    }
    
    /// Convert MjArray<Double> to Swift Array<Double>
    var asDoubleArray: [Double] {
        return indices.map { self[$0] }
    }
}
