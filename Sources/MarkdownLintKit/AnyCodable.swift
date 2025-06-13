import Foundation

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self.value = NSNull(); return }
        if let b = try? container.decode(Bool.self) { self.value = b; return }
        if let i = try? container.decode(Int.self) { self.value = i; return }
        if let d = try? container.decode(Double.self) { self.value = d; return }
        if let s = try? container.decode(String.self) { self.value = s; return }
        if let arr = try? container.decode([AnyCodable].self) { self.value = arr.map{ $0.value }; return }
        if let dict = try? container.decode([String: AnyCodable].self) { self.value = dict.mapValues{ $0.value }; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let arr as [Any]: try container.encode(arr.map { AnyCodable($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
