import XCTest
@testable import LaserDisc

final class ServerTests: XCTestCase {
    func testRecording() {
        let path = "xyz"
        let server = Server(baseURL: URL(string: "https://example.com")!, recordingPath: path)
        let port = try! server.start()
        server.isRecording = true

        let expectation = self.expectation(description: "request to succeed")
        let request = URLRequest(url: URL(string: "http://localhost:\(port)")!)
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            expectation.fulfill()
        }).resume()

        waitForExpectations(timeout: 10, handler: nil)
    }

    static var allTests = [
        ("testExample", testRecording),
    ]
}
