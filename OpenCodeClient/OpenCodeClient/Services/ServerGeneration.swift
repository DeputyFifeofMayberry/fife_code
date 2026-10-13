//
//  ServerGeneration.swift
//  OpenCodeClient
//
//  Generation detection per docs/v2_server_compatibility.md ("Detection"):
//  probe `GET /global/health` then `GET /api/info`, bind the result to the
//  host, and branch every request on it. V1 hosts keep the exact current
//  wire behavior.
//

import Foundation

/// Which wire protocol a host speaks. Stored on `HostProfile`; a missing
/// field decodes as `auto` (probe at connect time).
enum APIGeneration: String, Codable, Equatable {
    case auto
    case v1
    case v2
}

/// Outcome of the connect-time generation probe.
enum GenerationDetection: Equatable {
    case v1(version: String?)
    case v1Unhealthy(version: String?)
    case v2(version: String)
    case authFailure(healthStatus: Int, infoStatus: Int?)
    case transportFailure(code: Int, message: String)
    case unrecognized(healthStatus: Int?, infoStatus: Int?)

    /// The generation to run for this host, when the probe settled one.
    var generation: APIGeneration? {
        switch self {
        case .v1, .v1Unhealthy: return .v1
        case .v2: return .v2
        case .authFailure, .transportFailure, .unrecognized: return nil
        }
    }

    /// `version` string from the winning probe, when there was one.
    var version: String? {
        switch self {
        case .v1(let version), .v1Unhealthy(let version): return version
        case .v2(let version): return version
        case .authFailure, .transportFailure, .unrecognized: return nil
        }
    }
}

enum GenerationProbe {
    /// The probe reads the full body up to 8 KB, per the spec.
    static let maxBodyBytes = 8 * 1024

    struct Response: Equatable {
        let status: Int
        let body: Data
    }

    static func detect(
        baseURL: String,
        username: String?,
        password: String?,
        session: URLSession
    ) async -> GenerationDetection {
        let health = await get(path: "/global/health", baseURL: baseURL, username: username, password: password, session: session)
        switch health {
        case .failure(let error):
            return transportFailure(error)
        case .success(let healthResponse):
            switch classifyHealth(healthResponse) {
            case .decided(let detection):
                return detection
            case .keepProbing:
                let info = await get(path: "/api/info", baseURL: baseURL, username: username, password: password, session: session)
                switch info {
                case .failure(let error):
                    return transportFailure(error)
                case .success(let infoResponse):
                    return classifyInfo(infoResponse, healthStatus: healthResponse.status)
                }
            }
        }
    }

    enum ProbeStep {
        case decided(GenerationDetection)
        case keepProbing
    }

    static func classifyHealth(_ response: Response) -> ProbeStep {
        switch response.status {
        case 401, 403:
            // Authentication failures do not continue into the other probe.
            return .decided(.authFailure(healthStatus: response.status, infoStatus: nil))
        case 200:
            // V1 only when the body is JSON, `version` is a string, and
            // `healthy` is true. HTML 200 (packaged servers) or a shape we
            // cannot read keeps probing.
            guard let object = parseJSONObject(response.body), let healthy = object["healthy"] as? Bool else {
                return .keepProbing
            }
            let version = object["version"] as? String
            if healthy {
                guard version != nil else { return .keepProbing }
                return .decided(.v1(version: version))
            }
            // healthy: false is V1 and not connected.
            return .decided(.v1Unhealthy(version: version))
        default:
            // 404, empty 500, anything else: not V1, but keep probing.
            return .keepProbing
        }
    }

    static func classifyInfo(_ response: Response, healthStatus: Int) -> GenerationDetection {
        switch response.status {
        case 401, 403:
            return .authFailure(healthStatus: healthStatus, infoStatus: response.status)
        case 200:
            if let object = parseJSONObject(response.body), let version = object["version"] as? String {
                return .v2(version: version)
            }
            return .unrecognized(healthStatus: healthStatus, infoStatus: response.status)
        default:
            // `/api/health` is 404 on V2 and is never probed; anything this
            // probe cannot settle is unrecognized, reported with both statuses.
            return .unrecognized(healthStatus: healthStatus, infoStatus: response.status)
        }
    }

    static func parseJSONObject(_ body: Data) -> [String: Any]? {
        let capped = body.prefix(maxBodyBytes)
        guard !capped.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: Data(capped)) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func transportFailure(_ error: Error) -> GenerationDetection {
        let code = (error as? URLError)?.errorCode ?? URLError.badServerResponse.rawValue
        return .transportFailure(code: code, message: error.localizedDescription)
    }

    private static func get(
        path: String,
        baseURL: String,
        username: String?,
        password: String?,
        session: URLSession
    ) async -> Result<Response, Error> {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            return .failure(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let username, let password {
            let credential = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(URLError(.badServerResponse))
            }
            return .success(Response(status: http.statusCode, body: data))
        } catch {
            return .failure(error)
        }
    }
}
