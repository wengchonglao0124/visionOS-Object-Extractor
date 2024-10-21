//
//  simd_float4x4.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//

import simd


// Define the translation property for simd_float4x4
extension simd_float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}
