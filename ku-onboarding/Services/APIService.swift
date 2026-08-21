//
//  APIService.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  Talks to the `enroll` Supabase Edge Function (docs/SUPABASE.md §5).
//  The anon key ships in the app; all privileged work happens server-side.
//

import Foundation
import Supabase

enum EnrollmentError: LocalizedError, Equatable {
    /// Secrets.xcconfig missing or still holding placeholder values.
    case notConfigured
    /// Server rejected the Banner ID or payload shape (HTTP 400).
    case invalidPayload
    /// An active enrollment already exists for this Banner ID (HTTP 409).
    case duplicate
    case server(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Supabase is not configured. Fill in Config/Secrets.xcconfig."
        case .invalidPayload:
            "The enrollment data was rejected. Check the Banner ID and try again."
        case .duplicate:
            "This Banner ID is already enrolled."
        case .server(let message):
            "Server error: \(message)"
        case .network(let message):
            "Upload failed: \(message)"
        }
    }
}

protocol EnrollingService: Sendable {
    func enroll(_ payload: EnrollmentPayload) async throws -> EnrollmentResponse
}

final class APIService: EnrollingService {

    private let client: SupabaseClient?

    init(config: SupabaseConfig? = SupabaseConfig.load()) {
        client = config.map {
            SupabaseClient(
                supabaseURL: $0.url,
                supabaseKey: $0.anonKey,
                options: SupabaseClientOptions(
                    // This app uses no auth; opt in to silence the
                    // initial-session emission deprecation notice.
                    auth: .init(
                        storage: AuthClient.Configuration.defaultLocalStorage,
                        emitLocalSessionAsInitialSession: true
                    )
                )
            )
        }
    }

    func enroll(_ payload: EnrollmentPayload) async throws -> EnrollmentResponse {
        guard let client else { throw EnrollmentError.notConfigured }

        do {
            let response: EnrollmentResponse = try await client.functions.invoke(
                "enroll",
                options: FunctionInvokeOptions(body: payload)
            )
            return response
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                switch code {
                case 400: throw EnrollmentError.invalidPayload
                case 409: throw EnrollmentError.duplicate
                default: throw EnrollmentError.server(Self.message(from: data, fallback: "HTTP \(code)"))
                }
            case .relayError:
                throw EnrollmentError.network("Edge relay error — try again.")
            }
        } catch let error as EnrollmentError {
            throw error
        } catch {
            throw EnrollmentError.network(error.localizedDescription)
        }
    }

    /// Edge Function error bodies look like `{"error": "already_enrolled"}`.
    private static func message(from data: Data, fallback: String) -> String {
        struct Body: Decodable { let error: String? }
        if let body = try? JSONDecoder().decode(Body.self, from: data), let error = body.error {
            return error
        }
        return fallback
    }
}
