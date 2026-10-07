# Setting up Sheikha Textiles POS for all branches

The POS runs at **https://khiri1234.github.io/sheikha/**. Until it is connected
to Firebase it works on one computer only. These steps connect head office and
every branch to one shared, secure database.

You do steps 1–8 once, in the Firebase console, signed in with the company's
Google account. Then send the two things from step 8 to your developer, who
switches the POS over. Steps 9–11 happen after that.

---

## 1. Create the Firebase project
1. Go to https://console.firebase.google.com and click **Create a project**.
2. Name it `sheikha-pos`. Turn **Google Analytics off**. Click **Create project**.

## 2. Turn on email + password sign-in
1. Left menu: **Build → Authentication → Get started**.
2. **Sign-in method** tab → **Email/Password** → switch on the first option
   (*Email/Password*), leave *Email link* off → **Save**.

## 3. Create the logins
**Authentication → Users → Add user**, once for each login:

| Login | Example email | Who uses it |
|---|---|---|
| Head office | `hq@sheikhatextiles.ae` | Owner / manager at the main office |
| Branch 1 | `branch1@sheikhatextiles.ae` | The till PC at branch 1 |
| … | … | … |
| Branch 8 | `branch8@sheikhatextiles.ae` | The till PC at branch 8 |

- Use a strong password for each (at least 12 characters). Keep them in a safe place.
- The head-office email should be a real mailbox, so its password can be reset.
- Branch emails don't have to receive mail; they are just login names.

## 4. Stop strangers from creating accounts
**Authentication → Settings → User actions** → untick **Enable create (sign-up)** → **Save**.
Only you can add logins from now on.

## 5. Create the database
1. **Build → Firestore Database → Create database**.
2. Location: **me-central1 (Doha)** (closest to the UAE; it can't be changed later).
3. Start in **production mode** → **Create**.

## 6. Publish the security rules
1. **Firestore Database → Rules** tab.
2. Delete everything there and paste the contents of
   [`firestore.rules`](firestore.rules) from this repository.
3. Check the line `email() == '…'` shows your head-office login email
   (it is already set to `sheikhatextiles@gmail.com`).
4. Click **Publish**.

These rules mean: head office can see and manage everything; each branch login
can only see and add its own branch's sales and held bills, can void but never
edit or delete a sale, and can't change prices or settings; nobody else can
read anything.

## 7. Recommended: daily backups and a budget alert
1. Click **Upgrade** (bottom left) and choose the **Blaze** (pay as you go) plan.
   A shop this size usually stays within the free daily allowance or costs a few
   dollars a month.
2. In Google Cloud **Billing → Budgets & alerts**, create a budget (for example
   USD 10/month) with email alerts.
3. **Firestore Database → Disaster recovery**: turn on **daily backups** and
   **point-in-time recovery** (lets you rewind the database up to 7 days).
4. Turn on **2-Step Verification** on the Google account that owns the project.

## 8. Get the connection settings
1. Click the ⚙️ gear next to *Project Overview* → **Project settings**.
2. Under **Your apps**, click the **`</>`** (Web) icon, name it `Sheikha POS`,
   leave *Firebase Hosting* unticked → **Register app**.
3. Copy the `firebaseConfig = { … }` block.

**Send your developer:** the `firebaseConfig` block and the head-office login
email. (Never send passwords.)

---

## After the POS is switched over

### 9. Head office
1. Open https://khiri1234.github.io/sheikha/ and sign in with the head-office login.
2. When asked, click **Copy to cloud** to copy the fabric list and shop settings
   from this computer (or add fabrics under **Items** later).
3. **Branches → + Add branch** for each shop: code (B1…B8, starts every invoice
   number), name, address and phone (printed on receipts), and the branch login
   email from step 3.
4. **Settings**: check the shop name, **TRN**, VAT rate and receipt texts.

### 10. Each branch PC (Windows)
1. Open **Microsoft Edge** or **Google Chrome** and go to
   https://khiri1234.github.io/sheikha/.
2. Click the **Install** icon at the right end of the address bar
   (Edge: *App available → Install*; Chrome: the monitor-with-arrow icon).
   The POS gets its own desktop icon and window, and opens even without internet.
3. Sign in with that branch's login. It stays signed in.
4. If this PC was already used as the POS, it offers to **upload** its old sales
   to the branch. Click **Upload** so they appear in head-office reports.
5. Set the receipt printer as the default printer in Windows.

### 11. Day to day
- If the internet drops, keep selling. The sidebar shows **Offline – sales upload
  when back online**, and everything uploads automatically when it returns.
- Head office sees every branch under **Reports** (choose a branch or *All
  branches*) and files one combined **VAT 201** (all sales in box 1a, Abu Dhabi).
- Head office can download a full copy of all data from **Settings → Backup**.
- To move a branch to a new PC: install the POS there and sign in with the
  branch login. Nothing else to copy.
- If a branch login is lost or a staff member leaves: change that login's
  password in **Firebase → Authentication → Users**, then sign in again on the
  branch PC.

### 12. Cashiers, shifts and Z reports
**One-time:** the database rules gained a section for shifts. Copy the whole of
[`firestore.rules`](firestore.rules) again into **Firebase → Firestore Database →
Rules** and click **Publish**. Until then, branches show a yellow note and keep
selling without shifts.

**Head office – add cashiers:** **Branches → Cashiers** on each branch → enter the
cashier's name and a 4-digit PIN → **Add cashier**. Each PIN must be different
within the branch. **Remove** stops a cashier signing in (their past sales keep
their name); **New PIN** changes it. A branch with no cashiers sells without PINs.

**At the branch, every day:**
1. The cashier enters their PIN (**Who's on the till?**). Sales, held bills and
   voids record who made them. At a handover, click **Switch cashier** in the
   sidebar and the next person enters their PIN.
2. First thing in the morning: count the cash in the drawer and **Open shift**
   with that amount as the float. Selling starts once a shift is open.
3. Any time: **Shift → Print X report** for the shift so far.
4. At closing: **Shift → Close shift & Z report**, count the cash and enter it.
   The POS shows the expected cash (float + cash sales) and whether the drawer is
   **short** or **over**, then prints the numbered Z report (e.g. `B1-Z0001`) with
   lines for the cashier's and manager's signatures. A closed Z report can't be
   changed.

**Head office:** **Reports → Shifts (Z)** lists every branch's shifts with expected
cash, counted cash and over/short; **View** reprints a Z report. The dashboard
flags cash differences and shifts left open for more than 14 hours.

### 13. Petty cash and sending Z reports
**Head office, once:** **Settings** → *Head office WhatsApp (for Z reports)*
(for example `971501234567`) and *Email for Z reports* → **Save**.

**During the shift:** **Shift → ➖ Pay out** when cash leaves the drawer (delivery
charge, cleaning, tea…): amount and reason, then print the **petty cash voucher**
for the receiver to sign. **➕ Pay in** when cash is added (e.g. change from the
bank). Expected cash at closing = float + cash sales + paid in − paid out, and
every payout and pay-in is listed on the X and Z reports.

**After closing:** on the Z report, tap **💬 WhatsApp** (opens WhatsApp with the
report addressed to head office – press send) or **✉️ Email**. Old Z reports can be
sent again from **Shift → Recent Z reports → View**, and head office can do the
same from **Reports → Shifts (Z)**.

**Head office:** the dashboard's **💬 Share summary** sends the selected period's
totals, branch ranking and anything needing attention by WhatsApp or email.

### 14. Push notifications on the head-office iPhone
The **Sheikha HQ** iPhone app can alert head office when a shift is closed (Z
report), when the cash is short or over, when a sale is voided, when a large petty
cash payout is made, and with a daily sales summary at 11 pm. A small program in
Firebase (*Cloud Functions*, in the [`functions`](functions) folder) watches the
database and sends the alerts. It needs to be set up once:

1. **Blaze plan** – Cloud Functions need the Blaze plan from step 7. At this shop's
   size the cost stays within the free allowance.
2. **Apple push key** – on https://developer.apple.com/account → **Certificates,
   IDs & Profiles → Keys → +**: name it `Sheikha push`, tick **Apple Push
   Notifications service (APNs)** → **Continue → Register → Download** the `.p8`
   file (it can only be downloaded once – keep it safe). Note the **Key ID** and
   your **Team ID** (top right of the page).
3. **Give the key to Firebase** – **Project settings → Cloud Messaging → Apple app
   configuration** → under the *Sheikha HQ* iOS app, **APNs Authentication Key →
   Upload**: choose the `.p8` file and enter the Key ID and Team ID.
4. **Install the notification program** – on the Mac, in Terminal:
   ```sh
   cd ~/sheikha && git pull
   brew install node            # once
   npm install -g firebase-tools # once
   firebase login               # once, with the company Google account
   cd functions && npm install && cd ..
   firebase deploy --only functions
   ```
   It finishes with *Deploy complete!*. The program runs in **me-central1 (Doha)**,
   the same place as the database. If your database is in another location, change
   `REGION` at the top of `functions/index.js` to match before deploying.
5. **Update the iPhone app** – see *Updating the app* in [`ios/README.md`](ios/README.md):
   `cd ios && xcodegen`, then **Run** in Xcode.
6. **Turn it on** – in the app, **More → Notifications → Allow notifications**, then
   tap **Send test notification**. A "Push notifications are working ✓" alert
   should arrive within a few seconds.

On that screen head office chooses which alerts to receive and the minimum amounts
(for example, only cash differences from AED 5 and payouts from AED 100). Every
iPhone signed in with the head-office login receives the alerts; signing out of
the app stops them on that phone.

Nothing changes at the branches, and the database rules don't need updating.

**If the test notification doesn't arrive**, look at **More → Notifications**:

- **This iPhone** shows three ticks: *Registered with Apple*, *Firebase push token*,
  and *Saved for Sheikha's server*. An item that stays grey or red names the
  problem. If *Registered with Apple* never ticks, check **Signing & Capabilities →
  Push Notifications** in Xcode.
- After **Send test notification**, the server's answer appears under the button.
  - *"Apple rejected Firebase's push key"* means step 3 needs redoing. Upload the
    `.p8` file again with the right Key ID and Team ID.
  - *"No iPhone is registered"* means the third tick above is missing.
  - If no answer appears at all, the Cloud Functions aren't deployed. Run step 4
    again.
- For more detail, run `firebase functions:log --only notifyTest` in Terminal.

### 15. Purchases (supplier bills)
**One-time:** the database rules gained a section for purchases. Copy the whole of
[`firestore.rules`](firestore.rules) again into **Firebase → Firestore Database →
Rules** and click **Publish**. Until then, the Purchases page shows a note instead
of the list.

**Head office:** **Purchases → + Add purchase** for every supplier bill: date,
supplier, their invoice number and TRN, which branch it was for, the type (fabric
stock, rent, utilities…), how it was paid, and the amount. Type either the amount
before VAT or the total; the other figures fill in at the shop's VAT rate (change
the VAT figure if the bill shows something different, e.g. 0 for no VAT).

The page lists the bills for a period with totals, *Not paid yet* for bills on
credit, **Copy for Excel** and **Print**. **Reports → VAT 201** fills box 9 from
these bills automatically; typing figures into box 9 overrides that for the
period. Branches don't see purchases.
