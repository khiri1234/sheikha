# Security – Sheikha Textiles POS and Sheikha HQ

What protects the data, the settings to check for every shop, and what to know before
selling the system to a client.

## How the data is protected
- All data is in Google Firebase (Firestore). It is encrypted in transit (HTTPS) and at
  rest by Google. Nothing is stored on GitHub except the program itself.
- Every read and write is checked on Google's servers by `firestore.rules`, so changing
  the web page in a browser can't get round them:
  - not signed in → nothing;
  - a branch login → only its own branch's sales, held bills, shifts and log, plus the
    shared settings and fabric list (read only);
  - the head-office login → everything (settings, fabrics, branches, purchases, all branches).
- Sales can never be deleted, only voided. An edited bill keeps its number and date, and
  its earlier versions can't be removed or rewritten. A credit note can't be edited.
- An open shift's float can't be changed and petty cash entries can only be added; a
  closed shift (Z report) can't be changed at all. Invoice and Z-report counters can only
  go up, so a number is never handed out twice.
- Cashier PINs are stored as hashes, never as the PIN itself. After 5 wrong PINs the pad
  locks for 30 seconds, longer after each further 5.
- A till left alone locks itself after 10 minutes (Settings → *Lock the tills after*);
  the cashier enters their PIN again and the open bill is kept.
- New sales can only be saved as paid bills, log entries only for the branch's own log,
  and the list of head-office phones and notification settings is hidden from the branches.
- On Firebase Hosting (section 21 of SETUP.md) the site is sent with strict security
  headers: a Content-Security-Policy that only allows Google's Firebase and font servers,
  no framing by other sites (clickjacking), HTTPS only (HSTS), and no camera, microphone
  or location access. Notes like SETUP.md and the iPhone and server code are not published.
- The activity log records sales, edits, voids, returns, refunds, cash movements and
  sign-ins, and can't be edited or deleted by the branches.
- The Firebase "apiKey" in `index.html` is not a password. It only says which Firebase
  project to talk to; the rules above decide what anyone may do.
- The iPhone demo login (for Apple's reviewers) only opens sample data inside the app. It
  never connects to the live database.

## Check these settings (Firebase console) for every shop
1. **Authentication → Settings → User actions**: *Enable create (sign-up)* is **off**.
   Only you create logins (Authentication → Users → Add user). Also tick **Email
   enumeration protection**.
2. **Firestore → Rules**: after any update, publish the latest rules
   (`firebase deploy --only firestore:rules`).
3. **Passwords**: give the head-office login a long, unique password that isn't used
   anywhere else, and a different password for each branch. Change a branch password when
   staff who knew it leave.
4. **Google Cloud console → APIs & Services → Credentials →** the *Browser key*:
   under *Application restrictions* choose **Websites** and add
   `https://sheikha.hatef.cc/*`, `https://khiri1234.github.io/*` and `http://localhost/*`.
   This stops the key being used from other websites. Leave the *iOS key* as it is.
5. **Backups**: Firestore → *Disaster recovery* → turn on **Point-in-time recovery**
   (keeps 7 days) and/or a scheduled daily backup. Also use *Settings → Backup* in the
   POS from time to time.
6. **Google account of the Firebase project**: turn on 2-step verification for the Gmail
   that owns the project (myaccount.google.com → Security).

## Checked and in order
- Text typed into the POS (fabric names, notes, reasons, cashier names) is escaped before
  it is shown, so it can't inject code into the page.
- The repository history contains no passwords or private keys; the iPhone app's
  `GoogleService-Info.plist` is not in the repository.
- The Cloud Functions have no public web address; they only react to database changes.
- Server packages: `npm audit` reports 2 *moderate* findings inside Google's own
  `firebase-admin` (an old `uuid` in `gaxios`). The affected function isn't used, and
  they go away when Google updates the package (`npm update` in `functions`).

## Known limits
- Branch staff are trusted with their own branch: someone with the branch login can add
  bills, void bills and record returns for that branch. Every such action is in the
  activity log with the cashier's name and time, and head office gets a notification for
  voids.
- A 4-digit cashier PIN identifies who is on the till; it is not a strong password. The
  branch login is what keeps outsiders out.
- On a shared computer, sign out of the branch (or lock Windows) at the end of the day.

## Selling to other shops
- **Give each client their own Firebase project.** Their data is then completely separate
  from yours and from every other client, and they own their own backups. In the copy for
  the client change `FIREBASE_CONFIG` and `HQ_EMAIL` in `index.html`, the head-office email
  in `firestore.rules`, and (for the iPhone app) `GoogleService-Info.plist` and the
  head-office email in the app's `Config`.
- **Host each client's copy separately** (their own address, e.g. `client.hatef.cc`).
- **Keep the code private.** Move the site to Firebase Hosting (SETUP.md section 21), then
  make this GitHub repository private (GitHub → Settings → General → Danger Zone →
  Change visibility). Until then anyone can read and copy the program.
- The code is covered by `LICENSE` (all rights reserved) and the copyright notice on the
  sign-in screen.
- Give the client a short written agreement covering: who owns the data (the client),
  backups, support, and that they must keep their passwords private.
