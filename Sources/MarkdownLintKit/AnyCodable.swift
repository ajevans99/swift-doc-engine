import Foundation

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self.value = NSNull(); return }
        if let boolValue = try? container.decode(Bool.self) { self.value = boolValue; return }
        if let intValue = try? container.decode(Int.self) { self.value = intValue; return }
        if let doubleValue = try? container.decode(Double.self) { self.value = doubleValue; return }
        if let stringValue = try? container.decode(String.self) { self.value = stringValue; return }
        if let arrayValue = try? container.decode([AnyCodable].self) { self.value = arrayValue.map { $0.value }; return }
        if let dictValue = try? container.decode([String: AnyCodable].self) { self.value = dictValue.mapValues { $0.value }; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value")
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let boolValue as Bool: try container.encode(boolValue)
        case let intValue as Int: try container.encode(intValue)
        case let doubleValue as Double: try container.encode(doubleValue)
        case let stringValue as String: try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictionaryValue as [String: Any]:
            try container.encode(dictionaryValue.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}
