// Message wording and settings for Sheikha HQ push notifications.
// Kept free of Firebase triggers so it can be tested on its own.

const DEFAULTS = {
  zClosed: true,       // a branch closed its shift (Z report)
  cashDiff: true,      // counted cash differs from expected
  cashDiffMin: 5,      // ... by at least this many AED
  voids: true,         // a sale was voided
  payouts: true,       // petty cash paid out
  payoutMin: 100,      // ... of at least this many AED
  daily: true          // evening summary of the day
};

const settings = data => Object.assign({}, DEFAULTS, data || {});
const money = n => Number(n || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const label = br => (br && (br.code ? br.code + ' ' : '') + (br.name || '')) || 'Branch';

/** Shift went from open to closed. Returns a message or null. */
function shiftClosedMessage(before, after, branch, prefs) {
  if (!before || !after || before.status !== 'open' || after.status !== 'closed') return null;
  const p = settings(prefs);
  const diff = Number(after.diff || 0);
  const off = p.cashDiff && Math.abs(diff) >= Number(p.cashDiffMin || 0) && diff !== 0;
  if (!p.zClosed && !off) return null;
  const sales = after.summary ? after.summary.total : 0;
  const cash = diff < 0 ? 'cash SHORT ' + money(-diff) : diff > 0 ? 'cash OVER ' + money(diff) : 'cash exact';
  return {
    kind: off ? 'cashDiff' : 'zClosed',
    title: off ? (diff < 0 ? '⚠️ Cash short – ' : '⚠️ Cash over – ') + (branch && branch.name || 'Branch') : label(branch) + ' – shift closed',
    body: [after.zNo, 'Sales AED ' + money(sales), cash, after.closedBy ? 'by ' + after.closedBy : ''].filter(Boolean).join(' · ')
  };
}

/** Sale changed to void. */
function voidMessage(before, after, branch, prefs) {
  if (!before || !after || before.status === 'void' || after.status !== 'void') return null;
  if (!settings(prefs).voids) return null;
  return {
    kind: 'void',
    title: 'Void at ' + (branch && branch.name || 'branch'),
    body: [after.no, 'AED ' + money(after.total), after.voidedBy ? 'by ' + after.voidedBy : ''].filter(Boolean).join(' · ')
  };
}

/** New petty cash payouts added to an open shift (one message per payout). */
function payoutMessages(before, after, branch, prefs) {
  const p = settings(prefs);
  if (!p.payouts || !after) return [];
  const seen = new Set(((before && before.moves) || []).map(m => m.id));
  return ((after.moves || []))
    .filter(m => !seen.has(m.id) && m.type === 'out' && Number(m.amount) >= Number(p.payoutMin || 0))
    .map(m => ({
      kind: 'payout',
      title: 'Petty cash paid out – ' + (branch && branch.name || 'branch'),
      body: ['AED ' + money(m.amount), m.reason, m.cashier].filter(Boolean).join(' · ')
    }));
}

/** Evening summary. sales: today's sales of all branches; open: shifts still open. */
function dailyMessage(branches, sales, open, prefs) {
  if (!settings(prefs).daily) return null;
  const paid = sales.filter(s => s.status !== 'void');
  const total = paid.reduce((n, s) => n + Number(s.total || 0), 0);
  const per = branches.map(b => ({ b, t: paid.filter(s => s.branch === b.id).reduce((n, s) => n + Number(s.total || 0), 0) }))
    .sort((x, y) => y.t - x.t);
  const voids = sales.length - paid.length;
  const idle = per.filter(x => x.t === 0).length;
  const parts = [paid.length + ' bill' + (paid.length === 1 ? '' : 's')];
  if (per.length && per[0].t > 0) parts.push('best: ' + per[0].b.name + ' AED ' + money(per[0].t));
  if (idle) parts.push(idle + ' branch' + (idle === 1 ? '' : 'es') + ' with no sales');
  if (voids) parts.push(voids + ' void' + (voids === 1 ? '' : 's'));
  if (open.length) parts.push(open.length + ' shift' + (open.length === 1 ? '' : 's') + ' still open');
  return { kind: 'daily', title: "Today's sales: AED " + money(total), body: parts.join(' · ') };
}

module.exports = { DEFAULTS, settings, shiftClosedMessage, voidMessage, payoutMessages, dailyMessage, money };
