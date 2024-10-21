//
//  Edge.swift
//  ObjectExtractor
//
//  Created by weng chong lao on 20/10/2024.
//


struct Edge: Hashable {
    let start: Int
    let end: Int

    func hash(into hasher: inout Hasher) {
        let sortedIndices = start <= end ? (start, end) : (end, start)
        hasher.combine(sortedIndices.0)
        hasher.combine(sortedIndices.1)
    }

    static func == (lhs: Edge, rhs: Edge) -> Bool {
        return (lhs.start == rhs.start && lhs.end == rhs.end) ||
               (lhs.start == rhs.end && lhs.end == rhs.start)
    }
}
