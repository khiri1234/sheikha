import SwiftUI

struct ZReportsView: View {
    @Environment(HQStore.self) private var store
    @State private var days = 7
    @State private var branch = "all"
    @State private var shifts: [Shift] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        let closed = shifts.filter(\.isClosed)
        let diffTotal = closed.reduce(0) { $0 + $1.diff }
        List {
            Section {
                Picker("Period", selection: $days) {
                    Text("Last 7 days").tag(7); Text("Last 30 days").tag(30); Text("Last 90 days").tag(90)
                }
                Picker("Branch", selection: $branch) {
                    Text("All branches").tag("all")
                    ForEach(store.branches) { Text("\($0.code) · \($0.name)").tag($0.id) }
                }
            }
            if let error { Section { ErrorRow(message: error) } }
            Section {
                LabeledContent("Shifts closed", value: "\(closed.count)")
                LabeledContent("Sales", value: Fmt.aed(closed.reduce(0) { $0 + $1.summary.total }))
                LabeledContent("Paid out", value: Fmt.aed(closed.reduce(0) { $0 + $1.summary.paidOut }))
                LabeledContent("Cash over / short") {
                    Text(Fmt.signed(diffTotal)).foregroundStyle(diffTotal < 0 ? Brand.bad : diffTotal > 0 ? Brand.warn : Brand.good).monospaced()
                }
            }
            let openNow = shifts.filter { !$0.isClosed }
            if !openNow.isEmpty {
                Section("Open now") {
                    ForEach(openNow) { s in
                        HStack { Text(store.branchName(s.branch)).font(.body.weight(.semibold)); Spacer(); Text("since " + Fmt.dateTime(s.opened)).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            Section(loading ? "Z reports – loading…" : "Z reports") {
                if closed.isEmpty && !loading { Text("No closed shifts in this period.").foregroundStyle(.secondary) }
                ForEach(closed) { z in
                    NavigationLink { ZDetailView(shift: z) } label: { ZRow(shift: z, showBranch: branch == "all") }
                }
            }
        }
        .navigationTitle("Z reports")
        .refreshable { await load() }
        .task(id: "\(days)|\(branch)|\(store.branches.count)") { await load() }
    }

    private func load() async {
        guard !store.branches.isEmpty else { return }
        loading = true; error = nil
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        do { shifts = try await store.shifts(from: from, to: Date(), branch: branch == "all" ? nil : branch) }
        catch { self.error = "Could not load: \(error.localizedDescription)" }
        loading = false
    }
}

struct ZRow: View {
    @Environment(HQStore.self) private var store
    var shift: Shift
    var showBranch: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shift.zNo.isEmpty ? "Z" : shift.zNo).font(.callout.monospaced().weight(.semibold))
                Text((showBranch ? store.branchName(shift.branch) + " · " : "") + (shift.closed.map(Fmt.dateTime) ?? "")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.amount(shift.summary.total)).font(.callout.monospaced().bold())
                DiffText(diff: shift.diff)
            }
        }
    }
}

struct DiffText: View {
    var diff: Double
    var body: some View {
        Text(diff < 0 ? "short \(Fmt.amount(-diff))" : diff > 0 ? "over \(Fmt.amount(diff))" : "exact")
            .font(.caption2.weight(.bold))
            .foregroundStyle(diff < 0 ? Brand.bad : diff > 0 ? Brand.warn : Brand.good)
    }
}

struct ZDetailView: View {
    @Environment(HQStore.self) private var store
    var shift: Shift

    var body: some View {
        let s = shift.summary
        List {
            Section {
                LabeledContent("Branch", value: store.branchName(shift.branch))
                LabeledContent("Opened", value: Fmt.dateTime(shift.opened) + " · " + shift.openedBy)
                if let c = shift.closed { LabeledContent("Closed", value: Fmt.dateTime(c) + " · " + shift.closedBy) }
            }
            Section("Sales") {
                LabeledContent("Bills", value: Fmt.qty(s.bills))
                LabeledContent("Items (incl. VAT)", value: Fmt.amount(s.gross))
                if s.disc > 0 { LabeledContent("Discounts", value: "− " + Fmt.amount(s.disc)) }
                LabeledContent("Excl. VAT", value: Fmt.amount(s.net))
                LabeledContent("VAT", value: Fmt.amount(s.vat))
                LabeledContent("Total", value: Fmt.aed(s.total)).font(.headline)
                LabeledContent("Cash (\(Fmt.qty(s.cashN)))", value: Fmt.amount(s.cash))
                LabeledContent("Card (\(Fmt.qty(s.cardN)))", value: Fmt.amount(s.card))
                if s.voidN > 0 { LabeledContent("Voided (\(Fmt.qty(s.voidN)))", value: Fmt.amount(s.voidTotal)) }
            }
            if !s.byCashier.isEmpty {
                Section("By cashier") {
                    ForEach(s.byCashier.keys.sorted(), id: \.self) { k in
                        LabeledContent("\(k) (\(Fmt.qty(s.byCashier[k]?.bills ?? 0)))", value: Fmt.amount(s.byCashier[k]?.total ?? 0))
                    }
                }
            }
            Section("Cash drawer") {
                LabeledContent("Opening float", value: Fmt.amount(shift.openingFloat))
                LabeledContent("+ Cash sales", value: Fmt.amount(s.cash))
                if s.paidIn > 0 { LabeledContent("+ Paid in", value: Fmt.amount(s.paidIn)) }
                if s.paidOut > 0 { LabeledContent("− Paid out", value: Fmt.amount(s.paidOut)) }
                ForEach(shift.moves) { m in
                    HStack {
                        Text("\(Fmt.time(Date(timeIntervalSince1970: m.ts / 1000))) \(m.isOut ? "Paid out" : "Paid in") · \(m.reason)").font(.caption)
                        Spacer()
                        Text((m.isOut ? "− " : "+ ") + Fmt.amount(m.amount)).font(.caption.monospaced())
                    }
                    .foregroundStyle(.secondary)
                }
                LabeledContent("Expected cash", value: Fmt.amount(shift.expectedCash)).font(.headline)
                LabeledContent("Counted cash", value: Fmt.amount(shift.countedCash))
                LabeledContent("Difference") { DiffText(diff: shift.diff).font(.headline) }
                if !shift.note.isEmpty { Text("Note: " + shift.note).font(.callout).foregroundStyle(.secondary) }
            }
            Section { ShareButtons(text: zText, subject: "Z report \(shift.zNo) – \(store.branchName(shift.branch))") }
        }
        .navigationTitle(shift.zNo.isEmpty ? "Z report" : shift.zNo).navigationBarTitleDisplayMode(.inline)
    }

    /// Same wording as the WhatsApp text sent from the branch POS.
    private var zText: String {
        let s = shift.summary
        var l: [String] = ["*\(store.settings.name) – \(store.branchName(shift.branch))*", "Z REPORT \(shift.zNo)",
                           "Opened: \(Fmt.dateTime(shift.opened)) (\(shift.openedBy))"]
        if let c = shift.closed { l.append("Closed: \(Fmt.dateTime(c)) (\(shift.closedBy))") }
        l += ["", "Sales: \(Fmt.aed(s.total)) (\(Fmt.qty(s.bills)) bills)", "Cash: \(Fmt.aed(s.cash)) · Card: \(Fmt.aed(s.card))",
              "Excl. VAT: \(Fmt.amount(s.net)) · VAT: \(Fmt.amount(s.vat))"]
        if s.voidN > 0 { l.append("Voided: \(Fmt.qty(s.voidN)) (\(Fmt.aed(s.voidTotal)))") }
        if !s.byCashier.isEmpty { l += ["", "By cashier:"] + s.byCashier.keys.sorted().map { "• \($0): \(Fmt.aed(s.byCashier[$0]?.total ?? 0))" } }
        l += ["", "Cash drawer:", "Float \(Fmt.amount(shift.openingFloat)) + cash sales \(Fmt.amount(s.cash))" + (s.paidIn > 0 ? " + paid in \(Fmt.amount(s.paidIn))" : "") + (s.paidOut > 0 ? " − paid out \(Fmt.amount(s.paidOut))" : "") + " = expected *\(Fmt.amount(shift.expectedCash))*"]
        l += shift.moves.map { "  \($0.isOut ? "Paid out" : "Paid in") \(Fmt.amount($0.amount)) – \($0.reason)" }
        l.append("Counted: \(Fmt.amount(shift.countedCash))")
        l.append(shift.diff < 0 ? "⚠️ SHORT \(Fmt.amount(-shift.diff))" : shift.diff > 0 ? "⚠️ OVER \(Fmt.amount(shift.diff))" : "✅ Exact")
        if !shift.note.isEmpty { l.append("Note: \(shift.note)") }
        return l.joined(separator: "\n")
    }
}
