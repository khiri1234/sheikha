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
                        do { try await store.sendTestNotification(); message = "Sent – it should arrive within a few seconds." }
                        catch { message = error.localizedDescription }
                    }
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            } footer: {
                Text("Settings apply to every iPhone signed in as head office.")
            }
        }
        .navigationTitle("Notifications")
        .task {
            await refreshStatus()
            load()
        }
        .onChange(of: zClosed) { save() }
        .onChange(of: cashDiff) { save() }
        .onChange(of: cashDiffMin) { save() }
        .onChange(of: voids) { save() }
        .onChange(of: payouts) { save() }
        .onChange(of: payoutMin) { save() }
        .onChange(of: daily) { save() }
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
