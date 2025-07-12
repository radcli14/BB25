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
            printCurrentState()
            stepSimulation()
            printCurrentState()
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
    
    /// Steps the MuJoCo simulation
    func stepSimulation() {
        guard let model = model, var data = data else { return }
        model.step(data: &data)
    }
    
    var currentTime: Double? {
        data?.time
    }
    
    /// Reads the current generalized coordinates without stepping the simulation
    var currentCoordinates: [Double]? {
        guard let data else { return nil }
        return data.qpos.asDoubleArray
    }
    
    /// Reads the current generalized velocities (qvel)
    var currentVelocities: [Double]? {
        guard let data else { return nil }
        return data.qvel.asDoubleArray
    }
    
    func printCurrentState() {
        print("\nSTATES\n - Current time: \(currentTime ?? 0)\n - qpos: \(currentCoordinates ?? [])\n - qvel: \(currentVelocities ?? [])")
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
        guard let model, var data else { return }
        
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
