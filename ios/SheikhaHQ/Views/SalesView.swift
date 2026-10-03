import SwiftUI

struct SalesView: View {
    @Environment(HQStore.self) private var store
    @State private var day = Date()
    @State private var branch: String = "all"
    @State private var sales: [Sale] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        let t = Totals(sales)
        List {
            Section {
                DatePicker("Day", selection: $day, in: ...Date(), displayedComponents: .date)
                Picker("Branch", selection: $branch) {
                    Text("All branches").tag("all")
                    ForEach(store.branches) { Text("\($0.code) · \($0.name)").tag($0.id) }
                }
            }
            if let error { Section { ErrorRow(message: error) } }
            Section("Totals") {
                LabeledContent("Total sales", value: Fmt.aed(t.total))
                LabeledContent("Bills", value: "\(t.bills)")
                LabeledContent("Excl. VAT", value: Fmt.amount(t.net))
                LabeledContent("VAT", value: Fmt.amount(t.vat))
                LabeledContent("Cash · Card", value: Fmt.amount(t.cash) + " · " + Fmt.amount(t.card))
                if t.voidN > 0 { LabeledContent("Voided", value: "\(t.voidN) · \(Fmt.amount(t.voidTotal))") }
            }
            Section(loading ? "Invoices – loading…" : "Invoices (\(sales.count))") {
                if sales.isEmpty && !loading { Text("No invoices for this day.").foregroundStyle(.secondary) }
                ForEach(sales.reversed()) { s in
                    NavigationLink { InvoiceDetailView(sale: s) { updated in if let i = sales.firstIndex(where: { $0.id == updated.id }) { sales[i] = updated } } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.no).font(.callout.monospaced().weight(.semibold)).strikethrough(s.isVoid)
                                Text("\(Fmt.time(s.date)) · \(store.branchName(s.branch))\(s.cashier.isEmpty ? "" : " · " + s.cashier)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(Fmt.amount(s.total)).font(.callout.monospaced().bold()).foregroundStyle(s.isVoid ? .secondary : .primary).strikethrough(s.isVoid)
                                Text(s.isVoid ? "Void" : (s.isCard ? "Card" : "Cash")).font(.caption2).foregroundStyle(s.isVoid ? Brand.bad : .secondary)
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink("VAT 201 totals") { VATView() }
            }
        }
        .navigationTitle("Sales")
        .refreshable { await load() }
        .task(id: "\(day.timeIntervalSince1970)|\(branch)|\(store.branches.count)") { await load() }
    }

    private func load() async {
        guard !store.branches.isEmpty else { return }
        loading = true; error = nil
        do { sales = try await store.sales(from: day, to: day, branch: branch == "all" ? nil : branch) }
        catch { self.error = "Could not load: \(error.localizedDescription)" }
        loading = false
    }
}

struct InvoiceDetailView: View {
    @Environment(HQStore.self) private var store
    @State var sale: Sale
    var onUpdate: (Sale) -> Void
    @State private var confirmVoid = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Invoice", value: sale.no)
                LabeledContent("Date", value: Fmt.dateTime(sale.date))
                LabeledContent("Branch", value: store.branchName(sale.branch))
                if !sale.cashier.isEmpty { LabeledContent("Cashier", value: sale.cashier) }
                LabeledContent("Paid by", value: sale.isCard ? "Card" + (sale.ref.isEmpty ? "" : " (\(sale.ref))") : "Cash")
                if sale.isVoid { Label("Voided", systemImage: "xmark.circle.fill").foregroundStyle(Brand.bad) }
            }
            Section("Items") {
                ForEach(Array(sale.lines.enumerated()), id: \.offset) { _, l in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(l.name).font(.body.weight(.semibold)); Spacer(); Text(Fmt.amount(l.gross)).font(.body.monospaced()) }
                        Text("\(Fmt.qty(l.qty)) \(l.unit) × \(Fmt.amount(l.price)) (\(l.mode == "incl" ? "incl. VAT" : "excl. VAT"))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                LabeledContent("Items (incl. VAT)", value: Fmt.amount(sale.sumGross))
                if sale.disc > 0 { LabeledContent("Discount", value: "− " + Fmt.amount(sale.disc)) }
                LabeledContent("Excl. VAT", value: Fmt.amount(sale.net))
                LabeledContent("VAT \(Fmt.qty(sale.vatRate))%", value: Fmt.amount(sale.vat))
                LabeledContent("Total", value: Fmt.aed(sale.total)).font(.headline)
            }
            if let error { Section { ErrorRow(message: error) } }
            if !sale.isVoid {
                Section {
                    Button("Void this sale", role: .destructive) { confirmVoid = true }
                } footer: { Text("A voided sale stays on record, marked void, and is left out of all totals.") }
            }
        }
        .navigationTitle(sale.no).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Void \(sale.no)?", isPresented: $confirmVoid, titleVisibility: .visible) {
            Button("Void sale", role: .destructive) {
                Task {
                    do { try await store.void(sale); sale.status = "void"; onUpdate(sale) }
                    catch { self.error = error.localizedDescription }
                }
            }
        }
    }
}

/// VAT 201 working: all branches are standard rated in Abu Dhabi (box 1a).
struct VATView: View {
    @Environment(HQStore.self) private var store
    @State private var quarterOffset = 0
    @State private var t: Totals?
    @State private var error: String?

    private var range: (Date, Date) {
        let cal = Calendar.current, now = Date()
        let m = cal.component(.month, from: now), y = cal.component(.year, from: now)
        let qStart = cal.date(from: DateComponents(year: y, month: ((m - 1) / 3) * 3 + 1, day: 1))!
        let start = cal.date(byAdding: .month, value: 3 * quarterOffset, to: qStart)!
        let end = cal.date(byAdding: .day, value: -1, to: cal.date(byAdding: .month, value: 3, to: start)!)!
        return (start, end)
    }

    var body: some View {
        let (a, b) = range
        List {
            Section {
                Stepper(value: $quarterOffset, in: -8...0) { Text("\(Fmt.day(a).dropFirst(5)) – \(Fmt.day(b).dropFirst(5))") }
            } footer: { Text("Calendar quarters. Your FTA tax periods may differ – check before filing.") }
            if let error { Section { ErrorRow(message: error) } }
            if let t {
                Section("VAT on sales (box 1a – Abu Dhabi)") {
                    LabeledContent("Standard rated supplies", value: Fmt.amount(t.net))
                    LabeledContent("Output VAT", value: Fmt.amount(t.vat))
                    LabeledContent("Bills", value: "\(t.bills)")
                }
                Section {
                    LabeledContent("Box 8 – Totals", value: Fmt.amount(t.net) + " / " + Fmt.amount(t.vat))
                } footer: { Text("Purchases (box 9) are entered in the POS on a computer: Reports → VAT 201.") }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("VAT 201")
        .task(id: quarterOffset) {
            t = nil; error = nil
            do { t = Totals(try await store.sales(from: range.0, to: range.1)) } catch { self.error = error.localizedDescription }
        }
    }
}
