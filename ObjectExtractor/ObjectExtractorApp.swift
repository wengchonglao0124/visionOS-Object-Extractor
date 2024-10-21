//
//  ObjectExtractorApp.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//

import OSLog
import SwiftUI


@main
struct ObjectExtractorApp: App {
    @State private var viewModel = ExtractorImmersiveViewModel()
    
    @MainActor init() {}
    
    var body: some Scene {
        WindowGroup {
            InitialisationView()
        }
        
        WindowGroup(id: "error") {
            Text("An error occurred; check the app's logs for details.")
        }

        ImmersiveSpace(id: ExtractorImmersiveViewID) {
            ExtractorImmersiveView()
                .environment(viewModel)
        }
    }
}

@MainActor
let logger = Logger(subsystem: "com.apple-samplecode.SceneReconstructionExample", category: "general")
