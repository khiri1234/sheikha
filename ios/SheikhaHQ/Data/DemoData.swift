import Foundation

/// Sample shop for App Review and demonstrations. Signing in with Config.demoEmail and
/// Config.demoPassword shows this instead of the live database: about two months of
/// sales for eight made-up branches, with shifts, Z reports, payouts, voids and held
/// bills. Nothing is read from or written to Firebase in demo mode.
struct DemoData {
    var branches: [Branch] = []
    var fabrics: [Fabric] = []
    var sales: [Sale] = []
    var shifts: [Shift] = []
    var held: [HeldBill] = []
    var settings = ShopSettings()

    /// Small repeatable random generator, so the demo looks the same every time.
    private struct RNG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() * Double(range.count)) }
        mutating func pick<T>(_ list: [T]) -> T { list[Int(next() * Double(list.count))] }
    }

    private static let branchNames = ["Al Wahda", "Mussafah", "Khalifa City", "Al Ain", "Baniyas", "Shahama", "Ruwais", "Madinat Zayed"]
    private static let people = ["Ahmed", "Sara", "Omar", "Fatima", "Yousef", "Mariam", "Khalid", "Aisha", "Hassan", "Noura", "Ali", "Layla", "Saeed", "Huda", "Rashid", "Amna"]
    private static let fabricList: [(name: String, price: Double)] = [
        ("Swiss Voile", 45), ("Japanese Polyester", 28), ("Cotton Lawn", 22), ("Kandura Cloth", 35),
        ("Linen Blend", 40), ("Silk Chiffon", 65), ("Embroidered Lace", 85), ("Abaya Crepe", 30)
    ]
    private static let payoutReasons = ["Delivery charge", "Cleaning", "Tea and water", "Taxi"]

    init(now: Date = Date()) {
        var rng = RNG(state: 20_261_004)
        let cal = Calendar.current

        settings = ShopSettings([
            "name": "SHEIKHA TEXTILES (DEMO)", "trn": "100000000000003", "vat": 5.0,
            "waNumber": "971500000000", "reportEmail": "reports@example.com"
        ])

        for i in 1...8 {
            let id = "demo-b\(i)"
            let first: [String: Any] = ["id": id + "-c1", "name": Self.people[(i - 1) * 2], "pin": "demo", "active": true]
            let second: [String: Any] = ["id": id + "-c2", "name": Self.people[(i - 1) * 2 + 1], "pin": "demo", "active": true]
            let d: [String: Any] = [
                "id": id, "code": "B\(i)", "name": Self.branchNames[i - 1],
                "address": Self.branchNames[i - 1] + ", United Arab Emirates", "phone": "+971 2 000 00\(10 + i)",
                "cashiers": [first, second]
            ]
            branches.append(Branch(d))
        }

        for (i, f) in Self.fabricList.enumerated() {
            let d: [String: Any] = ["id": "demo-f\(i)", "name": f.name, "unit": "m", "price": Fmt.qty(f.price),
                                    "barcode": "62900000\(100 + i)", "cat": "Fabric", "order": Double(i)]
            fabrics.append(Fabric(d))
        }

        let today = cal.startOfDay(for: now)
        var billNo: [String: Int] = [:]
        var zNo: [String: Int] = [:]

        for back in stride(from: 62, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -back, to: today),
                  let openAt = cal.date(byAdding: .hour, value: 9, to: day),
                  let closeAt = cal.date(byAdding: .minute, value: 22 * 60 + 30, to: day) else { continue }
            if back == 0 && now < openAt { continue }   // today's shifts have not opened yet

            for (bi, b) in branches.enumerated() {
                let busy = 1.0 - Double(bi) * 0.08
                let count = Int(Double(rng.int(6...14)) * busy)
                var daySales: [Sale] = []

                for _ in 0..<count {
                    guard let t = cal.date(byAdding: .minute, value: 9 * 60 + rng.int(0...(13 * 60)), to: day), t <= now else { continue }
                    billNo[b.id, default: 0] += 1
                    let n = billNo[b.id] ?? 0

                    var lines: [[String: Any]] = []
                    var gross = 0.0
                    for _ in 0..<rng.int(1...3) {
                        let f = rng.pick(Self.fabricList)
                        let qty = Double(rng.int(2...12)) / 2
                        let g = r2(qty * f.price)
                        let net = r2(g / 1.05)
                        gross += g
                        lines.append(["name": f.name, "unit": "m", "price": f.price, "qty": qty, "mode": "incl",
                                      "gross": g, "net": net, "vat": r2(g - net)])
                    }
                    gross = r2(gross)
                    let disc = rng.next() < 0.15 ? r2(gross * 0.05) : 0
                    let total = r2(gross - disc)
                    let net = r2(total / 1.05)
                    let card = rng.next() < 0.42
                    let void = rng.next() < 0.02
                    let tendered = card ? total : (total / 50).rounded(.up) * 50
                    let d: [String: Any] = [
                        "id": "\(b.id)-s\(n)", "no": b.code + "-" + String(format: "%06d", n), "ts": Fmt.ms(t),
                        "branch": b.id, "branchName": b.name, "cashier": rng.pick(b.cashiers).name,
                        "method": card ? "card" : "cash", "status": void ? "void" : "paid", "lines": lines,
                        "sumGross": gross, "disc": disc, "net": net, "vat": r2(total - net), "total": total,
                        "tendered": tendered, "change": r2(tendered - total), "vatRate": 5.0
                    ]
                    daySales.append(Sale(d))
                }
                sales += daySales
                shifts.append(Self.shift(for: b, day: back, sales: daySales, openAt: openAt, closeAt: closeAt,
                                         open: back == 0, rng: &rng, zNo: &zNo))
            }
        }
        sales.sort { $0.ts < $1.ts }

        held = [
            HeldBill(["id": "demo-h1", "ts": Fmt.ms(now.addingTimeInterval(-3 * 3600)), "total": 240.0], branch: branches[2].id),
            HeldBill(["id": "demo-h2", "ts": Fmt.ms(now.addingTimeInterval(-20 * 60)), "total": 96.5], branch: branches[0].id)
        ]
    }

    /// One shift per branch per day: opened at 9:00 with a float, closed at 22:30 with a Z report.
    private static func shift(for b: Branch, day: Int, sales: [Sale], openAt: Date, closeAt: Date, open: Bool,
                              rng: inout RNG, zNo: inout [String: Int]) -> Shift {
        let paid = sales.filter { !$0.isVoid }
        let cashSales = paid.filter { !$0.isCard }, cardSales = paid.filter(\.isCard)
        let cash = r2(cashSales.reduce(0) { $0 + $1.total })
        let card = r2(cardSales.reduce(0) { $0 + $1.total })
        let float = 300.0

        var moves: [[String: Any]] = []
        var paidOut = 0.0
        if rng.next() < 0.3 {
            paidOut = Double(rng.int(1...12)) * 10
            moves.append(["id": "\(b.id)-m\(day)", "ts": Fmt.ms(openAt.addingTimeInterval(3 * 3600)), "type": "out",
                          "amount": paidOut, "reason": rng.pick(payoutReasons), "cashier": b.cashiers[0].name])
        }
        let expected = r2(float + cash - paidOut)

        var byCashier: [String: Any] = [:]
        for c in b.cashiers {
            let mine = paid.filter { $0.cashier == c.name }
            if mine.isEmpty { continue }
            byCashier[c.name] = ["bills": Double(mine.count), "total": r2(mine.reduce(0) { $0 + $1.total })] as [String: Any]
        }
        let voided = sales.filter(\.isVoid)
        let total = r2(cash + card)
        let summary: [String: Any] = [
            "bills": Double(paid.count), "gross": r2(paid.reduce(0) { $0 + $1.sumGross }), "disc": r2(paid.reduce(0) { $0 + $1.disc }),
            "net": r2(paid.reduce(0) { $0 + $1.net }), "vat": r2(paid.reduce(0) { $0 + $1.vat }), "total": total,
            "cash": cash, "card": card, "cashN": Double(cashSales.count), "cardN": Double(cardSales.count),
            "voidN": Double(voided.count), "voidTotal": r2(voided.reduce(0) { $0 + $1.total }),
            "paidOut": paidOut, "paidIn": 0.0, "expectedCash": expected, "byCashier": byCashier
        ]
        var d: [String: Any] = [
            "id": "\(b.id)-sh\(day)", "branch": b.id, "status": open ? "open" : "closed",
            "openedAt": Fmt.ms(openAt), "openedBy": b.cashiers[0].name, "openingFloat": float,
            "moves": moves, "expectedCash": expected, "summary": summary
        ]
        if !open {
            zNo[b.id, default: 0] += 1
            let diff = rng.next() < 0.12 ? Double(rng.int(-30...20)) : 0
            d["zNo"] = b.code + "-Z" + String(format: "%04d", zNo[b.id] ?? 0)
            d["closedAt"] = Fmt.ms(closeAt)
            d["closedBy"] = b.cashiers[1].name
            d["countedCash"] = r2(expected + diff)
            d["diff"] = diff
        }
        return Shift(d)
    }
}
