//
//  SIMD3.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//


extension SIMD3 where Scalar == Float {
    // Helper to check if a point is inside the cube
    func isInside(min: SIMD3<Float>, max: SIMD3<Float>) -> Bool {
        return self.x >= min.x && self.x <= max.x &&
               self.y >= min.y && self.y <= max.y &&
               self.z >= min.z && self.z <= max.z
    }
}
