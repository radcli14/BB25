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
                        .fill(.ultraThinMaterial)
                        .shadow(color: .secondary, radius: 4)
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
        DragGesture(minimumDistance: 0)
            .onChanged { dragValue in controlState.update(with: dragValue, in: geometry) }
            .onEnded { _ in controlState.reset() }
    }
    
    struct ControlState {
        var linear = 0.0  // Positive = forward
        var angular = 0.0  // Positive = counterclockwise
        
        mutating func update(with value: DragGesture.Value, in geometry: GeometryProxy) {
            linear = state(for: value.location.y, in: geometry.size.height)
            angular = state(for: value.location.x, in: geometry.size.width)
            print("\n\nlinear = \(linear)\nangular = \(angular)\ngeometry: \(geometry.size)\ntranslation = \(value.translation)")
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
}

#Preview {
    @Previewable @State var controlState = JoyStick.ControlState()
    JoyStick(controlState: $controlState)
}
