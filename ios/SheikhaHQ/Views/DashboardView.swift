import SwiftUI
import Charts

enum Period: String, CaseIterable, Identifiable {
    case today = "Today", yesterday = "Yesterday", month = "This month", lastMonth = "Last month"
    var id: String { rawValue }

    struct Info {
        var from: Date, to: Date, cmpFrom: Date, cmpTo: Date
        var cut: Date?            // compare "today" with yesterday only up to this time
        var cmpLabel: String
        var hourly: Bool
        var days: Int
    }

    var info: Info {
        let cal = Calendar.current, now = Date(), today = cal.startOfDay(for: now)
        let day: (Int) -> Date = { cal.date(byAdding: .day, value: $0, to: today)! }
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let month: (Int) -> Date = { cal.date(byAdding: .month, value: $0, to: monthStart)! }
        let daysIn: (Date) -> Int = { cal.range(of: .day, in: .month, for: $0)!.count }
        switch self {
        case .today:
            return Info(from: today, to: today, cmpFrom: day(-1), cmpTo: day(-1), cut: cal.date(byAdding: .day, value: -1, to: now), cmpLabel: "yesterday by this time", hourly: true, days: 1)
        case .yesterday:
            return Info(from: day(-1), to: day(-1), cmpFrom: day(-2), cmpTo: day(-2), cut: nil, cmpLabel: "the day before", hourly: true, days: 1)
        case .month:
            let lastStart = month(-1)
            let sameDay = min(cal.component(.day, from: today), daysIn(lastStart))
            return Info(from: monthStart, to: today, cmpFrom: lastStart, cmpTo: cal.date(byAdding: .day, value: sameDay - 1, to: lastStart)!, cut: nil, cmpLabel: "same days last month", hourly: false, days: daysIn(monthStart))
        case .lastMonth:
            let a = month(-1), b = month(-2)
            return Info(from: a, to: cal.date(byAdding: .day, value: -1, to: monthStart)!, cmpFrom: b, cmpTo: cal.date(byAdding: .day, value: -1, to: a)!, cut: nil, cmpLabel: "the month before", hourly: false, days: daysIn(a))
        }
    }
}

struct DashboardView: View {
    @Environment(HQStore.self) private var store
    @AppStorage("dashPeriod") private var periodRaw = Period.today.rawValue
    @State private var loaded: [Sale] = []
    @State private var compare: [Sale] = []
    @State private var held: [HeldBill] = []
    @State private var shifts: [Shift] = []
    @State private var open: [Shift] = []
    @State private var loading = false
    @State private var error: String?

    private var period: Period { Period(rawValue: periodRaw) ?? .today }
    private var current: [Sale] { period == .today ? store.todaySales : loaded }

    var body: some View {
        let info = period.info
        let a = Totals(current), b = Totals(compare)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $periodRaw) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)

                if let error { ErrorRow(message: error) }

                // headline
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOTAL SALES · \(period.rawValue.uppercased())").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("AED").font(.title3.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
                        Text(Fmt.amount(a.total)).font(.system(size: 44, weight: .bold)).minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(.white)
                    }
                    HStack {
                        DeltaPill(current: a.total, previous: b.total, label: info.cmpLabel, onColor: true)
                        if loading { ProgressView().controlSize(.small).tint(.white) }
                    }
                    Text("\(info.cmpLabel.prefix(1).uppercased() + info.cmpLabel.dropFirst()): \(Fmt.aed(b.total))").font(.caption).foregroundStyle(.white.opacity(0.85))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(alignment: .bottomTrailing) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 90, weight: .bold))
                        .foregroundStyle(.white.opacity(0.12)).offset(x: 10, y: 14)
                }
                .background(Brand.sunset, in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: Brand.orange.opacity(0.3), radius: 10, y: 4)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Bills", value: "\(a.bills)", delta: DeltaPill(current: Double(a.bills), previous: Double(b.bills)), icon: "doc.text.fill", tint: Brand.blue)
                    StatTile(title: "Average bill", value: Fmt.amount(a.average), delta: DeltaPill(current: a.average, previous: b.average), icon: "divide", tint: Brand.purple)
                    StatTile(title: "VAT collected", value: Fmt.amount(a.vat), footnote: "Excl. VAT " + Fmt.amount(a.net), icon: "building.columns.fill", tint: Brand.teal)
                    StatTile(title: "Cash · Card", value: a.total > 0 ? "\(Int((a.cash / a.total * 100).rounded()))% · \(Int((a.card / a.total * 100).rounded()))%" : "–", footnote: Fmt.amount(a.cash) + " · " + Fmt.amount(a.card), icon: "creditcard.fill", tint: Brand.good)
                    StatTile(title: "Discounts", value: Fmt.amount(a.disc), delta: DeltaPill(current: a.disc, previous: b.disc, upIsGood: false), icon: "tag.fill", tint: Brand.pink)
                    StatTile(title: "Voided bills", value: "\(a.voidN)", footnote: Fmt.aed(a.voidTotal), icon: "xmark", tint: Brand.bad)
                }

                card("Branches", "Highest first, change vs \(info.cmpLabel).", icon: "building.2.fill", tint: Brand.blue) { branchRanking }
                card(info.hourly ? "Sales by hour" : "Sales by day", "All branches, AED incl. VAT.", icon: "chart.bar.fill", tint: Brand.orange) { TrendChart(current: current, compare: compare, info: info, period: period) }
                card("Top fabrics", "Best sellers by sales value.", icon: "star.fill", tint: Brand.purple) { topFabrics(a.total) }
                card("Needs attention", "Things worth a phone call.", icon: "bell.fill", tint: Brand.amber) { attention(a) }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: summaryText(a, b), subject: Text("\(store.settings.name) – \(period.rawValue)")) { Image(systemName: "square.and.arrow.up") }
            }
        }
        .refreshable { await load() }
        .task(id: periodRaw) { await load() }
        .task(id: store.branches.map(\.id)) { await load() }
    }

    // MARK: sections

    private func card<C: View>(_ title: String, _ caption: String, icon: String, tint: Color, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label { Text(title).font(.headline) } icon: { Image(systemName: icon).foregroundStyle(tint) }
            Text(caption).font(.caption).foregroundStyle(.secondary)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private struct Row: Identifiable { var id: String; var branch: Branch; var cur: Totals; var prev: Totals }

    private var rows: [Row] {
        store.branches.map { br in
            Row(id: br.id, branch: br, cur: Totals(current.filter { $0.branch == br.id }), prev: Totals(compare.filter { $0.branch == br.id }))
        }.sorted { $0.cur.total > $1.cur.total }
    }

    @ViewBuilder private var branchRanking: some View {
        let list = rows, top = max(1, list.map(\.cur.total).max() ?? 1)
        if list.isEmpty { Text("No branches yet.").foregroundStyle(.secondary) }
        ForEach(list) { r in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(r.branch.code).font(.caption2.monospaced().bold()).padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4)).foregroundStyle(Brand.orange)
                    Text(r.branch.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Spacer()
                    DeltaPill(current: r.cur.total, previous: r.prev.total)
                }
                HStack(spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.12))
                            Capsule()
                                .fill(Brand.orange)
                                .frame(width: max(6, g.size.width * r.cur.total / top))
                        }
                    }
                    .frame(height: 12)
                    Text(Fmt.amount(r.cur.total)).font(.caption.monospaced().bold()).frame(width: 96, alignment: .trailing)
                }
                Text("\(r.cur.bills) bills · avg \(Fmt.amount(r.cur.average))").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private func topFabrics(_ total: Double) -> some View {
        let list = Array(fabricsSold(current).prefix(6))
        if list.isEmpty { Text("No sales in this period yet.").foregroundStyle(.secondary) }
        ForEach(list) { f in
            HStack {
                Text(f.name).font(.subheadline)
                Spacer()
                Text("\(Fmt.qty(f.qty)) \(f.unit)").font(.caption.monospaced()).foregroundStyle(.secondary)
                Text(Fmt.amount(f.total)).font(.caption.monospaced().bold()).frame(width: 90, alignment: .trailing)
                Text(total > 0 ? "\(Int((f.total / total * 100).rounded()))%" : "–").font(.caption2).foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
            }
        }
    }

    private struct AttentionItem: Identifiable { var id = UUID(); var icon: String; var color: Color; var title: String; var detail: String }

    private func alerts(_ a: Totals) -> [AttentionItem] {
        var out: [AttentionItem] = []
        let old = held.filter { Date().timeIntervalSince1970 * 1000 - $0.ts > 2 * 3600 * 1000 }
        if !old.isEmpty {
            out.append(AttentionItem(icon: "pause.circle.fill", color: Brand.warn, title: "\(old.count) held bill\(old.count == 1 ? "" : "s") waiting more than 2 hours",
                             detail: Dictionary(grouping: old, by: \.branch).map { "\(store.branchName($0.key)): \($0.value.count)" }.joined(separator: " · ")))
        }
        if period == .today && Calendar.current.component(.hour, from: Date()) >= 12 {
            let idle = store.branches.filter { br in !current.contains { $0.branch == br.id } }
            if !idle.isEmpty { out.append(AttentionItem(icon: "moon.zzz.fill", color: Brand.warn, title: "\(idle.count) branch\(idle.count == 1 ? "" : "es") with no sales yet today", detail: idle.map(\.name).joined(separator: " · "))) }
        }
        let voids = current.filter(\.isVoid)
        if !voids.isEmpty { out.append(AttentionItem(icon: "xmark.circle.fill", color: Brand.bad, title: "\(voids.count) voided bill\(voids.count == 1 ? "" : "s") (\(Fmt.aed(a.voidTotal)))", detail: Dictionary(grouping: voids, by: \.branch).map { "\(store.branchName($0.key)): \($0.value.count)" }.joined(separator: " · "))) }
        let off = shifts.filter { $0.isClosed && abs($0.diff) >= 1 }
        if !off.isEmpty { out.append(AttentionItem(icon: "banknote.fill", color: Brand.bad, title: "Cash difference on \(off.count) shift\(off.count == 1 ? "" : "s")", detail: off.map { "\(store.branchName($0.branch)) \($0.zNo): \(Fmt.signed($0.diff))" }.joined(separator: " · "))) }
        let stale = open.filter { Date().timeIntervalSince($0.opened) > 14 * 3600 }
        if !stale.isEmpty { out.append(AttentionItem(icon: "clock.badge.exclamationmark.fill", color: Brand.warn, title: "\(stale.count) shift\(stale.count == 1 ? "" : "s") open more than 14 hours", detail: stale.map { "\(store.branchName($0.branch)) since \(Fmt.dateTime($0.opened))" }.joined(separator: " · "))) }
        if a.total > 0 && a.disc / a.total > 0.1 { out.append(AttentionItem(icon: "percent", color: Brand.warn, title: "Discounts are \(Int((a.disc / a.total * 100).rounded()))% of sales", detail: Fmt.aed(a.disc) + " given")) }
        return out
    }

    @ViewBuilder private func attention(_ a: Totals) -> some View {
        let list = alerts(a)
        if list.isEmpty {
            Label("Nothing needs attention", systemImage: "checkmark.circle.fill").foregroundStyle(Brand.good).font(.subheadline.weight(.semibold))
        }
        ForEach(list) { al in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: al.icon).font(.subheadline.weight(.bold)).foregroundStyle(al.color)
                    .frame(width: 28, height: 28)
                    .background(al.color.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(al.title).font(.subheadline.weight(.semibold))
                    Text(al.detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func summaryText(_ a: Totals, _ b: Totals) -> String {
        var l: [String] = []
        l.append("*\(store.settings.name) – \(period.rawValue)*")
        let pc = b.total > 0 ? " (\(Int(((a.total - b.total) / b.total * 100).rounded()))% vs \(period.info.cmpLabel))" : ""
        l.append("Total sales: *\(Fmt.aed(a.total))*" + pc)
        l.append("\(a.bills) bills · avg \(Fmt.amount(a.average)) · VAT \(Fmt.amount(a.vat))")
        l.append("Cash \(Fmt.amount(a.cash)) · Card \(Fmt.amount(a.card))")
        l.append(""); l.append("Branches:")
        for (i, r) in rows.enumerated() { l.append("\(i + 1). \(r.branch.name): \(Fmt.aed(r.cur.total)) (\(r.cur.bills))") }
        let al = alerts(a)
        if !al.isEmpty { l.append(""); l.append("Needs attention:"); al.forEach { l.append("• \($0.title) – \($0.detail)") } }
        return l.joined(separator: "\n")
    }

    // MARK: loading

    private func load() async {
        guard !store.branches.isEmpty else { return }
        let info = period.info
        loading = true; error = nil
        do {
            if period != .today { loaded = try await store.sales(from: info.from, to: info.to) }
            var cmp = try await store.sales(from: info.cmpFrom, to: info.cmpTo)
            if let cut = info.cut { cmp = cmp.filter { $0.date <= cut } }
            compare = cmp
            shifts = (try? await store.shifts(from: info.from, to: info.to)) ?? []
            held = await store.heldBills()
            open = await store.openShifts()
        } catch {
            self.error = "Could not load: \(error.localizedDescription)"
        }
        loading = false
    }
}

/// Columns for the selected period, a grey line for the comparison period, one shared AED axis.
struct TrendChart: View {
    var current: [Sale]
    var compare: [Sale]
    var info: Period.Info
    var period: Period
    @State private var selected: Int?

    private struct Point: Identifiable { var id: Int { key }; var key: Int; var cur: Double; var cmp: Double }

    private var points: [Point] {
        let cal = Calendar.current
        let key: (Sale) -> Int = { info.hourly ? cal.component(.hour, from: $0.date) : cal.component(.day, from: $0.date) }
        var keys: [Int]
        if info.hourly {
            let hrs = (current + compare).filter { !$0.isVoid }.map(key)
            keys = Array(min(9, hrs.min() ?? 9)...max(22, hrs.max() ?? 22))
        } else { keys = Array(1...max(1, info.days)) }
        var a: [Int: Double] = [:], b: [Int: Double] = [:]
        current.filter { !$0.isVoid }.forEach { a[key($0), default: 0] += $0.total }
        compare.filter { !$0.isVoid }.forEach { b[key($0), default: 0] += $0.total }
        let lastCmp: Int = period == .today ? cal.component(.hour, from: Date()) : period == .month ? cal.component(.day, from: Date()) : (keys.last ?? 0)
        return keys.map { Point(key: $0, cur: a[$0] ?? 0, cmp: $0 <= lastCmp ? (b[$0] ?? 0) : -1) }
    }

    var body: some View {
        let pts = points
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                Label { Text(period.rawValue) } icon: { RoundedRectangle(cornerRadius: 2).fill(Brand.barFill).frame(width: 10, height: 10) }
                Label { Text(info.cmpLabel.prefix(1).uppercased() + info.cmpLabel.dropFirst()) } icon: { Rectangle().fill(Brand.compare).frame(width: 14, height: 2) }
            }
            .font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(pts) { p in
                    BarMark(x: .value(info.hourly ? "Hour" : "Day", p.key), y: .value("AED", p.cur), width: .fixed(info.hourly ? 12 : 6))
                        .foregroundStyle(Brand.barFill)
                        .cornerRadius(3)
                }
                ForEach(pts.filter { $0.cmp >= 0 }) { p in
                    LineMark(x: .value(info.hourly ? "Hour" : "Day", p.key), y: .value("AED", p.cmp), series: .value("Series", "compare"))
                        .foregroundStyle(Brand.compare)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                if let s = selected, let p = pts.first(where: { $0.key == s }) {
                    RuleMark(x: .value("Selected", p.key))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.hourly ? String(format: "%02d:00", p.key) : "Day \(p.key)").font(.caption2.bold()).foregroundStyle(.secondary)
                                Text(Fmt.aed(p.cur)).font(.caption.monospaced().bold())
                                if p.cmp >= 0 { Text("vs " + Fmt.aed(p.cmp)).font(.caption2.monospaced()).foregroundStyle(.secondary) }
                            }
                            .padding(6)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                        }
                }
            }
            .chartXSelection(value: $selected)
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compact(d)) } } } }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: info.hourly ? 7 : 8)) { v in AxisValueLabel { if let k = v.as(Int.self) { Text(info.hourly ? String(format: "%02d", k) : "\(k)") } } } }
            .frame(height: 200)
        }
    }
}
