import SwiftUI

struct MoreView: View {
    @Environment(HQStore.self) private var store
    @AppStorage("faceIDLock") private var faceIDLock = false
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @State private var wa = ""
    @State private var mail = ""
    @State private var saved = false
    @State private var error: String?
    @State private var confirmSignOut = false

    var body: some View {
        List {
            Section("Shop") {
                NavigationLink { FabricsView() } label: { Label("Fabric prices", systemImage: "tag") }
                LabeledContent("Name", value: store.settings.name)
                LabeledContent("TRN", value: store.settings.trn.isEmpty ? "not set" : store.settings.trn)
                LabeledContent("VAT", value: "\(Fmt.qty(store.settings.vat))%")
            }
            Section {
                TextField("Head office WhatsApp, e.g. 971501234567", text: $wa).keyboardType(.phonePad)
                TextField("Email for Z reports", text: $mail).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(saved ? "Saved ✓" : "Save") {
                    Task {
                        error = nil
                        do { try await store.saveReportContacts(whatsApp: wa, email: mail); saved = true } catch { self.error = error.localizedDescription }
                    }
                }
                if let error { ErrorRow(message: error) }
            } header: {
                Text("Where branches send Z reports")
            } footer: {
                Text("Branches tap WhatsApp or Email on the Z report after closing a shift.")
            }
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Automatic follows the iPhone's light or dark setting.")
            }
            Section {
                Toggle("Lock with Face ID", isOn: $faceIDLock)
            } footer: { Text("Asks for Face ID (or the iPhone passcode) whenever Sheikha HQ is opened.") }
            Section {
                LabeledContent("Signed in as", value: store.email)
                Link(destination: URL(string: "https://khiri1234.github.io/sheikha/")!) { Label("Open the POS website", systemImage: "safari") }
                Button("Sign out", role: .destructive) { confirmSignOut = true }
            } footer: {
                Text("Branches, logins, receipts and settings are managed in the POS on a computer.")
            }
        }
        .navigationTitle("More")
        .onAppear { wa = store.settings.waNumber; mail = store.settings.reportEmail; saved = false }
        .onChange(of: wa) { _, _ in saved = false }
        .onChange(of: mail) { _, _ in saved = false }
        .confirmationDialog("Sign out of Sheikha HQ?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { store.signOut() }
        }
    }
}

struct FabricsView: View {
    @Environment(HQStore.self) private var store
    var body: some View {
        List {
            if store.fabrics.isEmpty { Text("No fabrics yet.").foregroundStyle(.secondary) }
            ForEach(store.fabrics) { f in
                NavigationLink { FabricEditView(fabric: f) } label: {
                    HStack {
                        Circle().fill(Color(hex: f.color) ?? .gray).frame(width: 14, height: 14)
                        VStack(alignment: .leading) {
                            Text(f.name).font(.body.weight(.semibold))
                            if !f.barcode.isEmpty { Text(f.barcode).font(.caption.monospaced()).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text(f.price.isEmpty ? "at sale" : "AED " + f.price).font(.callout.monospaced()).foregroundStyle(f.price.isEmpty ? .secondary : .primary)
                    }
                }
            }
        }
        .navigationTitle("Fabric prices")
    }
}

struct FabricEditView: View {
    @Environment(HQStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var fabric: Fabric
    @State private var name = ""
    @State private var price = ""
    @State private var barcode = ""
    @State private var error: String?

    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Usual price in AED (empty = enter at sale)", text: $price).keyboardType(.decimalPad)
            TextField("Barcode (optional)", text: $barcode).autocorrectionDisabled()
            if let error { ErrorRow(message: error) }
        }
        .navigationTitle(fabric.name)
        .onAppear { name = fabric.name; price = fabric.price; barcode = fabric.barcode }
        .toolbar {
            Button("Save") {
                let p = Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0
                let code = barcode.trimmingCharacters(in: .whitespaces)
                if !code.isEmpty && store.fabrics.contains(where: { $0.id != fabric.id && $0.barcode == code }) { error = "Another fabric already uses this barcode."; return }
                Task {
                    do {
                        try await store.saveFabric(id: fabric.id, name: name.trimmingCharacters(in: .whitespaces), price: p > 0 ? Fmt.qty(p) : "", barcode: code)
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

extension Color {
    /// "#2F6F8F" → Color
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
