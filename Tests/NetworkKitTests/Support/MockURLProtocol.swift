import Foundation

/// In-memory HTTP stub used by `URLSession` / Alamofire so tests never hit the network.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var statusCode: Int
        var headers: [String: String]
        var data: Data
        var error: Error?

        static func success(
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "application/json"],
            data: Data = Data()
        ) -> Stub {
            Stub(statusCode: statusCode, headers: headers, data: data, error: nil)
        }

        static func failure(_ error: Error) -> Stub {
            Stub(statusCode: 0, headers: [:], data: Data(), error: error)
        }
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _stub: Stub = .success()
    nonisolated(unsafe) private static var _lastRequest: URLRequest?
    nonisolated(unsafe) private static var _lastBody: Data?

    static var stub: Stub {
        get { lock.withLock { _stub } }
        set { lock.withLock { _stub = newValue } }
    }

    static var lastRequest: URLRequest? {
        get { lock.withLock { _lastRequest } }
        set { lock.withLock { _lastRequest = newValue } }
    }

    /// Alamofire often delivers the body as `httpBodyStream` rather than `httpBody`.
    static var lastBody: Data? {
        get { lock.withLock { _lastBody } }
        set { lock.withLock { _lastBody = newValue } }
    }

    static func reset() {
        lock.withLock {
            _stub = .success()
            _lastRequest = nil
            _lastBody = nil
        }
    }

    static func data(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var data = Data()
        while stream.hasBytesAvailable {
            let readCount = stream.read(buffer, maxLength: bufferSize)
            if readCount > 0 {
                data.append(buffer, count: readCount)
            } else {
                break
            }
        }
        return data.isEmpty ? nil : data
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = Self.data(from: request)

        let stub = Self.stub
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: stub.headers
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
