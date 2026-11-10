/// Uses the context declared in local model metadata, including non-power-of-two limits.
enum ContextPolicy {
    static func limit(_ declared: Int?) -> Int? {
        guard let declared, declared > 0 else { return nil }
        return declared
    }

    static func options(presets: [Int], declared: Int?) -> [Int] {
        guard let maximum = limit(declared) else { return presets }
        return Array(Set(presets.filter { $0 <= maximum } + [maximum])).sorted()
    }

    static func clamped(_ value: Int, declared: Int?) -> Int {
        min(max(1, value), limit(declared) ?? max(1, value))
    }
}
