# NetworkKit

A lightweight, protocol oriented networking library for Swift, built on top of [Alamofire](https://github.com/Alamofire/Alamofire) and designed around `async/await`.

Define your API routes once as typed endpoints, then call them with a single line of code and get a decoded model back. No request building boilerplate, no manual status code checks, no manual JSON decoding.

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS-blue.svg)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)

## Overview

Most apps repeat the same networking steps for every API call: build a URL, set the HTTP method and headers, send the request, check the status code and decode the JSON. **NetworkKit** collapses that into two simple pieces:

1. An **`Endpoint`**: a small type that describes *what* you are calling (base URL, path, method, headers).
2. A **`NetworkClient`**: executes any endpoint and returns either the raw response or a decoded `Decodable` model.

Under the hood, `NetworkClient` uses Alamofire's `Session`, validates that the response is `2xx`, handles empty bodies and wraps decoding failures in a consistent error type.

## Features

- **Typed endpoints**: describe routes with an enum or struct conforming to `Endpoint`.
- **One-line API calls**: `try await client.execute(endpoint, as: Model.self)`.
- **Built on `async/await`**: no completion handlers or Combine pipelines.
- **Automatic validation**: non-2xx responses throw automatically.
- **Automatic decoding**: JSON is decoded straight into your `Decodable` models.
- **Raw response access**: get the body, status code, and headers when you need them.
- **Empty body support**: `2xx` responses with no content (e.g. `204`) do not fail.
- **Testable**: inject a stubbed Alamofire `Session` for unit tests.
- **Protocol-oriented**: `NetworkClient` conforms to `NetworkTransport`, so it is easy to mock.

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS         | 15.0+   |
| macOS       | 12.0+   |
| Swift       | 6.3+    |
| Xcode       | 26.4+   |


## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies…** and enter the repository URL:

```
https://github.com/mobihunterz/NetworkKit.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mobihunterz/NetworkKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["NetworkKit"]
    )
]
```

## Quick Start

```swift
import NetworkKit

let posts = try await NetworkClient.shared.execute(
    APIEndpoint.posts,
    as: [PostDTO].self
)
```

That's the whole call. The sections below show how to set it up.

---

## Usage

The example below fetches a list of posts from a dummy API: `https://api.example.com/posts`.

### 1. Define an Endpoint

Conform to `Endpoint` and describe your routes. An `enum` works well because each case is one route.

```swift
import NetworkKit

enum APIEndpoint: Endpoint {
    case posts

    var baseUrl: URL {
        URL(string: "https://api.example.com")!
    }

    var path: String {
        switch self {
        case .posts:
            return "/posts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .posts:
            return .get
        }
    }

    var headers: [String: String]? {
        nil
    }
}
```

Adding a new route is just a new `case` plus its `path` and `method`.

### 2. Create a Client

You can use the built-in shared client, or wrap your own in a small manager so it can be swapped out in tests.

```swift
import NetworkKit

final class NetworkManager {
    static let shared = NetworkManager()

    var postClient: NetworkClient

    init(client: NetworkClient = NetworkClient()) {
        self.postClient = client
    }
}
```

### 3. Execute a Request

Define a model that matches the response:

```swift
struct PostDTO: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}
```

Then call the endpoint and receive decoded data:

```swift
@MainActor
final class PostsViewModel: ObservableObject {
    @Published var posts: [PostDTO] = []
    @Published var errorMessage: String?
    var postRepo = NetworkManager.shared.postClient

    func loadPosts() async {
        do {
            posts = try await postRepo.execute(
                APIEndpoint.posts,
                as: [PostDTO].self
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Raw Responses

If you need the body bytes, status code, or response headers instead of a decoded model, call the non-generic `execute`:

```swift
let response = try await NetworkClient.shared.execute(APIEndpoint.posts)

print(response.statusCode)   // 200
print(response.headers)      // [String: String]
print(response.data.count)   // raw bytes
```

### Custom Session and Decoder

Pass your own Alamofire `Session` (custom configuration, timeouts, interceptors, etc.) and your own `JSONDecoder`:

```swift
let configuration = URLSessionConfiguration.default
configuration.timeoutIntervalForRequest = 30

let client = NetworkClient(session: Session(configuration: configuration))

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let posts = try await client.execute(
    APIEndpoint.posts,
    as: [PostDTO].self,
    decoder: decoder
)
```

### How It Behaves

| Scenario | Result |
|----------|--------|
| `2xx` response with JSON body | Decoded into `T` |
| `2xx` response with empty body | Returns empty `Data` (raw) |
| Non-`2xx` response | Throws an `AFError` (validation failure) |
| Transport failure (offline, timeout, etc.) | Throws an `AFError` wrapping the underlying error |
| Missing `HTTPURLResponse` | Throws `AFError.sessionTaskFailed` with `URLError.badServerResponse` |
| JSON decoding failure | Throws `AFError.responseSerializationFailed(.decodingFailed)` |

---

## NetworkKit vs. Alamofire

All three examples below do the same thing: `GET https://api.example.com/posts`, verify a `2xx` status, and decode the result into `[PostDTO]`.

### Alamofire

```swift
func fetchPosts() async throws -> [PostDTO] {
    try await AF.request(
        "https://api.example.com/posts",
        method: .get
    )
    .validate()
    .serializingDecodable([PostDTO].self)
    .value
}
```

Shorter, but the URL string, method, and decoding setup are still repeated at every call site and nothing is shared between routes.

### NetworkKit

```swift
func fetchPosts() async throws -> [PostDTO] {
    try await NetworkManager.shared.postClient.execute(
        APIEndpoint.posts,
        as: [PostDTO].self
    )
}
```

The route is defined **once** in `APIEndpoint`. The call site only says *which* endpoint and *what type* it expects.

## Testing

`NetworkClient` conforms to `NetworkTransport`, so you can mock the transport in your view models, or inject a stubbed Alamofire `Session` into the client.

```swift
final class MockClient: NetworkTransport {
    var result: NetworkResponse!

    func execute(_ endpoint: Endpoint) async throws -> NetworkResponse {
        result
    }
}
```

```swift
let stubbedSession = Session(configuration: stubbedConfiguration)
let client = NetworkClient(session: stubbedSession)
let manager = NetworkManager(client: client)
```

---

## Upcoming

The following features are planned for upcoming releases. The APIs shown are **proposals** and may change before release.

### 1. Network Connectivity

**What it does:** Lets your app know whether the device currently has a usable network connection, both *before* a request is sent and *while* the app is running.

**Why it matters:** Today, an offline request has to travel all the way to a timeout or transport failure before the app finds out. Detecting connectivity up front gives users instant feedback and prevents wasted requests.

**Planned capabilities:**

- **Real-time monitoring**: observe connection changes (online/offline) using `NWPathMonitor`, exposed as an `AsyncStream` and/or a Combine publisher.
- **Connection type awareness**: distinguish Wi-Fi, cellular, wired, and constrained/expensive connections (Low Data Mode, hotspots).
- **Pre-flight check**: optionally fail fast with a clear `offline` error instead of waiting for a timeout.
- **Auto-resume**: optionally queue requests made while offline and send them when the connection returns.
- **Testable**: connectivity is provided through a protocol, so it can be mocked in tests.

**Proposed API:**

```swift
// Observe changes
for await status in NetworkMonitor.shared.statusUpdates {
    switch status {
    case .connected(let type): print("Online via \(type)")
    case .disconnected:        print("Offline")
    }
}

// Fail fast when offline
let client = NetworkClient(configuration: .init(checksConnectivity: true))
```

### 2. Error Handling

**What it does:** Replaces raw `AFError` values with a single, well-defined `NetworkError` type that is easy to switch over, show to users, and log.

**Why it matters:** Currently callers have to inspect `AFError` internals to tell a `404` from a timeout from a decoding failure. A unified error model removes Alamofire details from your app code and makes error UI much simpler.

**Planned capabilities:**

- **Typed error cases** for the common failure modes:
  - `.noConnection`: the device is offline
  - `.timeout`: the request timed out
  - `.invalidURL`: the endpoint could not produce a valid URL
  - `.unauthorized` (`401`), `.forbidden` (`403`), `.notFound` (`404`)
  - `.clientError(statusCode:data:)`: other `4xx` responses
  - `.serverError(statusCode:data:)`: `5xx` responses
  - `.decodingFailed(underlying:)`: JSON did not match the model
  - `.cancelled`: the task was cancelled
  - `.unknown(underlying:)`: anything else
- **Server error payloads**: access the response body of failed requests so you can decode API error messages (e.g. `{ "message": "Invalid email" }`).
- **User-friendly messages**: every case provides a `LocalizedError` description suitable for display.
- **Underlying error preserved**: the original error is kept for logging and debugging.

**Proposed API:**

```swift
do {
    let posts = try await client.execute(APIEndpoint.posts, as: [PostDTO].self)
} catch let error as NetworkError {
    switch error {
    case .noConnection:
        showBanner("You appear to be offline.")
    case .unauthorized:
        router.showLogin()
    case .serverError(let code, _):
        showBanner("Server error (\(code)). Please try again later.")
    default:
        showBanner(error.localizedDescription)
    }
}
```

### 3. API Call Retry Handling

**What it does:** Automatically retries failed requests according to a configurable policy, so transient failures do not reach the user.

**Why it matters:** Flaky networks, brief server hiccups, and rate limiting are normal. A good retry strategy turns many of those failures into invisible successes, but retrying blindly (e.g. a `400` or a non-idempotent `POST`) can cause bugs, so it must be controllable.

**Planned capabilities:**

- **Configurable retry count**: set the maximum number of attempts (default planned: 3).
- **Backoff strategies**:
  - *Fixed*: wait the same delay between attempts
  - *Exponential*: delay doubles each attempt (e.g. 1s → 2s → 4s)
  - *Exponential with jitter*: adds randomness to avoid many clients retrying at the same moment
- **Retry conditions**: retry only when it makes sense:
  - Timeouts and connection lost errors
  - `5xx` server errors
  - `429 Too Many Requests` (honoring the `Retry-After` header)
  - Never retry `4xx` client errors (except `408` and `429`) by default
- **Idempotency awareness**: `GET`, `PUT`, `DELETE` retry by default; `POST` and `PATCH` retry only if explicitly enabled.
- **Per-endpoint overrides**: critical endpoints can have a different policy than the global default.
- **Cancellation-aware**: retries stop immediately if the calling `Task` is cancelled.

**Proposed API:**

```swift
let policy = RetryPolicy(
    maxAttempts: 3,
    backoff: .exponential(initial: 1.0, multiplier: 2.0, jitter: true),
    retryableStatusCodes: [408, 429, 500, 502, 503, 504]
)

let client = NetworkClient(retryPolicy: policy)

// Or override for a single endpoint
extension APIEndpoint {
    var retryPolicy: RetryPolicy? {
        switch self {
        case .posts: return .default
        }
    }
}
```

### 4. Authentication Support

**What it does:** Adds first-class support for authenticated APIs, including attaching credentials to requests and refreshing expired tokens automatically.

**Why it matters:** Today, auth headers must be added by hand in each endpoint's `headers`. Expired tokens cause `401` errors that every caller has to handle individually. Centralizing authentication keeps credentials out of endpoint definitions and makes token refresh seamless.

**Planned capabilities:**

- **Bearer token support**: automatically attach `Authorization: Bearer <token>` to requests.
- **Multiple auth schemes**: Basic auth, API key (header or query parameter), and custom schemes via an `Authenticator` protocol.
- **Automatic token refresh**: when a request returns `401`, refresh the token and transparently replay the original request.
- **Refresh de-duplication**: if several requests fail at once, only **one** refresh call is made and the rest wait for its result.
- **Secure storage**: token storage through a `TokenStore` protocol, with a Keychain-backed default implementation.
- **Per-endpoint control**: mark individual endpoints as public (e.g. `login`, `register`) so no credentials are attached.
- **Logout handling**: if refresh fails, clear stored credentials and surface a `.unauthorized` error so the app can route to login.

**Proposed API:**

```swift
struct MyAuthenticator: Authenticator {
    let tokenStore: TokenStore

    func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token = try await tokenStore.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func refresh() async throws {
        // Call your refresh-token endpoint and save the new tokens
    }
}

let client = NetworkClient(authenticator: MyAuthenticator(tokenStore: KeychainTokenStore()))

enum APIEndpoint: Endpoint {
    case login
    case profile

    var requiresAuthentication: Bool {
        switch self {
        case .login:   return false
        case .profile: return true
        }
    }
}
```

### Roadmap Summary

| Feature | Status | Description |
|---------|:------:|-------------|
| Network connectivity | Planned | Real-time monitoring and offline fail-fast |
| Error handling | Planned | Unified `NetworkError` type with server payloads |
| Retry handling | Planned | Configurable retries with backoff and idempotency rules |
| Authentication | Planned | Bearer/Basic/API key, auto token refresh, Keychain storage |

---

## License

NetworkKit is available under the MIT license. See the [LICENSE](LICENSE) file for details.
