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
- **Keep the code private.** This GitHub repository is public, so anyone can read and copy
  the program. Making it private needs a paid GitHub plan for GitHub Pages, or host the
  site on Firebase Hosting instead (free) and make the repository private.
- Give the client a short written agreement covering: who owns the data (the client),
  backups, support, and that they must keep their passwords private.
