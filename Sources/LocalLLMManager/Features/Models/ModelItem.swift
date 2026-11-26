import Foundation

struct ModelArch: Equatable, Hashable, Codable {
    var kvLayers: Int
    var kvHeads: Int
    var headDim: Int
    var trainedContext: Int?
    var elementBytes: Int
    var summary: String

    func kvBytes(tokens: Int) -> UInt64 {
        guard kvLayers > 0, kvHeads > 0, headDim > 0, tokens > 0, elementBytes > 0 else { return 0 }
        let perToken = UInt64(kvLayers) * UInt64(kvHeads) * UInt64(headDim) * UInt64(elementBytes)
        return perToken * 2 * UInt64(tokens)
    }
}

struct ModelItem: Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var engineID: String
    var path: String
    var mmproj: String?
    var sizeBytes: UInt64
    var arch: ModelArch?
}
