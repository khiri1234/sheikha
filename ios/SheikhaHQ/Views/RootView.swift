import SwiftUI
import LocalAuthentication

struct RootView: View {
    @Environment(HQStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("faceIDLock") private var faceIDLock = false
    @State private var locked = true

    var body: some View {
        Group {
            switch store.phase {
            case .loading:
                ProgressView("Connecting…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                LoginView(message: nil)
            case .denied(let msg):
                LoginView(message: msg)
            case .ready:
                MainTabs()
                    .overlay {
                        if faceIDLock && locked { LockView(unlock: unlock) }
                    }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { locked = true }
            if phase == .active {
                store.refreshToday()
                if faceIDLock && locked { unlock() }
            }
        }
        .onAppear { if faceIDLock { unlock() } else { locked = false } }
    }

    private func unlock() {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { locked = false; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Sheikha HQ") { ok, _ in
            Task { @MainActor in if ok { locked = false } }
        }
    }
}

struct LockView: View {
    var unlock: () -> Void
    var body: some View {
        ZStack {
            Brand.charcoal.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(Brand.orange)
                Text("Sheikha HQ is locked").font(.title3.bold()).foregroundStyle(.white)
                Button("Unlock", action: unlock).buttonStyle(.borderedProminent)
            }
        }
    }
}

struct MainTabs: View {
    @Environment(HQStore.self) private var store
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "chart.bar.xaxis") }
            NavigationStack { BranchesView() }
                .tabItem { Label("Branches", systemImage: "building.2") }
            NavigationStack { SalesView() }
                .tabItem { Label("Sales", systemImage: "doc.text.magnifyingglass") }
            NavigationStack { ZReportsView() }
                .tabItem { Label("Z reports", systemImage: "banknote") }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.isDemo {
                Text("Demo mode – sample data, not a real shop")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                    .background(Brand.orange)
            }
        }
    }
}

struct LoginView: View {
    @Environment(HQStore.self) private var store
    var message: String?
    @State private var email = Config.hqEmail
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            Brand.charcoal.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                VStack(spacing: 4) {
                    Text("SHEIKHA TEXTILES").font(.title2.weight(.heavy)).foregroundStyle(.white)
                    Text("Head office").font(.headline).foregroundStyle(Brand.orange)
                }
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(.password)
                }
                .textFieldStyle(.roundedBorder)
                if let e = error ?? message {
                    Text(e).font(.footnote.weight(.semibold)).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button {
                    Task { await signIn() }
                } label: {
                    Text(busy ? "Signing in…" : "Sign in").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy || email.isEmpty || password.isEmpty)
                Spacer()
                Text("Branch staff use the POS on the branch computer.").font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
    }

    private func signIn() async {
        busy = true; error = nil
        do { try await store.signIn(email: email, password: password) }
        catch {
            let code = (error as NSError).code
            self.error = [17004, 17009, 17011, 17008].contains(code) ? "Wrong email or password." :
                code == 17020 ? "No internet connection." :
                code == 17010 ? "Too many attempts. Wait a few minutes." : error.localizedDescription
        }
        busy = false
    }
}
