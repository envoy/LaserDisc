# LaserDisc

A library to record and replay HTTP requests for UI tests, inspired by [VCR](https://github.com/vcr/vcr).


## Overview:

A common problem with writing integration tests is determining where the integration test begins and ends. You could set up text fixtures and mock the network responses manually, but that tends to get very tedious, and involves writing a lot of boilerplate. Another approach is to run a full end-to-end test including the network stack, but then you'll need a very stable staging/test environment of your backend endpoints to make sure that the test data stays the same.

With LaserDisc, we tried to achieve the best of both worlds. The way it works, it will _record_ any network requests sent during your test case the first time you run it, and then _replay_ said requests any subsequent times the test is run. 

This is achieved by starting a _local HTTP server_ in the test process, which the app uses as a server in place of your normal server. The server then runs in either _recording_ or _replay_ mode. 

During the recording mode will forward any requests to your normal server while recording the request, response and round trip time. After the request finishes, it will write this record to disk in a human-readable format at a path of your choosing[1]. This record can later be changed by hand if needed, or updated by re-running the test in recording mode.

During the replay mode, the server instead reads an existing record and tries to match the incoming request[2] to a previously recorded request, and then replays it as if it were a normal request, with an identical response and round trip time. Since this all runs in the test process, the replay mode also lets you fail test cases when encountering requests that do not have a matching recorded request.

[1]: Helper methods exist to create fitting filepaths for each test case.
[2]: The matching logic uses a sort of fuzzy matching by default, but can be configured.

## Getting started:

### Starting the server

The first step is to actually start the server. This should be done in the setup phase of your UI test _before_ starting your application. This is because the server will attempt to find a free port to use on your local machine, and you need the port so that you can tell your application what URL LaserDisc is hosted on. More on this in the next step.

The first argument provided to the server is the `baseURL`, which tells LaserDisc where to forward the requests while it's recording. This should be your default server endpoint. LaserDisc will pull the path and and query parameters from the incoming requests and append them to this URL.

The second argument is the path to store the recording for this particular test case. The `laserDiscRecordingPath` is a helper extension provided on the `XCTestCase` class, which takes the `LASERDISC_PATH` provided in your test target's Info.plist file, and appends the module, the test class and test case, e.g. `LaserDisc/ExampleUITests/ExampleFlowTests/testExample.json`.

``` swift

class BaseTestClass: XCTestCase {
    var server: Server!

    override func setUp() {
        super.setUp()

        server = Server(baseURL: URL(string: "http://example.com")!,
                        recordingPath: laserDiscRecordingPath!)
        
        let port: Int
        do {
            port = try server.start()
        } catch {
            port = 0
            XCTFail("Error starting LaserDisc server: \(error)")
        }
    }

}

```

### Directing requests to the server

This step depends on how your network stack is set up. For Envoy, we define a base-URL in our dependency injection graph, which can optionally be configured through a launch argument. This URL is later used by our network stack throughout the app. When the UI test suite is run, we pass `http://localhost:\(port)` to use the LaserDisc server instead of the production endpoint.

Example:

``` swift

// Application code

var baseURL: URL {
    if let urlString = environment.value(for: "BASE_URL"),
       let url = URL(string: urlString) {
        return url
    } else {
        return URL(string: "http://example.com")!
    }
}

// Test code

// ...server setup

app.launchEnvironment["BASE_URL"] = "http://localhost:\(port)"

```

In addition to this, Apple's App Transport Security protections require you to add the following to your app's `Info.plist` to allow requests to `localhost`.

``` xml
<key>NSAppTransportSecurity</key>
<dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
</dict>
```

### Switching between record / replay mode:

The mode can be changed with the `isRecording`-setter. This should be called before the app is launched. Default value is `false`.

``` swift
func testExample() {
    server.isRecording = true

    // Start app and run test case
}
```

### Failing on unrecorded requests:

When introducing changes to the application you're testing, it can be helpful to see when new network requests are not being handled by the server. In order to do this, the server takes an optional third parameter, `unrecordedRequestHandler(_:)`, that is called with a `URLRequest` whenever no recorded entry is matched. 

As the server runs in the test process, you can also use this to fail any tests that encounter requests that are not yet recorded like so:

``` swift

var failOnUnrecordedRequests = true

override func setUp() {
    super.setUp()

    server = Server(baseURL: URL(string: "https://api.example.com")!,
                    recordingPath: laserDiscRecordingPath!,
                    unrecordedRequestHandler: handleUnrecordedRequest(_:))

    // ...launch application
}

private func handleUnrecordedRequest(_ request: URLRequest) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    let requestString: String
    if let jsonRequest = try? String(data: encoder.encode(request), encoding: .utf8) {
        requestString = jsonRequest
    } else {
        requestString = String(describing: request)
    }

    if failOnUnrecordedRequests {
        XCTFail("due to unrecorded request:\n \(requestString)")
    } else {
        print("Found unrecorded request:\n \(requestString)")
    }
}


```

### Custom request matching:

Since there is no defined order of a request's body, LaserDisc's default request matching ignores the request body. However, you might want to customize this behavior for a specific use-case. This can be achieved by providing the fourth parameter to the server's initializer, `requestMatcher`. 

This parameter takes a closure that matches an `Entry` to a `URLRequest`. The matcher will be called for every incoming request, attempting to match each `Entry` in the record until the closure returns true, or until there are no more recorded entries. The `Entry` struct contains the recorded `URLRequest`, along with its response data.

If you want to fall back to the default behavior, the default matcher is provided as a public extension on `URLRequest`, as the `isApproximatelyEqualTo(_:)` method.
