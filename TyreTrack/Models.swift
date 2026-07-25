//
//  Models.swift
//  TyreTrack
//
//  All data structures. Fully Codable for local JSON persistence.
//

import SwiftUI

// MARK: - Enums

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case car, van4x4, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .car:    return "Car"
        case .van4x4: return "Van / 4x4"
        case .other:  return "Other"
        }
    }
    var icon: String {
        switch self {
        case .car:    return "car.fill"
        case .van4x4: return "bus.fill"
        case .other:  return "cube.box.fill"
        }
    }
    /// Relative tyre-profile aspect used by the onboarding morph.
    var profileAspect: CGFloat {
        switch self {
        case .car:    return 0.58
        case .van4x4: return 0.78
        case .other:  return 0.68
        }
    }
}

enum TyreSeason: String, Codable, CaseIterable, Identifiable {
    case summer, winter, allSeason
    var id: String { rawValue }
    var label: String {
        switch self {
        case .summer:    return "Summer"
        case .winter:    return "Winter"
        case .allSeason: return "All-season"
        }
    }
    var icon: String {
        switch self {
        case .summer:    return "sun.max.fill"
        case .winter:    return "snowflake"
        case .allSeason: return "cloud.sun.fill"
        }
    }
    var tint: Color {
        switch self {
        case .summer:    return TT.accent
        case .winter:    return TT.steelLight
        case .allSeason: return TT.positive
        }
    }
}

enum TyrePosition: String, Codable, CaseIterable, Identifiable {
    case frontLeft, frontRight, rearLeft, rearRight, spare
    var id: String { rawValue }
    var short: String {
        switch self {
        case .frontLeft:  return "FL"
        case .frontRight: return "FR"
        case .rearLeft:   return "RL"
        case .rearRight:  return "RR"
        case .spare:      return "SP"
        }
    }
    var label: String {
        switch self {
        case .frontLeft:  return "Front Left"
        case .frontRight: return "Front Right"
        case .rearLeft:   return "Rear Left"
        case .rearRight:  return "Rear Right"
        case .spare:      return "Spare"
        }
    }
    static var roadWheels: [TyrePosition] { [.frontLeft, .frontRight, .rearLeft, .rearRight] }
}

enum Units: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var label: String { self == .metric ? "Metric (bar, km)" : "Imperial (psi, mi)" }
    /// Short form for rails and chips.
    var short: String { self == .metric ? "Metric" : "Imperial" }
    var pressureUnit: String { self == .metric ? "bar" : "psi" }
    var distanceUnit: String { self == .metric ? "km" : "mi" }
    /// Convert a canonical psi value into the display unit.
    func pressureValue(fromPSI psi: Double) -> Double {
        self == .metric ? psi * 0.0689476 : psi
    }
    func psi(fromDisplay value: Double) -> Double {
        self == .metric ? value / 0.0689476 : value
    }
    func distanceValue(fromMiles miles: Double) -> Double {
        self == .metric ? miles * 1.60934 : miles
    }
    func miles(fromDisplay value: Double) -> Double {
        self == .metric ? value / 1.60934 : value
    }
}

enum RotationPattern: String, Codable, CaseIterable, Identifiable {
    case forwardCross, rearwardCross, xPattern, sideToSide, frontToBack
    var id: String { rawValue }
    var label: String {
        switch self {
        case .forwardCross:  return "Forward Cross"
        case .rearwardCross: return "Rearward Cross"
        case .xPattern:      return "X-Pattern"
        case .sideToSide:    return "Side to Side"
        case .frontToBack:   return "Front to Back"
        }
    }
    var hint: String {
        switch self {
        case .forwardCross:  return "FWD cars: fronts straight back, rears cross to front."
        case .rearwardCross: return "RWD/4x4: rears straight forward, fronts cross to back."
        case .xPattern:      return "All wheels cross diagonally. Non-directional tyres."
        case .sideToSide:    return "Directional tyres: swap same-side front/rear only."
        case .frontToBack:   return "Staggered/directional: front↔rear, keep the side."
        }
    }
}

enum WearPattern: String, Codable, CaseIterable, Identifiable {
    case even, centre, bothEdges, oneEdge, feathering, cupping, flatSpot
    var id: String { rawValue }
    var label: String {
        switch self {
        case .even:       return "Even"
        case .centre:     return "Centre wear"
        case .bothEdges:  return "Both edges"
        case .oneEdge:    return "One edge"
        case .feathering: return "Feathering"
        case .cupping:    return "Cupping / patches"
        case .flatSpot:   return "Flat spot"
        }
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, normal, high
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var tint: Color {
        switch self {
        case .low:    return TT.steelBlue
        case .normal: return TT.accent
        case .high:   return TT.critical
        }
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case pressure, rotation, seasonalSwap, tread
    var id: String { rawValue }
    var label: String {
        switch self {
        case .pressure:     return "Check pressure"
        case .rotation:     return "Rotate tyres"
        case .seasonalSwap: return "Seasonal swap"
        case .tread:        return "Measure tread"
        }
    }
    var icon: String {
        switch self {
        case .pressure:     return "speedometer"
        case .rotation:     return "arrow.triangle.2.circlepath"
        case .seasonalSwap: return "arrow.left.arrow.right"
        case .tread:        return "ruler"
        }
    }
    var body: String {
        switch self {
        case .pressure:     return "Time to check your cold tyre pressures."
        case .rotation:     return "Rotate your tyres for even wear."
        case .seasonalSwap: return "Swap to your other seasonal tyre set."
        case .tread:        return "Measure tread depth against the legal minimum."
        }
    }
}

// MARK: - Value helpers

/// One wheel's value (depth in mm or pressure in psi) — used instead of a
/// dictionary keyed by enum to keep Codable simple and stable.
struct WheelValue: Codable, Hashable, Identifiable {
    var position: TyrePosition
    var value: Double
    var id: String { position.rawValue }

    static func full(_ v: Double) -> [WheelValue] {
        TyrePosition.roadWheels.map { WheelValue(position: $0, value: v) }
    }
}

// MARK: - Logs

struct TreadReading: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var depths: [WheelValue]

    var minDepth: Double { depths.map { $0.value }.min() ?? 0 }
    var avgDepth: Double {
        guard !depths.isEmpty else { return 0 }
        return depths.map { $0.value }.reduce(0, +) / Double(depths.count)
    }
}

struct PressureReading: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var pressures: [WheelValue]      // stored canonically in psi
    var coldCheck: Bool = true
}

struct RotationPlan: Codable, Hashable {
    var pattern: RotationPattern = .forwardCross
    var intervalMiles: Double = 6000
    var lastRotated: Date = Date()
}

struct SetHistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var season: TyreSeason
    var note: String = ""
}

struct SeasonalSwap: Codable, Hashable {
    var currentSeason: TyreSeason = .summer
    var lastSwapDate: Date = Date()
    var storageLocation: String = ""
    var history: [SetHistoryEntry] = []
}

struct WearDiagnosis: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var position: TyrePosition = .frontLeft
    var pattern: WearPattern = .even
    var notes: String = ""
}

struct TyreAgeInfo: Codable, Hashable {
    var dotCode: String = ""
    var ageLimitYears: Int = 6
    var cracking: Bool = false
}

struct LoadPressure: Codable, Hashable {
    var loadPressureFront: Double = 0    // psi
    var loadPressureRear: Double = 0     // psi
    var towing: Bool = false
    var fullCar: Bool = false
    var notes: String = ""
}

struct CostLife: Codable, Hashable {
    var costPerTyre: Double = 0
    var mileageLife: Double = 40000      // miles
    var currency: String = "£"
}

struct AlignmentNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var alignmentDone: Bool = false
    var balanceDone: Bool = false
    var symptoms: String = ""
    var action: String = ""
}

struct SignoffRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date = Date()
    var reviewer: String = ""
    var result: String = "Pass"
    var comment: String = ""
    var signature: Data? = nil          // PNG of the finger signature
}

struct TyreReminder: Identifiable, Codable, Hashable {
    var id = UUID()
    var type: ReminderType = .pressure
    var date = Date()
    var vehicleID: UUID? = nil
    var repeats: Bool = false
    var enabled: Bool = true
}

// MARK: - Vehicle (the passport)

struct Vehicle: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = ""
    var type: VehicleType = .car
    var tyreSize: String = ""
    var season: TyreSeason = .summer
    var loadIndex: String = ""
    var units: Units = .imperial
    var legalMinTread: Double = 1.6      // mm
    var newTread: Double = 8.0           // mm reference for a new tyre
    var recommendedPressure: Double = 32 // psi
    var tolerance: Double = 2            // psi tolerance band
    /// File name inside Documents/VehiclePhotos — never the image itself.
    var photoFile: String? = nil
    var notes: String = ""
    var priority: Priority = .normal
    var createdAt = Date()

    // Nested logs
    var treadReadings: [TreadReading] = []
    var pressureReadings: [PressureReading] = []
    var rotation: RotationPlan? = nil
    var swap: SeasonalSwap? = nil
    var diagnoses: [WearDiagnosis] = []
    var age: TyreAgeInfo? = nil
    var loadPressure: LoadPressure? = nil
    var costLife: CostLife? = nil
    var alignmentNotes: [AlignmentNote] = []
    var signoffs: [SignoffRecord] = []

    // MARK: Derived

    var latestTread: TreadReading? {
        treadReadings.sorted { $0.date > $1.date }.first
    }
    var latestPressure: PressureReading? {
        pressureReadings.sorted { $0.date > $1.date }.first
    }

    /// Worst tread status across the latest reading.
    var overallTreadStatus: TreadStatus {
        guard let r = latestTread else { return .unknown }
        return TreadEngine.status(depth: r.minDepth, legalMin: legalMinTread)
    }

    var minTreadNow: Double { latestTread?.minDepth ?? newTread }

    var displayTitle: String { title.isEmpty ? "Untitled Vehicle" : title }
}
