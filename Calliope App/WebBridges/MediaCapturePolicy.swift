//
//  MediaCapturePolicy.swift
//  Calliope App
//
//  Copyright © 2026 calliope. All rights reserved.
//

import WebKit

enum MediaCapturePolicy {
    static let trustedHosts: Set<String> = [
        "campus.calliope.cc",
        "teachablemachine.calliope.cc",
        "go.calliope.cc",
    ]

    static func decision(for origin: WKSecurityOrigin) -> WKPermissionDecision {
        decision(scheme: origin.protocol, host: origin.host)
    }

    static func decision(scheme: String, host: String) -> WKPermissionDecision {
        LogNotify.debug("Asked for media permission for scheme \(scheme) and host \(host)")
        guard scheme == "https" else { return .deny }
        return trustedHosts.contains(host.lowercased()) ? .grant : .prompt
    }
}
