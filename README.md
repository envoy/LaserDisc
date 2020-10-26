# LaserDisc

A library to record and replay HTTP requests for UI tests, inspired by [VCR](https://github.com/vcr/vcr).

## Usage:

``` swift
override func setUp() {
    super.setUp()

    // Creates the server with the base-URL it should proxy to, along with the path to save the recordings
    server = Server(baseURL: URL(string: "https://example.com")!,
                    recordingPath: laserDiscRecordingPath!)

    // Starts the server on a free port
    let port: Int
    do {
        port = try server.start() ?? 0
    } catch {
        port = 0
        XCTFail("Error starting proxy server: \(error)")
    }

    // Pass the replacement URL to the application
    app.launchEnvironment["BASE_URL"] = "http://localhost:\(port)"

    // Set isRecording to true to proxy to the original server and save the results, or false to replay previously saved recordings.
    server.isRecording = true

    // Start application and proceed with testing
    ...
}
```
