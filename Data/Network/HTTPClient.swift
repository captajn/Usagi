import Foundation

struct HTTPRequest: Sendable {
    var url: URL
    var method: String = "GET"
    var headers: [String: String] = [:]
    var body: Data?
    var timeout: TimeInterval = 30
}

struct HTTPResponse: Sendable {
    var data: Data
    var statusCode: Int
    var headers: [AnyHashable: Any]
    var url: URL?
}

protocol HTTPPerforming: Sendable {
    func data(for request: HTTPRequest) async throws -> HTTPResponse
}

enum HTTPClientError: LocalizedError {
    case invalidResponse
    case status(Int)
    case cloudflareChallenge(URL)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return String(localized: "Invalid network response")
        case .status(let code): return String(localized: "HTTP error \(code)")
        case .cloudflareChallenge: return String(localized: "Cloudflare protection required")
        case .cancelled: return String(localized: "Cancelled")
        }
    }
}

actor HTTPClient: HTTPPerforming {
    private let session: URLSession
    private let cookieStore: CookieJar
    private var defaultHeaders: [String: String]

    init(cookieStore: CookieJar = CookieJar(), configuration: URLSessionConfiguration = .default) {
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        self.session = URLSession(configuration: configuration)
        self.cookieStore = cookieStore
        self.defaultHeaders = [
            "User-Agent": "Usagi-iOS/0.1 (Swift; manga-reader)",
            "Accept": "*/*",
            "Accept-Language": Locale.current.identifier,
        ]
    }

    func data(for request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (k, v) in defaultHeaders { urlRequest.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in request.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }
        await cookieStore.apply(to: &urlRequest)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw HTTPClientError.invalidResponse }
        await cookieStore.store(from: http, for: request.url)

        if http.statusCode == 403 || http.statusCode == 503,
           let body = String(data: data, encoding: .utf8),
           body.localizedCaseInsensitiveContains("cloudflare") || body.localizedCaseInsensitiveContains("cf-browser") {
            throw HTTPClientError.cloudflareChallenge(request.url)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPClientError.status(http.statusCode)
        }
        return HTTPResponse(data: data, statusCode: http.statusCode, headers: http.allHeaderFields, url: http.url)
    }

    func downloadFile(from url: URL, to destination: URL) async throws {
        let response = try await data(for: HTTPRequest(url: url))
        try response.data.write(to: destination, options: .atomic)
    }
}

actor CookieJar {
    private var cookies: [HTTPCookie] = []

    func apply(to request: inout URLRequest) {
        guard let url = request.url else { return }
        let matched = cookies.filter { $0.matches(url) }
        let header = HTTPCookie.requestHeaderFields(with: matched)
        for (k, v) in header { request.setValue(v, forHTTPHeaderField: k) }
    }

    func store(from response: HTTPURLResponse, for url: URL) {
        guard let headerFields = response.allHeaderFields as? [String: String] else { return }
        let newCookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in newCookies {
            cookies.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
            cookies.append(cookie)
        }
        HTTPCookieStorage.shared.setCookies(newCookies, for: url, mainDocumentURL: url)
    }

    func exportCookies() -> [HTTPCookie] { cookies }

    func importCookies(_ list: [HTTPCookie]) {
        cookies = list
    }
}

private extension HTTPCookie {
    func matches(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        let domainMatch = host == domain || host.hasSuffix(domain.hasPrefix(".") ? domain : ".\(domain)")
        let pathMatch = url.path.hasPrefix(path)
        return domainMatch && pathMatch
    }
}
