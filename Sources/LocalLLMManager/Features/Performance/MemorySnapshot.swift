import Foundation

struct MemorySnapshot: Equatable {
    var total: UInt64 = 0
    var available: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var purgeable: UInt64 = 0
    var footprint: UInt64 = 0
    var resident: UInt64 = 0
    var processWired: UInt64 = 0
    var weights: UInt64 = 0
    var kvReserved: UInt64 = 0
    var kvUsed: UInt64 = 0
    var contextTokens: Int = 0
    var contextPeak: Int?
    var trainedContext: Int?
    var kvSummary: String = ""
    var promptRate: Double?
    var predictRate: Double?
}
