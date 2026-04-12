import Foundation

/// A single scan result row from the Go core.
struct ScanResult: Identifiable, Codable {
    let id: UUID
    let ip: String
    var type: ResultType
    var values: [AnyCodableValue]
    var mac: String?
    var complete: Bool

    enum ResultType: String, Codable {
        case unknown
        case dead
        case alive
        case withPorts = "with_ports"
    }

    private enum CodingKeys: String, CodingKey {
        case ip, type, values, mac, complete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.ip = try container.decode(String.self, forKey: .ip)
        self.type = try container.decode(ResultType.self, forKey: .type)
        self.values = try container.decodeIfPresent([AnyCodableValue].self, forKey: .values) ?? []
        self.mac = try container.decodeIfPresent(String.self, forKey: .mac)
        self.complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
    }

    init(ip: String, type: ResultType, values: [AnyCodableValue], mac: String? = nil, complete: Bool = false) {
        self.id = UUID()
        self.ip = ip
        self.type = type
        self.values = values
        self.mac = mac
        self.complete = complete
    }
}

/// A type-erased codable value for result columns (strings, ints, nil).
enum AnyCodableValue: Codable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    var description: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(format: "%.1f", d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .null: try container.encodeNil()
        }
    }
}
