import SwiftUI
import UserNotifications

/// More → Notifications: what head office is told about. Saved in config/notify
/// and read by the Cloud Functions, so the choice applies to every head-office phone.
struct NotificationsView: View {
    @Environment(HQStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var zClosed = true
    @State private var cashDiff = true
    @State private var cashDiffMin = 5.0
    @State private var voids = true
    @State private var payouts = true
    @State private var payoutMin = 100.0
    @State private var daily = true
    @State private var loaded = false
    @State private var message: String?
    @State private var tick = 0   // re-reads PushManager's state for the checklist

    var body: some View {
        Form {
            Section {
                switch status {
                case .authorized, .provisional, .ephemeral:
                    Label("Notifications are on for this iPhone", systemImage: "bell.badge.fill").foregroundStyle(Brand.good)
                case .denied:
                    Label("Notifications are off for Sheikha HQ", systemImage: "bell.slash.fill").foregroundStyle(Brand.bad)
                    Button("Open iPhone Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) } }
                default:
                    Button("Allow notifications") { PushManager.requestPermission(); Task { try? await Task.sleep(for: .seconds(2)); await refreshStatus() } }
                }
            }
            if status == .authorized || status == .provisional || status == .ephemeral { checklist }
            Section("Shifts") {
                Toggle("Shift closed (Z report)", isOn: $zClosed)
                Toggle("Cash short or over", isOn: $cashDiff)
                if cashDiff {
                    Stepper(value: $cashDiffMin, in: 1...500, step: cashDiffMin < 10 ? 1 : 5) {
                        LabeledContent("Only from", value: "AED " + Fmt.qty(cashDiffMin))
                    }
                }
            }
            Section("During the day") {
                Toggle("Voided sales", isOn: $voids)
                Toggle("Petty cash paid out", isOn: $payouts)
                if payouts {
                    Stepper(value: $payoutMin, in: 0...5000, step: payoutMin < 100 ? 10 : 50) {
                        LabeledContent("Only from", value: "AED " + Fmt.qty(payoutMin))
                    }
                }
            }
            Section {
                Toggle("Daily summary at 11 pm", isOn: $daily)
            } footer: {
                Text("Total sales, best branch, voids and shifts still open.")
            }
            Section {
                Button("Send test notification") {
                    Task {
                        do { try await store.sendTestNotification(); message = "Sent – the server’s answer appears below in a few seconds." }
                        catch { message = error.localizedDescription }
                    }
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                if let r = testResult { Label(r.text, systemImage: r.ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(r.ok ? Brand.good : Brand.bad) }
            } footer: {
                Text("Settings apply to every iPhone signed in as head office.")
            }
        }
        .navigationTitle("Notifications")
        .task {
            await refreshStatus()
            load()
            // already allowed: register again so a missing token is fixed, then keep the checklist fresh
            if status == .authorized { PushManager.requestPermission() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                store.saveDeviceToken()
                tick += 1
            }
        }
        .onChange(of: zClosed) { save() }
        .onChange(of: cashDiff) { save() }
        .onChange(of: cashDiffMin) { save() }
        .onChange(of: voids) { save() }
        .onChange(of: payouts) { save() }
        .onChange(of: payoutMin) { save() }
        .onChange(of: daily) { save() }
    }

    /// Each step a notification needs, so a broken one is easy to spot.
    private var checklist: some View {
        let _ = tick
        return Section {
            step("Registered with Apple", ok: PushManager.apnsRegistered, error: PushManager.registrationError)
            step("Firebase push token", ok: PushManager.token != nil, error: nil)
            step("Saved for Sheikha's server", ok: store.tokenSaved, error: store.tokenError)
        } header: {
            Text("This iPhone")
        } footer: {
            if !PushManager.apnsRegistered, PushManager.registrationError == nil {
                Text("Waiting for Apple… If this stays grey, check Signing & Capabilities → Push Notifications in Xcode.")
            }
        }
    }

    private func step(_ title: String, ok: Bool, error: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: ok ? "checkmark.circle.fill" : error != nil ? "xmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ok ? Brand.good : error != nil ? Brand.bad : .secondary)
            if let error { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
    }

    /// What the server reported for the last test (written by the notifyTest Cloud Function).
    private var testResult: (ok: Bool, text: String)? {
        guard let r = store.notify["testResult"] as? [String: Any] else { return nil }
        let sent = Int(num(r["sent"])), devices = Int(num(r["devices"]))
        let error = (r["error"] as? String) ?? ""
        if sent > 0 && error.isEmpty { return (true, "Server sent it to \(sent) iPhone\(sent == 1 ? "" : "s").") }
        if error.contains("third-party-auth-error") || error.contains("authentication credential") {
            return (false, "Apple rejected Firebase's push key. Re-upload the .p8 key in Firebase → Project settings → Cloud Messaging (check Key ID and Team ID NLYD4H32B3).")
        }
        if devices == 0 { return (false, error.isEmpty ? "No iPhone is registered yet." : error) }
        return (false, "Sent to \(sent) of \(devices). " + error)
    }

    private func refreshStatus() async { status = await PushManager.permissionStatus() }

    private func load() {
        let n = store.notify
        zClosed = (n["zClosed"] as? Bool) ?? true
        cashDiff = (n["cashDiff"] as? Bool) ?? true
        cashDiffMin = n["cashDiffMin"] == nil ? 5 : num(n["cashDiffMin"])
        voids = (n["voids"] as? Bool) ?? true
        payouts = (n["payouts"] as? Bool) ?? true
        payoutMin = n["payoutMin"] == nil ? 100 : num(n["payoutMin"])
        daily = (n["daily"] as? Bool) ?? true
        DispatchQueue.main.async { loaded = true }
    }

    private func save() {
        guard loaded else { return }
        let values: [String: Any] = ["zClosed": zClosed, "cashDiff": cashDiff, "cashDiffMin": cashDiffMin,
                                     "voids": voids, "payouts": payouts, "payoutMin": payoutMin, "daily": daily]
        Task { try? await store.saveNotify(values) }
    }
}
