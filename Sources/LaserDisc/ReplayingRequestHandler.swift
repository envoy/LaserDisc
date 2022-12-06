import Foundation
import Embassy

public typealias RequestMatcher = (_ entry: Entry, _ incomingRequest: URLRequest) -> Bool
public typealias ResponseTransformer = (_ incomingRequest: URLRequest, _ data: Data?) -> Data?

final class ReplayingRequestHandler: RequestHandler {
    private let eventLoop: EventLoop
    private let baseURL: URL
    private let recordingPath: String
    private let unrecordedRequestHandler: ((URLRequest) -> Void)?
    private let matcher: RequestMatcher
    private let transformer: ResponseTransformer?
    private let fileManager = FileManager()

    private lazy var recording: Recording = {
        readRecording(at: recordingPath)
    }()

    init(eventLoop: EventLoop,
         baseURL: URL,
         recordingPath: String,
         unrecordedRequestHandler: ((URLRequest) -> Void)? = nil,
         matcher: RequestMatcher?,
         transformer: ResponseTransformer?) {
        self.eventLoop = eventLoop
        self.baseURL = baseURL
        self.recordingPath = recordingPath
        self.unrecordedRequestHandler = unrecordedRequestHandler
        self.matcher = matcher ?? Self.approximateMatcher
        self.transformer = transformer
    }

    func handle(request: URLRequest, sendStatus: @escaping StatusHandler, sendBody: @escaping BodyHandler) {
        guard var response = response(for: request) else {
            unrecordedRequestHandler?(request)
            eventLoop.call {
                sendStatus("404 Not Found", [:])
                sendBody(Data())
            }
            return
        }

        let textEncoding = String.Encoding(rawValue: response.bodyEncodingRaw)
        var data = response.body.data(using: textEncoding)
        if let transformer {
            data = transformer(request, data)
        }
        response.headers["Content-Length"] = "\(data?.count ?? 0)"

        eventLoop.call(withDelay: response.elapsedTime) {
            sendStatus(response.status, response.headers)
            if let data {
                sendBody(data)
                sendBody(Data())
            } else {
                sendBody(Data())
            }
        }
    }

    fileprivate func readRecording(at path: String) -> Recording {
        guard let contents = fileManager.contents(atPath: path),
              let recording = try? JSONDecoder().decode(Recording.self, from: contents) else {
            return Recording(entries: [])
        }

        return recording
    }

    private func response(for request: URLRequest) -> Response? {
        var routedRequest = request
        routedRequest.baseURL = baseURL
        return recording.removeEntry(for: routedRequest, with: matcher)?.response
    }

    private static func approximateMatcher(entry: Entry, incomingRequest: URLRequest) -> Bool {
        entry.request.isApproximatelyEqualTo(incomingRequest)
    }
}

private extension Recording {
    mutating func removeEntry(for request: URLRequest, with matcher: RequestMatcher) -> Entry? {
        guard let index = entries.firstIndex(where: { matcher($0, request) }) else {
            return nil
        }

        return entries.remove(at: index)
    }
}
