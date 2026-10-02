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
3. On the line `email() == 'hq@example.com'`, replace `hq@example.com`
   with your head-office login email from step 3 (lower case).
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
