//
//  SupabaseConfig.swift
//  ku-onboarding
//
//  Created by Hardik Sharma on 21/08/26.
//
//  Reads Supabase credentials injected at build time from
//  Config/Secrets.xcconfig → Info.plist. The file is gitignored;
//  copy Secrets.xcconfig.example to create it.
//

import Foundation

struct SupabaseConfig: Sendable {
    let url: URL
    let anonKey: String

    static func load(from bundle: Bundle = .main) -> SupabaseConfig? {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String,
            let url = URL(string: rawURL),
            url.scheme == "https",
            let host = url.host(), host.contains("."),
            !host.hasPrefix("YOUR-PROJECT-REF"),
            let anonKey = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String,
            !anonKey.isEmpty,
            anonKey != "YOUR-ANON-KEY"
        else { return nil }
        return SupabaseConfig(url: url, anonKey: anonKey)
    }
}
