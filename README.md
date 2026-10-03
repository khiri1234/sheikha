# Sheikha Textiles POS

Point of sale for Sheikha Textiles, served from GitHub Pages at
https://khiri1234.github.io/sheikha/.

- `index.html` – the whole app (sale screen, held bills, reports and VAT 201,
  items, branches, settings, backup).
- `sw.js`, `manifest.json`, `icon-*.png` – lets the POS be installed and open
  without internet.
- `firestore.rules` – database security rules for the multi-branch setup.
- [`SETUP.md`](SETUP.md) – how to connect head office and all branches.
- [`ios/`](ios/README.md) – **Sheikha HQ**, the head-office iPhone app (SwiftUI + Firebase).

Without Firebase settings (`FIREBASE_CONFIG` in `index.html`) the POS keeps
everything on the one computer it runs on. With them, every branch signs in,
sales are stored per branch in Firestore and head office sees all branches.
