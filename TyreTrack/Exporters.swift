//
//  Exporters.swift
//  TyreTrack
//
//  Local PDF + CSV export and a UIActivityViewController share sheet.
//

import SwiftUI
import UIKit

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Report section selection

struct ReportSections: Equatable {
    var tread = true
    var pressure = true
    var rotation = true
    var season = true
    var costLife = true
    var wear = true
}

// MARK: - Report generator

enum ReportBuilder {

    // Plain-text summary shown on-screen before export.
    static func summaryText(for v: Vehicle, sections: ReportSections,
                            units: Units, currency: String,
                            milesPerMonth: Double) -> String {
        var lines: [String] = []
        lines.append("TYRE TRACK REPORT")
        lines.append(v.displayTitle + "  •  " + v.tyreSize)
        lines.append("Generated \(Fmt.date(Date()))")
        lines.append("")

        if sections.tread, let r = v.latestTread {
            lines.append("TREAD DEPTH (min legal \(Fmt.mm(v.legalMinTread)))")
            for d in r.depths {
                let st = TreadEngine.status(depth: d.value, legalMin: v.legalMinTread)
                lines.append("  \(d.position.short): \(Fmt.mm(d.value))  [\(st.label)]")
            }
            lines.append("")
        }
        if sections.pressure, let p = v.latestPressure {
            lines.append("PRESSURE (recommended \(Fmt.number(units.pressureValue(fromPSI: v.recommendedPressure), decimals: 1)) \(units.pressureUnit))")
            for wv in p.pressures {
                let disp = units.pressureValue(fromPSI: wv.value)
                lines.append("  \(wv.position.short): \(Fmt.number(disp, decimals: 1)) \(units.pressureUnit)")
            }
            lines.append("")
        }
        if sections.rotation, let rot = v.rotation {
            let next = RotationEngine.nextDate(lastRotated: rot.lastRotated,
                                               intervalMiles: rot.intervalMiles,
                                               milesPerMonth: milesPerMonth)
            lines.append("ROTATION")
            lines.append("  Pattern: \(rot.pattern.label)")
            lines.append("  Interval: \(Fmt.number(rot.intervalMiles, decimals: 0)) mi")
            lines.append("  Last: \(Fmt.date(rot.lastRotated))  Next: \(Fmt.date(next))")
            lines.append("  \(RotationEngine.estimateNote(milesPerMonth: milesPerMonth, units: units))")
            lines.append("")
        }
        if sections.season, let sw = v.swap {
            lines.append("SEASON")
            lines.append("  Current: \(sw.currentSeason.label)  Storage: \(sw.storageLocation)")
            lines.append("")
        }
        if sections.wear, !v.diagnoses.isEmpty {
            lines.append("WEAR DIAGNOSES")
            for d in v.diagnoses {
                lines.append("  \(d.position.short) \(d.pattern.label): \(WearPatternEngine.cause(d.pattern))")
            }
            lines.append("")
        }
        if sections.costLife, let c = v.costLife {
            let cpm = CostEngine.costPerMile(costPerTyre: c.costPerTyre, mileageLife: c.mileageLife)
            lines.append("COST & LIFE")
            lines.append("  Set: \(Fmt.money(CostEngine.totalSetCost(costPerTyre: c.costPerTyre), currency: currency))")
            lines.append("  Per mile: \(Fmt.money(cpm, currency: currency, decimals: 4))")
            lines.append("")
        }

        lines.append("Disclaimer: observe the legal tread minimum. Replace")
        lines.append("damaged or worn tyres. This is a tracking aid only.")
        return lines.joined(separator: "\n")
    }

    // CSV of tread + pressure history.
    static func csv(for v: Vehicle, units: Units) -> String {
        var rows = ["section,date,position,value,unit"]
        for r in v.treadReadings {
            for d in r.depths {
                rows.append("tread,\(Fmt.date(r.date)),\(d.position.short),\(Fmt.number(d.value, decimals: 1)),mm")
            }
        }
        for p in v.pressureReadings {
            for wv in p.pressures {
                let disp = units.pressureValue(fromPSI: wv.value)
                rows.append("pressure,\(Fmt.date(p.date)),\(wv.position.short),\(Fmt.number(disp, decimals: 1)),\(units.pressureUnit)")
            }
        }
        return rows.joined(separator: "\n")
    }

    // Renders a simple, clean A4 PDF and returns the file URL.
    static func pdf(for v: Vehicle, sections: ReportSections,
                    units: Units, currency: String,
                    milesPerMonth: Double) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TyreTrack-\(v.displayTitle).pdf")

        let text = summaryText(for: v, sections: sections, units: units,
                               currency: currency, milesPerMonth: milesPerMonth)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let cg = ctx.cgContext

                // Header band — graphite bench with the amber rule
                cg.setFillColor(UIColor(hex: 0x16181C).cgColor)
                cg.fill(CGRect(x: 0, y: 0, width: pageRect.width, height: 84))
                cg.setFillColor(UIColor(hex: 0xE9A231).cgColor)
                cg.fill(CGRect(x: 40, y: 36, width: 3, height: 18))

                // The tick rule, carried onto the printed page
                cg.setStrokeColor(UIColor(hex: 0x353B45).cgColor)
                cg.setLineWidth(1)
                var tick: CGFloat = 40
                while tick < pageRect.width - 40 {
                    cg.move(to: CGPoint(x: tick, y: 84))
                    cg.addLine(to: CGPoint(x: tick, y: 84 - (tick.truncatingRemainder(dividingBy: 30) < 6 ? 8 : 4)))
                    tick += 6
                }
                cg.strokePath()

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .black,
                                             width: .compressed),
                    .foregroundColor: UIColor(hex: 0xF3EFE6),
                    .kern: 1.0
                ]
                ("TYRETRACK" as NSString).draw(at: CGPoint(x: 54, y: 30), withAttributes: titleAttrs)

                let subAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor(hex: 0x9AB2CD)
                ]
                (v.displayTitle + "  ·  " + v.tyreSize as NSString)
                    .draw(at: CGPoint(x: 54, y: 58), withAttributes: subAttrs)

                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor(hex: 0x23272E)
                ]
                let body = NSString(string: text)
                body.draw(in: CGRect(x: 40, y: 104, width: pageRect.width - 80, height: pageRect.height - 140),
                          withAttributes: bodyAttrs)
            }
            return url
        } catch {
            return nil
        }
    }
}
