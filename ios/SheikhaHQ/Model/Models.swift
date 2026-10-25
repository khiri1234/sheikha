import Foundation

// Firestore stores numbers as Int64 or Double, and the web POS sometimes stores prices as text.
func num(_ v: Any?) -> Double {
    if let d = v as? Double { return d }
    if let i = v as? Int { return Double(i) }
    if let i = v as? Int64 { return Double(i) }
    if let n = v as? NSNumber { return n.doubleValue }
    if let s = v as? String { return Double(s) ?? 0 }
    return 0
}
func str(_ v: Any?) -> String {
    if let s = v as? String { return s }
    if let v = v { return "\(v)" }
    return ""
}
/// Round to fils the same way the web POS does.
func r2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

struct Branch: Identifiable, Hashable {
    var id: String
    var code: String
    var name: String
    var address: String
    var phone: String
    var email: String
    var cashiers: [Cashier]

    init(_ d: [String: Any]) {
        id = str(d["id"]); code = str(d["code"]); name = str(d["name"])
        address = str(d["address"]); phone = str(d["phone"]); email = str(d["email"])
        cashiers = (d["cashiers"] as? [[String: Any]] ?? []).map(Cashier.init)
    }
    var activeCashiers: [Cashier] { cashiers.filter { $0.active } }
}

struct Cashier: Identifiable, Hashable {
    var id: String
    var name: String
    var pin: String      // SHA-256 hash, never the PIN itself
    var active: Bool

    init(_ d: [String: Any]) {
        id = str(d["id"]); name = str(d["name"]); pin = str(d["pin"])
        active = (d["active"] as? Bool) ?? true
    }
    init(id: String, name: String, pin: String, active: Bool) {
        self.id = id; self.name = name; self.pin = pin; self.active = active
    }
    var dict: [String: Any] { ["id": id, "name": name, "pin": pin, "active": active] }
}

struct SaleLine: Hashable {
    var name: String
    var unit: String
    var price: Double
    var qty: Double
    var mode: String
    var gross: Double
    var net: Double
    var vat: Double

    init(_ d: [String: Any]) {
        name = str(d["name"]); unit = str(d["unit"]); mode = str(d["mode"])
        price = num(d["price"]); qty = num(d["qty"])
        gross = num(d["gross"]); net = num(d["net"]); vat = num(d["vat"])
    }
}

struct Sale: Identifiable, Hashable {
    var id: String
    var no: String
    var ts: Double
    var branch: String
    var branchName: String
    var cashier: String
    var method: String
    var status: String
    var lines: [SaleLine]
    var sumGross: Double
    var disc: Double
    var net: Double
    var vat: Double
    var total: Double
    var tendered: Double
    var change: Double
    var ref: String
    var vatRate: Double
    var cashAmt: Double
    var cardAmt: Double
    var kind: String
    var origNo: String
    var reason: String

    init(_ d: [String: Any]) {
        id = str(d["id"]); no = str(d["no"]); ts = num(d["ts"])
        branch = str(d["branch"]); branchName = str(d["branchName"]); cashier = str(d["cashier"])
        method = str(d["method"]); status = str(d["status"])
        lines = (d["lines"] as? [[String: Any]] ?? []).map(SaleLine.init)
        sumGross = num(d["sumGross"]); disc = num(d["disc"]); net = num(d["net"]); vat = num(d["vat"]); total = num(d["total"])
        tendered = num(d["tendered"]); change = num(d["change"]); ref = str(d["ref"])
        vatRate = d["vatRate"] == nil ? 5 : num(d["vatRate"])
        cashAmt = num(d["cashAmt"]); cardAmt = num(d["cardAmt"])
        kind = str(d["kind"]); origNo = str(d["origNo"]); reason = str(d["reason"])
    }
    var date: Date { Date(timeIntervalSince1970: ts / 1000) }
    var isVoid: Bool { status == "void" }
    var isCard: Bool { method == "card" }
    var isSplit: Bool { method == "split" }
    var isBank: Bool { method == "bank" }
    /// A return (credit note): minus amounts that take a refund off sales, VAT and the cash drawer.
    var isReturn: Bool { kind == "return" }
    /// Cash, card and bank-transfer parts of the bill (a split bill counts in cash and card).
    var cashPart: Double { isSplit ? cashAmt : (isCard || isBank ? 0 : total) }
    var cardPart: Double { isSplit ? cardAmt : (isCard ? total : 0) }
    var bankPart: Double { isBank ? total : 0 }
    var methodName: String {
        if isReturn { return isCard ? "Card refund" : isBank ? "Bank refund" : "Cash refund" }
        return isSplit ? "Cash + Card" : isCard ? "Card" : isBank ? "Bank transfer" : "Cash"
    }
}

struct CashMove: Identifiable, Hashable {
    var id: String
    var ts: Double
    var type: String
    var amount: Double
    var reason: String
    var cashier: String
    init(_ d: [String: Any]) {
        id = str(d["id"]); ts = num(d["ts"]); type = str(d["type"]); amount = num(d["amount"])
        reason = str(d["reason"]); cashier = str(d["cashier"])
    }
    var isOut: Bool { type == "out" }
}

struct ShiftSummary: Hashable {
    var bills = 0.0, gross = 0.0, disc = 0.0, net = 0.0, vat = 0.0, total = 0.0
    var cash = 0.0, card = 0.0, cashN = 0.0, cardN = 0.0, voidN = 0.0, voidTotal = 0.0, retN = 0.0, retTotal = 0.0
    var bank = 0.0, bankN = 0.0
    var paidOut = 0.0, paidIn = 0.0, expectedCash = 0.0
    var byCashier: [String: (bills: Double, total: Double)] = [:]

    init(_ d: [String: Any]?) {
        guard let d else { return }
        bills = num(d["bills"]); gross = num(d["gross"]); disc = num(d["disc"]); net = num(d["net"]); vat = num(d["vat"]); total = num(d["total"])
        cash = num(d["cash"]); card = num(d["card"]); cashN = num(d["cashN"]); cardN = num(d["cardN"])
        bank = num(d["bank"]); bankN = num(d["bankN"])
        voidN = num(d["voidN"]); voidTotal = num(d["voidTotal"]); retN = num(d["retN"]); retTotal = num(d["retTotal"])
        paidOut = num(d["paidOut"]); paidIn = num(d["paidIn"]); expectedCash = num(d["expectedCash"])
        for (k, v) in ((d["byCashier"] as? [String: Any]) ?? [:]) {
            let o = (v as? [String: Any]) ?? [:]
            byCashier[k] = (num(o["bills"]), num(o["total"]))
        }
    }
    static func == (a: ShiftSummary, b: ShiftSummary) -> Bool { a.total == b.total && a.bills == b.bills && a.expectedCash == b.expectedCash }
    func hash(into h: inout Hasher) { h.combine(total); h.combine(bills) }
}

struct Shift: Identifiable, Hashable {
    var id: String
    var branch: String
    var status: String
    var zNo: String
    var openedAt: Double
    var openedBy: String
    var closedAt: Double
    var closedBy: String
    var openingFloat: Double
    var countedCash: Double
    var expectedCash: Double
    var diff: Double
    var note: String
    var moves: [CashMove]
    var summary: ShiftSummary

    init(_ d: [String: Any]) {
        id = str(d["id"]); branch = str(d["branch"]); status = str(d["status"]); zNo = str(d["zNo"])
        openedAt = num(d["openedAt"]); openedBy = str(d["openedBy"])
        closedAt = num(d["closedAt"]); closedBy = str(d["closedBy"])
        openingFloat = num(d["openingFloat"]); countedCash = num(d["countedCash"])
        expectedCash = num(d["expectedCash"]); diff = num(d["diff"]); note = str(d["note"])
        moves = (d["moves"] as? [[String: Any]] ?? []).map(CashMove.init)
        summary = ShiftSummary(d["summary"] as? [String: Any])
    }
    var isClosed: Bool { status == "closed" }
    var opened: Date { Date(timeIntervalSince1970: openedAt / 1000) }
    var closed: Date? { closedAt > 0 ? Date(timeIntervalSince1970: closedAt / 1000) : nil }
}

struct HeldBill: Identifiable, Hashable {
    var id: String
    var branch: String
    var ts: Double
    var total: Double
    init(_ d: [String: Any], branch: String) {
        id = str(d["id"]); self.branch = branch; ts = num(d["ts"]); total = num(d["total"])
    }
}

struct Fabric: Identifiable, Hashable {
    var id: String
    var name: String
    var cat: String
    var unit: String
    var price: String
    var barcode: String
    var color: String
    var order: Double
    init(_ d: [String: Any]) {
        id = str(d["id"]); name = str(d["name"]); cat = str(d["cat"]); unit = str(d["unit"])
        price = d["price"] == nil ? "" : str(d["price"]); barcode = str(d["barcode"]); color = str(d["color"]); order = num(d["order"])
    }
}

struct ShopSettings {
    var name = "SHEIKHA TEXTILES"
    var nameAr = "الشيخة للأقمشة"
    var trn = ""
    var vat = 5.0
    var waNumber = ""
    var reportEmail = ""
    init() {}
    init(_ d: [String: Any]) {
        if let v = d["name"] as? String, !v.isEmpty { name = v }
        if let v = d["nameAr"] as? String { nameAr = v }
        trn = str(d["trn"]); vat = d["vat"] == nil ? 5 : num(d["vat"])
        waNumber = str(d["waNumber"]); reportEmail = str(d["reportEmail"])
    }
}

/// Totals for a list of sales – the same rules as agg() in the web POS (voided bills left out).
struct Totals {
    var bills = 0, gross = 0.0, disc = 0.0, net = 0.0, vat = 0.0, total = 0.0
    var cash = 0.0, card = 0.0, cashN = 0, cardN = 0, voidN = 0, voidTotal = 0.0, retN = 0, retTotal = 0.0
    var bank = 0.0, bankN = 0

    init(_ list: [Sale]) {
        for s in list {
            if s.isVoid { voidN += 1; voidTotal += s.total; continue }
            if s.isReturn { retN += 1; retTotal -= s.total } else { bills += 1 }
            gross += s.sumGross; disc += s.disc; net += s.net; vat += s.vat; total += s.total
            if s.cardPart > 0 { card += s.cardPart; cardN += 1 }
            if s.cashPart > 0 { cash += s.cashPart; cashN += 1 }
            if s.bankPart > 0 { bankN += 1 }
            bank += s.bankPart
        }
        gross = r2(gross); disc = r2(disc); net = r2(net); vat = r2(vat); total = r2(total)
        cash = r2(cash); card = r2(card); bank = r2(bank); voidTotal = r2(voidTotal); retTotal = r2(retTotal)
    }
    var average: Double { bills > 0 ? total / Double(bills) : 0 }
}

struct FabricSold: Identifiable {
    var id: String { name + "|" + unit }
    var name: String
    var unit: String
    var qty: Double
    var total: Double
}

/// Sales per fabric, discounts spread over the lines – same as byItem() in the web POS.
func fabricsSold(_ list: [Sale]) -> [FabricSold] {
    var map: [String: FabricSold] = [:]
    for s in list where !s.isVoid {
        let f = s.sumGross > 0 ? s.total / s.sumGross : 0
        for l in s.lines {
            let k = l.name + "|" + l.unit
            var o = map[k] ?? FabricSold(name: l.name, unit: l.unit, qty: 0, total: 0)
            o.qty = r2(o.qty + l.qty); o.total = r2(o.total + r2(l.gross * f))
            map[k] = o
        }
    }
    return map.values.sorted { $0.total > $1.total }
}

/// A choice in the Type and Paid by lists – ids match the web POS.
struct PurchaseOption: Identifiable, Hashable {
    let id: String
    let label: String
    init(_ id: String, _ label: String) { self.id = id; self.label = label }
}

/// A supplier bill entered under Purchases (purchases/{id}) – same fields as the web POS.
struct Purchase: Identifiable, Hashable {
    static let types: [PurchaseOption] = [
        .init("stock", "Fabric stock"), .init("rent", "Rent"), .init("utilities", "Electricity, water & internet"),
        .init("supplies", "Shop supplies & packing"), .init("transport", "Transport & delivery"),
        .init("repairs", "Repairs & maintenance"), .init("services", "Services & fees"), .init("other", "Other")
    ]
    static let payments: [PurchaseOption] = [
        .init("bank", "Bank transfer"), .init("cash", "Cash"), .init("card", "Card"), .init("cheque", "Cheque"), .init("credit", "On credit (not paid yet)")
    ]
    static func typeLabel(_ id: String) -> String { types.first { $0.id == id }?.label ?? id }
    static func paymentLabel(_ id: String) -> String { payments.first { $0.id == id }?.label ?? id }

    var id: String
    /// bill date as YYYY-MM-DD
    var date: String
    var supplier: String
    var trn: String
    var invNo: String
    /// branch id, or "hq" for head office
    var branch: String
    var cat: String
    var desc: String
    var net: Double
    var vat: Double
    var total: Double
    var paid: String
    var ts: Double
    var by: String

    init(_ d: [String: Any]) {
        id = str(d["id"]); date = str(d["date"]); supplier = str(d["supplier"]); trn = str(d["trn"]); invNo = str(d["invNo"])
        branch = str(d["branch"]).isEmpty ? "hq" : str(d["branch"]); cat = str(d["cat"]); desc = str(d["desc"])
        net = num(d["net"]); vat = num(d["vat"]); total = num(d["total"]); paid = str(d["paid"])
        ts = num(d["ts"]); by = str(d["by"])
    }
    /// A new, empty bill dated today.
    init() {
        self.init(["id": "p" + UUID().uuidString.prefix(10).lowercased(), "date": Fmt.ymd(Date()), "cat": "stock", "paid": "bank", "branch": "hq"])
    }
    var dict: [String: Any] {
        ["id": id, "date": date, "supplier": supplier, "trn": trn, "invNo": invNo, "branch": branch, "cat": cat, "desc": desc,
         "net": net, "vat": vat, "total": total, "paid": paid, "ts": ts, "by": by]
    }
    var day: Date { Fmt.parseYMD(date) ?? Date() }
    var isUnpaid: Bool { paid == "credit" }
}

struct PurchaseTotals {
    var bills = 0, net = 0.0, vat = 0.0, total = 0.0, unpaid = 0.0
    init(_ list: [Purchase]) {
        for p in list {
            bills += 1; net += p.net; vat += p.vat; total += p.total
            if p.isUnpaid { unpaid += p.total }
        }
        net = r2(net); vat = r2(vat); total = r2(total); unpaid = r2(unpaid)
    }
}
