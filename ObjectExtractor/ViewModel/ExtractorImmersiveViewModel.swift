//
//  ExtractorImmersiveViewModel.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//

import ARKit
import RealityKit


@Observable
@MainActor
class ExtractorImmersiveViewModel {
    let session = ARKitSession()
    let handTracking = HandTrackingProvider()
    let sceneReconstruction = SceneReconstructionProvider()

    var contentEntity = Entity()

    private var meshEntities = [UUID: ModelEntity]()
    private let fingerEntities: [HandAnchor.Chirality: ModelEntity] = [
        .left: .createFingertip(),
        .right: .createFingertip()
    ]
    
    var errorState = false

    /// Sets up the root entity in the scene.
    func setupContentEntity() -> Entity {
        for entity in fingerEntities.values {
            contentEntity.addChild(entity)
        }

        return contentEntity
    }
    
    var dataProvidersAreSupported: Bool {
        HandTrackingProvider.isSupported && SceneReconstructionProvider.isSupported
    }
    
    var isReadyToRun: Bool {
        handTracking.state == .initialized && sceneReconstruction.state == .initialized
    }
    
    /// Updates the scene reconstruction meshes as new data arrives from ARKit.
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor
            //print(meshAnchor.originFromAnchorTransform)
            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            switch update.event {
            case .added:
                guard meshAnchor.geometry.vertices.count > 0 else {
                    print("No vertices found in meshAnchor")
                    continue
                }
                await visualizeMeshEdgesInCube(from: meshAnchor)
                
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else { continue }
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision?.shapes = [shape]
                //await visualizeMeshVertices(from: meshAnchor)
                await visualizeMeshEdgesInCube(from: meshAnchor)
                
            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
                
                // Remove associated edge entities
                if let entities = edgeEntities[meshAnchor.id] {
                    for entity in entities {
                        await removeEntityFromScene(entity)
                    }
                    edgeEntities.removeValue(forKey: meshAnchor.id)
                }
            }
        }
    }
    
    // Properties to track vertices and pinch state
    var isPinching: Bool = false
    var firstVertex: ModelEntity? = nil
    var secondVertex: ModelEntity? = nil
    var cubeEntities: [ModelEntity] = []
    
    // Offset between the cube's center and the content's origin
    var cubeCenterToContentOriginOffset = SIMD3<Float>(0, 0, 0)
    
    // Variables for scaling
    var isScalingContent = false
    var initialHandDistance: Float = 0.0
    var initialContentScale: SIMD3<Float> = SIMD3<Float>(1, 1, 1)

    // Variables for hand pinch states and positions
    var isRightHandPinching = false
    var isLeftHandPinching = false
    var rightHandPosition = SIMD3<Float>(0, 0, 0)
    var leftHandPosition = SIMD3<Float>(0, 0, 0)

    // Variables for moving content with one hand
    var isMovingContent = false
    var moveContentOffset = SIMD3<Float>(0, 0, 0)
    
    func processHandUpdates() async {
        for await update in handTracking.anchorUpdates {
            let handAnchor = update.anchor

            // Ensure the hand is tracked and the index finger's tip joint is tracked
            guard
                handAnchor.isTracked,
                let indexFingerTipJoint = handAnchor.handSkeleton?.joint(.indexFingerTip),
                let thumbTipJoint = handAnchor.handSkeleton?.joint(.thumbTip),
                indexFingerTipJoint.isTracked, thumbTipJoint.isTracked else { continue }

            // Get the transformation matrices for the index finger tip and thumb tip in world space
            let originFromIndexFingerTip = handAnchor.originFromAnchorTransform * indexFingerTipJoint.anchorFromJointTransform
            let originFromThumbTip = handAnchor.originFromAnchorTransform * thumbTipJoint.anchorFromJointTransform

            // Extract the fingertip and thumb tip positions from the transformation matrices
            let indexFingerTipPosition = originFromIndexFingerTip.translation
            let thumbTipPosition = originFromThumbTip.translation

            // Calculate the distance between the index finger tip and thumb tip
            let pinchDistance = simd_distance(indexFingerTipPosition, thumbTipPosition)

            // Define a threshold for detecting a tap or pinch gesture
            let tapThreshold: Float = 0.02

            // Store whether the current hand is pinching
            let isHandPinching = pinchDistance < tapThreshold

            // Update hand pinch state and positions
            if handAnchor.chirality == .right {
                isRightHandPinching = isHandPinching
                rightHandPosition = indexFingerTipPosition
            } else if handAnchor.chirality == .left {
                isLeftHandPinching = isHandPinching
                leftHandPosition = indexFingerTipPosition
            }

            // Handle gestures

            // **Two-Hand Scaling**
            if isLeftHandPinching && isRightHandPinching && !isScalingContent && !isMovingContent && !isPinching {
                // Start scaling
                isScalingContent = true

                // Calculate initial distance between hands
                initialHandDistance = simd_distance(leftHandPosition, rightHandPosition)

                // Store initial content scale
                initialContentScale = contentEntity.scale(relativeTo: nil)
                print("Scaling started!")
            } else if isScalingContent {
                if isLeftHandPinching && isRightHandPinching {
                    // Both hands are still pinching, update scaling

                    // Calculate current distance between hands
                    let currentHandDistance = simd_distance(leftHandPosition, rightHandPosition)

                    // Calculate scale factor
                    let scaleFactor = currentHandDistance / initialHandDistance

                    // Apply scale factor to content
                    let newScale = initialContentScale * scaleFactor
                    contentEntity.setScale(newScale, relativeTo: nil)
                } else {
                    // Scaling ended
                    isScalingContent = false
                    print("Scaling ended!")
                }
            }
            // **Single-Hand Gestures**
            else if !isScalingContent {
                // Process single-hand gestures for right hand (cube definition and moving content)
                if handAnchor.chirality == .right {
                    let distance = pinchDistance

                    // **Cube Definition**
                    if distance < tapThreshold {
                        if !isPinching && firstVertex == nil {
                            // First pinch detection - create the first vertex
                            isPinching = true
                            firstVertex = createVertex(at: indexFingerTipPosition)
                            contentEntity.addChild(firstVertex!)
                            print("Pinch detected! First vertex created at: \(indexFingerTipPosition)")
                        }
                        else if isPinching {
                            // If the pinch is still active, move the second vertex to follow the fingertip
                            if secondVertex == nil {
                                // Create the second vertex if it doesn't exist
                                secondVertex = createVertex(at: indexFingerTipPosition)
                                contentEntity.addChild(secondVertex!)
                            } else {
                                // Update the second vertex position to follow the fingertip
                                secondVertex?.position = indexFingerTipPosition

                                // Update the cube dynamically as the fingers move
                                if let firstVertex = firstVertex {
                                    // Clear previous cube before creating a new one
                                    removeCube()

                                    // Create and update the cube based on the new position of the second vertex
                                    createCube(firstVertexPosition: firstVertex.position, secondVertexPosition: secondVertex!.position)
                                }
                            }
                        }

                        // **Moving Content**
                        if !isPinching && firstVertex != nil && secondVertex != nil {

                            if !isMovingContent {
                                // Start moving content
                                isMovingContent = true

                                // Calculate the cube center
                                let cubeCenter = (firstVertex!.position + secondVertex!.position) / 2.0

                                // Calculate the offset between the cube center and the finger position
                                moveContentOffset = cubeCenter - indexFingerTipPosition

                                // Calculate the offset between the content's origin and the cube center
                                let contentPosition = contentEntity.position(relativeTo: nil)
                                cubeCenterToContentOriginOffset = contentPosition - cubeCenter
                                print("Moving content started!")
                            } else if isMovingContent {
                                // Update the content's position to follow the finger
                                let newContentPosition = indexFingerTipPosition + moveContentOffset + cubeCenterToContentOriginOffset
                                contentEntity.setPosition(newContentPosition, relativeTo: nil)
                            }
                        }
                    }
                    // **Pinch Released**
                    else if isPinching && distance > tapThreshold {
                        // Pinch is released - finalize the second vertex position
                        isPinching = false
                        print("Pinch released! Second vertex settled at: \(indexFingerTipPosition)")

                        if #available(visionOS 2.0, *) {
                            for meshAnchor in sceneReconstruction.allAnchors {
                                await visualizeMeshEdgesInCube(from: meshAnchor)
                            }
                        } else {
                            // Fallback on earlier versions
                            print("sceneReconstruction.allAnchors not available")
                        }
                    }
                    // **Stop Moving Content**
                    else if isMovingContent && distance > tapThreshold {
                        // Stop moving content
                        isMovingContent = false
                        print("Moving content ended!")
                    }
                }
            }

            // Update the position of the finger entities for both hands
            fingerEntities[handAnchor.chirality]?.setTransformMatrix(originFromIndexFingerTip, relativeTo: nil)
        }
    }
    
    // Function to create a vertex (small sphere) at a given position
    func createVertex(at position: SIMD3<Float>) -> ModelEntity {
        let sphere = MeshResource.generateSphere(radius: 0.005) // Create a small sphere
        let material = SimpleMaterial(color: .systemCyan, isMetallic: false) // Assign a color/material
        let vertexEntity = ModelEntity(mesh: sphere, materials: [material])
        vertexEntity.position = position
        return vertexEntity
    }
    
    // Function to remove the existing cube
    func removeCube() {
        for entity in cubeEntities {
            entity.removeFromParent() // Remove each entity (vertex or edge) from the scene
        }
        cubeEntities.removeAll() // Clear the list of cube entities
    }
    
    // Function to create a cube based on two diagonally opposite vertices
    func createCube(firstVertexPosition: SIMD3<Float>, secondVertexPosition: SIMD3<Float>) {
        // Calculate the other six vertices of the cube
        let minX = min(firstVertexPosition.x, secondVertexPosition.x)
        let maxX = max(firstVertexPosition.x, secondVertexPosition.x)
        let minY = min(firstVertexPosition.y, secondVertexPosition.y)
        let maxY = max(firstVertexPosition.y, secondVertexPosition.y)
        let minZ = min(firstVertexPosition.z, secondVertexPosition.z)
        let maxZ = max(firstVertexPosition.z, secondVertexPosition.z)

        // Define the 8 vertices of the cube
        let vertices: [SIMD3<Float>] = [
            SIMD3<Float>(minX, minY, minZ),
            SIMD3<Float>(minX, minY, maxZ),
            SIMD3<Float>(minX, maxY, minZ),
            SIMD3<Float>(minX, maxY, maxZ),
            SIMD3<Float>(maxX, minY, minZ),
            SIMD3<Float>(maxX, minY, maxZ),
            SIMD3<Float>(maxX, maxY, minZ),
            SIMD3<Float>(maxX, maxY, maxZ)
        ]

        // Create the vertices in the scene
        var vertexEntities: [ModelEntity] = []
        for vertexPosition in vertices {
            let vertexEntity = createVertex(at: vertexPosition)
            contentEntity.addChild(vertexEntity)
            cubeEntities.append(vertexEntity) // Store vertex entities
            vertexEntities.append(vertexEntity)
        }

        // Define the edges of the cube as pairs of indices into the vertices array
        let edges: [(Int, Int)] = [
            (0, 1), (1, 3), (3, 2), (2, 0), // Bottom face
            (4, 5), (5, 7), (7, 6), (6, 4), // Top face
            (0, 4), (1, 5), (2, 6), (3, 7)  // Connecting edges
        ]

        // Create lines between the vertices to form the cube
        for (start, end) in edges {
            let startVertex = vertices[start]
            let endVertex = vertices[end]
            let lineEntity = createBoxLine(from: startVertex, to: endVertex)
            contentEntity.addChild(lineEntity)
            cubeEntities.append(lineEntity) // Store edge entities
        }
    }
    
    // Function to create a line between two vertices
    func createBoxLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> ModelEntity {
        let length = distance(start, end)
        let midPoint = (start + end) / 2
        let direction = normalize(end - start)

        // Create a thin box to represent the line
        let lineThickness: Float = 0.001
        let line = MeshResource.generateBox(size: SIMD3<Float>(lineThickness, lineThickness, length))
        let material = SimpleMaterial(color: .systemRed, isMetallic: false)

        let lineEntity = ModelEntity(mesh: line, materials: [material])
        lineEntity.position = midPoint

        // Rotate the line to align with the direction between the two vertices
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
        lineEntity.orientation = rotation

        return lineEntity
    }
    
    // Function to create a line between two vertices
    func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> ModelEntity {
        let length = distance(start, end)
        let midPoint = (start + end) / 2
        let direction = normalize(end - start)

        // Create a thin box to represent the line
        let lineThickness: Float = 0.0005
        let line = MeshResource.generateBox(size: SIMD3<Float>(lineThickness, lineThickness, length))
        let material = SimpleMaterial(color: .systemBlue, isMetallic: true)

        let lineEntity = ModelEntity(mesh: line, materials: [material])
        lineEntity.position = midPoint

        // Rotate the line to align with the direction between the two vertices
        let rotation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
        lineEntity.orientation = rotation

        return lineEntity
    }
    
    // Keep track of edge entities for each mesh anchor
    var edgeEntities: [UUID: [ModelEntity]] = [:]
    
    private func extractVertices(from meshAnchor: MeshAnchor) async -> [SIMD3<Float>] {
        let geometry = meshAnchor.geometry
        let vertexCount = geometry.vertices.count
        var vertices: [SIMD3<Float>] = []

        // Get the raw buffer pointer to vertex data
        let vertexBuffer = geometry.vertices.buffer.contents()
        let vertexStride = geometry.vertices.stride

        for index in 0..<vertexCount {
            let vertexPointer = vertexBuffer.advanced(by: index * vertexStride)
            let vertex = vertexPointer.assumingMemoryBound(to: (SIMD3<Float>.self)).pointee
            vertices.append(vertex)
        }
        
        return vertices
    }
    
    private func extractIndices(from meshAnchor: MeshAnchor) async -> [UInt32] {
        let geometry = meshAnchor.geometry
        let faceCount = geometry.faces.count // Number of triangles
        var indices: [UInt32] = []

        // Get the index buffer and properties
        let indexBuffer = geometry.faces.buffer.contents()
        let bytesPerIndex = geometry.faces.bytesPerIndex

        // Iterate through all triangles (each face is 3 indices)
        for i in 0..<faceCount {
            // Each triangle has 3 indices
            for j in 0..<3 {
                let indexOffset = (i * 3 + j) * bytesPerIndex
                let indexPointer = indexBuffer.advanced(by: indexOffset)
                
                // Read the index, accounting for whether it's UInt16 or UInt32
                let index: UInt32
                if bytesPerIndex == MemoryLayout<UInt16>.size {
                    index = UInt32(indexPointer.assumingMemoryBound(to: UInt16.self).pointee)
                } else {
                    index = indexPointer.assumingMemoryBound(to: UInt32.self).pointee
                }
                
                indices.append(index)
            }
        }
        
        return indices
    }
    
    private func visualizeMeshEdgesInCube(from meshAnchor: MeshAnchor) async {
        // Remove previous edge entities for this mesh anchor
        if let entities = edgeEntities[meshAnchor.id] {
            for entity in entities {
                await removeEntityFromScene(entity)
            }
            edgeEntities.removeValue(forKey: meshAnchor.id)
        }

        // Extract vertices and indices
        let vertices = await extractVertices(from: meshAnchor)
        let indices = await extractIndices(from: meshAnchor)

        // Transform the vertices to world space
        var worldVertices: [SIMD3<Float>] = []
        for vertex in vertices {
            let worldVertex = meshAnchor.originFromAnchorTransform * SIMD4<Float>(vertex, 1.0)
            worldVertices.append(SIMD3<Float>(worldVertex.x, worldVertex.y, worldVertex.z))
        }

        // Only proceed if firstVertex and secondVertex are set and not pinching
        if let firstVertex = firstVertex, let secondVertex = secondVertex, !isPinching {
            // Calculate the bounds of the cube (min and max vertices)
            let minVertex = SIMD3<Float>(
                min(firstVertex.position.x, secondVertex.position.x),
                min(firstVertex.position.y, secondVertex.position.y),
                min(firstVertex.position.z, secondVertex.position.z)
            )
            let maxVertex = SIMD3<Float>(
                max(firstVertex.position.x, secondVertex.position.x),
                max(firstVertex.position.y, secondVertex.position.y),
                max(firstVertex.position.z, secondVertex.position.z)
            )

            // Prepare to store edge entities
            var newEdgeEntities: [ModelEntity] = []

            // Create a set to keep track of processed edges to avoid duplicates
            var processedEdges = Set<Edge>()

            // Loop through each triangle
            for i in stride(from: 0, to: indices.count, by: 3) {
                let index0 = Int(indices[i])
                let index1 = Int(indices[i + 1])
                let index2 = Int(indices[i + 2])


                // Define the edges of the triangle
                let edges = [
                    Edge(start: index0, end: index1),
                    Edge(start: index1, end: index2),
                    Edge(start: index2, end: index0)
                ]

                for edge in edges {
                    // Ensure the edge hasn't been processed (to avoid duplicates)
                    if processedEdges.contains(edge) {
                        continue
                    }
                    processedEdges.insert(edge)

                    let startPos = worldVertices[edge.start]
                    let endPos = worldVertices[edge.end]

                    // Check if both points of the edge are inside the cube
                    if isPointInsideCube(point: startPos, minVertex: minVertex, maxVertex: maxVertex) &&
                        isPointInsideCube(point: endPos, minVertex: minVertex, maxVertex: maxVertex) {

                        // Create a line entity for the edge
                        let lineEntity = createLine(from: startPos, to: endPos)
                        await addEntityToScene(lineEntity)
                        newEdgeEntities.append(lineEntity)

                    }
                }
            }

            // Store the edge entities associated with this mesh anchor
            edgeEntities[meshAnchor.id] = newEdgeEntities

        } else {
            print("Cube not defined yet; skipping edge visualization.")
        }
    }
    
    func addEntityToScene(_ entity: ModelEntity) async {
        // Use the async task to add the entity to the scene
        await Task { [weak self] in
            self?.contentEntity.addChild(entity)
        }.value
    }
    
    func removeEntityFromScene(_ entity: ModelEntity) async {
        await Task { [weak self] in
            entity.removeFromParent()
        }.value
    }
    
    private func isPointInsideCube(point: SIMD3<Float>, minVertex: SIMD3<Float>, maxVertex: SIMD3<Float>) -> Bool {
        return (point.x >= minVertex.x && point.x <= maxVertex.x) &&
               (point.y >= minVertex.y && point.y <= maxVertex.y) &&
               (point.z >= minVertex.z && point.z <= maxVertex.z)
    }
    
    /// Responds to events like authorization revocation.
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(type: _, status: let status):
                logger.info("Authorization changed to: \(status)")
                
                if status == .denied {
                    errorState = true
                }
            case .dataProviderStateChanged(dataProviders: let providers, newState: let state, error: let error):
                logger.info("Data provider changed: \(providers), \(state)")
                if let error {
                    logger.error("Data provider reached an error state: \(error)")
                    errorState = true
                }
            @unknown default:
                fatalError("Unhandled new event type \(event)")
            }
        }
    }
}
