//
//  InitialisationView.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//

import SwiftUI
import RealityKit


struct InitialisationView: View {
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.dismiss) var dismissWindow

    var body: some View {
        Toggle("Start Tracking Object", isOn: $showImmersiveSpace)
            .toggleStyle(.button)
            .padding()
            .onChange(of: showImmersiveSpace) { _, shouldShowImmersiveSpace in
                Task { @MainActor in
                    if shouldShowImmersiveSpace {
                        switch await openImmersiveSpace(id: ExtractorImmersiveViewID) {
                        case .opened:
                            immersiveSpaceIsShown = true
                            dismissWindow()
                        case .error, .userCancelled:
                            fallthrough
                        @unknown default:
                            immersiveSpaceIsShown = false
                            showImmersiveSpace = false
                        }
                    } else if immersiveSpaceIsShown {
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    }
                }
            }
    }
}

#Preview(windowStyle: .automatic) {
    InitialisationView()
}
