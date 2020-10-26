import XCTest

public extension XCTestCase {
    var laserDiscRecordingPath: String? {
        let bundle = Bundle(for: type(of: self))
        guard let root = bundle.infoDictionary?["LASERDISC_PATH"],
              let moduleName = bundle.executableURL?.lastPathComponent,
              let selector = invocation?.selector else {
            return nil
        }

        let testClass = String(describing: type(of: self))
        let testName = NSStringFromSelector(selector)
        return "\(root)/\(moduleName)/\(testClass)/\(testName).json"
    }
}
