import Embassy
import Ambassador
import Foundation

enum ServerError: Error {
    case couldNotFindPort
}

public final class Server {
    private let loop = try! SelectorEventLoop(selector: try! KqueueSelector())
    private var httpServer: DefaultHTTPServer?
    private let replayingRequestHandler: ReplayingRequestHandler
    private let recordingRequestHandler: RecordingRequestHandler
    private let eventLoopThreadCondition: NSCondition = NSCondition()
    private lazy var eventLoopThread: Thread = {
        Thread(target: self, selector: #selector(runEventLoop), object: nil)
    }()

    public var isRecording: Bool = false

    public init(baseURL: URL,
                recordingPath: String,
                unrecordedRequestHandler: ((URLRequest) -> Void)? = nil,
                requestMatcher: RequestMatcher? = nil,
                contentTransformer: ResponseTransformer? = nil) {
        replayingRequestHandler = ReplayingRequestHandler(eventLoop: loop,
                                                          baseURL: baseURL,
                                                          recordingPath: recordingPath,
                                                          unrecordedRequestHandler: unrecordedRequestHandler,
                                                          matcher: requestMatcher,
                                                          transformer: contentTransformer)
        recordingRequestHandler = RecordingRequestHandler(eventLoop: loop, baseURL: baseURL, recordingPath: recordingPath)
    }

    @discardableResult
    public func start() throws -> Int {
        var server: DefaultHTTPServer?
        var openPort: Int = Int.max
        for port in (6000...6100).shuffled() {
            server = DefaultHTTPServer(eventLoop: loop, port: port, app: handleRequest)
            server?.logger.add(handler: PrintLogHandler())
            do {
                try server?.start()
                openPort = port
                break
            } catch {
                server = nil
            }
        }

        if server != nil {
            httpServer = server
            eventLoopThread.start()
        } else {
            throw ServerError.couldNotFindPort
        }

        return openPort
    }

    public func stop() {
        httpServer?.stop()
        loop.stop()
        eventLoopThread.cancel()
    }

    private func handleRequest(environ: [String: Any],
                               responseHandler: @escaping ((String, [(String, String)]) -> Void),
                               bodyHandler: @escaping (Data) -> Void) {
        let handler = { [unowned self] (data: Data?) in
            guard var request = URLRequest(environ: environ) else {
                return
            }

            request.httpBody = data

            let sendStatus = { (status: String, headers: [String: String]) -> Void in
                responseHandler(status, headers.map { $0 })
            }

            if self.isRecording {
                self.recordingRequestHandler.handle(request: request, sendStatus: sendStatus, sendBody: bodyHandler)
            } else {
                self.replayingRequestHandler.handle(request: request, sendStatus: sendStatus, sendBody: bodyHandler)
            }
        }

        if let contentLength = environ["HTTP_CONTENT_LENGTH"] as? String, contentLength != "0" {
            let input = environ["swsgi.input"] as! SWSGIInput
            DataReader.read(input, handler: { data in
                handler(data)
            })
        } else {
            handler(nil)
        }
    }

    @objc private func runEventLoop() {
        loop.runForever()
        eventLoopThreadCondition.lock()
        eventLoopThreadCondition.signal()
        eventLoopThreadCondition.unlock()
    }
}
