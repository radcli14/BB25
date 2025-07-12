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
    enum CameraType: String, CaseIterable {
        case virtual = "Virtual Camera"
        case spatialTracking = "Spatial Tracking"
    }
    
    enum Physics: String, CaseIterable {
        case realityKit = "RealityKit"
        case muJoCo = "MuJoCo"
    }
    
    enum Reset {
        case ready, requested, inProgress(hasResetEntity: Bool, hasResetSimulation: Bool)
    }
    
    @Observable
    class ViewModel {
        var camera: CameraType = .virtual
        var anchor: AnchorEntity?
        var controlState = JoyStick.ControlState()
        
        var physics: BB25RealityView.Physics = .muJoCo
        var model: MjModel?
        var data: MjData?
        
        // Real-time tracking for MuJoCo simulation
        private var lastRealTime: CFAbsoluteTime = 0
        private var simulationStartTime: Double = 0
        private var realTimeStart: CFAbsoluteTime = 0
        
        // Reset state management
        var resetState: Reset = .ready
        var isReady: Bool {
            switch resetState {
            case .ready: true
            default: false
            }
        }
        
        init() {
            model = loadMuJoCoModel()
            data = model?.makeData()
            lastRealTime = CFAbsoluteTimeGetCurrent()
            realTimeStart = lastRealTime
            simulationStartTime = 0
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
        resetState = .requested
    }
    
    // Creates a new anchor and adds the robot scene to it. Since the main body is async, there is a callback to send the anchor back to the RealityView content after it is prepared.
    func resetScene(onComplete: @escaping (AnchorEntity) -> Void) {
        // Prevent multiple simultaneous resets
        guard case .ready = resetState else { return }
        resetState = .inProgress(hasResetEntity: false, hasResetSimulation: false)
        
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
                self.resetState = .ready
                return
            }
                
            scene.setParent(anchor)
            scene.setScale(4 * .one, relativeTo: nil)
            
            // Set up physics based on the selected physics mode
            switch self.physics {
            case .realityKit:
                scene.setupPhysics()
            case .muJoCo:
                scene.setupMuJoCoPhysics()
            }
            
            self.resetState = .ready
            
            onComplete(anchor)
            print("resetScene completed with physics mode: \(self.physics.rawValue)")
        }
    }

    /// Sets the forces at each frame update
    func applyForces() {
        switch physics {
        case .realityKit:
            if controlState.isActive {
                anchor?.chassis?.addForce(.init(controlState.rightForce, 0, 0), at: BoEBotProperties.rightWheelPosition, relativeTo: anchor?.chassis)
                anchor?.chassis?.addForce(.init(controlState.leftForce, 0, 0), at: BoEBotProperties.leftWheelPosition, relativeTo: anchor?.chassis)
            }
        case .muJoCo:
            // TODO: note, I'm applying the .pi scale factor here to speed it up a bit, but thats somewhat of a placeholder
            let rightControl = .pi * Double(controlState.rightForce)
            let leftControl = .pi * Double(controlState.leftForce)
            applyControlInputs(controls: [rightControl, leftControl])
        }
    }
    
    /// Updates physics simulation based on selected physics mode
    func updatePhysics() {
        switch physics {
        case .realityKit:
            // RealityKit physics is handled automatically
            break
        case .muJoCo:
            stepSimulation()
            updateMuJoCoTransforms()
        }
    }
    
    /// Updates the transforms of robot components based on MuJoCo simulation results
    private func updateMuJoCoTransforms() {
        // Update chassis transform
        anchor?.chassis?.setPosition(chassisPosition ?? .zero, relativeTo: anchor?.chassis?.parent)
        anchor?.chassis?.setOrientation(chassisRotation ?? .init(), relativeTo: anchor?.chassis?.parent)
        
        // Set wheel positions relative to chassis (these should be fixed)
        anchor?.rightWheel?.setPosition(BoEBotProperties.rightWheelPosition, relativeTo: anchor?.chassis)
        anchor?.leftWheel?.setPosition(BoEBotProperties.leftWheelPosition, relativeTo: anchor?.chassis)
        anchor?.rearWheel?.setPosition(BoEBotProperties.rearWheelPosition, relativeTo: anchor?.chassis)
        
        // Set wheel orientations relative to chassis
        anchor?.rightWheel?.setOrientation(rightWheelRotation ?? .init(), relativeTo: anchor?.chassis)
        anchor?.leftWheel?.setOrientation(leftWheelRotation ?? .init(), relativeTo: anchor?.chassis)
        anchor?.rearWheel?.setOrientation(rearWheelRotation ?? .init(), relativeTo: anchor?.chassis)
    }
    
    /// Steps the MuJoCo simulation to match real time
    func stepSimulation() {
        guard let model = model, var data = data else { return }
        
        let currentRealTime = CFAbsoluteTimeGetCurrent()

        // Initialize simulation start time on first call
        if simulationStartTime == 0 {
            simulationStartTime = data.time
        }
        
        // Calculate target simulation time based on total real time elapsed since simulation start
        let totalRealTimeElapsed = currentRealTime - realTimeStart
        let targetSimulationTime = simulationStartTime + totalRealTimeElapsed
        
        // Step simulation until we reach or exceed the target time
        var stepCount = 0
        while data.time < targetSimulationTime {
            model.step(data: &data)
            stepCount += 1
        }

        lastRealTime = currentRealTime
    }
    
    var currentTime: Double? {
        data?.time
    }
    
    /// Reads the current generalized coordinates without stepping the simulation
    var currentCoordinates: [Double]? {
        guard let data else { return nil }
        return data.qpos.asDoubleArray
    }
    
    /// Assuming the first 3 coordinates are chassis position (x, y, z)
    var chassisPosition: SIMD3<Float>? {
        guard let data else { return nil }
        return SIMD3<Float>(x: Float(data.qpos[0]), y: Float(data.qpos[1]), z: Float(data.qpos[2]) - 0.05) // TODO: remove this 0.05 offset
    }
    
    /// The next four are the chassis quaternion (qr, qx, qy, qz),
    var chassisRotation: simd_quatf? {
        guard let data else { return nil }
        return simd_quatf(
            ix: Float(data.qpos[4]),
            iy: Float(data.qpos[5]),
            iz: Float(data.qpos[6]),
            r: Float(data.qpos[3])
        )
    }
    
    /// The next three are the wheel rotations about their axis (right, left, rear)
    var rightWheelRotation: simd_quatf? {
        guard let data else { return nil }
        return simd_mul(
            simd_quatf(angle: -.pi/2, axis: .init(1, 0, 0)),
            simd_quatf(angle: Float(data.qpos[7]), axis: SIMD3<Float>(0, 0, 1))
        )
    }
    var leftWheelRotation: simd_quatf? {
        guard let data else { return nil }
        return simd_mul(
            simd_quatf(angle: .pi/2, axis: .init(1, 0, 0)),
            simd_quatf(angle: Float(data.qpos[8]), axis: SIMD3<Float>(0, 0, 1))
        )
    }
    var rearWheelRotation: simd_quatf? {
        guard let data else { return nil }
        return simd_mul(
            simd_quatf(angle: -.pi/2, axis: .init(1, 0, 0)),
            simd_quatf(angle: Float(data.qpos[9]), axis: SIMD3<Float>(0, 0, 1))
        )
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
        // Only reset simulation once per reset cycle
        guard case .inProgress(_, let hasResetSimulation) = resetState, !hasResetSimulation else { return }
        resetState = .inProgress(hasResetEntity: true, hasResetSimulation: true)
        
        guard let model, var data else { return }
        
        model.reset(data: &data)
        
        // Reset real-time tracking
        lastRealTime = CFAbsoluteTimeGetCurrent()
        realTimeStart = lastRealTime
        simulationStartTime = 0
        
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
