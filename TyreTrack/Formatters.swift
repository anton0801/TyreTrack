//
//  Formatters.swift
//  TyreTrack
//
//  Shared date / number formatting helpers.
//

import Foundation

enum Fmt {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let dayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static func date(_ d: Date) -> String { shortDate.string(from: d) }
    static func dateTime(_ d: Date) -> String { dayTime.string(from: d) }

    static func mm(_ v: Double) -> String { String(format: "%.1f mm", v) }
    static func mmValue(_ v: Double) -> String { String(format: "%.1f", v) }

    static func number(_ v: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f", v)
    }

    static func money(_ v: Double, currency: String, decimals: Int = 2) -> String {
        currency + String(format: "%.\(decimals)f", v)
    }

    /// e.g. "in 12 days" / "3 days ago" / "today"
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let days = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
        if days == 0 { return "today" }
        if days > 0 { return "in \(days) day\(days == 1 ? "" : "s")" }
        let ago = -days
        return "\(ago) day\(ago == 1 ? "" : "s") ago"
    }
}
