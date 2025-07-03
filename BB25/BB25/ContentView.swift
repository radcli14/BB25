//
//  ContentView.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/3/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    
    @State var fwd = false
    @State var rev = false
    @State var ccw = false
    @State var cw = false
    
    var body: some View {
        RealityView { content in
            
        }
        .overlay(alignment: .bottom) {
            controls
        }
    }
    
    /// The control overlay for forward, reverse, counter-clockwise, and clockwise motion
    var controls: some View {
        VStack(spacing: 12) {
            Text("BB25")
                .font(.title.weight(.black))
            ZStack {
                VStack(spacing: 36) {
                    heldButton("FWD", systemImage: "arrow.up", isHeld: $fwd)
                    heldButton("REV", systemImage: "arrow.down", isHeld: $rev)
                }
                HStack {
                    heldButton("CCW", systemImage: "arrow.counterclockwise", isHeld: $ccw)
                    Spacer()
                    heldButton("CW", systemImage: "arrow.clockwise", isHeld: $cw)
                }
            }
        }
        .font(.headline)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .padding()
    }
    
    /// A button that activates a `isHeld` boolean on long press, that uses a conventional `title` and `systemImage` to form a label
    func heldButton(_ title: String, systemImage: String, isHeld: Binding<Bool>) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(isHeld.wrappedValue ? .red : .blue)
            .onLongPressGesture(
                minimumDuration: 0.01) {
                    
                } onPressingChanged: { isPressed in
                    isHeld.wrappedValue = isPressed
                }
    }
}

#Preview {
    ContentView()
}
