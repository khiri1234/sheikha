import SwiftUI

struct BranchesView: View {
    @Environment(HQStore.self) private var store

    var body: some View {
        List {
            if store.branches.isEmpty {
                Text("No branches yet. Add them in the POS on a computer (Branches → Add branch).").foregroundStyle(.secondary)
            }
            ForEach(store.branches) { b in
                let t = Totals((store.today[b.id] ?? []).filter { Calendar.current.isDateInToday($0.date) })
                NavigationLink(value: b) {
                    HStack {
                        Text(b.code).font(.caption.monospaced().bold()).foregroundStyle(Brand.orange)
                            .frame(width: 34, height: 28).background(Brand.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(b.name).font(.body.weight(.semibold))
                            Text("\(t.bills) bills today · \(b.activeCashiers.count) cashier\(b.activeCashiers.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Fmt.amount(t.total)).font(.callout.monospaced().bold())
                    }
                }
            }
        }
        .navigationTitle("Branches")
        .navigationDestination(for: Branch.self) { BranchDetailView(branchId: $0.id) }
    }
}

struct BranchDetailView: View {
    @Environment(HQStore.self) private var store
    var branchId: String
    @State private var shifts: [Shift] = []
    @State private var error: String?
    @State private var showAdd = false
    @State private var pinFor: Cashier?
    @State private var removing: Cashier?

    private var branch: Branch? { store.branch(branchId) }

    var body: some View {
        if let b = branch {
            let today = (store.today[b.id] ?? []).filter { Calendar.current.isDateInToday($0.date) }
            let t = Totals(today)
            List {
                Section("Today") {
                    row("Sales", Fmt.aed(t.total), bold: true)
                    row("Bills", "\(t.bills) · avg \(Fmt.amount(t.average))")
                    row("Cash · Card", Fmt.amount(t.cash) + " · " + Fmt.amount(t.card))
                    if t.voidN > 0 { row("Voided", "\(t.voidN) · \(Fmt.aed(t.voidTotal))") }
                }
                Section("Shift") {
                    if let open = shifts.first(where: { !$0.isClosed }) {
                        row("Open since", Fmt.dateTime(open.opened))
                        row("Opened by", open.openedBy)
                        row("Opening float", Fmt.aed(open.openingFloat))
                        let out = open.moves.filter(\.isOut).reduce(0) { $0 + $1.amount }
                        if out > 0 { row("Paid out so far", Fmt.aed(out)) }
                    } else {
                        Text("No shift open").foregroundStyle(.secondary)
                    }
                }
                Section("Recent Z reports") {
                    let closed = shifts.filter(\.isClosed).prefix(10)
                    if closed.isEmpty { Text("None in the last 30 days").foregroundStyle(.secondary) }
                    ForEach(Array(closed)) { z in
                        NavigationLink { ZDetailView(shift: z) } label: { ZRow(shift: z, showBranch: false) }
                    }
                }
                Section {
                    ForEach(b.cashiers) { c in
                        HStack {
                            Image(systemName: "person.fill").foregroundStyle(c.active ? Brand.orange : .secondary)
                            Text(c.name).strikethrough(!c.active)
                            if !c.active { Text("removed").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                        }
                        .swipeActions {
                            if c.active {
                                Button("Remove", role: .destructive) { removing = c }
                                Button("New PIN") { pinFor = c }.tint(Brand.orange)
                            } else {
                                Button("Restore") { Task { await run { try await store.setCashier(b, c, active: true) } } }.tint(Brand.good)
                            }
                        }
                    }
                    Button { showAdd = true } label: { Label("Add cashier", systemImage: "person.badge.plus") }
                } header: {
                    Text("Cashiers")
                } footer: {
                    Text("Each cashier signs in at the till with their own 4-digit PIN. Swipe a cashier for New PIN or Remove.")
                }
                if let error { Section { ErrorRow(message: error) } }
                Section("Details") {
                    row("Code", b.code)
                    if !b.address.isEmpty { row("Address", b.address) }
                    if !b.phone.isEmpty {
                        HStack { Text("Phone"); Spacer(); Link(b.phone, destination: URL(string: "tel:" + b.phone.filter { $0.isNumber || $0 == "+" }) ?? URL(string: "tel:")!) }
                    }
                    row("Login", b.email)
                }
            }
            .navigationTitle(b.name)
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showAdd) { CashierForm(title: "Add cashier", askName: true) { name, pin in try await store.addCashier(b, name: name, pin: pin) } }
            .sheet(item: $pinFor) { c in CashierForm(title: "New PIN for \(c.name)", askName: false) { _, pin in try await store.changePin(b, c, pin: pin) } }
            .confirmationDialog("Remove \(removing?.name ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("Remove", role: .destructive) { if let c = removing { Task { await run { try await store.setCashier(b, c, active: false) } } } }
            } message: { Text("They can no longer sign in at the till. Their past sales keep their name.") }
        } else {
            Text("Branch not found").foregroundStyle(.secondary)
        }
    }

    private func row(_ k: String, _ v: String, bold: Bool = false) -> some View {
        HStack { Text(k); Spacer(); Text(v).font(bold ? .body.monospaced().bold() : .body.monospaced()).foregroundStyle(bold ? .primary : .secondary).multilineTextAlignment(.trailing) }
    }

    private func run(_ op: () async throws -> Void) async {
        error = nil
        do { try await op() } catch { self.error = error.localizedDescription }
    }

    private func load() async {
        let from = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        do { shifts = try await store.shifts(from: from, to: Date(), branch: branchId) }
        catch { self.error = "Could not load shifts: \(error.localizedDescription)" }
    }
}

struct CashierForm: View {
    var title: String
    var askName: Bool
    var save: (String, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var pin = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                if askName { TextField("Name", text: $name).textInputAutocapitalization(.words) }
                SecureField("4-digit PIN", text: $pin).keyboardType(.numberPad)
                    .onChange(of: pin) { _, v in pin = String(v.filter(\.isNumber).prefix(4)) }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            busy = true; error = nil
                            do { try await save(name, pin); dismiss() } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    }
                    .disabled(busy || pin.count != 4 || (askName && name.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
