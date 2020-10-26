import Foundation

public struct Recording: Codable {
    public var entries: [Entry]
}

public struct Entry: Codable {
    public var request: URLRequest
    public var response: Response
}

public struct Response: Codable {
    public var status: String
    public var headers: [String: String]
    public var body: String
    public var bodyEncodingRaw: String.Encoding.RawValue
    public var elapsedTime: TimeInterval
}
