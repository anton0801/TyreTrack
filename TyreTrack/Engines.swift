//
//  Engines.swift
//  TyreTrack
//
//  Pure calculation engines — the unique core of the app.
//  No UI, no state: deterministic functions over primitives / models.
//

import SwiftUI

// MARK: - Status types

enum TreadStatus {
    case unknown, ok, warning, replace
    var label: String {
        switch self {
        case .unknown: return "No data"
        case .ok:      return "OK"
        case .warning: return "Getting low"
        case .replace: return "Replace"
        }
    }
    var tint: Color {
        switch self {
        case .unknown: return TT.textTertiary
        case .ok:      return TT.positive
        case .warning: return TT.caution
        case .replace: return TT.critical
        }
    }
}

enum PressureStatus {
    case unknown, ok, low, high
    var label: String {
        switch self {
        case .unknown: return "No data"
        case .ok:      return "In range"
        case .low:     return "Under-inflated"
        case .high:    return "Over-inflated"
        }
    }
    var tint: Color {
        switch self {
        case .unknown: return TT.textTertiary
        case .ok:      return TT.positive
        case .low:     return TT.critical
        case .high:    return TT.caution
        }
    }
}

// MARK: - Tread & wear engine

enum TreadEngine {
    /// Fraction of usable tread left (0…1) between legal min and a new tyre.
    static func remainingFraction(depth: Double, legalMin: Double, newDepth: Double) -> Double {
        let span = max(newDepth - legalMin, 0.1)
        return min(max((depth - legalMin) / span, 0), 1)
    }

    static func remainingPercent(depth: Double, legalMin: Double, newDepth: Double) -> Int {
        Int((remainingFraction(depth: depth, legalMin: legalMin, newDepth: newDepth) * 100).rounded())
    }

    /// Fraction of tread already worn away (0…1) — drives the eroding blocks.
    static func wornFraction(depth: Double, legalMin: Double, newDepth: Double) -> Double {
        1 - remainingFraction(depth: depth, legalMin: legalMin, newDepth: newDepth)
    }

    static func status(depth: Double, legalMin: Double) -> TreadStatus {
        if depth <= 0 { return .unknown }
        if depth <= legalMin { return .replace }
        let warnBand = max(3.0, legalMin + 1.0)
        if depth <= warnBand { return .warning }
        return .ok
    }
}

// MARK: - Pressure engine

enum PressureEngine {
    static func status(actualPSI: Double, recommendedPSI: Double, tolerance: Double) -> PressureStatus {
        if actualPSI <= 0 { return .unknown }
        let diff = actualPSI - recommendedPSI
        if diff < -tolerance { return .low }
        if diff >  tolerance { return .high }
        return .ok
    }

    static func deviationPSI(actualPSI: Double, recommendedPSI: Double) -> Double {
        actualPSI - recommendedPSI
    }

    /// Suggested load-corrected pressures (psi) for full car / towing.
    /// Rear axle typically wants the biggest bump under load.
    static func loadCorrected(basePSI: Double, fullCar: Bool, towing: Bool) -> (front: Double, rear: Double) {
        var front = basePSI
        var rear = basePSI
        if fullCar { front += 2; rear += 4 }
        if towing  { rear += 5 }
        return (front, rear)
    }
}

// MARK: - Rotation engine

enum RotationEngine {
    struct Move: Identifiable, Hashable {
        var from: TyrePosition
        var to: TyrePosition
        var id: String { from.rawValue + "-" + to.rawValue }
    }

    static func moves(for pattern: RotationPattern) -> [Move] {
        switch pattern {
        case .forwardCross:
            return [.init(from: .frontLeft, to: .rearLeft),
                    .init(from: .frontRight, to: .rearRight),
                    .init(from: .rearLeft, to: .frontRight),
                    .init(from: .rearRight, to: .frontLeft)]
        case .rearwardCross:
            return [.init(from: .rearLeft, to: .frontLeft),
                    .init(from: .rearRight, to: .frontRight),
                    .init(from: .frontLeft, to: .rearRight),
                    .init(from: .frontRight, to: .rearLeft)]
        case .xPattern:
            return [.init(from: .frontLeft, to: .rearRight),
                    .init(from: .frontRight, to: .rearLeft),
                    .init(from: .rearLeft, to: .frontRight),
                    .init(from: .rearRight, to: .frontLeft)]
        case .sideToSide:
            return [.init(from: .frontLeft, to: .rearLeft),
                    .init(from: .rearLeft, to: .frontLeft),
                    .init(from: .frontRight, to: .rearRight),
                    .init(from: .rearRight, to: .frontRight)]
        case .frontToBack:
            return [.init(from: .frontLeft, to: .rearLeft),
                    .init(from: .rearLeft, to: .frontLeft),
                    .init(from: .frontRight, to: .rearRight),
                    .init(from: .rearRight, to: .frontRight)]
        }
    }

    /// Fallback used only when the user has never set their own figure.
    static let defaultMilesPerMonth: Double = 800

    /// Projected next-rotation date. The interval is a distance, so turning
    /// it into a date needs the driver's own monthly mileage — it is passed
    /// in from Settings, never assumed silently.
    static func nextDate(lastRotated: Date,
                         intervalMiles: Double,
                         milesPerMonth: Double) -> Date {
        let perMonth = max(milesPerMonth, 50)
        let months = max(intervalMiles / perMonth, 0.5)
        return Calendar.current.date(byAdding: .day,
                                     value: Int(months * 30),
                                     to: lastRotated) ?? lastRotated
    }

    static func isDue(plan: RotationPlan, milesPerMonth: Double, now: Date = Date()) -> Bool {
        nextDate(lastRotated: plan.lastRotated,
                 intervalMiles: plan.intervalMiles,
                 milesPerMonth: milesPerMonth) <= now
    }

    /// The line shown next to every projected date so the estimate is
    /// never presented as a fact.
    static func estimateNote(milesPerMonth: Double, units: Units) -> String {
        let value = units.distanceValue(fromMiles: milesPerMonth)
        return "Estimated at \(Fmt.number(value, decimals: 0)) \(units.distanceUnit)/month"
    }
}

// MARK: - Season engine

enum SeasonEngine {
    /// Suggested next swap date. Summer→(mid-Oct), Winter→(mid-Apr). All-season → none.
    static func nextSwapDate(current: TyreSeason, after date: Date) -> Date? {
        guard current != .allSeason else { return nil }
        let cal = Calendar.current
        let targetMonth = (current == .summer) ? 10 : 4   // swap OUT of current
        let day = 15
        var comps = cal.dateComponents([.year], from: date)
        comps.month = targetMonth
        comps.day = day
        guard var candidate = cal.date(from: comps) else { return nil }
        if candidate <= date {
            candidate = cal.date(byAdding: .year, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func swapAdvice(current: TyreSeason) -> String {
        switch current {
        case .summer:    return "Fit winter tyres before temperatures drop below 7°C."
        case .winter:    return "Fit summer tyres once frosts have passed."
        case .allSeason: return "All-season set fitted — no seasonal swap needed."
        }
    }
}

// MARK: - Wear pattern engine

enum WearPatternEngine {
    static func cause(_ pattern: WearPattern) -> String {
        switch pattern {
        case .even:       return "Normal, even wear"
        case .centre:     return "Over-inflation (too much pressure)"
        case .bothEdges:  return "Under-inflation (too little pressure)"
        case .oneEdge:    return "Wheel alignment / camber off"
        case .feathering: return "Incorrect toe or worn steering"
        case .cupping:    return "Worn shocks / bushings or imbalance"
        case .flatSpot:   return "Hard braking or wheel imbalance"
        }
    }

    static func action(_ pattern: WearPattern) -> String {
        switch pattern {
        case .even:       return "Keep monitoring — you're good."
        case .centre:     return "Drop pressure to the recommended value."
        case .bothEdges:  return "Inflate to recommended; check for slow leaks."
        case .oneEdge:    return "Book a wheel alignment check."
        case .feathering: return "Alignment (toe) + inspect steering/suspension."
        case .cupping:    return "Inspect shocks/suspension and re-balance."
        case .flatSpot:   return "Re-balance wheels; review braking habits."
        }
    }

    static func severity(_ pattern: WearPattern) -> Color {
        switch pattern {
        case .even:                       return TT.positive
        case .centre, .bothEdges:         return TT.caution
        case .oneEdge, .feathering,
             .cupping, .flatSpot:         return TT.critical
        }
    }
}

// MARK: - Tyre age engine

enum TyreAgeEngine {
    /// Parse a DOT date code. Uses the final 4 digits = WWYY (week + 2-digit year).
    static func manufactureDate(dotCode: String) -> Date? {
        let digits = dotCode.filter { $0.isNumber }
        guard digits.count >= 4 else { return nil }
        let tail = String(digits.suffix(4))
        guard let week = Int(tail.prefix(2)),
              let yy = Int(tail.suffix(2)),
              week >= 1, week <= 53 else { return nil }
        let year = 2000 + yy
        var comps = DateComponents()
        comps.weekOfYear = week
        comps.yearForWeekOfYear = year
        comps.weekday = 2 // Monday
        return Calendar.current.date(from: comps)
    }

    static func ageYears(dotCode: String, now: Date = Date()) -> Double? {
        guard let made = manufactureDate(dotCode: dotCode) else { return nil }
        let days = now.timeIntervalSince(made) / 86400.0
        return max(days / 365.25, 0)
    }

    static func status(ageYears: Double?, limit: Int) -> (label: String, tint: Color) {
        guard let a = ageYears else { return ("Unknown", TT.textTertiary) }
        if a >= 10 { return ("Replace (over 10 yrs)", TT.critical) }
        if a >= Double(limit) { return ("Inspect closely", TT.caution) }
        return ("Within service age", TT.positive)
    }
}

// MARK: - Legal limit engine

enum LegalEngine {
    static func margin(tread: Double, legalMin: Double) -> Double { tread - legalMin }
    static func mustReplace(tread: Double, legalMin: Double) -> Bool { tread <= legalMin }
    static func verdict(tread: Double, legalMin: Double) -> (label: String, tint: Color) {
        let m = margin(tread: tread, legalMin: legalMin)
        if m <= 0 { return ("Below legal minimum — replace", TT.critical) }
        if m <= 0.5 { return ("At the limit — replace soon", TT.caution) }
        return ("Legal — \(String(format: "%.1f", m)) mm margin", TT.positive)
    }
}

// MARK: - Cost & life engine

enum CostEngine {
    static func totalSetCost(costPerTyre: Double, count: Int = 4) -> Double {
        costPerTyre * Double(count)
    }
    /// Cost per mile of the whole set over its mileage life.
    static func costPerMile(costPerTyre: Double, count: Int = 4, mileageLife: Double) -> Double {
        guard mileageLife > 0 else { return 0 }
        return totalSetCost(costPerTyre: costPerTyre, count: count) / mileageLife
    }
}
