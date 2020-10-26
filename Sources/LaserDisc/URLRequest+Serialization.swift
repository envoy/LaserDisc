import Foundation

extension URLRequest: Codable {
    enum Keys: String, CodingKey {
        case url = "url"
        case headers = "headers"
        case method = "method"
        case body = "body"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let url = try container.decode(URL.self, forKey: .url)
        self.init(url: url)

        httpMethod = try container.decode(String.self, forKey: .method)
        allHTTPHeaderFields = try container.decode([String: String].self, forKey: .headers)

        if let body = try? container.decodeIfPresent(String.self, forKey: .body) {
            httpBody = body.data(using: .utf8)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(httpMethod, forKey: .method)
        try container.encodeIfPresent(allHTTPHeaderFields, forKey: .headers)
        if let body = httpBody, let bodyString = String(data: body, encoding: .utf8) {
            try container.encode(bodyString, forKey: .body)
        }
    }

    // We're intentionally not matching the body of the request as JSON bodies rarely maintain their order
    public func isApproximatelyEqualTo(_ request: URLRequest) -> Bool {
        // compare query parameters one-by-one
        guard let url = self.url, let otherURL = request.url else {
            return false
        }
        return url.isApproximatelyEqualTo(otherURL)
            && httpMethod == request.httpMethod
    }
}

private extension URL {
    func isApproximatelyEqualTo(_ url: URL) -> Bool {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              var otherComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        // Comparing the query items without caring about order
        let queryItems = Set(components.queryItems ?? [])
        let otherQueryItems = Set(otherComponents.queryItems ?? [])

        components.query = nil
        otherComponents.query = nil

        return components == otherComponents && queryItems == otherQueryItems
    }

}
