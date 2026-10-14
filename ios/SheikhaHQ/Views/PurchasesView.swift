import SwiftUI

/// Supplier bills – the same list as Purchases in the POS on a computer. Their VAT is box 9 of the VAT 201.
struct PurchasesView: View {
    @Environment(HQStore.self) private var store
    @State private var period = PurchasePeriod.month
    @State private var branch = "all"
    @State private var search = ""
    @State private var editing: Purchase?
    @State private var adding = false

    var body: some View {
        let (a, b) = period.range
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.purchasesIn(from: a, to: b)
            .filter { branch == "all" || $0.branch == branch }
            .filter { p in q.isEmpty || [p.supplier, p.invNo, p.desc, p.trn].contains { $0.lowercased().contains(q) } }
            .sorted { ($0.date, $0.ts) > ($1.date, $1.ts) }
        let t = PurchaseTotals(list)
        List {
            Section {
                Picker("Period", selection: $period) {
                    ForEach(PurchasePeriod.allCases) { Text($0.label).tag($0) }
                }
                Picker("For", selection: $branch) {
                    Text("All").tag("all")
                    Text("Head office").tag("hq")
                    ForEach(store.branches) { Text("\($0.code) · \($0.name)").tag($0.id) }
                }
            } footer: {
                Text("\(Fmt.day(a)) – \(Fmt.day(b))")
            }
            if let e = store.purchasesError { Section { ErrorRow(message: e) } }
            Section("Totals") {
                LabeledContent("Total", value: Fmt.aed(t.total))
                LabeledContent("Bills", value: "\(t.bills)")
                LabeledContent("Excl. VAT", value: Fmt.amount(t.net))
                LabeledContent("VAT (recoverable)", value: Fmt.amount(t.vat))
                if t.unpaid > 0 {
                    LabeledContent("Not paid yet") { Text(Fmt.amount(t.unpaid)).foregroundStyle(Brand.bad).monospaced() }
                }
            }
            Section("Bills (\(list.count))") {
                if list.isEmpty { Text(q.isEmpty ? "No purchases in this period." : "No purchase matches “\(search)”.").foregroundStyle(.secondary) }
                ForEach(list) { p in
                    Button { editing = p } label: { PurchaseRow(purchase: p, showBranch: branch == "all") }
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Purchases")
        .searchable(text: $search, prompt: "Supplier, invoice no…")
        .toolbar {
            Button { adding = true } label: { Label("Add purchase", systemImage: "plus") }
        }
        .sheet(isPresented: $adding) {
            NavigationStack { PurchaseEditView(purchase: Purchase(), isNew: true) }
        }
        .sheet(item: $editing) { p in
            NavigationStack { PurchaseEditView(purchase: p, isNew: false) }
        }
    }
}

enum PurchasePeriod: String, CaseIterable, Identifiable {
    case month, lastMonth, quarter, lastQuarter, year
    var id: String { rawValue }
    var label: String {
        switch self {
        case .month: return "This month"
        case .lastMonth: return "Last month"
        case .quarter: return "This quarter"
        case .lastQuarter: return "Last quarter"
        case .year: return "This year"
        }
    }
    /// Whole calendar periods, like the quick buttons in the POS.
    var range: (Date, Date) {
        let cal = Calendar.current, now = Date()
        let y = cal.component(.year, from: now), m = cal.component(.month, from: now)
        func span(_ start: Date, months: Int) -> (Date, Date) {
            let end = cal.date(byAdding: .day, value: -1, to: cal.date(byAdding: .month, value: months, to: start)!)!
            return (start, end)
        }
        let monthStart = cal.date(from: DateComponents(year: y, month: m, day: 1))!
        let quarterStart = cal.date(from: DateComponents(year: y, month: ((m - 1) / 3) * 3 + 1, day: 1))!
        switch self {
        case .month: return span(monthStart, months: 1)
        case .lastMonth: return span(cal.date(byAdding: .month, value: -1, to: monthStart)!, months: 1)
        case .quarter: return span(quarterStart, months: 3)
        case .lastQuarter: return span(cal.date(byAdding: .month, value: -3, to: quarterStart)!, months: 3)
        case .year: return span(cal.date(from: DateComponents(year: y, month: 1, day: 1))!, months: 12)
        }
    }
}

struct PurchaseRow: View {
    @Environment(HQStore.self) private var store
    var purchase: Purchase
    var showBranch: Bool
    var body: some View {
        let p = purchase
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(p.supplier).font(.body.weight(.semibold)).lineLimit(1)
                Text([String(Fmt.day(p.day).dropFirst(5)), Purchase.typeLabel(p.cat), p.invNo].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if showBranch && p.branch != "hq" {
                    Text(store.branchName(p.branch)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.amount(p.total)).font(.callout.monospaced().bold())
                Text(p.isUnpaid ? "Not paid" : Purchase.paymentLabel(p.paid))
                    .font(.caption2.weight(p.isUnpaid ? .bold : .regular))
                    .foregroundStyle(p.isUnpaid ? Brand.bad : .secondary)
            }
        }
    }
}

struct PurchaseEditView: View {
    @Environment(HQStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var purchase: Purchase
    var isNew: Bool

    enum Amount { case net, vat, total }
    @FocusState private var focus: Amount?
    @State private var date = Date()
    @State private var net = ""
    @State private var vat = ""
    @State private var total = ""
    @State private var error: String?
    @State private var confirmDelete = false
    @State private var duplicate: Purchase?
    @State private var loaded = false

    private var rate: Double { store.settings.vat / 100 }
    private func value(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0 }
    private func text(_ v: Double) -> String { String(format: "%.2f", v) }
    private var suppliers: [String] {
        let typed = purchase.supplier.trimmingCharacters(in: .whitespaces).lowercased()
        let all = Set(store.purchases.map(\.supplier).filter { !$0.isEmpty })
        return all.filter { typed.isEmpty || ($0.lowercased().contains(typed) && $0.lowercased() != typed) }.sorted().prefix(4).map { $0 }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Bill date", selection: $date, displayedComponents: .date)
                Picker("Type", selection: $purchase.cat) {
                    ForEach(Purchase.types) { Text($0.label).tag($0.id) }
                }
            }
            Section {
                TextField("Supplier, e.g. Al Noor Fabrics Trading", text: $purchase.supplier)
                    .textInputAutocapitalization(.words)
                ForEach(suppliers, id: \.self) { s in
                    Button { pickSupplier(s) } label: { Label(s, systemImage: "arrow.up.left") }.font(.callout)
                }
                TextField("Supplier invoice no.", text: $purchase.invNo).autocorrectionDisabled()
                TextField("Supplier TRN (optional, 15 digits)", text: $purchase.trn).keyboardType(.numberPad)
            } header: { Text("Supplier") }
            Section {
                Picker("For", selection: $purchase.branch) {
                    Text("Head office").tag("hq")
                    ForEach(store.branches) { Text("\($0.code) · \($0.name)").tag($0.id) }
                }
                Picker("Paid by", selection: $purchase.paid) {
                    ForEach(Purchase.payments) { Text($0.label).tag($0.id) }
                }
                TextField("Description (optional)", text: $purchase.desc)
            }
            Section {
                amountField("Amount excl. VAT", $net, .net)
                amountField("VAT", $vat, .vat)
                amountField("Total incl. VAT", $total, .total)
            } header: {
                Text("Amount")
            } footer: {
                Text("Type the amount before VAT or the total – the other figures fill in at \(Fmt.qty(store.settings.vat))% VAT. Change the VAT if the bill shows something different, e.g. 0.")
            }
            if let error { Section { ErrorRow(message: error) } }
            if !isNew {
                Section {
                    Button("Delete purchase", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .navigationTitle(isNew ? "Add purchase" : "Edit purchase")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { save(checkDuplicate: true) } }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            date = purchase.day
            if !isNew { net = text(purchase.net); vat = text(purchase.vat); total = text(purchase.total) }
        }
        .onChange(of: net) { _, v in
            guard focus == .net else { return }
            let n = value(v), t = r2(n * rate)
            vat = v.isEmpty ? "" : text(t); total = v.isEmpty ? "" : text(r2(n + t))
        }
        .onChange(of: vat) { _, _ in
            guard focus == .vat else { return }
            total = text(r2(value(net) + value(vat)))
        }
        .onChange(of: total) { _, v in
            guard focus == .total else { return }
            let t = value(v), n = r2(t / (1 + rate))
            net = v.isEmpty ? "" : text(n); vat = v.isEmpty ? "" : text(r2(t - n))
        }
        .confirmationDialog("Delete this purchase?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    do { try await store.deletePurchase(purchase); dismiss() } catch { self.error = error.localizedDescription }
                }
            }
        } message: {
            Text("It will be removed from Purchases and the VAT 201.")
        }
        .alert("Already entered?", isPresented: Binding(get: { duplicate != nil }, set: { if !$0 { duplicate = nil } })) {
            Button("Save anyway") { save(checkDuplicate: false) }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let d = duplicate {
                Text("Invoice \(d.invNo) from \(d.supplier) was already entered on \(Fmt.day(d.day)) (\(Fmt.aed(d.total))).")
            }
        }
    }

    private func amountField(_ title: String, _ binding: Binding<String>, _ which: Amount) -> some View {
        LabeledContent(title) {
            TextField("0.00", text: binding)
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospaced()
                .focused($focus, equals: which)
        }
    }

    private func pickSupplier(_ s: String) {
        purchase.supplier = s
        if purchase.trn.isEmpty, let last = store.purchases.filter({ $0.supplier == s && !$0.trn.isEmpty }).max(by: { $0.ts < $1.ts }) {
            purchase.trn = last.trn
        }
    }

    private func save(checkDuplicate: Bool) {
        var p = purchase
        p.supplier = p.supplier.trimmingCharacters(in: .whitespaces)
        p.invNo = p.invNo.trimmingCharacters(in: .whitespaces)
        p.trn = p.trn.trimmingCharacters(in: .whitespaces)
        p.desc = p.desc.trimmingCharacters(in: .whitespaces)
        p.date = Fmt.ymd(date)
        p.net = r2(value(net)); p.vat = r2(value(vat)); p.total = r2(p.net + p.vat)
        error = nil
        if p.supplier.isEmpty { error = "Enter the supplier."; return }
        if p.total <= 0 || p.net < 0 || p.vat < 0 { error = "Enter the amount."; return }
        if !p.trn.isEmpty && (p.trn.count != 15 || !p.trn.allSatisfy(\.isNumber)) { error = "A TRN has 15 digits."; return }
        if checkDuplicate, !p.invNo.isEmpty, let d = store.purchases.first(where: {
            $0.id != p.id && $0.supplier.lowercased() == p.supplier.lowercased() && $0.invNo.lowercased() == p.invNo.lowercased()
        }) {
            duplicate = d; return
        }
        Task {
            do { try await store.savePurchase(p, isNew: isNew); dismiss() } catch { self.error = error.localizedDescription }
        }
    }
}
