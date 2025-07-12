//
//  JoyStick.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/8/25.
//

import SwiftUI

/// The control overlay for forward, reverse, counter-clockwise, and clockwise motion
struct JoyStick: View {
    @Binding var controlState: ControlState
    
    var body: some View {
        ZStack {
            VStack {
                Image(systemName: "arrow.up")
                    .foregroundColor(.secondary.mix(with: .green, by: max(0, controlState.linear)))
                Spacer()
                Image(systemName: "arrow.down")
                    .foregroundColor(.secondary.mix(with: .green, by: max(0, -controlState.linear)))
            }
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.secondary.mix(with: .green, by: max(0, controlState.angular)))
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary.mix(with: .green, by: max(0, -controlState.angular)))
            }
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .secondary, radius: 4)
                .frame(width: Constants.stickRadius, height: Constants.stickRadius)
                .offset(
                    x: -0.5 * controlState.angular * Constants.padSize,
                    y: -0.5 * controlState.linear * Constants.padSize
                )
        }
        .font(.largeTitle.weight(.black))
        .gesture(controlDragGesture)
        .frame(width: Constants.padSize, height: Constants.padSize)
        .padding()
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: Constants.stickRadius)
        )
        .mask(gradientMask)
        .padding()
        .padding(.bottom)
    }
    
    var controlDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { dragValue in
                controlState.update(with: dragValue, relativeTo: Constants.padSize)
            }
            .onEnded { _ in controlState.reset() }
    }
    
    var gradientMask: some View {
        LinearGradient(
            gradient: Gradient(stops: gradientStops),
            startPoint: gradientStartPoint,
            endPoint: gradientEndPoint
        )
    }
    
    private var gradientStops: [Gradient.Stop] {
        let baseOpacity = 0.5
        
        if controlState.linear != 0 || controlState.angular != 0 {
            // Calculate opacity based on control direction
            // For linear control: positive (forward) brightens top, negative (reverse) brightens bottom
            // For angular control: positive (counter-clockwise) brightens left, negative (clockwise) brightens right
            let linearEffect = 0.25 * (controlState.linear + 1)
            let angularEffect = 0.25 * (controlState.angular + 1)
            
            // When linear is positive: start (top) should be bright, end (bottom) should be dark
            // When linear is negative: start (bottom) should be bright, end (top) should be dark
            let startOpacity = baseOpacity + linearEffect + angularEffect
            let endOpacity = baseOpacity - linearEffect - angularEffect
            
            return [
                .init(color: .white.opacity(startOpacity), location: 0),
                .init(color: .white.opacity(endOpacity), location: 1)
            ]
        } else {
            // No control - uniform 50% opacity
            return [
                .init(color: .white.opacity(baseOpacity), location: 0),
                .init(color: .white.opacity(baseOpacity), location: 1)
            ]
        }
    }
    
    private var gradientStartPoint: UnitPoint {
        // Calculate start point based on control values
        // When both controls are active, create diagonal gradients
        let x = 0.5 - (controlState.angular * 0.5)  // Reversed angular direction
        let y = 0.5 - (controlState.linear * 0.5)
        return UnitPoint(x: x, y: y)
    }
    
    private var gradientEndPoint: UnitPoint {
        // Calculate end point based on control values
        // Opposite direction from start point
        let x = 0.5 + (controlState.angular * 0.5)  // Reversed angular direction
        let y = 0.5 + (controlState.linear * 0.5)
        return UnitPoint(x: x, y: y)
    }
    
    struct ControlState {
        var linear = 0.0  // Positive = forward
        var angular = 0.0  // Positive = counterclockwise
        
        mutating func update(with value: DragGesture.Value, relativeTo padSize: Double) {
            linear = state(for: value.location.y, in: padSize)
            angular = state(for: value.location.x, in: padSize)
        }
        
        private func state(for location: Double, in dimension: Double) -> Double {
            min(1.0, max(-1.0, -2.0 * location / dimension + 1))
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
    
    private struct Constants {
        static let padSize: CGFloat = 172
        static let stickRadius: CGFloat = 44
    }
}

#Preview {
    @Previewable @State var controlState = JoyStick.ControlState()
    JoyStick(controlState: $controlState)
}
