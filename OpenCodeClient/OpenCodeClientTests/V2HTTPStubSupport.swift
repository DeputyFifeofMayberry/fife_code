//
//  V2HTTPStubSupport.swift
//  OpenCodeClientTests
//
//  Offline HTTP stubbing shared by the v2 test files (probe, wire, SSE).
//  Same machinery as HTTPStatusAcceptanceTests but with its own registry so
//  the files stay independent.
//

import Foundation
@testable import OpenCodeClient

struct V2StubRoute {
    var path: String
    var method: String?
    var status: Int
    var body: Data
    var headers: [String: String]

    init(path: String, method: String? = nil, status: Int, body: Data, headers: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.status = status
        self.body = body
        self.headers = headers
    }

    init(path: String, method: String? = nil, status: Int, body: String, headers: [String: String] = [:]) {
        self.init(path: path, method: method, status: status, body: Data(body.utf8), headers: headers)
    }
}

struct V2RecordedRequest {
    var host: String
    var path: String
    var method: String
    var body: Data
    var headers: [String: String]
}

enum V2StubRegistry {
    static let lock = NSLock()
    static var stubs: [String: [V2StubRoute]] = [:]
    static var requests: [V2RecordedRequest] = []
    static var failingHosts: Set<String> = []

    static func set(host: String, routes: [V2StubRoute]) {
        lock.lock()
        stubs[host] = routes
        lock.unlock()
    }

    static func remove(host: String) {
        lock.lock()
        stubs[host] = nil
        lock.unlock()
    }

    static func setFailing(host: String) {
        lock.lock()
        failingHosts.insert(host)
        lock.unlock()
    }

    static func resetRequests() {
        lock.lock()
        requests = []
        lock.unlock()
    }

    static func record(_ request: V2RecordedRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    static func recordedRequests(host: String) -> [V2RecordedRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests.filter { $0.host == host }
    }

    static func route(for url: URL, method: String) -> V2StubRoute? {
        lock.lock()
        defer { lock.unlock() }
        guard let host = url.host, let routes = stubs[host] else { return nil }
        return routes.first { $0.path == url.path && ($0.method == nil || $0.method == method) }
    }

    static func isFailing(host: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return failingHosts.contains(host)
    }
}

final class V2StubHTTPProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasPrefix("w10v2-") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let host = url.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        V2StubRegistry.record(V2RecordedRequest(
            host: host,
            path: url.path,
            method: request.httpMethod ?? "GET",
            body: Self.readBody(request),
            headers: request.allHTTPHeaderFields ?? [:]
        ))
        if V2StubRegistry.isFailing(host: host) {
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
            return
        }
        guard let route = V2StubRegistry.route(for: url, method: request.httpMethod ?? "GET") else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        let response = HTTPURLResponse(
            url: url,
            statusCode: route.status,
            httpVersion: "HTTP/1.1",
            headerFields: route.headers.isEmpty ? ["Content-Type": "application/json"] : route.headers
        ) ?? HTTPURLResponse(url: url, statusCode: route.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: route.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

func makeV2StubHost() -> String {
    "w10v2-\(UUID().uuidString.lowercased()).invalid"
}

func makeV2StubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [V2StubHTTPProtocol.self]
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.urlCache = nil
    config.timeoutIntervalForRequest = 2
    config.timeoutIntervalForResource = 2
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
}
