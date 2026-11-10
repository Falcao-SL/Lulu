import Foundation

enum ModelMetadata {
    // Names and tags are hints, not authoritative model configuration.
    static func quantization(in text: String) -> String? {
        let pattern = #"(?i)(?:^|[^a-z0-9])(IQ[1-4](?:_[A-Z0-9]+)*|Q[2-8](?:_[A-Z0-9]+)+|[248]bit|[248]-bit|BF16|FP16|FP32)(?=$|[^a-z0-9])"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        return String(text[range]).trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
    }
}
