import Foundation
import UIKit
import UserNotifications
import Observation
import CryptoKit
import FirebaseAuth
import FirebaseFirestore

/// Everything the head-office app reads and writes, over the same Firestore
/// layout as the web POS (see firestore.rules):
///   config/shop, items/*, branches/{id} (+ sales, held, shifts, logs), hqlog/*
@MainActor
@Observable
final class HQStore {
    enum Phase: Equatable { case loading, signedOut, denied(String), ready }

    var phase: Phase = .loading
    var email = ""
    var branches: [Branch] = []
    var settings = ShopSettings()
    var fabrics: [Fabric] = []
    /// Today's sales per branch, live.
    var today: [String: [Sale]] = [:]
    var lastError: String?
    /// config/notify – which push notifications head office receives
    var notify: [String: Any] = [:]

    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    @ObservationIgnored private var todayListeners: [ListenerRegistration] = []
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private var tokenObserver: NSObjectProtocol?
    private var savedToken: String?
    /// Error from saving this iPhone's push token, shown in More → Notifications.
    var tokenError: String?
    var tokenSaved: Bool { isDemo ? PushManager.token != nil : savedToken != nil && savedToken == PushManager.token }
    /// Demo mode for App Review: sample data (DemoData), nothing read from or written to Firebase.
    var isDemo = false
    @ObservationIgnored private var demo: DemoData?

    init() {
        tokenObserver = NotificationCenter.default.addObserver(forName: PushManager.tokenChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.saveDeviceToken() }
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.authChanged(user) }
        }
    }

    // MARK: sign in

    private func authChanged(_ user: User?) {
        if isDemo { return }
        stop()
        guard let user else { phase = .signedOut; return }
        let mail = (user.email ?? "").lowercased()
        guard mail == Config.hqEmail.lowercased() else {
            try? Auth.auth().signOut()
            phase = .denied("This app is for the head-office login only. Branch logins use the POS on the branch computer.")
            return
        }
        email = mail
        start()
        phase = .ready
        PushManager.requestPermission()
        saveDeviceToken()
    }

    func signIn(email: String, password: String) async throws {
        let mail = email.trimmingCharacters(in: .whitespaces)
        if mail.lowercased() == Config.demoEmail && password == Config.demoPassword { enterDemo(); return }
        _ = try await Auth.auth().signIn(withEmail: mail, password: password)
    }

    private func enterDemo() {
        stop()
        let d = DemoData()
        demo = d
        isDemo = true
        email = Config.demoEmail
        branches = d.branches
        settings = d.settings
        fabrics = d.fabrics
        notify = [:]
        refreshDemoToday()
        phase = .ready
        PushManager.requestPermission()
    }

    private func refreshDemoToday() {
        guard let d = demo else { return }
        let cal = Calendar.current
        today = Dictionary(grouping: d.sales.filter { cal.isDateInToday($0.date) }, by: \.branch)
    }

    func signOut() {
        if isDemo {
            isDemo = false; demo = nil
            stop(); settings = ShopSettings(); notify = [:]
            phase = .signedOut
            return
        }
        // stop notifications to this phone before signing out
        if let t = savedToken {
            db.collection("config").document("devices").updateData([FieldPath(["tokens", t]): FieldValue.delete()])
            savedToken = nil
        }
        try? Auth.auth().signOut()
    }

    // MARK: push notifications

    /// Store this iPhone's push token so the Cloud Functions can reach it.
    func saveDeviceToken() {
        guard !isDemo, phase == .ready, let t = PushManager.token, t != savedToken else { return }
        savedToken = t
        tokenError = nil
        db.collection("config").document("devices").setData([
            "tokens": [t: ["ts": Fmt.ms(Date()), "device": UIDevice.current.name]]
        ], merge: true) { [weak self] error in
            guard let error else { return }
            let message = error.localizedDescription
            Task { @MainActor in
                // forget it so the next attempt tries again
                if self?.savedToken == t { self?.savedToken = nil }
                self?.tokenError = message
            }
        }
    }

    func saveNotify(_ values: [String: Any]) async throws {
        if isDemo { notify.merge(values) { $1 }; return }
        try await db.collection("config").document("notify").setData(values, merge: true)
    }

    /// The test is sent by the notifyTest Cloud Function when testAt changes.
    func sendTestNotification() async throws {
        if isDemo {
            // no server in demo mode: show the same message as a local notification
            let content = UNMutableNotificationContent()
            content.title = "Sheikha HQ"
            content.body = "Test notification – push notifications are working ✓"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger))
            notify["testResult"] = ["devices": 1, "sent": 1, "error": "", "ts": Fmt.ms(Date())] as [String: Any]
            return
        }
        try await saveNotify(["testAt": Fmt.ms(Date())])
    }

    // MARK: live data

    private func start() {
        listeners.append(db.collection("branches").addSnapshotListener { [weak self] snap, err in
            let list = (snap?.documents ?? []).map { Branch($0.data()) }
                .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            let message = err?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if let message { self.lastError = message; return }
                let changed = list.map(\.id) != self.branches.map(\.id)
                self.branches = list
                if changed { self.watchToday() }
            }
        })
        listeners.append(db.collection("config").document("shop").addSnapshotListener { [weak self] snap, _ in
            let s = ShopSettings(snap?.data() ?? [:])
            Task { @MainActor in self?.settings = s }
        })
        listeners.append(db.collection("config").document("notify").addSnapshotListener { [weak self] snap, _ in
            let d = snap?.data() ?? [:]
            Task { @MainActor in self?.notify = d }
        })
        listeners.append(db.collection("items").addSnapshotListener { [weak self] snap, _ in
            let list = (snap?.documents ?? []).map { Fabric($0.data()) }
                .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
            Task { @MainActor in self?.fabrics = list }
        })
    }

    private func watchToday() {
        todayListeners.forEach { $0.remove() }
        todayListeners = []
        today = [:]
        let start = Fmt.ms(Calendar.current.startOfDay(for: Date()))
        for b in branches {
            let id = b.id
            todayListeners.append(salesCol(id).whereField("ts", isGreaterThanOrEqualTo: start).addSnapshotListener { [weak self] snap, _ in
                let list = (snap?.documents ?? []).map { Sale($0.data()) }
                Task { @MainActor in self?.today[id] = list }
            })
        }
    }

    /// Call when the app comes back to the foreground: after midnight "today" moves on.
    func refreshToday() {
        if isDemo { refreshDemoToday(); return }
        if phase == .ready { watchToday() }
    }

    private func stop() {
        listeners.forEach { $0.remove() }; listeners = []
        todayListeners.forEach { $0.remove() }; todayListeners = []
        branches = []; today = [:]; fabrics = []; email = ""
    }

    var todaySales: [Sale] {
        let cal = Calendar.current
        return today.values.flatMap { $0 }.filter { cal.isDateInToday($0.date) }
    }

    func branchName(_ id: String) -> String { branches.first { $0.id == id }?.name ?? id }
    func branch(_ id: String) -> Branch? { branches.first { $0.id == id } }

    // MARK: queries

    private func bref(_ id: String) -> DocumentReference { db.collection("branches").document(id) }
    private func salesCol(_ id: String) -> CollectionReference { bref(id).collection("sales") }

    /// Sales between two days for one branch, or every branch when branch is nil.
    func sales(from: Date, to: Date, branch: String? = nil) async throws -> [Sale] {
        let cal = Calendar.current
        if let d = demo {
            let a = cal.startOfDay(for: from), b = cal.endOfDay(to)
            return d.sales.filter { $0.date >= a && $0.date <= b && (branch == nil || $0.branch == branch) }
        }
        let a = Fmt.ms(cal.startOfDay(for: from)), b = Fmt.ms(cal.endOfDay(to)) + 999
        let ids = branch.map { [$0] } ?? branches.map(\.id)
        let queries = ids.map { salesCol($0).whereField("ts", isGreaterThanOrEqualTo: a).whereField("ts", isLessThanOrEqualTo: b) }
        var out: [Sale] = []
        for q in queries {
            let snap = try await q.getDocuments()
            out += snap.documents.map { Sale($0.data()) }
        }
        return out.sorted { $0.ts < $1.ts }
    }

    func shifts(from: Date, to: Date, branch: String? = nil) async throws -> [Shift] {
        let cal = Calendar.current
        if let d = demo {
            let a = cal.startOfDay(for: from), b = cal.endOfDay(to)
            return d.shifts.filter { $0.opened >= a && $0.opened <= b && (branch == nil || $0.branch == branch) }
                .sorted { $0.openedAt > $1.openedAt }
        }
        let a = Fmt.ms(cal.startOfDay(for: from)), b = Fmt.ms(cal.endOfDay(to)) + 999
        let ids = branch.map { [$0] } ?? branches.map(\.id)
        let queries = ids.map { bref($0).collection("shifts").whereField("openedAt", isGreaterThanOrEqualTo: a).whereField("openedAt", isLessThanOrEqualTo: b) }
        var out: [Shift] = []
        for q in queries {
            let snap = try await q.getDocuments()
            out += snap.documents.map { Shift($0.data()) }
        }
        return out.sorted { $0.openedAt > $1.openedAt }
    }

    func openShifts() async -> [Shift] {
        if let d = demo { return d.shifts.filter { !$0.isClosed } }
        var out: [Shift] = []
        for b in branches {
            if let q = try? await bref(b.id).collection("shifts").whereField("status", isEqualTo: "open").getDocuments() {
                out += q.documents.map { Shift($0.data()) }
            }
        }
        return out
    }

    func heldBills() async -> [HeldBill] {
        if let d = demo { return d.held }
        var out: [HeldBill] = []
        for b in branches {
            if let q = try? await bref(b.id).collection("held").getDocuments() {
                out += q.documents.map { HeldBill($0.data(), branch: b.id) }
            }
        }
        return out
    }

    // MARK: changes (allowed for head office by firestore.rules)

    func void(_ sale: Sale) async throws {
        if isDemo {
            if let i = demo?.sales.firstIndex(where: { $0.id == sale.id }) { demo?.sales[i].status = "void" }
            refreshDemoToday()
            return
        }
        try await salesCol(sale.branch).document(sale.id).updateData([
            "status": "void", "voidedAt": Fmt.ms(Date()), "voidedBy": email
        ])
        log("Void", "\(sale.no) voided from Sheikha HQ (\(Fmt.aed(sale.total)), \(sale.method))")
    }

    func saveFabric(id: String, name: String, price: String, barcode: String) async throws {
        if isDemo {
            if let i = fabrics.firstIndex(where: { $0.id == id }) { fabrics[i].name = name; fabrics[i].price = price; fabrics[i].barcode = barcode }
            return
        }
        try await db.collection("items").document(id).setData(["name": name, "price": price, "barcode": barcode], merge: true)
        log("Item", "Fabric \"\(name)\" updated from Sheikha HQ" + (price.isEmpty ? "" : " (usual price AED \(price))"))
    }

    func saveReportContacts(whatsApp: String, email: String) async throws {
        let digits = whatsApp.filter { $0.isNumber || $0 == "+" }
        if isDemo { settings.waNumber = digits; settings.reportEmail = email; return }
        try await db.collection("config").document("shop").setData(["waNumber": digits, "reportEmail": email], merge: true)
        log("Settings", "Report contacts updated from Sheikha HQ")
    }

    // MARK: cashiers – PINs are hashed exactly like the web POS so they work at the tills

    static func pinHash(branchId: String, pin: String) -> String {
        let digest = SHA256.hash(data: Data("sheikha-pos|\(branchId)|\(pin)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    enum CashierError: LocalizedError {
        case badPin, pinTaken, noName
        var errorDescription: String? {
            switch self {
            case .badPin: return "The PIN must be 4 digits."
            case .pinTaken: return "Another cashier at this branch already uses that PIN."
            case .noName: return "Enter the cashier's name."
            }
        }
    }

    private func saveCashiers(_ branch: Branch, _ list: [Cashier], _ msg: String) async throws {
        if isDemo {
            if let i = branches.firstIndex(where: { $0.id == branch.id }) { branches[i].cashiers = list }
            return
        }
        try await bref(branch.id).updateData(["cashiers": list.map(\.dict)])
        log("Settings", msg)
    }

    private func checkedHash(_ branch: Branch, _ pin: String, except: String? = nil) throws -> String {
        guard pin.count == 4, pin.allSatisfy(\.isNumber) else { throw CashierError.badPin }
        let h = Self.pinHash(branchId: branch.id, pin: pin)
        if branch.cashiers.contains(where: { $0.active && $0.pin == h && $0.id != except }) { throw CashierError.pinTaken }
        return h
    }

    func addCashier(_ branch: Branch, name: String, pin: String) async throws {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { throw CashierError.noName }
        let h = try checkedHash(branch, pin)
        let c = Cashier(id: "c" + UUID().uuidString.prefix(10).lowercased(), name: name, pin: h, active: true)
        try await saveCashiers(branch, branch.cashiers + [c], "Cashier \(name) added to \(branch.name)")
    }

    func setCashier(_ branch: Branch, _ c: Cashier, active: Bool) async throws {
        let list = branch.cashiers.map { $0.id == c.id ? Cashier(id: $0.id, name: $0.name, pin: $0.pin, active: active) : $0 }
        try await saveCashiers(branch, list, "Cashier \(c.name) \(active ? "restored at" : "removed from") \(branch.name)")
    }

    func changePin(_ branch: Branch, _ c: Cashier, pin: String) async throws {
        let h = try checkedHash(branch, pin, except: c.id)
        let list = branch.cashiers.map { $0.id == c.id ? Cashier(id: $0.id, name: $0.name, pin: h, active: $0.active) : $0 }
        try await saveCashiers(branch, list, "PIN changed for \(c.name) at \(branch.name)")
    }

    private func log(_ type: String, _ text: String) {
        if isDemo { return }
        db.collection("hqlog").addDocument(data: ["ts": Fmt.ms(Date()), "type": type, "text": text, "by": email, "branch": "hq"])
    }
}
