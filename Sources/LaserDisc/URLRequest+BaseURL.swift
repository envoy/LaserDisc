import Foundation

extension URLRequest {
    var baseURL: URL? {
        set {
            guard let url = self.url,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }

            components.scheme = newValue?.scheme
            components.host = newValue?.host
            components.port = nil

            self.setValue(newValue?.host, forHTTPHeaderField: "Host")
            self.url = components.url
        }
        get {
            url
        }
    }
}
