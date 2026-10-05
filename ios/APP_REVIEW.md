# Submitting Sheikha HQ to App Review

Everything App Store Connect asks for, ready to paste. Build **1.0 (4)** or later.

## 0. Choose how the app is distributed

Sheikha HQ is for one company's head office, so a normal public App Store listing risks
rejection under guideline 3.2 (apps for a single business's internal use). Choose one:

| Option | Who can install | Review | Recommended |
|---|---|---|---|
| **Unlisted App Distribution** | Anyone with the direct link; not searchable on the App Store | Full App Review | **Yes** |
| TestFlight only (what you use now) | Testers you invite | Light beta review | Fine, but each build expires after 90 days |
| Apple Business Manager custom app | Only Sheikha's own Apple Business Manager account | Full App Review | Needs a D-U-N-S number |

For **Unlisted**: submit the app normally (steps below), choose *Public* availability, then fill
in Apple's request form at https://developer.apple.com/support/unlisted-app-distribution/
with the app's Apple ID. Apple switches it to unlisted after approval. Mention it in the review
notes too (already included below).

## 1. Before you start

- [ ] `privacy.html` and `support.html` are live on GitHub Pages, so they must be on the `main` branch.
      Check that both links in step 3 open.
- [ ] In the POS on a computer: **Settings → TRN** filled in, and branch names tidy
      (**Branches**, e.g. "b6" → proper name). The app shows these.
- [ ] On the Mac: `cd ~/sheikha && git pull && cd ios && xcodegen`, open the project, then
      **Product → Archive → Distribute App → App Store Connect → Upload**.

## 2. App Information (App Store Connect → your app → App Information)

| Field | Value |
|---|---|
| Name | `Sheikha HQ` (if taken: `Sheikha HQ – Head Office`) |
| Subtitle | `Live sales for head office` |
| Category | Primary **Business**, secondary **Productivity** |
| Content rights | Does not contain third-party content |
| Age rating | Answer **None / No** to every question → **4+** |

## 3. Version page (1.0)

**Promotional text**
```
Every Sheikha Textiles branch, live on your iPhone: sales, shifts, Z reports and alerts.
```

**Description**
```
Sheikha HQ is the head-office app for Sheikha Textiles. It shows what is happening in every branch, live, from the shop POS computers.

DASHBOARD
• Total sales for today, yesterday, this month or last month, compared with the period before
• Bills, average bill, VAT, cash and card, discounts and voids
• Branches ranked from best to lowest, sales by hour or by day, and top fabrics
• "Needs attention": held bills waiting, branches with no sales, voids, cash differences and shifts left open
• Share the summary by WhatsApp or email

BRANCHES
• Each branch's sales today, open shift and recent Z reports
• Add or remove cashiers and change their PINs – it works at the tills straight away

SALES AND VAT
• Every invoice by day and branch, with full details
• Void a sale (it stays on record, marked void)
• VAT 201 totals per quarter

Z REPORTS
• All closed shifts with expected and counted cash, over or short, and petty cash payouts
• Send any Z report by WhatsApp

NOTIFICATIONS
• Shift closed, cash short or over, voids and large payouts, and a daily summary at 11 pm

Face ID lock, light and dark mode. Sign-in is for the Sheikha Textiles head office only.
```

**Keywords** (100 characters max)
```
POS,sales,dashboard,branches,Z report,VAT,shift,cashier,retail,textiles,fabric,head office
```

| Field | Value |
|---|---|
| Support URL | `https://khiri1234.github.io/sheikha/support.html` |
| Marketing URL | `https://khiri1234.github.io/sheikha/hq.html` |
| Privacy Policy URL (App Privacy page) | `https://khiri1234.github.io/sheikha/privacy.html` |
| Copyright | `2026 Sheikha Textiles LLC` |
| Version | `1.0` |

### Screenshots (required: iPhone 6.9", 1320 × 2868)

The easiest way to get the exact size, with nice data:
1. In Xcode choose the **iPhone 17 Pro Max** (or 16 Pro Max) simulator and press **Run**.
2. Sign in with the demo account below. The app fills with two months of sample sales.
3. Press **⌘S** in the Simulator on each screen; files land on the Desktop at the right size.

Take 5: **Dashboard** (top), **Dashboard** scrolled to the chart and *Needs attention*,
**Branches → a branch**, **Sales** with an invoice open, **Z reports → a Z report**.
Appearance can be Light or Dark; pick one and keep it for all five.

## 4. App Review Information

**Sign-in required:** Yes

| Field | Value |
|---|---|
| User name | `demo@sheikhatextiles.app` |
| Password | `SheikhaDemo2026` |
| Contact | your name, phone and email |

**Notes** (paste):
```
Sheikha HQ is the internal head-office app of Sheikha Textiles LLC (UAE), a fabric retailer with 8 branches. Branch computers run our web POS; this app shows head office live sales, shifts and Z reports from all branches and sends alerts. We request Unlisted App Distribution, as the app is only for our own head office.

DEMO ACCOUNT: demo@sheikhatextiles.app / SheikhaDemo2026
It opens a demo mode with two months of sample data for 8 made-up branches (an orange "Demo mode" bar is shown at the top). Every feature works on the sample data, and no real company data is shown or changed.

Things to try:
• Dashboard: switch Today / Yesterday / This month / Last month, tap the chart, Share.
• Branches → any branch: cashiers can be added, given a new PIN or removed.
• Sales: open an invoice; "Void" marks it void.
• Z reports: open a report; WhatsApp share.
• More → Notifications → Allow notifications → Send test notification (in demo mode the test arrives as a local notification after 2 seconds; with the real account it is a push from our Firebase server).
• More: Face ID lock and Light / Dark appearance.

Accounts are created by the company, not in the app, so there is no in-app sign-up or account deletion. No ads, no tracking, no in-app purchases.
```

## 5. App Privacy (App Store Connect → App Privacy)

Privacy Policy URL: `https://khiri1234.github.io/sheikha/privacy.html`

"Do you or your third-party partners collect data from this app?" **Yes**

| Data type | Used for | Linked to user | Tracking |
|---|---|---|---|
| Contact Info → **Email Address** | App Functionality | Yes | No |
| Identifiers → **Device ID** (push token) | App Functionality | Yes | No |

Everything else: **not collected**. Sales records are the company's own business data, not
data about the app user.

## 6. Already handled in the project

- Export compliance: `ITSAppUsesNonExemptEncryption = NO` (standard HTTPS only), so no question at upload.
- Privacy manifest `PrivacyInfo.xcprivacy` (email, push token, UserDefaults reason CA92.1).
- Face ID permission text, push notifications entitlement, background mode for notifications.
- iPhone only (no iPad screenshots needed); portrait.
- Demo mode for the reviewer, which never touches the live Firebase data.

## 7. Submit

App Store Connect → version 1.0 → **Build: +** (pick 1.0 (4)) → fill steps 2–5 → **Add for Review →
Submit**. Review usually takes 1–3 days. If Apple asks a question, it appears under
**App Review → Messages**; reply there.
