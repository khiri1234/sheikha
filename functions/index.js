// Sheikha POS – Cloud Functions that send push notifications to the
// head-office iPhone app (Sheikha HQ). The app saves its push token in
// config/devices; preferences live in config/notify (set in the app).
//
// Deploy from the repository folder:  firebase deploy --only functions
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentUpdated, onDocumentWritten } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldPath, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const N = require('./notify');

// Must match the Firestore database location chosen in SETUP.md step 5.
const REGION = 'me-central1';
const TIME_ZONE = 'Asia/Dubai';

setGlobalOptions({ region: REGION, maxInstances: 5 });
initializeApp();
const db = getFirestore();

const prefs = async () => (await db.doc('config/notify').get()).data() || {};
const branchOf = async id => (await db.doc('branches/' + id).get()).data() || { id };

/** Send to every registered head-office device; forget tokens that no longer work.
 *  Returns { devices, sent, error } so the test notification can report back to the app. */
async function send(msg) {
  if (!msg) return null;
  const devices = (await db.doc('config/devices').get()).data() || {};
  const tokens = Object.keys(devices.tokens || {});
  if (process.env.FUNCTIONS_EMULATOR) {
    // local testing: record instead of sending
    await db.collection('notifyLog').add(Object.assign({ ts: Date.now(), tokens: tokens.length }, msg));
    return { devices: tokens.length, sent: tokens.length, error: '' };
  }
  if (!tokens.length) {
    logger.warn('No head-office iPhone registered in config/devices – nothing sent', { kind: msg.kind });
    return { devices: 0, sent: 0, error: 'No iPhone is registered for notifications yet.' };
  }
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title: msg.title, body: msg.body },
    data: { kind: msg.kind || '' },
    apns: { payload: { aps: { sound: 'default' } } }
  });
  const dead = [], errors = [];
  res.responses.forEach((r, i) => {
    if (!r.error) return;
    const code = r.error.code;
    errors.push(code + ': ' + r.error.message);
    if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') dead.push(tokens[i]);
  });
  if (errors.length) logger.error('Push failed for ' + errors.length + ' of ' + tokens.length + ' device(s)', { kind: msg.kind, errors });
  for (const t of dead) await db.doc('config/devices').update(new FieldPath('tokens', t), FieldValue.delete());
  return { devices: tokens.length, sent: res.successCount, error: errors[0] || '' };
}

// Shift closed (Z report), with a cash-difference warning when counted cash is off.
// Also: petty cash payouts added to an open shift.
exports.shiftChanged = onDocumentUpdated('branches/{b}/shifts/{id}', async event => {
  const before = event.data.before.data(), after = event.data.after.data();
  const p = await prefs(), br = await branchOf(event.params.b);
  await send(N.shiftClosedMessage(before, after, br, p));
  for (const m of N.payoutMessages(before, after, br, p)) await send(m);
});

// A sale was voided (at a branch, or from head office).
exports.saleVoided = onDocumentUpdated('branches/{b}/sales/{id}', async event => {
  const before = event.data.before.data(), after = event.data.after.data();
  if (before.status === after.status) return;
  await send(N.voidMessage(before, after, await branchOf(event.params.b), await prefs()));
});

// "Send test notification" in the app writes config/notify.testAt. Uses onDocumentWritten
// because the very first test may create config/notify. The outcome is written back to
// config/notify.testResult so the app can show what happened.
exports.notifyTest = onDocumentWritten('config/notify', async event => {
  const before = (event.data.before && event.data.before.data()) || {};
  const after = (event.data.after && event.data.after.data()) || {};
  if (!after.testAt || after.testAt === before.testAt) return;
  let result;
  try {
    result = await send({ kind: 'test', title: 'Sheikha HQ', body: 'Test notification – push notifications are working ✓' });
  } catch (e) {
    logger.error('Test notification failed', e);
    result = { devices: 0, sent: 0, error: (e.code ? e.code + ': ' : '') + e.message };
  }
  await db.doc('config/notify').set({ testResult: Object.assign({ at: after.testAt, ts: Date.now() }, result) }, { merge: true });
});

/** Today's summary – exported separately so it can be tested. */
async function dailySummary(now = new Date()) {
  const p = await prefs();
  if (!N.settings(p).daily) return null;
  // start of today in the UAE (UTC+4, no daylight saving)
  const dubai = new Date(now.getTime() + 4 * 3600e3);
  const start = Date.UTC(dubai.getUTCFullYear(), dubai.getUTCMonth(), dubai.getUTCDate()) - 4 * 3600e3;
  const branches = (await db.collection('branches').get()).docs.map(d => Object.assign({ id: d.id }, d.data()));
  let sales = [], open = [];
  for (const b of branches) {
    const [s, o] = await Promise.all([
      db.collection('branches/' + b.id + '/sales').where('ts', '>=', start).get(),
      db.collection('branches/' + b.id + '/shifts').where('status', '==', 'open').get()
    ]);
    sales = sales.concat(s.docs.map(d => d.data()));
    open = open.concat(o.docs.map(d => d.data()));
  }
  const msg = N.dailyMessage(branches, sales, open, p);
  await send(msg);
  return msg;
}
exports.dailySummary = onSchedule({ schedule: '0 23 * * *', timeZone: TIME_ZONE }, () => dailySummary());
exports.dailySummary.__run = dailySummary; // for local testing
