import Foundation
import SwiftUI

/// Errors shown to the user. Each case maps to a distinct UI state.
nonisolated enum APIError: Error, Equatable, Sendable {
    case offline
    case rateLimited
    /// Raider.IO answered 400 "Could not find requested character".
    case notFound
    case server(status: Int, message: String?)
    case decoding(String)
    case transport(String)

    /// Localized via `Localizable.xcstrings`; resolved with the locale chosen in Settings.
    var title: LocalizedStringKey {
        switch self {
        case .offline: "No internet connection"
        case .rateLimited: "Too many requests"
        case .notFound: "Not found"
        case .server: "Server error"
        case .decoding: "Unexpected data"
        case .transport: "Network error"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .offline:
            "Check your connection and try again."
        case .rateLimited:
            "Raider.IO is rate limiting requests. Wait a few seconds, then retry."
        case .notFound:
            "Raider.IO could not find this character."
        case .server(let status, let message?):
            "Raider.IO returned HTTP \(status): \(message)"
        case .server(let status, nil):
            "Raider.IO returned HTTP \(status)."
        case .decoding(let details):
            "The response could not be read. \(details)"
        case .transport(let details):
            "\(details)"
        }
    }

    var systemImage: String {
        switch self {
        case .offline: "wifi.slash"
        case .rateLimited: "hourglass"
        case .notFound: "person.fill.questionmark"
        case .server, .transport: "exclamationmark.icloud"
        case .decoding: "doc.questionmark"
        }
    }

    /// Errors that affect every request, so a multi-request load should stop instead of skipping one player.
    /// `.transport` (e.g. a timeout) usually hits a single request, so that player is skipped instead.
    var abortsBatch: Bool {
        switch self {
        case .offline, .rateLimited: true
        case .transport, .notFound, .server, .decoding: false
        }
    }
}

/// Body of Raider.IO error responses, e.g. `{"statusCode":400,"error":"Bad Request","message":"…"}`.
nonisolated struct RaiderIOErrorBody: Decodable, Sendable {
    let statusCode: Int?
    let error: String?
    let message: String?
}
