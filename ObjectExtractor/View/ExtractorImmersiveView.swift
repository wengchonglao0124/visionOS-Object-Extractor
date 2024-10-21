//
//  ExtractorImmersiveView.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//

import ARKit
import SwiftUI
import RealityKit

let ExtractorImmersiveViewID = "ExtractorImmersiveView"


struct ExtractorImmersiveView: View {
    @Environment(ExtractorImmersiveViewModel.self) var viewModel
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        RealityView { content in
            content.add(viewModel.setupContentEntity())
        }
        .task {
            do {
                if viewModel.dataProvidersAreSupported && viewModel.isReadyToRun {
                    try await viewModel.session.run([viewModel.sceneReconstruction, viewModel.handTracking])
                } else {
                    await dismissImmersiveSpace()
                }
            } catch {
                print("Failed to start session: \(error)")
                await dismissImmersiveSpace()
                openWindow(id: "error")
            }
        }
        .task {
            await viewModel.processHandUpdates()
        }
        .task {
            await viewModel.monitorSessionEvents()
        }
        .task(priority: .low) {
            await viewModel.processReconstructionUpdates()
        }
        .onChange(of: viewModel.errorState) {
            openWindow(id: "error")
        }
    }
}
