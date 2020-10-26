import Foundation

extension URLRequest {
    /// Initializes a URLRequest from Embassy's environ variables
    init?(environ: [String: Any]) {
        guard let host = environ["HTTP_HOST"] as? String,
              let path = environ["PATH_INFO"] as? String,
              let method = environ["REQUEST_METHOD"] as? String,
              let headers = environ["embassy.headers"] as? [(String, String)] else {
            return nil
        }

        if let query = environ["QUERY_STRING"] as? String, !query.isEmpty,
           let url = URL(string: "http://\(host)\(path)?\(query)") {
            self.init(url: url)
        } else if let url = URL(string: "http://\(host)\(path)") {
            self.init(url: url)
        } else {
            return nil
        }

        httpMethod = method
        allHTTPHeaderFields = headers.reduce(into: [String: String](), { headerDict, header in
            headerDict[header.0] = header.1
        })
    }
}
