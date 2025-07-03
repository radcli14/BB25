//
//  ContentView.swift
//  BB25
//
//  Created by Eliott Radcliffe on 7/3/25.
//

import SwiftUI
import RealityKit
import BB25_3D_Assets

struct ContentView: View {
    
    @State var fwd = false
    @State var rev = false
    @State var ccw = false
    @State var cw = false
    
    @State var requestReset = false
    
    @State private var anchor: AnchorEntity?
    
    var body: some View {
        RealityView { content in
            content.camera = .spatialTracking
            resetScene(in: content)
        } update: { content in
            if requestReset {
                resetScene(in: content)
            }
            print("update... requestReset: \(requestReset), [\(fwd), \(rev), \(ccw), \(cw)]")
        }
        .overlay(alignment: .bottom) {
            controls
        }
        .ignoresSafeArea(.all)
    }
    
    // Creates a new anchor and adds the robot scene to it
    func resetScene(in content: RealityViewCameraContent) {
        DispatchQueue.main.async {
            anchor?.removeFromParent()
            anchor = AnchorEntity(.plane(.horizontal, classification: .any,  minimumBounds: SIMD2<Float>(0.2, 0.2)))
            guard let anchor else {
                requestReset = false
                return
            }
            
            if let scene = try? Entity.load(named: "Scene", in: BB25_3D_Assets.bB25_3D_AssetsBundle) {
                scene.setParent(anchor)
            }
            
            content.add(anchor)
            
            requestReset = false
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
                    heldButton("CW   ", systemImage: "arrow.clockwise", isHeld: $cw)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Reset") {
                requestReset = true
            }
            .disabled(requestReset)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .padding()
        .padding(.bottom)
    }
    
    /// A button that activates a `isHeld` boolean on long press, that uses a conventional `title` and `systemImage` to form a label
    func heldButton(_ title: String, systemImage: String, isHeld: Binding<Bool>) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundColor(isHeld.wrappedValue ? .red : .blue)
            .fontWeight(isHeld.wrappedValue ? .black : .semibold)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .onLongPressGesture(
                minimumDuration: 0.01) {
                    
                } onPressingChanged: { isPressed in
                    withAnimation {
                        isHeld.wrappedValue = isPressed
                    }
                }
    }
}

#Preview {
    ContentView()
}
