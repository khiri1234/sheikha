import SwiftUI

/// ▲ 12% vs yesterday – green when the change is good, red when bad.
struct DeltaPill: View {
    var current: Double
    var previous: Double
    var label: String = ""
    var upIsGood = true
    /// white text for use on a coloured background
    var onColor = false

    var body: some View {
        let (text, color) = info
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(onColor ? Color.white.opacity(0.22) : color.opacity(0.12), in: Capsule())
            .foregroundStyle(onColor ? Color.white : color)
    }
    private var info: (String, Color) {
        if previous == 0 && current == 0 { return ("– no change", .secondary) }
        if previous == 0 { return ("new", .secondary) }
        let pc = (current - previous) / previous * 100
        if abs(pc) < 0.5 { return ("– same" + (label.isEmpty ? "" : " as \(label)"), .secondary) }
        let up = pc >= 0, good = upIsGood ? up : !up
        let n = abs(pc) < 10 ? String(format: "%.1f", abs(pc)) : String(format: "%.0f", abs(pc))
        return ((up ? "▲ " : "▼ ") + n + "%" + (label.isEmpty ? "" : " vs \(label)"), good ? Brand.good : Brand.bad)
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var footnote: String? = nil
    var delta: DeltaPill? = nil
    var icon: String? = nil
    var tint: Color = .secondary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let icon {
                    Image(systemName: icon).font(.caption.weight(.semibold)).foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(tint.opacity(0.12), in: Circle())
                }
            }
            Text(value).font(.system(.title3, design: .monospaced).weight(.bold)).minimumScaleFactor(0.6).lineLimit(1)
            if let delta { delta }
            if let footnote { Text(footnote).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
    }
}

/// Opens WhatsApp addressed to the head-office number with the text filled in.
func whatsAppURL(_ text: String, number: String) -> URL? {
    let digits = number.filter(\.isNumber)
    var c = URLComponents(string: "https://wa.me/" + digits)
    c?.queryItems = [URLQueryItem(name: "text", value: text)]
    return c?.url
}

struct ShareButtons: View {
    var text: String
    var subject: String
    @Environment(HQStore.self) private var store
    @Environment(\.openURL) private var openURL
    var body: some View {
        HStack {
            Button {
                if let u = whatsAppURL(text, number: store.settings.waNumber) { openURL(u) }
            } label: { Label("WhatsApp", systemImage: "message.fill") }
            .buttonStyle(.borderedProminent)
            ShareLink(item: text, subject: Text(subject)) { Label("Share", systemImage: "square.and.arrow.up") }
                .buttonStyle(.bordered)
        }
    }
}

struct ErrorRow: View {
    var message: String
    var body: some View {
        Label(message, systemImage: "wifi.exclamationmark").font(.footnote).foregroundStyle(.red)
    }
}
