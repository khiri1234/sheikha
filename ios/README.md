# Sheikha HQ – head-office iPhone app

A native SwiftUI app for **head office only** (signs in with `sheikhatextiles@gmail.com`).
It uses the same Firebase project and security rules as the web POS, so everything it
shows is live from the branches.

| Tab | What it does |
|---|---|
| **Dashboard** | Today (live) / Yesterday / This month / Last month: total sales with change vs the previous period, bills, average bill, VAT, cash/card, discounts, voids, branch ranking, sales by hour/day chart (tap for values), top fabrics, *Needs attention* (old held bills, idle branches, voids, cash differences, shifts left open, high discounts). Share the summary. |
| **Branches** | Each branch's sales today, open shift (float, payouts), recent Z reports, and **cashiers**: add, remove/restore, new PIN (works at the tills straight away). Call the branch. |
| **Sales** | Invoices for any day, one or all branches, with totals; invoice detail and **void**; VAT 201 totals per quarter (box 1a Abu Dhabi). |
| **Z reports** | All branches' closed shifts with over/short, totals and payouts; full Z detail; send by WhatsApp or share. |
| **More** | Fabric prices and barcodes, the WhatsApp number / email branches send Z reports to, Face ID lock, sign out. |

Branch set-up, logins, receipts and other settings stay in the POS on a computer.

---

## What you need
- A **Mac** with **Xcode 15 or newer** (free from the Mac App Store).
- An **Apple ID**. To keep the app on your iPhone long-term or install it through TestFlight
  you need the **Apple Developer Program** (USD 99 / year).
- About 30 minutes the first time.

## 1. Register the iPhone app in Firebase (5 minutes)
1. https://console.firebase.google.com → project **sheikha-pos** → ⚙️ **Project settings**.
2. **Your apps → Add app → iOS** (the Apple icon).
3. Apple bundle ID: `ae.sheikhatextiles.hq` (or your own – then change
   `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to match). App nickname: `Sheikha HQ`.
4. **Register app**, then **Download GoogleService-Info.plist**. Skip the remaining steps
   in the wizard (the code is already done).
5. Put `GoogleService-Info.plist` into the `ios/SheikhaHQ/` folder (next to `App`, `Views`…).

## 2. Create the Xcode project (2 commands)
The project is described in `project.yml` and generated with XcodeGen:

```bash
# once: install Homebrew from https://brew.sh, then
brew install xcodegen

# every time project.yml changes
cd path/to/sheikha/ios
xcodegen
open SheikhaHQ.xcodeproj
```

Xcode downloads the Firebase libraries on first open (a few minutes – see the progress at
the top of the window).

## 3. Sign and run on your iPhone
1. In Xcode, click **SheikhaHQ** (blue icon, top left) → target **SheikhaHQ** →
   **Signing & Capabilities** → **Team**: choose your Apple ID / developer team.
2. Connect the iPhone with a cable (or same Wi-Fi), unlock it, and pick it at the top of
   Xcode as the run destination. On the iPhone: **Settings → Privacy & Security →
   Developer Mode → On** (first time only).
3. Press **▶ Run**. With a free Apple ID, also allow it on the iPhone under
   **Settings → General → VPN & Device Management**. (Free Apple ID builds stop opening
   after 7 days – just run again from Xcode. A paid developer account avoids this.)
4. Sign in with `sheikhatextiles@gmail.com` and its password.

## 4. Install through TestFlight (recommended for daily use)
With the Apple Developer Program:
1. https://appstoreconnect.apple.com → **Apps → +** → New App: iOS, name *Sheikha HQ*,
   bundle ID `ae.sheikhatextiles.hq`, SKU `sheikha-hq`.
2. In Xcode: choose **Any iOS Device (arm64)** → **Product → Archive** → **Distribute App →
   App Store Connect → Upload**.
3. In App Store Connect → **TestFlight**, add yourself (and anyone else at head office) as
   an internal tester. Install **TestFlight** from the App Store on the iPhone and accept the
   invite. TestFlight builds last 90 days; upload a new build before then.

The app doesn't need to be public on the App Store. If you ever want that, submit the
same build for review from App Store Connect (Apple may ask for a demo login).

## Updating the app
After changes to the code: `git pull`, run `xcodegen` again, then **Run** (or Archive and
upload a new TestFlight build – increase `CURRENT_PROJECT_VERSION` in `project.yml` first).

## Notes
- Only the head-office login can use the app; branch logins are refused.
- Cashier PINs set here are hashed exactly like the web POS
  (`SHA-256("sheikha-pos|<branch id>|<PIN>")`), so they work at the tills immediately.
- Firestore keeps a copy on the phone, so the last data stays visible without internet.
- The code was written and syntax-checked without a Mac. If Xcode shows a build error,
  copy the error text and send it over – it will be a small fix.
