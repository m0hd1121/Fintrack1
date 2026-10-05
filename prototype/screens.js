// FinTrack redesign prototype — screen renderers.
// Each screen returns an HTML string. Navigation uses data attributes handled in app.js:
//   data-go="route"   push a screen (or "sheet:x", "scene:x", "tab:x")
//   data-act="name"   run ACTIONS[name] with data-arg
'use strict';

// ---------- helpers ----------
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const _fmt = {};
function money(v, cur = 'AED', compact = false) {
  const key = cur + compact;
  _fmt[key] = _fmt[key] || new Intl.NumberFormat('en-AE', { style: 'currency', currency: cur, currencyDisplay: 'code',
    minimumFractionDigits: compact ? 0 : 2, maximumFractionDigits: compact ? 0 : 2 });
  return _fmt[key].format(v).replace(/ /g, ' ');
}
const toBase = (v, cur) => v * (FX[cur] || 1);
const sum = (arr, f) => arr.reduce((a, x) => a + f(x), 0);
function signed(t) {
  const m = money(Math.abs(t.amount), t.cur);
  if (t.cat === 'transfer') return `<bdi>${m}</bdi>`;
  return t.amount < 0 ? `<bdi>−${m}</bdi>` : `<bdi class="income-c">+${m}</bdi>`;
}
const fmtDate = new Intl.DateTimeFormat('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
const fmtShort = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' });
const fmtTime = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit' });
function dayLabel(date) {
  const a = new Date(date); a.setHours(0, 0, 0, 0);
  const b = new Date(TODAY); b.setHours(0, 0, 0, 0);
  const diff = Math.round((b - a) / 864e5);
  if (diff === 0) return 'Today';
  if (diff === 1) return 'Yesterday';
  if (diff === -1) return 'Tomorrow';
  return fmtDate.format(date);
}
function dueLabel(date) {
  const days = Math.round((new Date(date).setHours(0, 0, 0, 0) - new Date(TODAY).setHours(0, 0, 0, 0)) / 864e5);
  if (days < 0) return { t: `Overdue by ${-days} day${days === -1 ? '' : 's'}`, cls: 'bad' };
  if (days === 0) return { t: 'Due today', cls: 'warn' };
  if (days === 1) return { t: 'Due tomorrow', cls: 'warn' };
  if (days <= 7) return { t: `Due in ${days} days`, cls: 'info' };
  return { t: `Due ${fmtShort.format(date)}`, cls: 'info' };
}
const acct = id => DATA.accounts.find(a => a.id === id);
const pct = (a, b) => (b > 0 ? Math.round((a / b) * 100) : 0);
function attrs(o) {
  let s = '';
  if (o.go) s += ` data-go="${esc(o.go)}"`;
  if (o.act) s += ` data-act="${esc(o.act)}"`;
  if (o.arg !== undefined) s += ` data-arg="${esc(o.arg)}"`;
  if (o.label) s += ` aria-label="${esc(o.label)}"`;
  return s;
}
function row(o) {
  const interactive = o.go || o.act;
  const tag = interactive ? 'button' : 'div';
  const icon = o.icon ? `<span class="row-icon" style="--ic:${o.ic || 'var(--accent)'}" aria-hidden="true">${o.icon}</span>` : '';
  const trail = (o.trail || o.trailSub || (interactive && o.chev !== false))
    ? `<span class="row-trail"><span>${o.trail ? `<span class="amt">${o.trail}</span>` : ''}${o.trailSub ? `<div class="sub">${o.trailSub}</div>` : ''}</span>${interactive && o.chev !== false ? '<span class="chev" aria-hidden="true">›</span>' : ''}</span>` : '';
  return `<${tag} class="row${interactive ? '' : ' static'}"${attrs(o)}${o.key ? ` data-key="${o.key}"` : ''}>${icon}<span class="row-main"><div class="row-title">${o.title}</div>${o.sub ? `<div class="row-sub">${o.sub}</div>` : ''}</span>${trail}${o.extra || ''}</${tag}>`;
}
const group = rows => `<div class="group">${rows.join('')}</div>`;
function section(title, body, link) {
  return `<section class="section"><div class="section-h"><h2>${title}</h2>${link ? `<button class="link"${attrs(link)}>${link.text}</button>` : ''}</div>${body}</section>`;
}
function empty(icon, title, text, btn) {
  return `<div class="empty card"><div class="ei" aria-hidden="true">${icon}</div><h3>${title}</h3><p>${text}</p>${btn ? `<button class="btn primary"${attrs(btn)}>${btn.text}</button>` : ''}</div>`;
}
function bar(spent, limit, label) {
  const p = pct(spent, limit);
  const cls = p > 100 ? 'over' : p >= 80 ? 'warn' : '';
  return `<div class="bar ${cls}" role="progressbar" aria-label="${esc(label)}" aria-valuenow="${p}" aria-valuemin="0" aria-valuemax="100" aria-valuetext="${p} percent"><i style="width:${Math.min(p, 100)}%"></i></div>`;
}
function budgetStatus(spent, limit) {
  const p = pct(spent, limit);
  if (p > 100) return `<span class="status bad">▲ Over by ${money(spent - limit, 'AED', true)}</span>`;
  if (p >= 80) return `<span class="status warn">● ${p}% used</span>`;
  return `<span class="status ok">✓ On track</span>`;
}
function seg(name, options, current) {
  return `<div class="segmented" role="tablist" aria-label="${esc(name)}">${options.map(([v, l]) =>
    `<button role="tab" aria-selected="${v === current}" data-act="seg" data-arg="${esc(name)}|${v}">${l}</button>`).join('')}</div>`;
}
function chips(name, options, current) {
  return `<div class="chips" role="group" aria-label="${esc(name)}">${options.map(([v, l]) =>
    `<button class="chip" aria-pressed="${v === current}" data-act="seg" data-arg="${esc(name)}|${v}">${l}</button>`).join('')}</div>`;
}
const ui = (k, def) => (S.ui[k] === undefined ? def : S.ui[k]);
function donut(slices, label) {
  const total = sum(slices, s => s.v) || 1;
  let off = 0;
  const C = 2 * Math.PI * 40;
  const arcs = slices.map(s => {
    const len = (s.v / total) * C;
    const el = `<circle r="40" cx="50" cy="50" fill="none" stroke="${s.c}" stroke-width="16" stroke-dasharray="${len} ${C - len}" stroke-dashoffset="${-off}" transform="rotate(-90 50 50)"/>`;
    off += len; return el;
  }).join('');
  return `<svg class="donut" viewBox="0 0 100 100" role="img" aria-label="${esc(label)}"><circle r="40" cx="50" cy="50" fill="none" stroke="var(--separator)" stroke-width="16"/>${arcs}</svg>`;
}
function legend(slices, cur = 'AED') {
  const total = sum(slices, s => s.v) || 1;
  return `<div class="legend">${slices.map(s => `<div><span class="sw" style="background:${s.c}" aria-hidden="true"></span>${esc(s.l)} <b style="float:inline-end"><bdi>${money(s.v, cur, true)}</bdi> · ${pct(s.v, total)}%</b></div>`).join('')}</div>`;
}
function spark(points, label) {
  const max = Math.max(...points), min = Math.min(...points);
  const xs = points.map((p, i) => [i * (300 / (points.length - 1)), 80 - ((p - min) / ((max - min) || 1)) * 64 - 8]);
  const line = xs.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
  const [lx, ly] = xs[xs.length - 1];
  return `<svg class="spark" viewBox="0 0 300 90" preserveAspectRatio="none" role="img" aria-label="${esc(label)}">
    <path d="${line} L300,90 L0,90 Z" fill="color-mix(in srgb, var(--accent) 16%, transparent)"/>
    <path d="${line}" fill="none" stroke="var(--accent)" stroke-width="2.5" vector-effect="non-scaling-stroke"/>
    <circle cx="${lx}" cy="${ly}" r="4" fill="var(--accent)"/></svg>`;
}
function bars(vals, labels, label) {
  const max = Math.max(...vals.map(Math.abs)) || 1;
  const w = 300 / vals.length;
  return `<svg viewBox="0 0 300 110" class="spark" style="height:110px" role="img" aria-label="${esc(label)}">${vals.map((v, i) =>
    `<rect x="${i * w + w * 0.2}" y="${90 - (Math.abs(v) / max) * 80}" width="${w * 0.6}" height="${(Math.abs(v) / max) * 80}" rx="4" fill="${v < 0 ? 'var(--expense)' : 'var(--accent)'}"/>
     <text x="${i * w + w / 2}" y="105" text-anchor="middle" font-size="10" fill="var(--text-2)">${labels[i]}</text>`).join('')}</svg>`;
}
function banner(kind, icon, text, btn) {
  return `<div class="banner ${kind}" role="${kind === 'err' ? 'alert' : 'status'}"><span aria-hidden="true">${icon}</span><div class="bt">${text}</div>${btn ? `<button class="btn"${attrs(btn)}>${btn.text}</button>` : ''}</div>`;
}
const offlineBanner = what => (P.network === 'offline' ? banner('warn', '⚠︎', `<b>You're offline.</b> ${what}`) : '');
function skeleton() {
  return `<div class="content" aria-busy="true" aria-label="Loading"><div class="skeleton" style="height:150px"></div><div class="skeleton" style="height:60px"></div><div class="skeleton" style="height:220px"></div></div>`;
}

// ---------- derived numbers ----------
function monthTx() { return DATA.transactions.filter(t => t.date.getMonth() === TODAY.getMonth() && !t.pending); }
function monthIncome() { return sum(DATA.transactions.filter(t => t.amount > 0 && t.date >= new Date(2026, 8, 6)), t => toBase(t.amount, t.cur)); }
function monthSpend() { return sum(monthTx().filter(t => t.amount < 0 && t.cat !== 'transfer'), t => toBase(-t.amount, t.cur)); }
function netWorth() {
  const cash = sum(DATA.accounts, a => toBase(a.balance, a.cur));
  const inv = sum(DATA.investments, i => i.value);
  const assets = sum(DATA.assets, a => a.value);
  const rewards = sum(DATA.rewards, r => r.est);
  const liab = sum(DATA.loans, l => l.outstanding) + sum(DATA.bnpl, b => b.installment * (b.total - b.paid)) + sum(DATA.borrowed, b => b.amount) + sum(DATA.assets, a => a.owed || 0);
  const lent = sum(DATA.lent, l => l.amount);
  const totalAssets = cash + inv + assets + rewards + lent;
  return { assets: totalAssets, liab, net: totalAssets - liab };
}
function upcoming() {
  const items = [];
  DATA.bills.forEach(b => items.push({ title: b.name, amount: b.amount, date: b.due, icon: CATS[b.cat]?.icon || '🧾', go: `bill:${b.id}`, kind: b.sub ? 'Subscription' : 'Bill' }));
  DATA.loans.forEach(l => items.push({ title: l.name, amount: l.emi, date: l.next, icon: '🏦', go: `loan:${l.id}`, kind: 'Loan EMI' }));
  DATA.bnpl.forEach(b => items.push({ title: `${b.provider} — ${b.name}`, amount: b.installment, date: b.next, icon: '🧩', go: 'debt', kind: `Instalment ${b.paid + 1} of ${b.total}` }));
  DATA.accounts.filter(a => a.due).forEach(a => items.push({ title: `${a.name} minimum`, amount: Math.max(25, Math.abs(a.balance) * 0.05), date: a.due, icon: '💳', go: `account:${a.id}`, kind: 'Card payment' }));
  DATA.borrowed.forEach(b => items.push({ title: `Repay ${b.person}`, amount: b.amount, date: b.due, icon: '🤝', go: 'debt', kind: 'Borrowed' }));
  return items.sort((a, b) => a.date - b.date);
}
function catSpend() {
  const m = {};
  monthTx().filter(t => t.amount < 0 && t.cat !== 'transfer').forEach(t => { m[t.cat] = (m[t.cat] || 0) + toBase(-t.amount, t.cur); });
  // add late-September spend so the sample donut is meaningful
  DATA.transactions.filter(t => t.date.getMonth() === 8 && t.amount < 0).forEach(t => { m[t.cat] = (m[t.cat] || 0) + toBase(-t.amount, t.cur) * 0.5; });
  return Object.entries(m).sort((a, b) => b[1] - a[1]).slice(0, 5).map(([k, v]) => ({ l: CATS[k].name, v, c: CATS[k].color }));
}
const pendingReview = () => DATA.review.filter(r => !r.done);

// ---------- shared rows ----------
function txRow(t) {
  const a = acct(t.acct);
  const flags = [t.pending ? '<span class="status warn">Pending</span>' : '', t.recurring ? '<span class="status info">Repeats</span>' : '', t.split ? '<span class="status info">Split</span>' : '', t.via ? `<span class="status info">${esc(t.via)}</span>` : ''].join(' ');
  const foreign = t.cur !== DATA.profile.base ? ` · ≈ ${money(toBase(Math.abs(t.amount), t.cur))}` : '';
  const sel = S.ui.selecting ? `<input type="checkbox" class="sel" data-act="toggleSel" data-arg="${t.id}" aria-label="Select ${esc(t.title)}" ${S.ui.sel && S.ui.sel[t.id] ? 'checked' : ''} style="width:24px;height:24px;margin-inline-start:14px">` : '';
  return `<div class="row-split" style="display:flex;align-items:center;position:relative">${sel}${row({ icon: CATS[t.cat].icon, ic: CATS[t.cat].color, title: esc(t.title),
    sub: `${CATS[t.cat].name} · ${a ? esc(a.name) : 'No account'}${foreign} ${flags}`, trail: signed(t), go: S.ui.selecting ? undefined : `txn:${t.id}`, act: S.ui.selecting ? 'toggleSel' : undefined, arg: S.ui.selecting ? t.id : undefined,
    chev: false, label: `${t.title}, ${t.amount < 0 ? 'spent' : 'received'} ${money(Math.abs(t.amount), t.cur)}, ${CATS[t.cat].name}, ${dayLabel(t.date)}${t.pending ? ', pending' : ''}` })}
    ${S.ui.selecting ? '' : `<button class="more-btn" data-act="txMenu" data-arg="${t.id}" aria-label="More actions for ${esc(t.title)}">•••</button>`}</div>`;
}
function upRow(u) {
  const due = dueLabel(u.date);
  return row({ icon: u.icon, title: esc(u.title), sub: `${u.kind} · <span class="status ${due.cls}">${due.t}</span>`, trail: `<bdi>${money(u.amount)}</bdi>`, go: u.go });
}

// ---------- screens ----------
const SCREENS = {};

SCREENS.home = {
  title: () => 'Home',
  sub: () => `Good evening, ${esc(DATA.profile.name)}`,
  trail: () => `<button class="circle-btn glass" data-go="settings" aria-label="Settings and profile">👤</button>`,
  notes: { purpose: 'Answer "how am I doing this month and what needs me?" in one glance.', primary: 'Review imported transactions; add a transaction (bar above the tab bar).',
    moved: ['Unlabelled AI / Reports / Profile icons → labelled shortcut tiles and one profile button (Settings).', 'Review queue surfaced here instead of only inside Transactions.', '"Edit Home" at the bottom (was Settings → Dashboard Layout).'],
    a11y: ['Hero is one VoiceOver element with a spoken summary.', 'Every shortcut has a text label; no icon-only controls.', 'Budget state uses text and icons (✓ ● ▲), not only colour.'] },
  render() {
    const hidden = S.ui.homeHidden || {};
    const order = S.ui.homeOrder || ['review', 'shortcuts', 'upcoming', 'budgets', 'spending', 'recent', 'insights'];
    const inc = monthIncome(), sp = monthSpend();
    const savings = inc > 0 ? Math.round(((inc - sp) / inc) * 100) : 0;
    const noData = DATA.transactions.length === 0 && DATA.accounts.length === 0;
    if (noData) {
      return `${empty('👋', 'Set up FinTrack', 'Add an account and your first transaction, or connect your bank emails so purchases arrive for review automatically.', { text: 'Add an account', go: 'sheet:form:account' })}
        ${group([row({ icon: '✉️', title: 'Connect bank emails', sub: 'Gmail, Outlook, iCloud or IMAP', go: 'import-email' }), row({ icon: '💬', title: 'Set up bank SMS', sub: 'A Shortcuts automation sends bank texts to FinTrack', go: 'import-sms' }), row({ icon: '📄', title: 'Import a spreadsheet or statement', sub: 'CSV, OFX, QFX or QIF', go: 'import' })])}`;
    }
    const parts = {
      review: () => pendingReview().length ? `<div class="card" style="flex-direction:row;align-items:center;gap:12px">
          <span class="row-icon" aria-hidden="true">📥</span><div class="row-main"><div class="row-title"><b>${pendingReview().length} imported transactions to review</b></div>
          <div class="row-sub">From bank emails, SMS and Apple Pay. They're added to your accounts only after you approve them.</div></div>
          <button class="btn primary" data-go="review">Review</button></div>` : '',
      shortcuts: () => `<div class="grid-tiles">${[['📊', 'Reports', 'Spending, income, VAT', 'reports'], ['✨', 'Insights', 'Health score, patterns', 'insights'], ['📈', 'Net worth', money(netWorth().net, 'AED', true), 'networth'], ['🧾', 'Bills', `${DATA.bills.length} active`, 'bills']]
          .map(([i, t, s, g]) => `<button class="tile" data-go="${g}"><span aria-hidden="true" style="font-size:1.3em">${i}</span><span class="t">${t}</span><span class="s">${s}</span></button>`).join('')}</div>`,
      upcoming: () => section('Coming up', upcoming().length ? group(upcoming().slice(0, 3).map(upRow)) : empty('🗓', 'Nothing due', 'Bills, loan instalments and card payments will show here.'), { text: 'See all', go: 'upcoming' }),
      budgets: () => section('Budgets', DATA.budgets.length ? group([...DATA.budgets].sort((a, b) => b.spent / b.limit - a.spent / a.limit).slice(0, 3).map(b =>
          `<button class="row" data-go="budget:${b.id}" style="flex-direction:column;align-items:stretch;gap:6px"><div style="display:flex;gap:10px;align-items:center"><span class="row-icon" style="--ic:${CATS[b.cat].color}" aria-hidden="true">${CATS[b.cat].icon}</span><span class="row-main"><div class="row-title">${CATS[b.cat].name}</div><div class="row-sub"><bdi>${money(b.spent, 'AED', true)}</bdi> of <bdi>${money(b.limit, 'AED', true)}</bdi></div></span>${budgetStatus(b.spent, b.limit)}</div>${bar(b.spent, b.limit, CATS[b.cat].name + ' budget')}</button>`))
          : empty('🎯', 'No budgets yet', 'Set a monthly limit for a category and FinTrack tracks it for you.', { text: 'Add a budget', go: 'sheet:form:budget' }), { text: 'All budgets', go: 'budgets' }),
      spending: () => { const sl = catSpend(); return sl.length ? section('Spending by category', `<div class="card"><div class="split-h">${donut(sl, 'Spending by category: ' + sl.map(s => `${s.l} ${money(s.v, 'AED', true)}`).join(', '))}${legend(sl)}</div></div>`, { text: 'Report', go: 'report:spending' }) : ''; },
      recent: () => section('Recent', group([...DATA.transactions].sort((a, b) => b.date - a.date).slice(0, 4).map(txRow)), { text: 'See all', act: 'switchTab', arg: 'activity' }),
      insights: () => section('Insights', `<div class="card"><div class="row-title">🍽 Dining is 23% higher than your 3-month average</div><div class="row-sub">Mostly Talabat orders after 9 pm. At this pace you'll pass your Dining budget on 9 Oct.</div><div class="btn-row"><button class="btn" data-go="insight:patterns">See patterns</button><button class="btn" data-go="budget:bu2">Open budget</button></div></div>`, { text: 'All insights', go: 'insights' }),
    };
    return `${offlineBanner('Exchange rates and prices are from 10:42. Bank emails will sync when you reconnect.')}
      <button class="hero" data-go="reports" style="border:0;text-align:start;cursor:pointer" aria-label="This pay cycle since 28 September: spent ${money(sp)}, income ${money(inc)}, ${savings} percent not spent yet. Opens reports.">
        <span class="k">This pay cycle · since 28 Sep</span><span class="big"><bdi>${money(sp)}</bdi></span><span style="opacity:.92;font-size:.85em">spent of <bdi>${money(inc)}</bdi> income</span>
        <span class="hero-stats"><span>Income<b><bdi>${money(inc, 'AED', true)}</bdi></b></span><span>Spent<b><bdi>${money(sp, 'AED', true)}</bdi></b></span><span>Not spent<b><bdi>${savings}%</bdi></b></span></span></button>
      ${order.filter(k => !hidden[k]).map(k => parts[k]()).join('')}
      <button class="btn block" data-go="home-edit">Edit Home</button>`;
  },
};

SCREENS['home-edit'] = {
  title: () => 'Edit Home',
  notes: { purpose: 'Choose and order Home sections.', primary: 'Toggle sections; Move up/down.', moved: ['Was Settings → Dashboard Layout (toggles only, no order). Also linked from Settings → Home Screen.'], a11y: ['Reordering uses Move Up / Move Down buttons, so it works without drag gestures.'] },
  render() {
    const names = { review: 'To review', shortcuts: 'Shortcuts', upcoming: 'Coming up', budgets: 'Budgets', spending: 'Spending by category', recent: 'Recent transactions', insights: 'Insights' };
    const order = S.ui.homeOrder || Object.keys(names);
    const hidden = S.ui.homeHidden || {};
    return `<p class="subtitle">Turn sections on or off and set their order. The October summary always stays at the top.</p>
      <div class="form-group">${order.map((k, i) => `<div class="field"><label for="hs-${k}" style="flex:1">${names[k]}</label>
        <button class="more-btn" data-act="homeMove" data-arg="${k}|-1" aria-label="Move ${names[k]} up" ${i === 0 ? 'disabled' : ''}>↑</button>
        <button class="more-btn" data-act="homeMove" data-arg="${k}|1" aria-label="Move ${names[k]} down" ${i === order.length - 1 ? 'disabled' : ''}>↓</button>
        <input id="hs-${k}" class="switch" type="checkbox" role="switch" data-act="homeToggle" data-arg="${k}" ${hidden[k] ? '' : 'checked'}></div>`).join('')}</div>`;
  },
};

SCREENS.upcoming = {
  title: () => 'Upcoming payments',
  notes: { purpose: 'Everything due: bills, EMIs, card minimums, BNPL, money you owe.', primary: 'Open an item to pay or record it.', moved: ['Was a sheet from Dashboard; now a pushed screen from Home → Coming up.'], a11y: ['Due state is written out (“Due in 3 days”), not colour-coded only.'] },
  render() {
    const r = ui('upRange', 'month');
    const lim = { week: 7, month: 31, quarter: 92 }[r];
    const items = upcoming().filter(u => (u.date - TODAY) / 864e5 <= lim);
    const total = sum(items, i => i.amount);
    return `${seg('upRange', [['week', 'This week'], ['month', 'Month'], ['quarter', '3 months']], r)}
      <div class="kpis"><div class="kpi"><div class="k">Due in range</div><div class="v"><bdi>${money(total)}</bdi></div></div><div class="kpi"><div class="k">Payments</div><div class="v">${items.length}</div></div></div>
      ${items.length ? group(items.map(upRow)) : empty('🎉', 'Nothing due in this range', 'Choose a longer range to see later payments.')}`;
  },
};

// ---------- Activity ----------
function filteredTx() {
  const q = (S.ui.q || '').toLowerCase();
  const scope = ui('txScope', 'all');
  return [...DATA.transactions].sort((a, b) => b.date - a.date).filter(t => {
    if (q && !(`${t.title} ${CATS[t.cat].name} ${(t.tags || []).join(' ')} ${acct(t.acct)?.name || ''}`.toLowerCase().includes(q))) return false;
    if (scope === 'expense' && !(t.amount < 0 && t.cat !== 'transfer')) return false;
    if (scope === 'income' && !(t.amount > 0)) return false;
    if (scope === 'transfer' && t.cat !== 'transfer') return false;
    if (scope === 'pending' && !t.pending) return false;
    if (scope === 'dupes') return false;
    if (S.ui.filterAcct && t.acct !== S.ui.filterAcct) return false;
    return true;
  });
}
function activityList() {
  const list = filteredTx();
  if (!DATA.transactions.length) return empty('🧾', 'No transactions yet', 'Add one yourself, or connect your bank so purchases arrive for review.', { text: 'Add transaction', go: 'sheet:add' });
  if (!list.length) return empty('🔍', S.ui.q ? `No results for “${esc(S.ui.q)}”` : (ui('txScope', 'all') === 'dupes' ? 'No possible duplicates' : 'No matching transactions'), 'Try a different search or clear the filters.', { text: 'Clear search and filters', act: 'clearFilters' });
  const groups = {};
  list.forEach(t => { const k = dayLabel(t.date); (groups[k] = groups[k] || []).push(t); });
  return Object.entries(groups).map(([day, ts]) => {
    const net = sum(ts.filter(t => t.cat !== 'transfer'), t => toBase(t.amount, t.cur));
    return `<section class="section"><div class="section-h"><h2 style="font-size:.95em">${day}</h2><span class="muted" style="font-size:.8em">Net <bdi>${net < 0 ? '−' : '+'}${money(Math.abs(net))}</bdi></span></div>${group(ts.map(txRow))}</section>`;
  }).join('');
}
SCREENS.activity = {
  title: () => 'Activity',
  trail: () => S.ui.selecting ? `<button class="pill-btn glass" data-act="selectMode">Done</button>`
    : `<button class="pill-btn glass" data-go="import">Import</button><button class="pill-btn glass" data-act="selectMode">Select</button>`,
  notes: { purpose: 'Find, check and fix any transaction.', primary: 'Search; open a transaction. Review card when imports are waiting.',
    moved: ['Review queue banner → a clear "To review" card with count.', 'Import moved here (toolbar) from Settings; still in Settings → Import & Sync.', 'Delete was swipe-only → “•••” menu per row + swipe (iOS 27 adds swipe actions outside List).'],
    a11y: ['Each row reads as one sentence (merchant, amount, category, day).', 'Day headers include the day’s net.', 'Select mode uses real checkboxes.'] },
  render() {
    const n = pendingReview().length;
    const fCount = (S.ui.filterAcct ? 1 : 0) + (S.ui.filterRange ? 1 : 0);
    const selCount = Object.values(S.ui.sel || {}).filter(Boolean).length;
    return `${n ? `<button class="banner" data-go="review" style="border:0;text-align:start;cursor:pointer;width:100%"><span aria-hidden="true">📥</span><span class="bt"><b>${n} to review</b><br><span class="muted">Imported from bank emails, SMS and Apple Pay</span></span><span class="chev" aria-hidden="true">›</span></button>` : ''}
      <div class="search-field"><span aria-hidden="true">🔍</span><label class="sr-only" for="tx-q">Search transactions</label><input id="tx-q" type="search" placeholder="Search merchant, category, tag, account" value="${esc(S.ui.q || '')}" data-input="txSearch" autocomplete="off"></div>
      <div style="display:flex;gap:8px;align-items:center">${chips('txScope', [['all', 'All'], ['expense', 'Expenses'], ['income', 'Income'], ['transfer', 'Transfers'], ['pending', 'Pending'], ['dupes', 'Possible duplicates']], ui('txScope', 'all'))}
        <button class="chip" data-go="sheet:filter" aria-label="Filters${fCount ? `, ${fCount} active` : ''}">⚙︎ Filters${fCount ? ` (${fCount})` : ''}</button></div>
      <div id="tx-results">${P.loading ? skeleton() : activityList()}</div>
      ${S.ui.selecting ? `<div class="glass" style="position:sticky;bottom:150px;border-radius:22px;padding:8px;display:flex;gap:6px;flex-wrap:wrap;align-items:center"><span style="flex:1;padding-inline:8px;font-size:.85em">${selCount} selected</span><button class="btn" data-act="bulk" data-arg="category" ${selCount ? '' : 'disabled'}>Category</button><button class="btn" data-act="bulk" data-arg="tag" ${selCount ? '' : 'disabled'}>Tag</button><button class="btn danger" data-act="bulk" data-arg="delete" ${selCount ? '' : 'disabled'}>Delete</button></div>` : ''}`;
  },
};

SCREENS.txn = {
  title: () => 'Transaction', large: false,
  trail: id => `<button class="pill-btn glass" data-go="sheet:add:${id}">Edit</button>`,
  notes: { purpose: 'See every detail of one transaction.', primary: 'Edit.', moved: ['Same content as TransactionDetailView, grouped into Details / Extras.'], a11y: ['Amount, category and account are announced first.', 'iOS 27 proposal: annotate this view with its entity so “Siri, split this with Layla” can refer to it (see Siri & Shortcuts).'] },
  render(id) {
    const t = DATA.transactions.find(x => x.id === id);
    if (!t) return empty('🗑', 'Transaction deleted', 'It was removed. Use Undo in the message at the bottom if you didn’t mean to.');
    const a = acct(t.acct);
    return `<div class="card" style="align-items:center;text-align:center"><span class="row-icon" style="--ic:${CATS[t.cat].color};width:56px;height:56px;font-size:1.6em" aria-hidden="true">${CATS[t.cat].icon}</span>
        <h2 class="large-title" style="font-size:1.4em">${esc(t.title)}</h2><div style="font-family:var(--sys-round);font-weight:800;font-size:2em">${signed(t)}</div>
        ${t.cur !== DATA.profile.base ? `<div class="muted" style="font-size:.85em">≈ ${money(toBase(Math.abs(t.amount), t.cur))} at 1 ${t.cur} = ${FX[t.cur]} AED (locked when saved)</div>` : ''}
        <div class="muted" style="font-size:.85em">${dayLabel(t.date)}, ${fmtTime.format(t.date)}</div></div>
      ${group([row({ title: 'Category', trail: CATS[t.cat].name }), row({ title: t.to ? 'From' : 'Account', trail: a ? esc(a.name) : 'None', go: a ? `account:${a.id}` : undefined }), t.to ? row({ title: 'To', trail: esc(acct(t.to).name) }) : '',
        row({ title: 'Payment method', trail: t.method }), t.pending ? row({ title: 'Status', trail: '<span class="status warn">Pending — balance not changed yet</span>' }) : '', t.recurring ? row({ title: 'Repeats', trail: t.recurring }) : '',
        t.bnpl ? row({ title: 'BNPL plan', trail: 'tabby — instalment 3 of 4', go: 'debt' }) : '', t.loan ? row({ title: 'Loan', trail: 'Car loan — ENBD', go: 'loan:l1' }) : '', t.bill ? row({ title: 'Bill', trail: esc(DATA.bills.find(b => b.id === t.bill)?.name || ''), go: `bill:${t.bill}` }) : '',
        row({ title: 'Tags', trail: (t.tags || []).join(', ') || 'None' })])}
      ${t.split ? section('Split', group([row({ title: 'Me', trail: money(60) }), row({ title: 'Layla', trail: money(60), sub: 'Owes you' })])) : ''}
      <div class="btn-row"><button class="btn" data-act="toast" data-arg="Receipt viewer (sample)">📎 Receipt</button><button class="btn" data-act="toast" data-arg="Duplicated as a new transaction (sample)">Duplicate</button><button class="btn danger" data-act="deleteTx" data-arg="${t.id}">Delete</button></div>`;
  },
};

SCREENS.review = {
  title: () => 'To review',
  trail: () => `<button class="pill-btn glass" data-act="syncNow">Check now</button>`,
  notes: { purpose: 'Approve, fix or reject transactions imported from email, SMS and Apple Pay. This is the only way imports reach the ledger.', primary: 'Approve ready items.',
    moved: ['Swipe and long-press gestures are kept but every row now has visible Approve / Edit / Reject buttons.', 'Blocked rows (BNPL plan, duplicate) say what they need before you tap.'],
    a11y: ['Confidence is written (“High confidence”), not just a coloured badge.', 'Approving announces where the money was posted.'] },
  render() {
    const items = pendingReview();
    const ready = items.filter(r => r.confidence >= 0.9 && !r.bnplNeeded && !r.duplicateOf);
    const err = P.syncError ? banner('err', '⛔︎', '<b>Couldn’t check Gmail.</b> Your sign-in expired. Reconnect to keep importing bank emails.', { text: 'Reconnect', go: 'import-email' }) : '';
    if (!items.length) return `${err}${empty('✅', 'All caught up', 'New transactions from your bank emails, SMS and Apple Pay will appear here for you to approve.', { text: 'Import settings', go: 'import' })}${reviewHistory()}`;
    return `${err}${offlineBanner('Showing items already downloaded.')}
      <p class="subtitle">Nothing is added to your accounts until you approve it.</p>
      ${ready.length ? `<button class="btn primary block" data-act="approveReady">Approve ${ready.length} ready item${ready.length > 1 ? 's' : ''}</button>` : ''}
      ${items.map(r => {
        const a = acct(r.acct);
        const block = r.bnplNeeded ? '<span class="status warn">● Choose a BNPL plan before approving</span>' : r.duplicateOf ? `<span class="status warn">● Possible duplicate of ${esc(DATA.transactions.find(t => t.id === r.duplicateOf)?.title || '')} on ${fmtShort.format(r.when)}</span>` : '';
        const conf = r.confidence >= 0.9 ? '<span class="status ok">✓ High confidence</span>' : '<span class="status warn">● Check details</span>';
        return `<div class="card" data-key="rv-${r.id}"><div style="display:flex;gap:12px;align-items:center"><span class="row-icon" style="--ic:${CATS[r.cat].color}" aria-hidden="true">${CATS[r.cat].icon}</span>
          <div class="row-main"><div class="row-title"><b>${esc(r.merchant)}</b></div><div class="row-sub">${CATS[r.cat].name} · ${a ? esc(a.name) : 'Account not matched'}${r.card ? ` ••${r.card}` : ''} · ${dayLabel(r.when)}</div></div>
          <div class="amt" style="font-weight:700"><bdi>−${money(r.amount, r.cur)}</bdi></div></div>
          <div style="display:flex;gap:6px;flex-wrap:wrap"><span class="status info">${r.channel === 'Email' ? '✉️' : r.channel === 'SMS' ? '💬' : '' } ${r.channel}: ${esc(r.source)}</span>${conf}${block}</div>
          <div class="btn-row"><button class="btn primary" data-act="approve" data-arg="${r.id}">Approve</button><button class="btn" data-go="sheet:reviewEdit:${r.id}">Edit</button><button class="btn danger" data-act="reject" data-arg="${r.id}">Reject</button></div></div>`;
      }).join('')}
      <button class="btn block danger" data-act="confirm" data-arg="rejectAll">Reject all</button>${reviewHistory()}`;
  },
};
function reviewHistory() {
  const done = DATA.review.filter(r => r.done);
  return `<details class="more"><summary>Reviewed (${done.length + 12}) <span class="chev" aria-hidden="true">›</span></summary><div class="inner">${group([...done.map(r => row({ title: esc(r.merchant), sub: r.done === 'approved' ? 'Approved' : 'Rejected', trail: money(r.amount) })), row({ title: 'Earlier items', sub: '12 approved in September', trail: '' })])}</div></details>`;
}

// ---------- Import ----------
SCREENS.import = {
  title: () => 'Import & Sync',
  notes: { purpose: 'Connect the ways transactions reach FinTrack.', primary: 'Connect bank emails.', moved: ['Was Settings → Import & Integration only; now also Activity → Import.', 'Backup moved out to Settings → Backup & Restore (it is not an import).'], a11y: ['Status text per channel (“Connected · checked 12 min ago”).'] },
  render() {
    const e = DATA.emailAccounts.length;
    return `${section('Automatic — arrives in To review', group([
      row({ icon: '✉️', title: 'Bank emails', sub: e ? `Connected · ${DATA.emailAccounts[0].provider} · checked ${DATA.emailAccounts[0].last}` : 'Not connected', go: 'import-email' }),
      row({ icon: '💬', title: 'Bank SMS', sub: 'Via a Shortcuts automation · last text 2 h ago', go: 'import-sms' }),
      row({ icon: '📱', title: 'Apple Pay', sub: 'Via a Shortcuts automation · 3 this week', go: 'import-applepay' })]))}
      ${section('From a file — added directly', group([
      row({ icon: '📄', title: 'Spreadsheet (CSV)', sub: 'Map columns, preview, skip duplicates', go: 'import-csv' }),
      row({ icon: '🏦', title: 'Bank statement file', sub: 'OFX, QFX or QIF', go: 'import-ofx' })]))}
      <p class="inline-note">Imports are parsed on this iPhone. Email access is read-only.</p>`;
  },
};
SCREENS['import-email'] = {
  title: () => 'Bank emails',
  notes: { purpose: 'Connect mailboxes and bank sender rules.', primary: 'Connect an account.', moved: ['Unchanged content; rule delete now always confirms.'], a11y: ['Provider buttons are labelled with provider name.'] },
  render() {
    return `${P.syncError ? banner('err', '⛔︎', '<b>Gmail sign-in expired.</b> Reconnect to keep importing.', { text: 'Reconnect', act: 'toast', arg: 'Sign-in sheet would open (ASWebAuthenticationSession) — simulated' }) : ''}
      ${section('Connected', DATA.emailAccounts.length ? group(DATA.emailAccounts.map(a => row({ icon: '✉️', title: a.addr, sub: `${a.provider} · checked ${a.last}`, trail: '', act: 'toast', arg: 'Checking mailbox… (simulated)' }))) : empty('✉️', 'No mailbox connected', 'Connect the mailbox your bank sends alerts to.'))}
      ${section('Connect a mailbox', `<div class="grid-tiles">${['Gmail', 'Outlook', 'iCloud Mail', 'Other (IMAP)'].map(p => `<button class="tile" data-act="toast" data-arg="${p} sign-in would open — simulated">${p}</button>`).join('')}</div>`)}
      ${section('Bank rules', group([...DATA.bankRules.map(r => row({ icon: '🏦', title: r.bank, sub: r.sender, go: 'sheet:form:bankRule' })), row({ icon: '＋', title: 'Add a bank rule', go: 'sheet:form:bankRule' })]))}
      ${group([row({ title: 'Paste an email', sub: 'Import one alert by pasting its text', go: 'sheet:form:paste' }), row({ title: 'Try with sample emails', sub: 'Adds 3 example items to To review', act: 'sampleEmails' })])}`;
  },
};
SCREENS['import-sms'] = {
  title: () => 'Bank SMS',
  notes: { purpose: 'Set up the Shortcuts automation that forwards bank texts.', primary: 'Open Shortcuts.', moved: ['Dense paragraph → numbered steps (it is a real sequence).'], a11y: ['Steps are an ordered list.'] },
  render() {
    return `<div class="card"><div class="row-title"><b>How it works</b></div><ol style="margin:0;padding-inline-start:1.2em;line-height:1.6;font-size:.9em"><li>Open Shortcuts → Automation → New → Message.</li><li>Sender: your bank (for example “FAB” or “ENBD”). Run immediately.</li><li>Add action: FinTrack → <b>Log Transaction From Text</b>, pass the message.</li><li>Bank texts now arrive in To review.</li></ol>
      <button class="btn primary" data-act="toast" data-arg="Would open the Shortcuts app — simulated">Open Shortcuts</button></div>
      ${section('Recent texts', group([row({ icon: '💬', title: 'FAB', sub: 'Purchase of AED 95.00 at ENOC 1043 with card ending 7702…', trail: '<span class="status ok">Added to review</span>' }), row({ icon: '💬', title: 'ENBD', sub: 'Your OTP is •••••• — skipped (not a transaction)', trail: '<span class="status info">Skipped</span>' })]))}
      ${group([row({ title: 'Bank SMS rules', sub: 'Map a sender ID to a bank and account', go: 'sheet:form:bankRule' })])}`;
  },
};
SCREENS['import-applepay'] = {
  title: () => 'Apple Pay',
  notes: { purpose: 'Set up the Wallet “Transaction” automation.', primary: 'Open Shortcuts.', moved: ['Unchanged.'], a11y: ['Numbered steps.'] },
  render() {
    return `<div class="card"><ol style="margin:0;padding-inline-start:1.2em;line-height:1.6;font-size:.9em"><li>Shortcuts → Automation → New → Transaction.</li><li>Choose your cards. Run immediately.</li><li>Add FinTrack → <b>Log Apple Pay Transaction</b>; pass Amount, Merchant and Card.</li></ol><button class="btn primary" data-act="toast" data-arg="Would open the Shortcuts app — simulated">Open Shortcuts</button></div>
      ${section('Received', group([row({ icon: '📱', title: 'Noon', sub: '3 Oct · AED 349.00', trail: '<span class="status ok">Added to review</span>' }), row({ icon: '📱', title: 'Talabat', sub: '4 Oct · AED 86.50', trail: '<span class="status ok">Approved</span>' })]))}`;
  },
};
SCREENS['import-csv'] = {
  title: () => 'Spreadsheet (CSV)',
  notes: { purpose: 'Import rows from a CSV with column mapping.', primary: 'Choose a file.', moved: ['Same flow: choose → map → preview → import.'], a11y: ['Mapping uses labelled pickers.'] },
  render() {
    const step = ui('csvStep', 0);
    if (step === 0) return `${empty('📄', 'Choose a CSV file', 'Comma, semicolon, tab or pipe separated. You’ll match columns before anything is imported.', { text: 'Choose file…', act: 'csvPick' })}`;
    return `<p class="subtitle">enbd_september.csv · 42 rows</p><div class="form-group">${[['Date', 'Transaction Date'], ['Description', 'Details'], ['Amount', 'Amount'], ['Currency', '(use AED)']].map(([l, v]) => `<div class="field"><label for="m-${l}">${l}</label><select id="m-${l}"><option>${v}</option><option>Details</option><option>Debit</option><option>Credit</option></select></div>`).join('')}
      <div class="field"><label for="csv-acct">Account</label><select id="csv-acct">${DATA.accounts.map(a => `<option>${esc(a.name)}</option>`).join('')}</select></div><div class="field"><label for="csv-skip" style="flex:1">Skip likely duplicates (3)</label><input id="csv-skip" type="checkbox" class="switch" role="switch" checked></div></div>
      ${section('Preview', group([row({ title: 'Spinneys', sub: '12 Sep · Groceries', trail: '−AED 187.35' }), row({ title: 'Salik', sub: '13 Sep · Transport', trail: '−AED 50.00' }), row({ title: 'Carrefour', sub: '14 Sep · Groceries · <span class="status warn">Likely duplicate — skipped</span>', trail: '−AED 312.40' })]))}
      <button class="btn primary block" data-act="csvImport">Import 39 transactions</button>`;
  },
};
SCREENS['import-ofx'] = {
  title: () => 'Bank statement file',
  notes: { purpose: 'Import OFX/QFX/QIF files.', primary: 'Choose a file.', moved: ['Unchanged.'], a11y: [] },
  render() { return empty('🏦', 'Choose a statement file', 'OFX, QFX or QIF from your bank’s website. Rows are categorised and checked for duplicates before import.', { text: 'Choose file…', act: 'toast', arg: 'File picker would open — simulated' }); },
};

// ---------- Plan ----------
SCREENS.plan = {
  title: () => 'Plan',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:plan">Add</button>`,
  notes: { purpose: 'Everything about where money should go: budgets, bills, goals, income, debt.', primary: 'Open Budgets; Add (budget, bill, goal…).',
    moved: ['Budget tab’s unlabelled “Add or open” menu split into: an Add button (create) and this list (navigate).', 'Income and Debt moved here from the Budget menu (Debt was also in Accounts).', 'Goals moved here from Accounts. Household and Planning tools moved here from Settings.'],
    a11y: ['Each row has a live one-line summary so VoiceOver users get the status without opening it.'] },
  render() {
    const over = DATA.budgets.filter(b => b.spent > b.limit).length, near = DATA.budgets.filter(b => b.spent <= b.limit && b.spent / b.limit >= 0.8).length;
    const nextBill = [...DATA.bills].sort((a, b) => a.due - b.due)[0];
    const debt = sum(DATA.loans, l => l.outstanding) + sum(DATA.bnpl, b => b.installment * (b.total - b.paid)) + sum(DATA.borrowed, b => b.amount);
    return `${group([
      row({ icon: '🎯', title: 'Budgets', sub: DATA.budgets.length ? `${DATA.budgets.length - over - near} on track · ${near} near limit · ${over} over` : 'No budgets yet', go: 'budgets' }),
      row({ icon: '🧾', title: 'Bills & Subscriptions', sub: nextBill ? `Next: ${esc(nextBill.name)} — ${dueLabel(nextBill.due).t.toLowerCase()}` : 'None yet', go: 'bills' }),
      row({ icon: '⭐️', title: 'Goals', sub: DATA.goals.length ? `${money(sum(DATA.goals, g => g.saved), 'AED', true)} saved across ${DATA.goals.length} goals` : 'No goals yet', go: 'goals' }),
      row({ icon: '💼', title: 'Income', sub: DATA.income.salary ? `Salary expected on the ${DATA.income.salary.day}th` : 'Track salary, freelance, rent, dividends', go: 'income' }),
      row({ icon: '🏦', title: 'Debt', sub: debt ? `${money(debt, 'AED', true)} outstanding · payoff planner` : 'No debts', go: 'debt' })])}
      ${group([row({ icon: '👨‍👩‍👦', title: 'Household', sub: 'Family budget, allowances, shared goals', go: 'family' }), row({ icon: '🧭', title: 'Planning tools', sub: 'Retirement, life events, estate, AI CFO and more', go: 'tools' })])}`;
  },
};

SCREENS.budgets = {
  title: () => 'Budgets',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:budgets">Add</button>`,
  notes: { purpose: 'Track spending limits.', primary: 'Add a budget; open one.', moved: ['Monthly / Annual / Envelopes / Zero-based kept as a view picker.', 'Templates and suggestions shown as sections (were hidden in the toolbar menu).'], a11y: ['Progress bars expose percent values; status text is never colour-only.'] },
  render() {
    const v = ui('budgetView', 'monthly');
    const total = sum(DATA.budgets, b => b.limit), spent = sum(DATA.budgets, b => b.spent);
    let body = '';
    if (!DATA.budgets.length) body = empty('🎯', 'No budgets yet', 'Start with a monthly limit for groceries or dining, or apply a seasonal template.', { text: 'Add a budget', go: 'sheet:form:budget' });
    else if (v === 'monthly') body = `<div class="kpis"><div class="kpi"><div class="k">Spent</div><div class="v"><bdi>${money(spent, 'AED', true)}</bdi></div></div><div class="kpi"><div class="k">Budgeted</div><div class="v"><bdi>${money(total, 'AED', true)}</bdi></div></div><div class="kpi"><div class="k">Left · 26 days</div><div class="v"><bdi>${money(total - spent, 'AED', true)}</bdi></div></div></div>`
      + group(DATA.budgets.map(b => `<button class="row" data-go="budget:${b.id}" style="flex-direction:column;align-items:stretch;gap:6px"><div style="display:flex;gap:10px;align-items:center"><span class="row-icon" style="--ic:${CATS[b.cat].color}" aria-hidden="true">${CATS[b.cat].icon}</span><span class="row-main"><div class="row-title">${CATS[b.cat].name}</div><div class="row-sub"><bdi>${money(b.spent, 'AED', true)}</bdi> of <bdi>${money(b.limit, 'AED', true)}</bdi></div></span>${budgetStatus(b.spent, b.limit)}</div>${bar(b.spent, b.limit, CATS[b.cat].name)}</button>`));
    else if (v === 'annual') body = group(DATA.budgets.map(b => row({ title: CATS[b.cat].name, sub: `${money(b.limit * 12, 'AED', true)} a year`, trail: `${money(b.spent + b.limit * 8.4, 'AED', true)} so far` })));
    else if (v === 'envelopes') body = group(DATA.envelopes.map(e => row({ icon: '✉️', title: esc(e.name), sub: `${money(e.balance, 'AED', true)} of ${money(e.target, 'AED', true)}`, trail: '', act: 'toast', arg: 'Envelope detail: fund or transfer (sample)' }))) + `<button class="btn block" data-go="sheet:form:envelope">Add envelope</button>`;
    else body = `<div class="card"><div class="row-title"><b>Every dirham has a job</b></div><div class="row-sub">Income AED 28,250 · Assigned AED 26,900 · <b>AED 1,350 left to assign</b></div>${bar(26900, 28250, 'Assigned share of income')}</div>` + group(DATA.budgets.map(b => row({ title: CATS[b.cat].name, trail: money(b.limit, 'AED', true) })));
    return `${seg('budgetView', [['monthly', 'Monthly'], ['annual', 'Annual'], ['envelopes', 'Envelopes'], ['zero', 'Zero-based']], v)}${body}
      ${DATA.budgets.length ? section('Suggestions', group([row({ icon: '💡', title: 'Raise Dining to AED 1,300', sub: 'You’ve gone over in 3 of the last 4 months', act: 'confirm', arg: 'applyRec' }), row({ icon: '💡', title: 'Lower Entertainment to AED 300', sub: 'You used 30% on average', act: 'confirm', arg: 'applyRec' })])) : ''}
      ${section('Templates', `<div class="grid-tiles">${[['🌙', 'Ramadan'], ['🎉', 'Eid'], ['☀️', 'Summer']].map(([i, t]) => `<button class="tile" data-act="confirm" data-arg="template|${t}"><span aria-hidden="true">${i}</span><span class="t">${t}</span><span class="s">Seasonal budget set</span></button>`).join('')}</div>`)}`;
  },
};
SCREENS.budget = {
  title: id => CATS[DATA.budgets.find(b => b.id === id)?.cat]?.name || 'Budget', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:budget">Edit</button>`,
  notes: { purpose: 'One budget in depth.', primary: 'Edit; see what counted.', moved: ['Uses the same spend rule as the list (current app’s detail can disagree with the row — fixed in implementation).'], a11y: ['Forecast stated in words.'] },
  render(id) {
    const b = DATA.budgets.find(x => x.id === id);
    if (!b) return empty('🎯', 'Budget not found', '');
    const txs = DATA.transactions.filter(t => t.cat === b.cat).slice(0, 4);
    return `<div class="hero"><span class="k">${CATS[b.cat].name} · October</span><span class="big"><bdi>${money(b.spent)}</bdi></span><span>of <bdi>${money(b.limit)}</bdi> · ${budgetStatus(b.spent, b.limit).replace('class="status', 'style="background:rgba(255,255,255,.2);color:#fff" class="status')}</span>${bar(b.spent, b.limit, 'Used')}</div>
      <div class="card"><div class="row-title">At this pace you’ll spend about <b><bdi>${money(b.spent / 5 * 31, 'AED', true)}</bdi></b> by 31 Oct.</div></div>
      ${section('Counted this month', group(txs.map(txRow)))}
      <div class="form-group"><div class="field"><label for="b-roll" style="flex:1">Roll over unused amount</label><input id="b-roll" type="checkbox" class="switch" role="switch"></div><div class="field"><label for="b-share" style="flex:1">Shared with household</label><input id="b-share" type="checkbox" class="switch" role="switch"></div>
        <div class="field"><label for="b-alert">Alert me at</label><select id="b-alert"><option>80%</option><option>90%</option><option>75%</option></select></div><div class="field"><label for="b-end">Ends</label><select id="b-end"><option>Never</option><option>31 Dec 2026</option></select></div></div>
      <button class="btn danger block" data-act="confirm" data-arg="deleteBudget|${b.id}">Delete budget</button>`;
  },
};

SCREENS.bills = {
  title: () => 'Bills & Subscriptions',
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:bill">Add</button>`,
  notes: { purpose: 'All recurring bills and subscriptions in one place.', primary: 'Add a bill; open one to record payment.', moved: ['One screen replaces three entry points (Dashboard sheet, Budget menu, Debt → Bills tab).'], a11y: ['Calendar days are buttons labelled with the date and bills due.'] },
  render() {
    const v = ui('billView', 'upcoming');
    if (!DATA.bills.length) return empty('🧾', 'No bills yet', 'Add rent, utilities and subscriptions to get reminders and spot price changes.', { text: 'Add a bill', go: 'sheet:form:bill' });
    let body;
    if (v === 'upcoming') body = group([...DATA.bills].sort((a, b) => a.due - b.due).map(b => upRow({ title: b.name, amount: b.amount, date: b.due, icon: CATS[b.cat].icon, go: `bill:${b.id}`, kind: `${b.cycle}${b.auto ? ' · Auto-pay' : ''}` })));
    else if (v === 'calendar') {
      const cells = [];
      const first = new Date(2026, 9, 1).getDay(); // Thursday
      const lead = (first + 6) % 7; // Monday-first week (setting: first weekday)
      for (let i = 0; i < lead; i++) cells.push('<span></span>');
      for (let dd = 1; dd <= 31; dd++) {
        const due = DATA.bills.filter(b => b.due.getMonth() === 9 && b.due.getDate() === dd);
        cells.push(`<button class="cal-d" style="min-height:44px;border:0;border-radius:10px;cursor:pointer;background:${dd === 5 ? 'color-mix(in srgb,var(--accent) 22%,transparent)' : due.length ? 'var(--surface)' : 'transparent'};font-weight:${due.length ? 700 : 400}" aria-label="${dd} October${due.length ? ', ' + due.map(b => b.name).join(', ') + ' due' : ''}" ${due.length ? `data-go="bill:${due[0].id}"` : 'data-act="noop"'}>${dd}${due.length ? '<br><span aria-hidden="true" style="color:var(--accent-text)">•</span>' : ''}</button>`);
      }
      body = `<div class="card"><div class="row-title"><b>October 2026</b></div><div style="display:grid;grid-template-columns:repeat(7,1fr);gap:4px;text-align:center;font-size:.85em">${['M', 'T', 'W', 'T', 'F', 'S', 'S'].map(x => `<span class="muted" aria-hidden="true">${x}</span>`).join('')}${cells.join('')}</div></div>`;
    } else {
      const subs = DATA.bills.filter(b => b.sub);
      body = `<div class="kpis"><div class="kpi"><div class="k">Per month</div><div class="v"><bdi>${money(sum(subs, s => s.amount))}</bdi></div></div><div class="kpi"><div class="k">Per year</div><div class="v"><bdi>${money(sum(subs, s => s.amount) * 12, 'AED', true)}</bdi></div></div></div>
        ${banner('warn', '💤', '<b>Spotify Family</b> — no matching payment activity for 41 days. Still using it?', { text: 'Review', go: 'bill:bl4' })}
        ${banner('warn', '↗︎', '<b>DEWA</b> went up 8% compared with last month.', { text: 'See history', go: 'bill:bl1' })}
        ${group(subs.map(b => row({ icon: CATS[b.cat].icon, title: b.name, sub: b.cycle, trail: money(b.amount), go: `bill:${b.id}` })))}`;
    }
    return `${seg('billView', [['upcoming', 'Upcoming'], ['calendar', 'Calendar'], ['subs', 'Subscriptions']], v)}${body}`;
  },
};
SCREENS.bill = {
  title: id => DATA.bills.find(b => b.id === id)?.name || 'Bill', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:bill">Edit</button>`,
  notes: { purpose: 'One bill: due date, history, reminders.', primary: 'Record payment.', moved: ['Was a sheet; now pushed so Back works consistently.'], a11y: ['Reminder chips are toggle buttons with pressed state.'] },
  render(id) {
    const b = DATA.bills.find(x => x.id === id);
    if (!b) return empty('🧾', 'Bill not found', '');
    const due = dueLabel(b.due);
    return `<div class="hero"><span class="k">${b.sub ? 'Subscription' : 'Bill'} · ${b.cycle}</span><span class="big"><bdi>${money(b.amount)}</bdi></span><span>${due.t} · ${b.auto ? 'Auto-pay on' : 'Pay manually'}</span></div>
      <button class="btn primary block" data-go="sheet:form:billPay">Record payment</button>
      ${b.priceChange ? banner('warn', '↗︎', `Price changed: <b>${b.priceChange}</b>`) : ''}${b.unused ? banner('warn', '💤', `${b.unused}.`, { text: 'Not using it', act: 'toast', arg: 'Marked for cancellation reminder (sample)' }) : ''}
      ${section('Remind me', `<div class="chips">${['1 day', '3 days', '7 days'].map((x, i) => `<button class="chip" aria-pressed="${i < 2}" data-act="togglePressed">${x} before</button>`).join('')}</div>`)}
      ${section('Price history', group([row({ title: 'Oct 2026', trail: money(b.amount) }), row({ title: 'Sep 2026', trail: money(b.amount * 0.93) }), row({ title: 'Aug 2026', trail: money(b.amount * 0.95) })]))}
      <div class="btn-row"><button class="btn" data-act="toast" data-arg="Bill paused — reminders cancelled (sample)">Pause</button><button class="btn danger" data-act="confirm" data-arg="deleteBill|${b.id}">Delete</button></div>`;
  },
};

SCREENS.goals = {
  title: () => 'Goals',
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:goal">Add</button>`,
  notes: { purpose: 'Save towards targets.', primary: 'Add money to a goal.', moved: ['Moved from Accounts tab grid to Plan.'], a11y: ['Each goal card reads progress as a sentence.'] },
  render() {
    if (!DATA.goals.length) return empty('⭐️', 'No goals yet', 'Emergency fund, Hajj, a car down payment — set a target and FinTrack works out the monthly amount.', { text: 'Add a goal', go: 'sheet:form:goal' });
    const f = ui('goalFilter', 'active');
    return `<div class="hero"><span class="k">Saved towards goals</span><span class="big"><bdi>${money(sum(DATA.goals, g => g.saved))}</bdi></span><span>of <bdi>${money(sum(DATA.goals, g => g.target), 'AED', true)}</bdi></span></div>
      ${chips('goalFilter', [['active', 'Active'], ['track', 'On track'], ['done', 'Completed'], ['all', 'All']], f)}
      ${f === 'done' ? empty('🏁', 'No completed goals yet', 'Goals you finish move here.') : DATA.goals.map(g => `<div class="card"><button class="row" style="padding:0;min-height:0" data-go="goal:${g.id}" aria-label="${esc(g.name)}, ${pct(g.saved, g.target)} percent saved, ${money(g.saved)} of ${money(g.target)}"><span class="row-main"><div class="row-title"><b>${esc(g.name)}</b></div><div class="row-sub">${g.kind} · needs <bdi>${money(g.perMonth, 'AED', true)}</bdi>/month</div></span><span class="status ok">✓ On track</span><span class="chev" aria-hidden="true">›</span></button>${bar(g.saved, g.target, g.name)}<div class="row-sub"><bdi>${money(g.saved, 'AED', true)}</bdi> of <bdi>${money(g.target, 'AED', true)}</bdi> · ${pct(g.saved, g.target)}%</div><div class="btn-row"><button class="btn" data-go="sheet:form:contribute">Add money</button></div></div>`).join('')}`;
  },
};
SCREENS.goal = {
  title: id => DATA.goals.find(g => g.id === id)?.name || 'Goal', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:goal">Edit</button>`,
  notes: { purpose: 'Goal progress, projection and auto-save.', primary: 'Add money.', moved: ['Overview / Progress / Auto-save / Insights tabs → one scrolling page with sections.'], a11y: [] },
  render(id) {
    const g = DATA.goals.find(x => x.id === id);
    return `<div class="hero"><span class="k">${g.kind}</span><span class="big"><bdi>${money(g.saved)}</bdi></span><span>of <bdi>${money(g.target)}</bdi> · on track for Mar 2027</span>${bar(g.saved, g.target, 'Progress')}</div>
      <div class="btn-row"><button class="btn primary" data-go="sheet:form:contribute">Add money</button><button class="btn" data-go="sheet:form:withdraw">Withdraw</button></div>
      ${section('Milestones', group([['25%', true], ['50%', true], ['75%', false], ['100%', false]].map(([m, ok]) => row({ title: m, trail: ok ? '<span class="status ok">✓ Reached</span>' : '<span class="status info">Not yet</span>' }))))}
      ${section('Auto-save', group([row({ title: 'Monthly reminder', sub: `${money(g.perMonth)} on the 28th (after salary)`, trail: 'On' }), row({ title: 'Round-ups', sub: 'Round purchases up to the nearest AED 5', trail: 'Off' }), row({ title: 'Share of salary', trail: '5%' })]))}
      <div class="btn-row"><button class="btn" data-act="toast" data-arg="Goal archived (sample)">Archive</button><button class="btn danger" data-act="confirm" data-arg="deleteGoal|${g.id}">Delete</button></div>`;
  },
};

SCREENS.income = {
  title: () => 'Income',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:income">Add</button>`,
  notes: { purpose: 'All income streams.', primary: 'Record a salary or other payment.', moved: ['Was hidden in the Budget toolbar menu.', '7 chip tabs → 5 views; Passive + Stability merged into Analysis.'], a11y: [] },
  render() {
    const v = ui('incView', 'overview');
    const s = DATA.income.salary;
    let body;
    if (v === 'overview') body = `<div class="hero"><span class="k">Income so far in October</span><span class="big"><bdi>${money(monthIncome())}</bdi></span><span>+4% vs September</span></div>` + group([row({ icon: '💼', title: 'Salary', sub: s ? `${esc(s.employer)} · ${s.onTime}` : 'Not set up', trail: s ? money(s.amount, 'AED', true) : '', act: 'seg', arg: 'incView|salary' }), row({ icon: '🧑‍💻', title: 'Freelance', sub: '1 active project', trail: money(4250, 'AED', true), act: 'seg', arg: 'incView|freelance' }), row({ icon: '🏠', title: 'Rental', sub: '1 property · occupied', trail: money(5200, 'AED', true), act: 'seg', arg: 'incView|rental' }), row({ icon: '📈', title: 'Dividends', sub: 'This year', trail: money(312, 'AED', true), act: 'seg', arg: 'incView|dividends' })]);
    else if (v === 'salary') body = s ? `<div class="card"><div class="row-title"><b>${esc(s.employer)}</b></div><div class="row-sub">Expected <bdi>${money(s.amount)}</bdi> on the ${s.day}th · ${s.onTime}</div><button class="btn primary" data-go="sheet:form:salaryPay">Record salary payment</button></div>` + section('History', group([row({ title: 'September', trail: '<span class="status ok">✓ On time</span>' }), row({ title: 'August', trail: '<span class="status warn">2 days late</span>' })])) : empty('💼', 'No salary set up', 'Add your salary to get a reminder and track late payments.', { text: 'Add salary', go: 'sheet:form:salary' });
    else if (v === 'freelance') body = group(DATA.income.freelance.map(f => row({ title: esc(f.name), sub: `Paid ${money(f.paid, 'AED', true)} of ${money(f.value, 'AED', true)}`, act: 'toast', arg: 'Project detail with invoices (sample)' }))) + `<button class="btn block" data-go="sheet:form:project">Add project</button>`;
    else if (v === 'rental') body = group(DATA.income.rental.map(r => row({ title: esc(r.name), sub: r.status, trail: `${money(r.rent, 'AED', true)}/mo`, act: 'toast', arg: 'Property detail: tenancy and rent records (sample)' }))) + `<button class="btn block" data-go="sheet:form:rentPay">Record rent payment</button>`;
    else if (v === 'dividends') body = group(DATA.income.dividends.map(x => row({ title: esc(x.name), sub: fmtShort.format(x.date), trail: money(x.amount) }))) + `<button class="btn block" data-go="sheet:form:dividend">Add dividend</button>`;
    else body = `<div class="card"><div class="row-title"><b>Income stability: 82 / 100</b></div><div class="row-sub">Salary on time 11 of 12 months; 2 other sources.</div>${bar(82, 100, 'Stability score')}</div><div class="card"><div class="row-title"><b>Passive income</b></div><div class="row-sub">${money(5512, 'AED', true)} a month · 19% of income</div>${bars([4800, 5100, 5200, 5250, 5300, 5512], ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'], 'Passive income, last 6 months, rising from 4,800 to 5,512 AED')}</div>`;
    return `${seg('incView', [['overview', 'Overview'], ['salary', 'Salary'], ['freelance', 'Freelance'], ['rental', 'Rental'], ['dividends', 'Dividends'], ['analysis', 'Analysis']], v)}${body}`;
  },
};

SCREENS.debt = {
  title: () => 'Debt',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:debt">Add</button>`,
  notes: { purpose: 'See and pay down what you owe; track money between people.', primary: 'Plan payoff.', moved: ['One entry (Plan → Debt) replaces Budget-menu and Accounts-grid entries.', '10 chip tabs → 4 views: Overview, Payoff plan, People, BNPL. Calculator and utilisation are inside Overview / Payoff plan. Bills tab removed (Bills has its own screen).'], a11y: ['Slider has a text value and +/− buttons.'] },
  render() {
    const v = ui('debtView', 'overview');
    const total = sum(DATA.loans, l => l.outstanding) + sum(DATA.bnpl, b => b.installment * (b.total - b.paid)) + sum(DATA.borrowed, b => b.amount) + Math.abs(DATA.accounts.find(a => a.id === 'a5')?.balance || 0);
    let body;
    if (v === 'overview') body = `<div class="hero"><span class="k">Total owed</span><span class="big"><bdi>${money(total)}</bdi></span><span>Minimum payments this month <bdi>${money(2150 + 349 + 162, 'AED', true)}</bdi></span></div>`
      + section('Loans', group(DATA.loans.map(l => row({ icon: '🚗', title: esc(l.name), sub: `${l.paid} of ${l.total} paid · ${l.rate}% · next ${fmtShort.format(l.next)}`, trail: money(l.outstanding, 'AED', true), go: `loan:${l.id}` }))))
      + section('Credit cards', group([row({ icon: '💳', title: 'FAB Visa Platinum', sub: `13% of limit used <span class="status ok">✓ Healthy</span>`, trail: money(3240.5), go: 'account:a5' })]));
    else if (v === 'plan') {
      const extra = ui('extra', 500);
      const m = ui('method', 'avalanche');
      body = `${seg('method', [['avalanche', 'Highest interest first'], ['snowball', 'Smallest balance first']], m)}
        <div class="card"><label for="extra" class="row-title"><b>Extra payment each month</b></label><div style="display:flex;gap:8px;align-items:center"><button class="circle-btn" style="background:var(--surface-2)" data-act="extra" data-arg="-250" aria-label="Decrease extra payment">−</button><input id="extra" type="range" min="0" max="5000" step="250" value="${extra}" data-input="extra" style="flex:1" aria-valuetext="${money(extra)}"><button class="circle-btn" style="background:var(--surface-2)" data-act="extra" data-arg="250" aria-label="Increase extra payment">＋</button></div><div class="row-sub"><bdi>${money(extra)}</bdi> a month</div></div>
        <div class="kpis"><div class="kpi"><div class="k">Debt-free</div><div class="v">${extra >= 1000 ? 'Mar 2028' : extra > 0 ? 'Nov 2028' : 'Oct 2029'}</div></div><div class="kpi"><div class="k">Interest saved</div><div class="v"><bdi>${money(extra * 3.1, 'AED', true)}</bdi></div></div></div>
        ${section('Order', group([row({ title: '1. FAB Visa Platinum', sub: '39% APR' }), row({ title: '2. Car loan — ENBD', sub: '3.49%' }), row({ title: '3. tabby — Noon', sub: '0%' })]))}<button class="btn block" data-act="toast" data-arg="Loan calculator (sample)">Loan calculator</button>`;
    } else if (v === 'people') body = section('Lent', group(DATA.lent.map(x => row({ icon: '🤝', title: esc(x.person), sub: `Due ${fmtShort.format(x.due)}`, trail: money(x.amount), go: 'sheet:form:repayment' })))) + section('Borrowed', group(DATA.borrowed.map(x => row({ icon: '🤝', title: esc(x.person), sub: `Due ${fmtShort.format(x.due)}`, trail: money(x.amount), go: 'sheet:form:repayment' })))) + `<div class="btn-row"><button class="btn" data-go="sheet:form:lent">I lent money</button><button class="btn" data-go="sheet:form:borrowed">I borrowed money</button></div>`;
    else body = DATA.bnpl.length ? DATA.bnpl.map(b => `<div class="card"><div class="row-title"><b>${b.provider} — ${esc(b.name)}</b></div><div class="row-sub">${b.paid} of ${b.total} instalments paid · next <bdi>${money(b.installment)}</bdi> on ${fmtShort.format(b.next)}</div>${bar(b.paid, b.total, 'Instalments paid')}<button class="btn primary" data-go="sheet:form:bnplPay">Record instalment</button></div>`).join('') : empty('🧩', 'No BNPL plans', 'Track tabby, Tamara and other instalment plans.', { text: 'Add plan', go: 'sheet:form:bnpl' });
    return `${seg('debtView', [['overview', 'Overview'], ['plan', 'Payoff plan'], ['people', 'People'], ['bnpl', 'BNPL']], v)}${body}`;
  },
};
SCREENS.loan = {
  title: () => 'Car loan — ENBD', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:loan">Edit</button>`,
  notes: { purpose: 'Loan detail.', primary: 'Record payment.', moved: ['Reachable from Wealth (liabilities) and Plan → Debt.'], a11y: ['Amortisation is a real table with headers.'] },
  render() {
    const l = DATA.loans[0];
    if (!l) return empty('🏦', 'No loan', '');
    return `<div class="hero"><span class="k">Outstanding</span><span class="big"><bdi>${money(l.outstanding)}</bdi></span><span>EMI <bdi>${money(l.emi)}</bdi> · ${l.rate}% · ${l.paid} of ${l.total} paid</span>${bar(l.paid, l.total, 'Instalments paid')}</div>
      <button class="btn primary block" data-go="sheet:form:loanPay">Record payment</button>
      ${section('Amortisation', `<div class="card" style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:.82em;font-variant-numeric:tabular-nums"><thead><tr><th style="text-align:start">Month</th><th style="text-align:end">Interest</th><th style="text-align:end">Principal</th><th style="text-align:end">Balance</th></tr></thead><tbody>${['Nov 26', 'Dec 26', 'Jan 27', 'Feb 27'].map((m, i) => `<tr><td>${m}</td><td style="text-align:end">${(158 - i * 6).toFixed(2)}</td><td style="text-align:end">${(1992 + i * 6).toFixed(2)}</td><td style="text-align:end">${(52308 - i * 1998).toLocaleString('en-AE')}</td></tr>`).join('')}</tbody></table></div>`)}
      ${section('Payments', group([row({ title: '1 Oct', trail: money(l.emi), go: 'txn:t10' })]))}`;
  },
};
SCREENS.family = {
  title: () => 'Household',
  notes: { purpose: 'Family records kept on this device.', primary: 'Open a household tool.', moved: ['Moved from Settings → Family Finance.', 'Copy now says plainly that nothing is shared or synced (true today).'], a11y: [] },
  render() {
    return `${banner('', 'ℹ︎', 'Household records are stored on this iPhone only. Nothing is shared with family members.')}
      <div class="card"><div class="row-title"><b>${esc(DATA.family?.group || 'No household yet')}</b></div><div class="row-sub">${(DATA.family?.members || []).join(' · ')}</div></div>
      ${group([['📊', 'Household overview', 'Cash flow and member summaries'], ['🎯', 'Household budget', 'Shared spending and bills'], ['🧒', 'Child allowances', 'Omar · next on 8 Oct'], ['⭐️', 'Shared goals', 'Summer trip — 45%'], ['🔐', 'Permissions', 'Who can see what (for your records)'], ['👥', 'Members', '3 people']].map(([i, t, s]) => row({ icon: i, title: t, sub: s, go: `familyTool:${t}` })))}`;
  },
};
SCREENS.familyTool = { title: t => t, large: false, notes: { purpose: 'Household tool (content summarised in the prototype).', primary: '—', moved: [], a11y: [] },
  render: t => `<div class="card"><div class="row-title"><b>${esc(t)}</b></div><div class="row-sub">Keeps today’s ${esc(t)} content and actions. The prototype shows the entry point and layout pattern only.</div></div>${group([row({ title: 'Sample item', sub: 'Tap for detail', act: 'toast', arg: `${t} detail (sample)` })])}<button class="btn primary block" data-act="toast" data-arg="Add sheet for ${esc(t)} (sample)">Add</button>` };

const TOOLS = [['🤖', 'AI CFO', 'Weekly money review and recommendations'], ['🏖', 'Retirement', 'Projection, UAE end-of-service gratuity'], ['💍', 'Life events', 'Wedding, baby, relocation checklists'], ['📜', 'Estate planning', 'Net estate, Zakat estimate, checklist'], ['💡', 'Smart cash allocation', 'Where idle cash could go'], ['📚', 'Learn', 'Short money lessons']];
SCREENS.tools = {
  title: () => 'Planning tools',
  notes: { purpose: 'Longer-term planning tools.', primary: 'Open a tool.', moved: ['Were “Premium Features” inside Settings.', 'Hidden features (Tax, Business, Insurance, Remittance, Collaborative planner) stay hidden by DisableableFeature; when re-enabled they appear in this list.'], a11y: [] },
  render: () => group(TOOLS.map(([i, t, s]) => row({ icon: i, title: t, sub: s, go: `tool:${t}` }))),
};
SCREENS.tool = { title: t => t, large: false, notes: { purpose: 'Planning tool.', primary: '—', moved: [], a11y: [] },
  render: t => t === 'Retirement' ? `<div class="hero"><span class="k">Retirement readiness</span><span class="big">68%</span><span>On track for <bdi>AED 3.1M</bdi> at 60 · target AED 4.5M</span>${bar(68, 100, 'Readiness')}</div>${group([row({ title: 'Monthly contribution', trail: 'AED 3,000' }), row({ title: 'Expected return', trail: '6%' }), row({ title: 'End-of-service gratuity', trail: 'AED 186,000' })])}<button class="btn primary block" data-go="sheet:form:retirement">Edit assumptions</button>`
    : `<div class="card"><div class="row-title"><b>${esc(t)}</b></div><div class="row-sub">Existing ${esc(t)} content is kept as is. The prototype shows the new entry point.</div></div>` };

// ---------- Wealth ----------
SCREENS.wealth = {
  title: () => 'Wealth',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:wealth">Add</button>`,
  notes: { purpose: 'What you own and owe.', primary: 'Open an account; see net worth.',
    moved: ['Accounts tab’s 4 inner tabs (Accounts / Investments / Crypto / Other) → one grouped list.', 'Net worth was a sheet → pushed screen.', 'Goals and Debt moved to Plan; Income moved to Plan.'],
    a11y: ['Liabilities show a minus sign and the word “owed”, not only red.'] },
  render() {
    const nw = netWorth();
    if (!DATA.accounts.length) return empty('🏦', 'No accounts yet', 'Add your bank accounts, cards and cash to see your net worth.', { text: 'Add an account', go: 'sheet:form:account' });
    const groups = {};
    DATA.accounts.forEach(a => { (groups[a.group] = groups[a.group] || []).push(a); });
    return `<button class="hero" data-go="networth" style="border:0;text-align:start;cursor:pointer" aria-label="Net worth ${money(nw.net)}. Assets ${money(nw.assets)}, liabilities ${money(nw.liab)}. Opens net worth."><span class="k">Net worth</span><span class="big"><bdi>${money(nw.net)}</bdi></span><span class="hero-stats"><span>Assets<b><bdi>${money(nw.assets, 'AED', true)}</bdi></b></span><span>Owed<b><bdi>${money(nw.liab, 'AED', true)}</bdi></b></span><span>This month<b><bdi>+2.4%</bdi></b></span></span></button>
      ${Object.entries(groups).map(([g, as]) => section(g, group(as.map(a => row({ icon: a.kind === 'Credit card' ? '💳' : a.kind === 'Cash' ? '💵' : '🏦', title: esc(a.name), sub: `${a.kind}${a.last4 ? ' ••' + a.last4 : ''}${a.limit ? ` · ${pct(Math.abs(a.balance), a.limit)}% of limit` : ''}`,
        trail: a.balance < 0 ? `<bdi>−${money(-a.balance, a.cur)}</bdi>` : `<bdi>${money(a.balance, a.cur)}</bdi>`, trailSub: a.balance < 0 ? 'owed' : (a.cur !== 'AED' ? `<bdi>≈ ${money(toBase(a.balance, a.cur), 'AED', true)}</bdi>` : ''), go: `account:${a.id}` }))))).join('')}
      ${section('Loans & instalments', group([...DATA.loans.map(l => row({ icon: '🚗', title: esc(l.name), sub: 'Loan', trail: `<bdi>−${money(l.outstanding, 'AED', true)}</bdi>`, trailSub: 'owed', go: `loan:${l.id}` })), ...DATA.bnpl.map(b => row({ icon: '🧩', title: `${b.provider} — ${esc(b.name)}`, sub: 'BNPL', trail: `<bdi>−${money(b.installment * (b.total - b.paid), 'AED', true)}</bdi>`, trailSub: 'owed', go: 'debt' }))]))}
      ${section('Investments & assets', group([row({ icon: '📈', title: 'Investments', sub: 'Stocks, ETFs, crypto, gold', trail: money(sum(DATA.investments, i => i.value), 'AED', true), go: 'investments' }), row({ icon: '🏠', title: 'Property & assets', sub: 'Real estate, vehicles, personal, digital', trail: money(sum(DATA.assets, a => a.value), 'AED', true), go: 'assets' }), row({ icon: '🎁', title: 'Cards & rewards', sub: 'Gift cards and loyalty points', trail: money(sum(DATA.rewards, r => r.est), 'AED', true), go: 'rewards' })]))}`;
  },
};
SCREENS.account = {
  title: id => acct(id)?.name || 'Account', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:account">Edit</button>`,
  notes: { purpose: 'One account’s balance and history.', primary: 'Add a transaction to this account.', moved: ['Was a sheet; now pushed.', 'Home’s account cards now open this instead of switching tabs.'], a11y: ['Chart has a text summary.'] },
  render(id) {
    const a = acct(id);
    if (!a) return empty('🏦', 'Account not found', '');
    const txs = DATA.transactions.filter(t => t.acct === id || t.to === id).sort((x, y) => y.date - x.date);
    return `<div class="hero"><span class="k">${a.kind}${a.last4 ? ' ••' + a.last4 : ''}</span><span class="big"><bdi>${a.balance < 0 ? '−' : ''}${money(Math.abs(a.balance), a.cur)}</bdi></span>${a.limit ? `<span>${money(a.limit - Math.abs(a.balance), a.cur, true)} available · due ${fmtShort.format(a.due)}</span>` : '<span>Balance</span>'}</div>
      <div class="card">${spark([16.2, 17.1, 16.4, 15.9, 40.1, 39.2, 21.4, 20.9, 19.8, 18.45], `Balance over the last 30 days, ending at ${money(a.balance, a.cur)}`)}<div class="row-sub">Last 30 days</div></div>
      <button class="btn primary block" data-go="sheet:add">Add transaction</button>
      ${section('Transactions', txs.length ? group(txs.slice(0, 6).map(txRow)) : empty('🧾', 'No transactions in this account', ''))}`;
  },
};
SCREENS.networth = {
  title: () => 'Net worth',
  notes: { purpose: 'Net worth over time.', primary: 'Record a snapshot.', moved: ['Was a sheet from Accounts; now pushed (Wealth hero, Home shortcut).'], a11y: ['Each chart has a spoken summary.'] },
  render() {
    const v = ui('nwView', 'overview'); const nw = netWorth();
    const body = {
      overview: `<div class="hero"><span class="k">Net worth</span><span class="big"><bdi>${money(nw.net)}</bdi></span><span>Top 18% for your age in the UAE (estimate)</span></div>${group([row({ title: 'Cash & bank', trail: money(sum(DATA.accounts.filter(a => a.balance > 0), a => toBase(a.balance, a.cur)), 'AED', true) }), row({ title: 'Investments', trail: money(sum(DATA.investments, i => i.value), 'AED', true) }), row({ title: 'Property & assets', trail: money(sum(DATA.assets, a => a.value), 'AED', true) }), row({ title: 'Owed', trail: `−${money(nw.liab, 'AED', true)}` })])}`,
      history: `<div class="card">${spark([512, 528, 541, 538, 556, 571, 590, 602], 'Net worth rose from 512 thousand to 602 thousand AED over 8 months')}<div class="row-sub">Snapshots you recorded · 8 months</div></div>`,
      forecast: `<div class="card"><div class="row-title"><b>In 10 years: about AED 1.9M</b></div><div class="row-sub">Saving AED 4,000/month at 6% return</div>${spark([602, 760, 930, 1120, 1330, 1560, 1900], 'Forecast rising to 1.9 million AED in 10 years')}</div>`,
      allocation: `<div class="card"><div class="split-h">${donut([{ l: 'Property', v: 1.1e6, c: 'var(--cat-blue)' }, { l: 'Investments', v: 99e3, c: 'var(--cat-teal)' }, { l: 'Cash', v: 66e3, c: 'var(--cat-gold)' }, { l: 'Other', v: 114e3, c: 'var(--cat-purple)' }], 'Asset allocation')}${legend([{ l: 'Property', v: 1.1e6, c: 'var(--cat-blue)' }, { l: 'Investments', v: 99e3, c: 'var(--cat-teal)' }, { l: 'Cash', v: 66e3, c: 'var(--cat-gold)' }, { l: 'Other', v: 114e3, c: 'var(--cat-purple)' }])}</div></div>`,
      milestones: group([['AED 100,000', true], ['AED 250,000', true], ['AED 500,000', true], ['AED 1,000,000', false]].map(([m, ok]) => row({ title: m, trail: ok ? '<span class="status ok">✓ Reached</span>' : '<span class="status info">Next</span>' }))),
    }[v];
    return `${seg('nwView', [['overview', 'Overview'], ['history', 'History'], ['forecast', 'Forecast'], ['allocation', 'Allocation'], ['milestones', 'Milestones']], v)}${body}<button class="btn block" data-act="toast" data-arg="Snapshot recorded for 5 Oct">Record today’s snapshot</button>`;
  },
};
SCREENS.investments = {
  title: () => 'Investments',
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:investment">Add</button>`,
  notes: { purpose: 'Portfolio value and holdings.', primary: 'Open a holding; refresh prices.', moved: ['10 chip tabs → Holdings (grouped by type) + an Analysis list (Allocation, Performance, Dividends, Capital gains, Scenarios, Simulation).'], a11y: ['Gains show ▲/▼ and a sign, not only green/red.'] },
  render() {
    const v = ui('invView', 'holdings');
    const total = sum(DATA.investments, i => i.value);
    const by = {}; DATA.investments.forEach(i => { (by[i.kind] = by[i.kind] || []).push(i); });
    const holdings = Object.entries(by).map(([k, is]) => section(k === 'Gold' ? 'Gold & metals' : k === 'Stock' ? 'Stocks' : k, group(is.map(i => row({ title: esc(i.name), sub: i.symbol, trail: money(i.value, 'AED', true), trailSub: `${i.change >= 0 ? '▲ +' : '▼ '}${i.change}%`, act: 'toast', arg: `${i.name}: lots, sales and edit (sample)` }))))).join('');
    const analysis = group(['Allocation', 'Performance vs benchmark', 'Dividends', 'Capital gains', 'Scenarios', 'Monte Carlo simulation'].map(x => row({ title: x, act: 'toast', arg: `${x} (sample)` })));
    return `${P.network === 'offline' ? banner('warn', '⚠︎', 'Prices last updated 10:42. They’ll refresh when you’re back online.') : ''}<div class="hero"><span class="k">Portfolio</span><span class="big"><bdi>${money(total)}</bdi></span><span><bdi>▲ +${money(7840, 'AED', true)} (+8.6%)</bdi> all time</span></div>
      ${seg('invView', [['holdings', 'Holdings'], ['analysis', 'Analysis']], v)}${v === 'holdings' ? holdings : analysis}<button class="btn block" data-act="refreshPrices">Refresh prices</button>`;
  },
};
SCREENS.assets = {
  title: () => 'Property & assets',
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:asset">Add</button>`,
  notes: { purpose: 'Non-financial assets.', primary: 'Add an asset.', moved: ['Was “Assets & Liabilities” (name promised liabilities it didn’t show).'], a11y: [] },
  render: () => DATA.assets.length ? ['Real estate', 'Vehicle', 'Personal', 'Digital'].filter(k => DATA.assets.some(a => a.kind === k)).map(k => section(k === 'Vehicle' ? 'Vehicles' : k, group(DATA.assets.filter(a => a.kind === k).map(a => row({ title: esc(a.name), sub: a.owed ? `Mortgage ${money(a.owed, 'AED', true)}` : '', trail: money(a.value, 'AED', true), act: 'toast', arg: `${a.name}: edit / archive / delete (sample)` }))))).join('') : empty('🏠', 'No property or assets', 'Add real estate, vehicles, valuables or digital assets to include them in net worth.', { text: 'Add an asset', go: 'sheet:form:asset' }),
};
SCREENS.rewards = {
  title: () => 'Cards & rewards',
  trail: () => `<button class="pill-btn glass" data-go="sheet:form:reward">Add</button>`,
  notes: { purpose: 'Gift cards and loyalty programmes.', primary: 'Add.', moved: ['Was the “Other” inner tab of Accounts.'], a11y: ['Gift-card PIN field will be a secure field (it is a plain text field today).'] },
  render: () => group(DATA.rewards.map(r => row({ icon: r.kind === 'Gift card' ? '🎁' : '✈️', title: esc(r.name), sub: `${r.value}${r.expires ? ' · ' + r.expires : ''}`, trail: `≈ ${money(r.est, 'AED', true)}`, act: 'toast', arg: `${r.name} detail (sample)` }))),
};

// ---------- Insights & reports ----------
const INSIGHT_TOOLS = [['patterns', '📅', 'Spending patterns', 'By day, hour and merchant'], ['anomalies', '⚠️', 'Unusual spending', '2 found this month'], ['forecast', '🔮', 'Balance forecast', 'Next 30 days'], ['savings', '💰', 'Ways to save', 'AED 410/month possible'], ['coach', '🎓', 'Budget coach', 'Weekly tips'], ['negotiate', '📞', 'Lower your bills', 'Scripts for du and DEWA'], ['twin', '🧪', 'What-if simulator', 'Try changes to income and spending'], ['esg', '🌱', 'Spending impact', 'Estimated carbon by category']];
SCREENS.insights = {
  title: () => 'Insights',
  trail: () => `<button class="pill-btn glass" data-go="sheet:ask">Ask</button>`,
  notes: { purpose: 'One home for analysis.', primary: 'Health score; Ask.', moved: ['Merges the AI Assistant hub (Dashboard sparkle icon) and Financial Intelligence (Settings). Two different health scores become one (decision needed — see implementation plan).'], a11y: ['Score is announced with its grade and meaning.'] },
  render: () => `<button class="card" style="border:0;text-align:start;cursor:pointer" data-go="insight:health" aria-label="Financial health 74 out of 100, grade B. Opens details."><div class="row-title"><b>Financial health · 74 / 100 · B</b></div><div class="row-sub">Strong savings rate; emergency fund covers 3.2 months (aim for 6).</div>${bar(74, 100, 'Health score')}</button>
    ${section('Explore', `<div class="grid-tiles">${INSIGHT_TOOLS.map(([k, i, t, s]) => `<button class="tile" data-go="insight:${k}"><span aria-hidden="true" style="font-size:1.3em">${i}</span><span class="t">${t}</span><span class="s">${s}</span></button>`).join('')}</div>`)}
    ${section('Latest', group([row({ icon: '🍽', title: 'Dining up 23% vs 3-month average', sub: 'Mostly late-night delivery', go: 'insight:patterns' }), row({ icon: '🔁', title: 'Spotify Family unused for 41 days', go: 'bill:bl4' }), row({ icon: '📈', title: 'Savings rate 29% — above your 20% target', go: 'report:trends' })]))}
    <p class="inline-note">Calculated on this iPhone from your own data.</p>`,
};
SCREENS.insight = {
  title: k => k === 'health' ? 'Financial health' : (INSIGHT_TOOLS.find(x => x[0] === k) || [])[2] || 'Insight', large: false,
  notes: { purpose: 'One analysis tool.', primary: '—', moved: ['Destinations of the old AI hub, pushed in one NavigationStack (the current code nests stacks).'], a11y: [] },
  render(k) {
    if (k === 'health') return `<div class="hero"><span class="k">Financial health</span><span class="big">74 / 100</span><span>Grade B</span></div>${group([['Savings rate', '29%', 'ok'], ['Emergency fund', '3.2 months', 'warn'], ['Debt to income', '18%', 'ok'], ['Budget discipline', '3 of 5 on track', 'warn'], ['Goals', 'On track', 'ok']].map(([t, v, c]) => row({ title: t, trail: `<span class="status ${c}">${c === 'ok' ? '✓' : '●'} ${v}</span>` })))}${section('Predictions', group([row({ title: 'End-of-month balance', trail: money(16900, 'AED', true), sub: 'High confidence' }), row({ title: 'Bills still due in October', trail: money(1278, 'AED', true) })]))}`;
    if (k === 'patterns') return `<div class="card"><div class="row-title"><b>You spend most on Fridays</b></div>${bars([310, 280, 260, 300, 820, 640, 410], ['M', 'T', 'W', 'T', 'F', 'S', 'S'], 'Average spend by weekday; Friday highest at 820 AED')}</div>${section('Top merchants', group([row({ title: 'Carrefour', trail: money(1180, 'AED', true) }), row({ title: 'Talabat', trail: money(690, 'AED', true) }), row({ title: 'ENOC', trail: money(540, 'AED', true) })]))}`;
    if (k === 'forecast') return `<div class="card"><div class="row-title"><b>Lowest point: AED 9,800 on 31 Oct</b></div>${spark([18.4, 17.2, 16.1, 15.5, 12.0, 11.2, 9.8, 33.5], 'Balance forecast for 30 days, lowest 9,800 AED on 31 October, then salary')}<div class="row-sub">Includes bills and EMIs; salary expected 28 Oct.</div></div>`;
    return `<div class="card"><div class="row-title"><b>${esc((INSIGHT_TOOLS.find(x => x[0] === k) || [])[2])}</b></div><div class="row-sub">${esc((INSIGHT_TOOLS.find(x => x[0] === k) || [])[3])}. Existing content is kept; this prototype shows the entry point.</div></div>`;
  },
};
const REPORTS = [['cashflow', 'Cash flow'], ['spending', 'Spending'], ['income', 'Income statement'], ['investments', 'Investments'], ['debt', 'Debt'], ['cheques', 'Cheques'], ['networth', 'Net worth'], ['trends', 'Trends'], ['goals', 'Savings goals'], ['tax', 'Tax summary'], ['vat', 'VAT (5%)'], ['annual', 'Annual summary'], ['merchants', 'Merchants']];
SCREENS.reports = {
  title: () => 'Reports',
  notes: { purpose: 'Standard reports with export.', primary: 'Open a report.', moved: ['Was an unlabelled icon on Dashboard; 13 report chips → a list (scannable, works at large text sizes).'], a11y: [] },
  render: () => `${seg('period', [['week', 'Week'], ['month', 'Month'], ['q', '3 months'], ['year', 'Year'], ['custom', 'Custom']], ui('period', 'month'))}${group(REPORTS.map(([k, t]) => row({ title: t, go: `report:${k}` })))}`,
};
SCREENS.report = {
  title: k => (REPORTS.find(r => r[0] === k) || [])[1] || 'Report', large: false,
  trail: () => `<button class="pill-btn glass" data-go="sheet:export">Export</button>`,
  notes: { purpose: 'A report.', primary: 'Export as PDF or CSV.', moved: ['Export kept; now a labelled toolbar button.'], a11y: ['Charts summarised in text.'] },
  render(k) {
    const sl = catSpend();
    return `<p class="subtitle">October 2026 · compared with September</p>${k === 'spending' ? `<div class="card"><div class="split-h">${donut(sl, 'Spending by category')}${legend(sl)}</div></div>` : `<div class="card">${bars([21.2, 19.8, 23.4, 20.1, 22.7, 6.2], ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'], 'Monthly totals, May to October')}</div>`}
      ${group([row({ title: 'Total', trail: money(monthSpend()) }), row({ title: 'vs September', trail: '▼ −12%' }), row({ title: 'Largest', trail: 'Rent — AED 7,500' })])}`;
  },
};

// ---------- Search ----------
function searchIndex() {
  const screens = FEATURES.filter(f => f[0] !== 'Hidden').map(f => ({ kind: 'Screen or setting', title: f[1], sub: f[4], go: f[5] }));
  const extra = [['Face ID & Passcode', 'security'], ['Notifications', 'notifications'], ['Appearance', 'appearance'], ['Backup & Restore', 'backup'], ['Clear all data', 'backup'], ['Base currency', 'settings'], ['Siri & Shortcuts', 'siri'], ['Categories & Rules', 'categories']].map(([t, g]) => ({ kind: 'Screen or setting', title: t, sub: 'Settings', go: g }));
  return [...DATA.transactions.map(t => ({ kind: 'Transactions', title: t.title, sub: `${CATS[t.cat].name} · ${dayLabel(t.date)}`, trail: signed(t), go: `txn:${t.id}` })),
    ...DATA.accounts.map(a => ({ kind: 'Accounts', title: a.name, sub: a.kind, trail: money(a.balance, a.cur), go: `account:${a.id}` })),
    ...DATA.bills.map(b => ({ kind: 'Bills', title: b.name, sub: dueLabel(b.due).t, trail: money(b.amount), go: `bill:${b.id}` })),
    ...DATA.goals.map(g => ({ kind: 'Goals', title: g.name, sub: `${pct(g.saved, g.target)}% saved`, go: `goal:${g.id}` })),
    ...extra, ...screens];
}
function searchResults() {
  const q = (S.ui.sq || '').trim().toLowerCase();
  const scope = ui('sScope', 'all');
  if (!q) return `${section('Suggestions', group([row({ icon: '🔎', title: 'Carrefour', act: 'searchFor', arg: 'Carrefour' }), row({ icon: '🔎', title: 'Bills due this week', act: 'searchFor', arg: 'due' }), row({ icon: '🔎', title: 'Backup', act: 'searchFor', arg: 'backup' })]))}
    ${section('Browse', group([['Home', 'tab:home'], ['Activity', 'tab:activity'], ['Plan', 'tab:plan'], ['Wealth', 'tab:wealth'], ['Insights', 'insights'], ['Reports', 'reports'], ['Import & Sync', 'import'], ['Settings', 'settings']].map(([t, g]) => row({ title: t, go: g }))))}`;
  const map = { tx: 'Transactions', accts: 'Accounts', screens: 'Screen or setting' };
  const res = searchIndex().filter(r => (scope === 'all' || r.kind === map[scope]) && `${r.title} ${r.sub}`.toLowerCase().includes(q));
  if (!res.length) return empty('🔍', `No results for “${esc(S.ui.sq)}”`, 'Check the spelling or search for a merchant, account, amount or setting.');
  const by = {}; res.forEach(r => { (by[r.kind] = by[r.kind] || []).push(r); });
  return Object.entries(by).map(([k, rs]) => section(k, group(rs.slice(0, 8).map(r => row({ title: esc(r.title), sub: esc(r.sub), trail: r.trail, go: r.go }))))).join('');
}
SCREENS.search = {
  title: () => 'Search',
  notes: { purpose: 'Find any record, screen or setting by name.', primary: 'Type.', moved: ['New (uses iOS Tab role .search). Previously no way to find a feature by name; Spotlight indexing of transactions/accounts stays.'], a11y: ['Results grouped with headings; empty state explains what you can search.'] },
  render: () => `<div class="search-field"><span aria-hidden="true">🔍</span><label class="sr-only" for="s-q">Search FinTrack</label><input id="s-q" type="search" placeholder="Merchants, accounts, bills, settings" value="${esc(S.ui.sq || '')}" data-input="search" autocomplete="off"></div>
    ${chips('sScope', [['all', 'All'], ['tx', 'Transactions'], ['accts', 'Accounts'], ['screens', 'Screens & settings']], ui('sScope', 'all'))}<div id="s-results">${searchResults()}</div>`,
};

// ---------- Settings ----------
SCREENS.settings = {
  title: () => 'Settings',
  notes: { purpose: 'Preferences only. Modules moved out to Plan, Wealth and Insights.', primary: '—',
    moved: ['Premium features, Financial Intelligence, Family → Plan / Insights.', 'Face ID / PIN / Auto-lock were in Settings AND Security & Privacy → one page.', 'New: Siri & Shortcuts, Home Screen.'], a11y: ['Grouped rows with values shown as trailing text.'] },
  render: () => `<div class="card" style="flex-direction:row;align-items:center"><span class="row-icon" aria-hidden="true" style="width:48px;height:48px;border-radius:50%">👤</span><div class="row-main"><label for="pname" class="row-sub">Your name</label><input id="pname" value="${esc(DATA.profile.name)}" style="border:0;background:transparent;font-size:1.1em;font-weight:600;width:100%;min-height:36px" data-input="pname"></div></div>
    ${group([row({ icon: '💱', title: 'Base currency', trail: 'AED', go: 'sheet:form:currency' }), row({ icon: '🔔', title: 'Notifications', go: 'notifications' }), row({ icon: '🎨', title: 'Appearance', go: 'appearance' }), row({ icon: '🏠', title: 'Home screen', go: 'home-edit' }), row({ icon: '🎙', title: 'Siri & Shortcuts', go: 'siri' })])}
    ${group([row({ icon: '⇅', title: 'Import & Sync', go: 'import' }), row({ icon: '🏷', title: 'Categories & Rules', go: 'categories' }), row({ icon: '💾', title: 'Backup & Restore', go: 'backup' })])}
    ${group([row({ icon: '🔐', title: 'Face ID & Passcode', trail: 'On', go: 'security' })])}
    ${group([row({ icon: 'ℹ︎', title: 'About FinTrack', go: 'about' })])}`,
};
SCREENS.security = {
  title: () => 'Face ID & Passcode',
  notes: { purpose: 'App lock.', primary: 'Toggle Face ID / passcode.', moved: ['Single home for controls previously duplicated in Settings and Security & Privacy.'], a11y: ['Switches are role=switch with labels.'] },
  render: () => `<div class="card"><div class="row-title"><b>Security score: 80 / 100</b></div><div class="row-sub">Turn on a passcode as a backup to Face ID to reach 100.</div>${bar(80, 100, 'Security score')}</div>
    <div class="form-group"><div class="field"><label for="sec-face" style="flex:1">Unlock with Face ID</label><input id="sec-face" type="checkbox" class="switch" role="switch" checked></div>
    <div class="field"><label for="sec-pin" style="flex:1">App passcode</label><input id="sec-pin" type="checkbox" class="switch" role="switch" data-act="pinToggle" ${S.ui.pin ? 'checked' : ''}></div>
    <div class="field"><label for="sec-auto">Lock after</label><select id="sec-auto"><option>Immediately</option><option selected>1 minute</option><option>5 minutes</option><option>15 minutes</option></select></div></div>
    <p class="inline-note">Your data is always encrypted on this iPhone.</p><button class="btn block" data-go="scene:lock">Preview lock screen</button>`,
};
SCREENS.notifications = {
  title: () => 'Notifications',
  notes: { purpose: 'Alert preferences.', primary: '—', moved: ['Unchanged; adds the permission-denied state.'], a11y: ['Disabled switches explain why.'] },
  render() {
    const denied = P.notifPerm === 'denied';
    const sw = (id, label, on = true) => `<div class="field"><label for="${id}" style="flex:1">${label}</label><input id="${id}" type="checkbox" class="switch" role="switch" ${on ? 'checked' : ''} ${denied ? 'disabled aria-describedby="perm-msg"' : ''}></div>`;
    return `${denied ? `<div id="perm-msg">${banner('err', '🔕', '<b>Notifications are off for FinTrack.</b> Turn them on in iOS Settings to get bill and budget alerts.', { text: 'Open Settings', act: 'toast', arg: 'Would open iOS Settings → FinTrack — simulated' })}</div>` : ''}
      <div class="form-group">${sw('n-bills', 'Bill reminders')}${sw('n-b75', 'Budget at 75%')}${sw('n-b90', 'Budget at 90%')}${sw('n-b100', 'Budget over')}${sw('n-low', 'Low balance (below AED 1,000)')}${sw('n-large', 'Large purchase (over AED 2,000)')}${sw('n-sal', 'Salary late')}${sw('n-goal', 'Goal milestones')}${sw('n-imp', 'New items to review')}</div>
      <div class="form-group">${sw('n-week', 'Weekly summary (Sunday 9:00)', false)}${sw('n-month', 'Monthly summary (1st, 9:00)')}</div>`;
  },
};
SCREENS.appearance = {
  title: () => 'Appearance',
  notes: { purpose: 'Theme and calendar preferences.', primary: '—', moved: ['Unchanged. Text size and motion follow iOS Settings (Dynamic Type, Reduce Motion).'], a11y: ['Accent swatches have names, not only colours.'] },
  render: () => `${section('Theme', seg('theme', [['system', 'System'], ['light', 'Light'], ['dark', 'Dark'], ['oled', 'Black']], ui('theme', 'system')))}
    ${section('Accent', `<div class="chips">${[['teal', '#0E9C8A'], ['blue', '#1A6FD0'], ['purple', '#7C5BD0'], ['coral', '#E5736B'], ['gold', '#C8902B'], ['rose', '#D04B7C']].map(([n, c]) => `<button class="chip" aria-pressed="${ui('accentName', 'teal') === n}" data-act="seg" data-arg="accentName|${n}"><span aria-hidden="true" style="display:inline-block;width:12px;height:12px;border-radius:50%;background:${c};margin-inline-end:6px"></span>${n[0].toUpperCase() + n.slice(1)}</button>`).join('')}</div>`)}
    <div class="form-group"><div class="field"><label for="ap-hc" style="flex:1">Increase contrast</label><input id="ap-hc" type="checkbox" class="switch" role="switch" data-act="hcToggle" ${P.contrast === 'high' ? 'checked' : ''}></div><div class="field"><label for="ap-wk">First day of week</label><select id="ap-wk"><option>Monday</option><option>Saturday</option><option>Sunday</option></select></div><div class="field"><label for="ap-fy">Financial year starts</label><select id="ap-fy"><option>January</option><option>April</option></select></div></div>
    <p class="inline-note">Text size, bold text, Reduce Motion and Reduce Transparency follow iOS Settings → Accessibility.</p>`,
};
SCREENS.categories = {
  title: () => 'Categories & Rules',
  trail: () => `<button class="pill-btn glass" data-go="sheet:addMenu:categories">Add</button>`,
  notes: { purpose: 'Custom categories and auto-categorisation rules.', primary: 'Add.', moved: ['Were two separate sheets from Settings; now one pushed screen. Deleting a category with subcategories now confirms.'], a11y: [] },
  render: () => `${section('Your categories', group([row({ icon: '🐾', title: 'Pets', sub: '2 subcategories', go: 'sheet:form:category' }), row({ icon: '🎓', title: 'School fees', go: 'sheet:form:category' })]))}
    ${section('Rules', group([row({ title: 'Merchant contains “ENOC” → Transport', sub: 'Priority 1 · on', go: 'sheet:form:rule' }), row({ title: 'Merchant contains “Spinneys” → Groceries', sub: 'Priority 2 · on', go: 'sheet:form:rule' })]))}
    <p class="inline-note">Rules apply when you add a transaction and to email, SMS, Apple Pay and file imports.</p>`,
};
SCREENS.backup = {
  title: () => 'Backup & Restore',
  notes: { purpose: 'Protect and restore data.', primary: 'Back up now.', moved: ['Was split across Settings → Data & Privacy rows and Import & Sync → Backup.', 'Clear All Data moved to the bottom with a typed confirmation.'], a11y: ['Progress announced; destructive action requires typing.'] },
  render: () => `<div class="card"><div class="row-title"><b>Last backup: today, 18:42</b></div><div class="row-sub">1.4 MB · encrypted · stored privately on this iPhone · survives reinstalling the app</div><button class="btn primary" data-act="backupNow">${S.ui.backingUp ? 'Backing up…' : 'Back up now'}</button></div>
    <div class="form-group"><div class="field"><label for="bk-auto" style="flex:1">Back up after every change</label><input id="bk-auto" type="checkbox" class="switch" role="switch" checked></div></div>
    ${group([row({ title: 'Restore from on-device backup', sub: 'Merge or replace', act: 'confirm', arg: 'restore' }), row({ title: 'Email backup', sub: 'Send an encrypted copy to your own inbox every hour', go: 'sheet:form:emailBackup' }), row({ title: 'Import a backup file', sub: '.fintrack files made on this iPhone', act: 'confirm', arg: 'restore' })])}
    <p class="inline-note">Backups can only be opened on this iPhone.</p>
    ${section('Danger zone', `<button class="btn danger block" data-go="sheet:clear">Clear all data…</button>`)}`,
};
SCREENS.siri = {
  title: () => 'Siri & Shortcuts',
  notes: { purpose: 'Show what Siri and Shortcuts can do with FinTrack.', primary: 'Try a phrase.', moved: ['New page — the intents already exist (FinTrackIntents.swift) but nothing in the app mentions them.'], a11y: [] },
  render: () => `${section('Ask Siri', group([['“Log an expense in FinTrack”', 'siriLog'], ['“What’s my FinTrack balance?”', 'siriBalance'], ['“Show my budget status in FinTrack”', 'siriBudget'], ['“Open my FinTrack transactions”', 'siriOpen']].map(([t, a]) => row({ icon: '🎙', title: t, sub: 'Try it (simulated)', act: a }))))}
    ${section('Automations', group([row({ icon: '💬', title: 'Bank SMS → To review', go: 'import-sms' }), row({ icon: '📱', title: 'Apple Pay → To review', go: 'import-applepay' })]))}
    ${section('Proposed for iOS 27 (needs your approval)', `<div class="sysbox">${row({ icon: '🧠', title: 'Refer to what’s on screen', sub: '“Split this with Layla” while a transaction is open. Uses App Intents view annotations. <span class="status warn">Proposed · iOS 27 SDK</span>', act: 'siriThis' })}${row({ icon: '🔎', title: 'Let Siri search your transactions', sub: 'Index transactions as App Intents entities for Spotlight’s semantic search. Off by default because it puts financial data in the system index. <span class="status warn">Proposed · privacy review</span>' })}</div>`)}`,
};
SCREENS.about = {
  title: () => 'About',
  notes: { purpose: 'Version and legal.', primary: '—', moved: ['Version comes from the bundle (was hard-coded once).'], a11y: [] },
  render: () => `${group([row({ title: 'Version', trail: '1.0.1 (sample)' }), row({ title: 'Privacy policy', act: 'toast', arg: 'Privacy policy (existing text)' }), row({ title: 'Terms of service', act: 'toast', arg: 'Terms (existing text)' })])}<p class="inline-note">FinTrack keeps your data on this iPhone. Exchange rates, prices, merchant lookups and mail are the only network requests.</p>`,
};
