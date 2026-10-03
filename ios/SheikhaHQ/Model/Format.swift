import Foundation

enum Fmt {
    private static let money: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = Locale(identifier: "en_US")
        return f
    }()
    static func amount(_ v: Double) -> String { money.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v) }
    static func aed(_ v: Double) -> String { "AED " + amount(v) }
    static func signed(_ v: Double) -> String { (v > 0 ? "+" : "") + amount(v) }
    static func compact(_ v: Double) -> String {
        let a = abs(v)
        if a >= 1_000_000 { return String(format: a >= 10_000_000 ? "%.0fM" : "%.1fM", v / 1_000_000) }
        if a >= 10_000 { return String(format: a >= 100_000 ? "%.0fK" : "%.1fK", v / 1_000) }
        return String(format: "%.0f", v)
    }
    static func qty(_ v: Double) -> String { v == v.rounded() ? String(format: "%.0f", v) : String(format: "%g", v) }

    private static let dt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "dd MMM yyyy, HH:mm"; return f }()
    private static let d: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "EEE, dd MMM yyyy"; return f }()
    private static let t: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "HH:mm"; return f }()
    static func dateTime(_ date: Date) -> String { dt.string(from: date) }
    static func day(_ date: Date) -> String { d.string(from: date) }
    static func time(_ date: Date) -> String { t.string(from: date) }
    static func ms(_ date: Date) -> Double { (date.timeIntervalSince1970 * 1000).rounded() }
}

extension Calendar {
    func endOfDay(_ date: Date) -> Date { self.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay(for: date)) ?? date }
}
