import Foundation
import Embassy

enum RecordingError: Error {
    case missingHTTPResponse
    case missingData
    case missingURL
}

final class RecordingRequestHandler: RequestHandler {
    private let eventLoop: EventLoop
    private let baseURL: URL
    private let recordingPath: String
    private let urlSession: URLSession
    private let fileManager: FileManager
    private let recordingErrorHandler: ((Error) -> Void)?
    private var recording = Recording(entries: [])
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        if #available(macOS 10.13, iOS 11, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.prettyPrinted]
        }
        return encoder
    }()

    init(eventLoop: EventLoop,
         baseURL: URL,
         recordingPath: String,
         urlSession: URLSession = .shared,
         fileManager: FileManager = .default,
         recordingErrorHandler: ((Error) -> Void)? = nil) {
        self.eventLoop = eventLoop
        self.baseURL = baseURL
        self.recordingPath = recordingPath
        self.urlSession = urlSession
        self.fileManager = fileManager
        self.recordingErrorHandler = recordingErrorHandler
    }

    func handle(request: URLRequest, sendStatus: @escaping StatusHandler, sendBody: @escaping BodyHandler) {
        // TODO: Figure out whether or not its a data or upload task
        do {
            let routed = try routedRequest(for: request)

            let startTime = CFAbsoluteTimeGetCurrent()
            let task = urlSession.dataTask(with: routed) { [weak self] data, response, error in
                guard let this = self else {
                    return
                }

                let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

                if let error = error {
                    this.recordingErrorHandler?(error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    this.recordingErrorHandler?(RecordingError.missingHTTPResponse)
                    return
                }

                guard let data = data else {
                    this.recordingErrorHandler?(RecordingError.missingData)
                    return
                }

                var headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
                let status: String
                if let statusHeader = headers["Status"] {
                    status = statusHeader
                } else {
                    status = "200 OK"
                }

                // The system has already decoded the gzipped data here, so it'll fail if it tries to do so again
                if headers["Content-Encoding"] == "gzip" {
                    headers["Content-Encoding"] = nil
                }

                // ...and the content length will be determined when read from disk to allow for manual editing
                headers["Content-Length"] = nil
                let encoding = httpResponse.stringEncoding

                let response = Response(status: status,
                                        headers: headers,
                                        body: String(data: data, encoding: encoding) ?? "",
                                        bodyEncodingRaw: encoding.rawValue,
                                        elapsedTime: elapsedTime)
                let entry = Entry(request: routed, response: response)
                this.recording.entries.append(entry)
                try! this.writeRecordingToFile()

                this.eventLoop.call {
                    sendStatus(status, headers)

                    if !data.isEmpty {
                        sendBody(data)
                    }
                    // Sending EOF
                    sendBody(Data())
                }
            }
            task.resume()
        } catch {
            recordingErrorHandler?(error)
        }
    }

    private func routedRequest(for request: URLRequest) throws -> URLRequest {
        var routedRequest = request
        routedRequest.baseURL = baseURL
        routedRequest.cachePolicy = .reloadIgnoringLocalCacheData
        return routedRequest
    }

    private func writeRecordingToFile() throws {
        let data = try encoder.encode(recording)
        let directoryPath = recordingPath.containingDirectory
        if !fileManager.fileExists(atPath: directoryPath) {
            try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: [:])
        }
        fileManager.createFile(atPath: recordingPath, contents: data, attributes: nil)

    }
}

extension String {
    var containingDirectory: String {
        guard let fileName = components(separatedBy: "/").last else {
            return self
        }
        return self.replacingOccurrences(of: "/\(fileName)", with: "")
    }
}

extension String.Encoding {
    init(from httpTextEncoding: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(httpTextEncoding as CFString)
        self = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }
}

extension HTTPURLResponse {
    var stringEncoding: String.Encoding {
        guard let encodingName = textEncodingName else {
            return .utf8
        }
        return .init(from: encodingName)
    }
}
