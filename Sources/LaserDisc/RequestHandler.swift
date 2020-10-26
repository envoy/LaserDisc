import Foundation

typealias StatusHandler = (_ status: String, _ headers: [String: String]) -> Void
typealias BodyHandler = (_ body: Data) -> Void

protocol RequestHandler {
    func handle(request: URLRequest, sendStatus: @escaping StatusHandler, sendBody: @escaping BodyHandler)
}
