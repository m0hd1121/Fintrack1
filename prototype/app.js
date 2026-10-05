// FinTrack redesign prototype — app shell, navigation, sheets, actions, workbench.
'use strict';

const clone = o => JSON.parse(JSON.stringify(o), (k, v) => (typeof v === 'string' && /^\d{4}-\d\d-\d\dT/.test(v) ? new Date(v) : v));
let DATA = clone(SAMPLE);
const EMPTY = { profile: { name: 'Mohammad', base: 'AED' }, accounts: [], transactions: [], review: [], budgets: [], envelopes: [], bills: [], goals: [], loans: [], bnpl: [], lent: [], borrowed: [],
  income: { salary: null, freelance: [], rental: [], dividends: [] }, investments: [], assets: [], rewards: [], family: null, emailAccounts: [], bankRules: [] };

// Workbench preferences (simulated device/OS state)
const P = { size: 'standard', appearance: 'light', text: 'default', transparency: 'normal', motion: 'normal', contrast: 'normal', rtl: false, pseudo: false,
  dataset: 'sample', network: 'online', loading: false, notifPerm: 'granted', camPerm: 'granted', syncError: false };
const SIZES = { compact: [375, 667, 'Small iPhone · 375 × 667 pt'], standard: [402, 874, 'iPhone · 402 × 874 pt'], large: [440, 956, 'Large iPhone · 440 × 956 pt'],
  regular: [900, 700, 'Regular width · 900 × 700 (iPad or a foldable’s inner display — representative size, not a device spec)'] };
const TEXT = { default: [1, false, 'Default'], large: [1.18, false, 'Large'], xxl: [1.35, false, 'XXL'], ax3: [1.9, true, 'Accessibility 3'] };

// Navigation / UI state
const ROOTS = { home: 'home', activity: 'activity', plan: 'plan', wealth: 'wealth', search: 'search' };
const S = { tab: 'home', stacks: { home: ['home'], activity: ['activity'], plan: ['plan'], wealth: ['wealth'], search: ['search'] },
  sheet: null, dialog: null, toast: null, scene: null, siri: null, form: null, chat: null, ui: {} };
const isRegular = () => P.size === 'regular';
const parse = r => { const i = r.indexOf(':'); return i < 0 ? [r, undefined] : [r.slice(0, i), r.slice(i + 1)]; };
const curRoute = () => S.stacks[S.tab][S.stacks[S.tab].length - 1];
let toastTimer = null, siriTimer = null;

// ---------------- navigation ----------------
function go(route, opener) {
  if (route.startsWith('sheet:')) return openSheet(route.slice(6));
  if (route.startsWith('scene:')) { S.scene = route.slice(6); S.ui.pinEntry = ''; S.ui.obStep = 0; return render(); }
  if (route.startsWith('tab:')) return switchTab(route.slice(4));
  // From the Search tab, results open in the tab that owns them.
  const owner = ownerTab(route);
  if (S.tab === 'search' && owner && owner !== 'search') { S.tab = owner; S.stacks[owner] = parse(route)[0] === ROOTS[owner] ? [owner] : [ROOTS[owner], route]; }
  else S.stacks[S.tab].push(route);
  S.ui.focusTitle = true; S.ui.selecting = false;
  render();
}
function ownerTab(route) {
  const id = parse(route)[0];
  const map = { home: 'home', 'home-edit': 'home', upcoming: 'home', insights: 'home', insight: 'home', reports: 'home', report: 'home', settings: 'home', security: 'home', notifications: 'home', appearance: 'home', categories: 'home', backup: 'home', siri: 'home', about: 'home',
    activity: 'activity', txn: 'activity', review: 'activity', import: 'activity', 'import-email': 'activity', 'import-sms': 'activity', 'import-applepay': 'activity', 'import-csv': 'activity', 'import-ofx': 'activity',
    plan: 'plan', budgets: 'plan', budget: 'plan', bills: 'plan', bill: 'plan', goals: 'plan', goal: 'plan', income: 'plan', debt: 'plan', loan: 'plan', family: 'plan', familyTool: 'plan', tools: 'plan', tool: 'plan',
    wealth: 'wealth', account: 'wealth', networth: 'wealth', investments: 'wealth', assets: 'wealth', rewards: 'wealth', search: 'search' };
  return map[id];
}
function back() { if (S.stacks[S.tab].length > 1) S.stacks[S.tab].pop(); S.ui.focusTitle = true; render(); }
function switchTab(tab) {
  if (S.tab === tab) S.stacks[tab] = [ROOTS[tab]]; // tapping the current tab pops to root (keeps popToRootTick behaviour)
  S.tab = tab; S.ui.selecting = false; S.ui.focusTitle = true; render();
}
function titleOf(route) { const [id, p] = parse(route); const sc = SCREENS[id]; return sc ? sc.title(p) : id; }

// ---------------- sheets ----------------
function openSheet(spec) {
  const [kind, arg] = parse(spec);
  S.sheet = { kind, arg };
  if (kind === 'add') {
    const t = arg && DATA.transactions.find(x => x.id === arg);
    S.form = t ? { editId: t.id, type: t.cat === 'transfer' ? 'transfer' : t.amount < 0 ? 'expense' : 'income', amount: String(Math.abs(t.amount)), cur: t.cur, title: t.title, cat: t.cat, acct: t.acct, to: t.to || 'a2', date: '2026-10-05', method: t.method, repeat: t.recurring || 'Never', status: t.pending ? 'Pending' : 'Posted', tags: (t.tags || []).join(', '), dirty: false }
      : { type: 'expense', amount: S.ui.prefill?.amount || '', cur: 'AED', title: S.ui.prefill?.title || '', cat: S.ui.prefill?.cat || null, acct: DATA.accounts[0]?.id || '', to: 'a2', date: '2026-10-05', method: 'Card', repeat: 'Never', status: 'Posted', tags: '', dirty: !!S.ui.prefill };
    S.ui.prefill = null;
  }
  if (kind === 'ask' && !S.chat) S.chat = [{ me: false, t: 'Ask about your spending, budgets, bills or goals. Answers use your data on this iPhone.' }];
  if (kind === 'form') S.ui.ff = {};
  if (kind === 'clear') S.ui.clearText = '';
  S.ui.focusSheet = true;
  render();
}
function closeSheet(force) {
  if (!force && S.sheet && ((S.sheet.kind === 'add' && S.form?.dirty) || (S.sheet.kind === 'form' && Object.values(S.ui.ff || {}).some(Boolean)))) {
    S.dialog = { title: S.sheet.kind === 'add' ? (S.form.editId ? 'Discard changes?' : 'Discard this transaction?') : 'Discard changes?', msg: 'What you entered will be lost.',
      buttons: [{ label: 'Discard', kind: 'danger', act: 'discard' }, { label: 'Keep editing', act: 'dismiss' }] };
    return render();
  }
  S.sheet = null; S.form = null; S.ui.focusTitle = true; render();
}

const FORMS = {
  account: ['Account', [['Name', 'text', 'e.g. Emirates NBD Current', 1], ['Type', 'select', 'Bank,Savings,Cash,Credit card,Wallet,Retirement'], ['Currency', 'select', 'AED,USD,EUR,GBP,SAR'], ['Current balance', 'amount', '0.00', 1]], 'Add account', 'Account added'],
  budget: ['Budget', [['Category', 'select', 'Groceries,Dining,Transport,Shopping,Entertainment,Health', 1], ['Monthly limit', 'amount', 'AED 0.00', 1], ['Only count merchants containing', 'text', 'optional, e.g. Talabat'], ['Alert at', 'select', '80%,90%,75%,50%'], ['Roll over unused', 'switch']], 'Save budget', 'Budget saved'],
  envelope: ['Envelope', [['Name', 'text', 'e.g. Holiday', 1], ['Target', 'amount', 'AED 0.00']], 'Add envelope', 'Envelope added'],
  goal: ['Goal', [['Type', 'select', 'Emergency fund,Hajj / Umrah,Down payment,Education,Custom', 1], ['Name', 'text', 'e.g. Emergency fund', 1], ['Target', 'amount', 'AED 0.00', 1], ['Target date', 'date'], ['Monthly reminder', 'switch']], 'Save goal', 'Goal saved'],
  contribute: ['Add money', [['Amount', 'amount', 'AED 0.00', 1], ['From account', 'acct']], 'Add to goal', 'Added to goal'],
  withdraw: ['Withdraw', [['Amount', 'amount', 'AED 0.00', 1], ['To account', 'acct']], 'Withdraw', 'Withdrawn from goal'],
  bill: ['Bill', [['Name', 'text', 'e.g. DEWA', 1], ['Amount', 'amount', 'AED 0.00', 1], ['Repeats', 'select', 'Monthly,Weekly,Quarterly,Yearly'], ['Next due', 'date', '', 1], ['Subscription', 'switch'], ['Auto-pay', 'switch']], 'Save bill', 'Bill saved'],
  billPay: ['Record payment', [['Amount', 'amount', 'AED 640.30', 1], ['Paid from', 'acct'], ['Date', 'date']], 'Record payment', 'Payment recorded · next due 14 Nov'],
  loan: ['Loan', [['Lender', 'text', 'ENBD', 1], ['Outstanding', 'amount', 'AED 54,300.00', 1], ['Interest rate %', 'text', '3.49'], ['EMI', 'amount', 'AED 2,150.00'], ['Next payment', 'date']], 'Save loan', 'Loan saved'],
  loanPay: ['Record loan payment', [['Amount', 'amount', 'AED 2,150.00', 1], ['Paid from', 'acct']], 'Record payment', 'Loan payment recorded'],
  bnpl: ['BNPL plan', [['Provider', 'select', 'tabby,Tamara,Postpay,Other', 1], ['Purchase', 'text', 'e.g. Noon — headphones', 1], ['Instalment', 'amount', 'AED 0.00', 1], ['Instalments', 'select', '4,3,6,12']], 'Save plan', 'Plan saved'],
  bnplPay: ['Record instalment', [['Amount', 'amount', 'AED 349.00', 1], ['Paid from', 'acct']], 'Record instalment', 'Instalment 3 of 4 recorded'],
  lent: ['I lent money', [['Person', 'text', 'Name', 1], ['Amount', 'amount', 'AED 0.00', 1], ['From account', 'acct'], ['Due', 'date']], 'Save', 'Saved — Ahmed owes you'],
  borrowed: ['I borrowed money', [['Person', 'text', 'Name', 1], ['Amount', 'amount', 'AED 0.00', 1], ['Into account', 'acct'], ['Due', 'date']], 'Save', 'Saved'],
  repayment: ['Record repayment', [['Amount', 'amount', 'AED 0.00', 1], ['Account', 'acct']], 'Record', 'Repayment recorded'],
  investment: ['Holding', [['Type', 'select', 'Stock,ETF,Crypto,Gold,Fund,Bond', 1], ['Symbol or name', 'text', 'e.g. VWRA', 1], ['Quantity', 'text', '0'], ['Average cost', 'amount', '0.00'], ['Currency', 'select', 'USD,AED,EUR']], 'Add holding', 'Holding added'],
  asset: ['Asset', [['Type', 'select', 'Real estate,Vehicle,Personal,Digital', 1], ['Name', 'text', 'e.g. Apartment — JVC', 1], ['Value', 'amount', 'AED 0.00', 1]], 'Add asset', 'Asset added'],
  reward: ['Card or programme', [['Type', 'select', 'Loyalty programme,Gift card', 1], ['Name', 'text', 'e.g. Emirates Skywards', 1], ['Balance', 'text', 'Points or amount'], ['Expires', 'date']], 'Add', 'Added'],
  salary: ['Salary', [['Employer', 'text', 'e.g. Al Futtaim', 1], ['Amount', 'amount', 'AED 0.00', 1], ['Pay day', 'select', '25,26,27,28,1']], 'Save salary', 'Salary saved · reminder set'],
  salaryPay: ['Record salary', [['Amount received', 'amount', 'AED 24,000.00', 1], ['Into account', 'acct'], ['Date', 'date']], 'Record', 'Salary recorded · 5% added to Emergency fund'],
  project: ['Freelance project', [['Client / project', 'text', '', 1], ['Contract value', 'amount', 'AED 0.00']], 'Add project', 'Project added'],
  rentPay: ['Record rent', [['Amount', 'amount', 'AED 5,200.00', 1], ['Into account', 'acct']], 'Record', 'Rent recorded'],
  dividend: ['Dividend', [['Holding', 'text', 'e.g. Emaar', 1], ['Gross amount', 'amount', 'AED 0.00', 1], ['Withholding', 'amount', 'AED 0.00'], ['Into account', 'acct']], 'Add dividend', 'Dividend added'],
  retirement: ['Retirement assumptions', [['Retire at', 'select', '60,55,65'], ['Monthly contribution', 'amount', 'AED 3,000.00'], ['Expected return %', 'text', '6']], 'Save', 'Assumptions saved'],
  bankRule: ['Bank rule', [['Bank', 'select', 'Emirates NBD,FAB,ADCB,Mashreq,DIB,RAKBANK,Other', 1], ['Sender email or SMS ID', 'text', 'alerts@bank.ae', 1], ['Post to account', 'acct'], ['Subject contains', 'text', 'optional']], 'Save rule', 'Rule saved'],
  paste: ['Paste an email', [['Email text', 'textarea', 'Paste the full alert…', 1]], 'Import', 'Added to To review'],
  category: ['Category', [['Name', 'text', '', 1], ['Icon', 'select', '🐾,🎓,🎁,🧸,✈️'], ['Parent', 'select', 'None,Pets,School fees'], ['Use for', 'select', 'Expenses and income,Expenses,Income']], 'Save category', 'Category saved'],
  rule: ['Rule', [['When', 'select', 'Merchant contains,Merchant is,Title contains,Amount between', 1], ['Value', 'text', 'e.g. ENOC', 1], ['Set category to', 'select', 'Transport,Groceries,Dining,Utilities'], ['Add tags', 'text', 'optional']], 'Save rule', 'Rule saved'],
  currency: ['Base currency', [['Currency', 'select', 'AED — UAE dirham,USD — US dollar,SAR — Saudi riyal,EUR — Euro,GBP — Pound,INR — Indian rupee', 1]], 'Change currency', 'Base currency unchanged (sample)'],
  emailBackup: ['Email backup', [['Email', 'text', 'you@example.com', 1], ['App password', 'password', '', 1], ['Only on Wi-Fi', 'switch']], 'Connect', 'Email backup connected'],
  pin: ['Set a passcode', [['New passcode (4–6 digits)', 'password', '', 1], ['Confirm passcode', 'password', '', 1]], 'Turn on passcode', 'Passcode on'],
};
const ADD_MENUS = {
  plan: [['Budget', 'form:budget'], ['Bill or subscription', 'form:bill'], ['Goal', 'form:goal'], ['Salary', 'form:salary'], ['Loan', 'form:loan'], ['BNPL plan', 'form:bnpl'], ['Money I lent', 'form:lent'], ['Money I borrowed', 'form:borrowed']],
  budgets: [['Budget', 'form:budget'], ['Envelope', 'form:envelope']],
  income: [['Salary', 'form:salary'], ['Freelance project', 'form:project'], ['Rent payment', 'form:rentPay'], ['Dividend', 'form:dividend']],
  debt: [['Loan', 'form:loan'], ['BNPL plan', 'form:bnpl'], ['Money I lent', 'form:lent'], ['Money I borrowed', 'form:borrowed']],
  wealth: [['Bank, cash or card account', 'form:account'], ['Loan', 'form:loan'], ['BNPL plan', 'form:bnpl'], ['Investment', 'form:investment'], ['Property or other asset', 'form:asset'], ['Gift card or loyalty', 'form:reward']],
  categories: [['Category', 'form:category'], ['Rule', 'form:rule']],
};

function renderSheet() {
  const sh = S.sheet; if (!sh) return '';
  let title = '', body = '', foot = '', lead = `<button class="pill-btn glass" data-act="closeSheet">Cancel</button>`;
  if (sh.kind === 'add') ({ title, body, foot } = addSheet());
  else if (sh.kind === 'form') {
    const [t, fields, save] = FORMS[sh.arg] || ['Form', [], 'Save'];
    title = t;
    body = `<div class="form-group">${fields.map(([l, type, opt, req], i) => {
      const id = `ff-${i}`; const v = esc(S.ui.ff[id] || '');
      const lab = `<label for="${id}">${l}${req ? '' : ' <span class="muted">(optional)</span>'}</label>`;
      if (type === 'select') return `<div class="field">${lab}<select id="${id}" data-ffield="${id}">${opt.split(',').map(o => `<option>${o}</option>`).join('')}</select></div>`;
      if (type === 'acct') return `<div class="field">${lab}<select id="${id}" data-ffield="${id}">${DATA.accounts.map(a => `<option>${esc(a.name)}</option>`).join('') || '<option>None</option>'}</select></div>`;
      if (type === 'switch') return `<div class="field"><label for="${id}" style="flex:1">${l}</label><input id="${id}" type="checkbox" class="switch" role="switch"></div>`;
      if (type === 'textarea') return `<div class="field" style="flex-direction:column;align-items:stretch">${lab}<textarea id="${id}" data-ffield="${id}" placeholder="${esc(opt)}">${v}</textarea></div>`;
      return `<div class="field">${lab}<input id="${id}" data-ffield="${id}" ${req ? 'aria-required="true"' : ''} type="${type === 'date' ? 'date' : type === 'password' ? 'password' : 'text'}" ${type === 'amount' ? 'inputmode="decimal"' : ''} ${type === 'password' ? 'inputmode="numeric"' : ''} placeholder="${esc(opt || '')}" value="${v}"></div>`;
    }).join('')}</div><div id="ff-err" class="inline-err" role="alert"></div>`;
    foot = `<button class="btn primary block" data-act="formSave">${save}</button>`;
  } else if (sh.kind === 'addMenu') {
    title = 'Add'; body = group(ADD_MENUS[sh.arg].map(([l, f]) => row({ title: l, go: `sheet:${f}` })));
  } else if (sh.kind === 'filter') {
    title = 'Filters';
    body = `${section('Date', seg('filterRange', [['', 'Any time'], ['month', 'This month'], ['last', 'Last month'], ['custom', 'Custom']], S.ui.filterRange || ''))}
      ${section('Account', `<div class="form-group"><div class="field"><label for="f-acct">Account</label><select id="f-acct" data-input="filterAcct"><option value="">All accounts</option>${DATA.accounts.map(a => `<option value="${a.id}" ${S.ui.filterAcct === a.id ? 'selected' : ''}>${esc(a.name)}</option>`).join('')}</select></div></div>`)}`;
    foot = `<button class="btn primary block" data-act="applyFilters">Show ${filteredTx().length} transactions</button><button class="btn block" data-act="clearFilters">Clear filters</button>`;
    lead = `<span></span>`;
  } else if (sh.kind === 'reviewEdit') {
    const r = DATA.review.find(x => x.id === sh.arg);
    title = 'Edit import';
    body = `<div class="form-group"><div class="field"><label for="re-m">Merchant</label><input id="re-m" value="${esc(r.merchant)}"></div><div class="field"><label for="re-a">Amount</label><input id="re-a" inputmode="decimal" value="${r.amount}"></div><div class="field"><label for="re-c">Category</label><select id="re-c">${Object.entries(CATS).map(([k, c]) => `<option ${k === r.cat ? 'selected' : ''}>${c.name}</option>`).join('')}</select></div><div class="field"><label for="re-acc">Account</label><select id="re-acc">${DATA.accounts.map(a => `<option ${a.id === r.acct ? 'selected' : ''}>${esc(a.name)}</option>`).join('')}</select></div></div>
      ${r.bnplNeeded ? section('BNPL plan', `<p class="inline-note">This merchant offers instalments. Choose the plan this charge belongs to, or “Not BNPL”.</p><div class="form-group">${[['b1', 'tabby — Noon headphones (instalment 3 of 4)'], ['none', 'Not a BNPL purchase']].map(([v, l]) => `<div class="field"><label for="bn-${v}" style="flex:1">${l}</label><input type="radio" name="bnpl" id="bn-${v}" value="${v}" data-input="bnplPick" ${S.ui.bnplPick === v ? 'checked' : ''} style="width:22px;height:22px"></div>`).join('')}</div>`) : ''}
      <details class="more"><summary>I paid for someone else <span class="chev" aria-hidden="true">›</span></summary><div class="inner"><div class="form-group"><div class="field"><label for="re-p">Person</label><input id="re-p" placeholder="Name"></div><div class="field"><label for="re-pa">Their share</label><input id="re-pa" inputmode="decimal" placeholder="AED 0.00"></div></div></div></details>
      ${section('Original message', `<div class="card" style="font-size:.8em;font-family:var(--wb-mono)">Purchase of ${r.cur} ${r.amount.toFixed(2)} at ${esc(r.merchant.toUpperCase())}${r.card ? ` with card ending ${r.card}` : ''}. Avl bal AED 15,118.20</div>`)}`;
    foot = `<button class="btn primary block" data-act="reviewSave" data-arg="${r.id}">Save and approve</button><button class="btn block" data-act="closeSheet" data-arg="force">Save for later</button>`;
  } else if (sh.kind === 'ask') {
    title = 'Ask FinTrack';
    body = `<div style="display:flex;flex-direction:column;gap:8px" role="log" aria-live="polite">${S.chat.map(m => `<div class="bubble ${m.me ? 'me' : 'bot'}">${m.t}</div>`).join('')}</div>
      <div class="chips">${['How much did I spend on dining?', 'Can I afford AED 3,000 this month?', 'What’s due this week?'].map(q => `<button class="chip" data-act="askSend" data-arg="${esc(q)}">${q}</button>`).join('')}</div>`;
    foot = `<form data-form="ask" style="display:flex;gap:8px"><label class="sr-only" for="ask-q">Question</label><input id="ask-q" class="search-field" style="flex:1;border:0" placeholder="Ask about your money" autocomplete="off"><button class="btn primary" type="submit">Send</button></form><p class="inline-note">Answers come from rules over your data on this iPhone. <span class="sim-tag">Proposal</span> Foundation Models could answer free-form questions on supported devices.</p>`;
    lead = `<button class="pill-btn glass" data-act="closeSheet">Done</button>`;
  } else if (sh.kind === 'export') {
    title = 'Export report'; body = group([row({ icon: '📄', title: 'PDF', sub: 'A4, opens the share sheet', act: 'exportPick', arg: 'PDF' }), row({ icon: '📊', title: 'CSV', sub: 'For Numbers or Excel', act: 'exportPick', arg: 'CSV' })]);
  } else if (sh.kind === 'clear') {
    title = 'Clear all data';
    body = `${banner('err', '⚠︎', '<b>This deletes all accounts, transactions, budgets, goals and on-device backups.</b> Settings, your profile and email connections are kept. This can’t be undone.')}
      <div class="form-group"><div class="field"><label for="clr">Type DELETE to confirm</label><input id="clr" data-input="clearText" autocomplete="off" value="${esc(S.ui.clearText)}"></div></div><p class="inline-note">Tip: make a backup first in Backup & Restore.</p>`;
    foot = `<button class="btn danger block" data-act="clearAll" ${S.ui.clearText === 'DELETE' ? '' : 'disabled aria-disabled="true"'} style="${S.ui.clearText === 'DELETE' ? 'background:var(--expense);color:#fff' : ''}">Delete everything</button>`;
  }
  return `<div class="scrim" data-act="closeSheet" aria-hidden="true"></div><div class="sheet" role="dialog" aria-modal="true" aria-labelledby="sheet-title"><div class="grabber" aria-hidden="true"></div>
    <div class="sheet-head"><div>${lead}</div><h2 id="sheet-title" tabindex="-1">${title}</h2><div></div></div><div class="sheet-body" id="sheet-body">${body}</div>${foot ? `<div class="sheet-foot">${foot}</div>` : ''}</div>`;
}

function addSheet() {
  const f = S.form;
  const typeLabel = { expense: 'Expense', income: 'Income', transfer: 'Transfer' }[f.type];
  const catKeys = f.type === 'income' ? ['salary', 'freelance', 'transfer'] : ['groceries', 'dining', 'transport', 'utilities', 'shopping', 'entertainment', 'health', 'housing', 'subscriptions', 'loan'];
  const acctOpts = sel => DATA.accounts.map(a => `<option value="${a.id}" ${a.id === sel ? 'selected' : ''}>${esc(a.name)} · ${money(a.balance, a.cur, true)}</option>`).join('') || '<option value="">No accounts yet</option>';
  const body = `${seg('form.type', [['expense', 'Expense'], ['income', 'Income'], ['transfer', 'Transfer']], f.type)}
    <div class="amount-wrap"><label for="amt" class="sr-only">Amount in ${f.cur}</label><input id="amt" class="amount-input" inputmode="decimal" placeholder="0.00" value="${esc(f.amount)}" data-field="amount" autocomplete="off">
      <button class="cur-btn" data-act="addCur" aria-label="Currency: ${f.cur}. Change currency">${f.cur} ▾</button><div id="fx-note" class="inline-note"></div></div>
    <div class="btn-row" style="justify-content:center"><button class="btn" data-act="scanReceipt">📷 Scan receipt</button><button class="btn" data-act="dictate">🎙 Dictate</button></div>
    ${S.ui.scanning ? `<div class="card" role="status" aria-live="polite"><div class="skeleton" style="height:14px;width:60%"></div><div class="row-sub">Reading receipt…</div></div>` : ''}
    <div class="form-group"><div class="field"><label for="ttl">${f.type === 'income' ? 'From' : f.type === 'transfer' ? 'Note' : 'Merchant'}</label><input id="ttl" data-field="title" placeholder="${f.type === 'expense' ? 'e.g. Carrefour' : ''}" value="${esc(f.title)}" autocomplete="off"></div>
      ${f.type === 'transfer' ? `<div class="field"><label for="from">From</label><select id="from" data-field="acct">${acctOpts(f.acct)}</select></div><div class="field"><label for="to">To</label><select id="to" data-field="to">${acctOpts(f.to)}</select></div>`
        : `<div class="field"><label for="acc">Account</label><select id="acc" data-field="acct">${acctOpts(f.acct)}</select></div>`}
      <div class="field"><label for="dt">Date</label><input id="dt" type="date" data-field="date" value="${f.date}"></div></div>
    ${f.type !== 'transfer' ? section('Category', `<div id="suggest"></div><div class="chips" role="radiogroup" aria-label="Category" style="flex-wrap:wrap">${catKeys.map(k => `<button class="chip" role="radio" aria-checked="${f.cat === k}" aria-pressed="${f.cat === k}" data-act="pickCat" data-arg="${k}">${CATS[k].icon} ${CATS[k].name}</button>`).join('')}<button class="chip" data-act="toast" data-arg="Categories & Rules opens inside this sheet (simulated)">Manage…</button></div>`) : ''}
    <details class="more"><summary>More details <span class="muted" style="font-weight:400;font-size:.85em">notes, tags, payment method, repeat, split, receipt, tax</span><span class="chev" aria-hidden="true">›</span></summary><div class="inner">
      <div class="form-group"><div class="field"><label for="nts">Notes</label><input id="nts" data-field="notes" value="${esc(f.notes || '')}"></div><div class="field"><label for="tgs">Tags</label><input id="tgs" data-field="tags" placeholder="e.g. family, work" value="${esc(f.tags)}"></div>
        <div class="field"><label for="pm">Payment method</label><select id="pm" data-field="method">${['Card', 'Apple Pay', 'Cash', 'Transfer', 'Cheque', 'BNPL'].map(m => `<option ${m === f.method ? 'selected' : ''}>${m}</option>`).join('')}</select></div>
        ${f.method === 'Cheque' ? `<div class="field"><label for="chq">Cheque number</label><input id="chq" inputmode="numeric"></div><div class="field"><label for="chqd">Cheque date</label><input id="chqd" type="date"></div>` : ''}
        ${f.method === 'BNPL' ? `<div class="field"><label for="bnp">BNPL plan</label><select id="bnp"><option>tabby — Noon headphones</option><option>New plan…</option></select></div>` : ''}
        <div class="field"><label for="rep">Repeat</label><select id="rep" data-field="repeat">${['Never', 'Daily', 'Weekly', 'Monthly', 'Yearly'].map(m => `<option ${m === f.repeat ? 'selected' : ''}>${m}</option>`).join('')}</select></div>
        <div class="field"><label for="st">Status</label><select id="st" data-field="status">${['Posted', 'Pending', 'Scheduled'].map(m => `<option ${m === f.status ? 'selected' : ''}>${m}</option>`).join('')}</select></div>
        <div class="field"><label for="bl">Pays a bill</label><select id="bl"><option>None</option>${DATA.bills.map(b => `<option>${esc(b.name)}</option>`).join('')}</select></div></div>
      <div class="form-group" style="margin-top:12px"><div class="field"><label for="spl" style="flex:1">Split into several categories</label><input id="spl" type="checkbox" class="switch" role="switch"></div><div class="field"><label for="ded" style="flex:1">Tax deductible</label><input id="ded" type="checkbox" class="switch" role="switch"></div><div class="field"><label for="vat" style="flex:1">VAT reclaimable</label><input id="vat" type="checkbox" class="switch" role="switch"></div>
        <div class="field"><label for="loy">Loyalty points</label><select id="loy"><option>None</option><option>Earn — SHARE</option><option>Redeem — Skywards</option></select></div></div>
      <div class="btn-row" style="margin-top:12px;padding-inline:12px"><button class="btn" data-act="addLocation">📍 Add location</button><button class="btn" data-act="toast" data-arg="Document picker would open — simulated">📎 Attach file</button></div>
    </div></details>`;
  const foot = `<div id="add-derived"></div>`;
  return { title: f.editId ? 'Edit transaction' : `New ${typeLabel.toLowerCase()}`, body, foot };
}
function addValidation() {
  const f = S.form;
  const amt = parseFloat(String(f.amount).replace(/,/g, ''));
  const a = acct(f.acct);
  if (!amt || amt <= 0) return 'Enter an amount.';
  if (f.type !== 'transfer' && !f.cat) return 'Choose a category.';
  if (!DATA.accounts.length) return 'Add an account first.';
  if (f.type === 'transfer' && f.acct === f.to) return 'Choose two different accounts.';
  if (f.type === 'expense' && a && a.kind !== 'Credit card' && f.status === 'Posted' && toBase(amt, f.cur) > toBase(a.balance, a.cur)) return `${a.name} has ${money(a.balance, a.cur)}. Choose another account or lower the amount.`;
  return '';
}
function updateAddDerived() {
  const el = document.getElementById('add-derived'); if (!el || !S.form) return;
  const f = S.form; const err = addValidation();
  const label = f.editId ? 'Save changes' : `Save ${f.type}`;
  el.innerHTML = `${err ? `<div class="inline-err" id="save-why">${esc(err)}</div>` : ''}<button class="btn primary block" data-act="saveTx" ${err ? 'aria-disabled="true" aria-describedby="save-why" style="opacity:.5"' : ''}>${label}</button>`;
  const fx = document.getElementById('fx-note');
  if (fx) fx.textContent = f.cur !== 'AED' && parseFloat(f.amount) ? `≈ ${money(toBase(parseFloat(f.amount), f.cur))} at today’s rate (locked when you save)` : '';
  const sg = document.getElementById('suggest');
  if (sg) {
    const m = (f.title || '').toLowerCase();
    const guess = /carrefour|lulu|spinneys|choithrams/.test(m) ? 'groceries' : /enoc|adnoc|careem|salik|uber/.test(m) ? 'transport' : /talabat|starbucks|deliveroo/.test(m) ? 'dining' : /dewa|du |etisalat|e&/.test(m + ' ') ? 'utilities' : null;
    sg.innerHTML = guess && f.cat !== guess ? `<div class="banner" style="padding:8px 12px"><span aria-hidden="true">✨</span><div class="bt">Looks like <b>${CATS[guess].name}</b> (from your past purchases)</div><button class="btn" data-act="pickCat" data-arg="${guess}">Use</button></div>` : '';
  }
}

// ---------------- dialogs & toasts ----------------
function renderDialog() {
  const d = S.dialog; if (!d) return '';
  return `<div class="dialog-wrap" data-act="dismiss"><div class="dialog glass" role="alertdialog" aria-modal="true" aria-labelledby="dlg-t" aria-describedby="dlg-m" data-stop="1"><h2 id="dlg-t" tabindex="-1">${d.title}</h2>${d.msg ? `<p id="dlg-m">${d.msg}</p>` : ''}
    ${d.buttons.map(b => `<button class="btn ${b.kind === 'danger' ? 'danger' : b.kind === 'primary' ? 'primary' : ''}" data-act="${b.act}" ${b.arg !== undefined ? `data-arg="${esc(b.arg)}"` : ''}>${b.label}</button>`).join('')}</div></div>`;
}
function toast(msg, undo) {
  S.toast = { msg, undo }; clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { S.toast = null; render(); }, undo ? 6000 : 3200);
  render();
}
function siri(q, answer, after) {
  S.siri = { q, a: answer }; clearTimeout(siriTimer);
  siriTimer = setTimeout(() => { S.siri = null; render(); }, 7000);
  if (after) after();
  render();
}

// ---------------- data mutations ----------------
function postTx(t) {
  DATA.transactions.unshift(t);
  const a = acct(t.acct); if (a && !t.pending) a.balance += t.amount * (FX[t.cur] / FX[a.cur]);
  if (t.to) { const b = acct(t.to); if (b) b.balance += -t.amount * (FX[t.cur] / FX[b.cur]); }
}
function unpostTx(id) {
  const i = DATA.transactions.findIndex(x => x.id === id); if (i < 0) return null;
  const [t] = DATA.transactions.splice(i, 1);
  const a = acct(t.acct); if (a && !t.pending) a.balance -= t.amount * (FX[t.cur] / FX[a.cur]);
  if (t.to) { const b = acct(t.to); if (b) b.balance -= -t.amount * (FX[t.cur] / FX[b.cur]); }
  return { t, i };
}
function approveItem(r) {
  r.done = 'approved';
  const t = { id: 'rt' + r.id + Date.now(), title: r.merchant, cat: r.cat, amount: -r.amount, cur: r.cur, date: r.when, acct: r.acct, method: r.channel === 'Apple Pay' ? 'Apple Pay' : 'Card', via: r.channel };
  postTx(t);
  return t;
}

// ---------------- actions ----------------
const DIALOGS = {
  rejectAll: () => ({ title: `Reject ${pendingReview().length} items?`, msg: 'They’ll move to Reviewed. Nothing is added to your accounts.', buttons: [{ label: 'Reject all', kind: 'danger', act: 'doRejectAll' }, { label: 'Cancel', act: 'dismiss' }] }),
  applyRec: () => ({ title: 'Apply suggestion?', msg: 'Your budget limit will change from next refresh.', buttons: [{ label: 'Apply', kind: 'primary', act: 'doToast', arg: 'Budget updated' }, { label: 'Cancel', act: 'dismiss' }] }),
  template: n => ({ title: `Apply the ${n} template?`, msg: 'Adds monthly budgets for its categories. Categories you already budget are skipped.', buttons: [{ label: 'Apply template', kind: 'primary', act: 'doToast', arg: `${n} budgets added (3 new, 2 skipped)` }, { label: 'Cancel', act: 'dismiss' }] }),
  deleteBudget: id => ({ title: 'Delete this budget?', msg: 'Your transactions stay. Only the limit is removed.', buttons: [{ label: 'Delete budget', kind: 'danger', act: 'doDelete', arg: `budgets|${id}` }, { label: 'Cancel', act: 'dismiss' }] }),
  deleteBill: id => ({ title: 'Delete this bill?', msg: 'Its reminders are cancelled. Past payments stay in Activity.', buttons: [{ label: 'Delete bill', kind: 'danger', act: 'doDelete', arg: `bills|${id}` }, { label: 'Cancel', act: 'dismiss' }] }),
  deleteGoal: id => ({ title: 'Delete this goal?', msg: 'Money already moved to a goal account stays in that account.', buttons: [{ label: 'Delete goal', kind: 'danger', act: 'doDelete', arg: `goals|${id}` }, { label: 'Cancel', act: 'dismiss' }] }),
  restore: () => ({ title: 'Restore backup', msg: 'Merge adds records you don’t have. Replace deletes current data first.', buttons: [{ label: 'Merge', kind: 'primary', act: 'doToast', arg: 'Restored: 0 new records (sample)' }, { label: 'Replace everything', kind: 'danger', act: 'doToast', arg: 'Replaced with backup from today, 18:42 (sample)' }, { label: 'Cancel', act: 'dismiss' }] }),
};
const ACTIONS = {
  noop() {},
  seg(arg) {
    const [name, v] = arg.split('|');
    if (name.startsWith('form.')) { S.form[name.slice(5)] = v; S.form.dirty = true; if (name === 'form.type') S.form.cat = null; }
    else S.ui[name] = v;
    if (name === 'theme') { P.appearance = v === 'dark' || v === 'oled' ? 'dark' : v === 'light' ? 'light' : (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'); syncControls(); }
    render();
  },
  switchTab: a => switchTab(a),
  closeSheet: a => closeSheet(a === 'force'),
  discard() { S.dialog = null; closeSheet(true); },
  dismiss() { S.dialog = null; render(); },
  toast: a => toast(a),
  doToast(a) { S.dialog = null; toast(a); },
  confirm(arg) { const [k, p] = arg.split('|'); S.dialog = DIALOGS[k](p); render(); },
  doDelete(arg) { const [coll, id] = arg.split('|'); const i = DATA[coll].findIndex(x => x.id === id); const [item] = DATA[coll].splice(i, 1); S.dialog = null; back(); toast('Deleted', () => DATA[coll].splice(i, 0, item)); },
  togglePressed(_, el) { el.setAttribute('aria-pressed', el.getAttribute('aria-pressed') === 'true' ? 'false' : 'true'); },
  txMenu(id) { const t = DATA.transactions.find(x => x.id === id); S.dialog = { title: esc(t.title), msg: `${signed(t)} · ${dayLabel(t.date)}`, buttons: [{ label: 'Edit', kind: 'primary', act: 'editTx', arg: id }, { label: 'Delete', kind: 'danger', act: 'deleteTx', arg: id }, { label: 'Cancel', act: 'dismiss' }] }; render(); },
  editTx(id) { S.dialog = null; openSheet(`add:${id}`); },
  deleteTx(id) {
    S.dialog = null; const r = unpostTx(id); if (!r) return;
    if (parse(curRoute())[0] === 'txn') S.stacks[S.tab].pop();
    toast(`Deleted ${esc(r.t.title)} · balance updated`, () => { DATA.transactions.splice(r.i, 0, r.t); const a = acct(r.t.acct); if (a && !r.t.pending) a.balance += r.t.amount * (FX[r.t.cur] / FX[a.cur]); });
  },
  selectMode() { S.ui.selecting = !S.ui.selecting; S.ui.sel = {}; render(); },
  toggleSel(id) { S.ui.sel = S.ui.sel || {}; S.ui.sel[id] = !S.ui.sel[id]; render(); },
  bulk(kind) {
    const ids = Object.keys(S.ui.sel || {}).filter(k => S.ui.sel[k]);
    if (kind === 'delete') { S.dialog = { title: `Delete ${ids.length} transactions?`, msg: 'Account balances are adjusted. You can undo right after.', buttons: [{ label: `Delete ${ids.length}`, kind: 'danger', act: 'doBulkDelete' }, { label: 'Cancel', act: 'dismiss' }] }; return render(); }
    S.ui.selecting = false; toast(kind === 'category' ? `Category changed for ${ids.length} transactions (sample)` : `Tag added to ${ids.length} transactions (sample)`);
  },
  doBulkDelete() { const ids = Object.keys(S.ui.sel || {}).filter(k => S.ui.sel[k]); const removed = ids.map(unpostTx).filter(Boolean); S.dialog = null; S.ui.selecting = false; toast(`Deleted ${removed.length} transactions`, () => removed.reverse().forEach(r => postTx(r.t))); },
  clearFilters() { S.ui.q = ''; S.ui.txScope = 'all'; S.ui.filterAcct = ''; S.ui.filterRange = ''; if (S.sheet?.kind === 'filter') S.sheet = null; render(); },
  applyFilters() { S.sheet = null; render(); },
  approve(id) {
    const r = DATA.review.find(x => x.id === id);
    if (r.bnplNeeded) { S.ui.bnplPick = ''; openSheet(`reviewEdit:${id}`); return; }
    if (r.duplicateOf) { S.dialog = { title: 'This may already be in Activity', msg: `Talabat, AED 86.50 on 4 Oct looks like this item.`, buttons: [{ label: 'Approve anyway', kind: 'primary', act: 'approveAnyway', arg: id }, { label: 'Reject as duplicate', kind: 'danger', act: 'reject', arg: id }, { label: 'Cancel', act: 'dismiss' }] }; return render(); }
    const t = approveItem(r); toast(`Added ${esc(r.merchant)} to ${esc(acct(r.acct)?.name || 'Activity')}`, () => { r.done = null; unpostTx(t.id); });
  },
  approveAnyway(id) { S.dialog = null; const r = DATA.review.find(x => x.id === id); r.duplicateOf = null; ACTIONS.approve(id); },
  approveReady() { const ready = pendingReview().filter(r => r.confidence >= 0.9 && !r.bnplNeeded && !r.duplicateOf); const ts = ready.map(approveItem); toast(`Approved ${ready.length} items`, () => { ready.forEach(r => (r.done = null)); ts.forEach(t => unpostTx(t.id)); }); },
  reject(id) { S.dialog = null; const r = DATA.review.find(x => x.id === id); r.done = 'rejected'; toast(`Rejected ${esc(r.merchant)}`, () => (r.done = null)); },
  doRejectAll() { const items = pendingReview(); items.forEach(r => (r.done = 'rejected')); S.dialog = null; toast(`Rejected ${items.length} items`, () => items.forEach(r => (r.done = null))); },
  reviewSave(id) {
    const r = DATA.review.find(x => x.id === id);
    if (r.bnplNeeded && !S.ui.bnplPick) { const el = document.getElementById('sheet-body'); toast('Choose a BNPL plan or “Not a BNPL purchase” first'); return; }
    r.bnplNeeded = false; S.sheet = null; const t = approveItem(r); toast(`Added ${esc(r.merchant)}${S.ui.bnplPick === 'b1' ? ' · tabby plan now 3 of 4' : ''}`, () => { r.done = null; r.bnplNeeded = true; unpostTx(t.id); });
  },
  syncNow() { if (P.network === 'offline') return toast('You’re offline. FinTrack will check again when you reconnect.'); if (P.syncError) return toast('Couldn’t check Gmail — reconnect in Bank emails'); toast('Checked 1 mailbox · nothing new'); },
  sampleEmails() { DATA.review.push({ id: 'rs' + Date.now(), merchant: 'Spinneys', amount: 187.35, cur: 'AED', type: 'Expense', cat: 'groceries', when: TODAY, channel: 'Email', source: 'Sample email', confidence: 0.94, acct: 'a1', card: '4821' }); toast('Added sample emails to To review'); },
  csvPick() { S.ui.csvStep = 1; render(); },
  csvImport() { S.ui.csvStep = 0; back(); toast('Imported 39 transactions · 3 duplicates skipped (sample)'); },
  homeMove(arg) { const [k, dir] = arg.split('|'); const o = S.ui.homeOrder || ['review', 'shortcuts', 'upcoming', 'budgets', 'spending', 'recent', 'insights']; const i = o.indexOf(k); const j = i + Number(dir); if (j < 0 || j >= o.length) return; [o[i], o[j]] = [o[j], o[i]]; S.ui.homeOrder = o; S.ui.refocus = `[data-act="homeMove"][data-arg="${k}|${dir}"]`; render(); },
  homeToggle(k) { S.ui.homeHidden = S.ui.homeHidden || {}; S.ui.homeHidden[k] = !S.ui.homeHidden[k]; },
  extra(d) { S.ui.extra = Math.max(0, Math.min(5000, ui('extra', 500) + Number(d))); render(); },
  refreshPrices() { toast(P.network === 'offline' ? 'You’re offline. Prices will refresh when you reconnect.' : 'Prices updated'); },
  backupNow() { S.ui.backingUp = true; render(); setTimeout(() => { S.ui.backingUp = false; toast('Backed up · 1.4 MB'); }, P.motion === 'reduced' ? 200 : 1200); },
  pinToggle(_, el) { if (el.checked) { S.ui.pin = true; openSheet('form:pin'); } else { S.ui.pin = false; toast('Passcode turned off'); } },
  hcToggle(_, el) { P.contrast = el.checked ? 'high' : 'normal'; syncControls(); render(); },
  searchFor(q) { S.ui.sq = q; render(); },
  pickCat(k) { S.form.cat = k; S.form.dirty = true; render(); },
  addCur() { const list = ['AED', 'USD', 'EUR', 'GBP']; S.form.cur = list[(list.indexOf(S.form.cur) + 1) % list.length]; S.form.dirty = true; render(); },
  scanReceipt() {
    if (P.camPerm === 'denied') { S.dialog = { title: 'Camera access is off', msg: 'Allow camera access for FinTrack in iOS Settings to scan receipts. You can also choose a photo.', buttons: [{ label: 'Open Settings', kind: 'primary', act: 'doToast', arg: 'Would open iOS Settings — simulated' }, { label: 'Choose photo', act: 'doScan' }, { label: 'Cancel', act: 'dismiss' }] }; return render(); }
    ACTIONS.doScan();
  },
  doScan() { S.dialog = null; S.ui.scanning = true; render(); setTimeout(() => { S.ui.scanning = false; if (!S.form) return render(); Object.assign(S.form, { amount: '187.35', title: 'Spinneys', cat: 'groceries', dirty: true }); toast('Receipt read · check the details'); }, P.motion === 'reduced' ? 100 : 900); },
  dictate() { Object.assign(S.form, { amount: '45', title: 'Starbucks', cat: 'dining', type: 'expense', dirty: true }); toast('Heard: “Spent 45 dirhams at Starbucks” (simulated)'); },
  addLocation() { toast(P.camPerm === 'denied' ? 'Location access is off — enable it in iOS Settings' : 'Location added: Dubai Mall (simulated)'); },
  saveTx() {
    const err = addValidation(); if (err) { const el = document.getElementById('save-why'); el && el.focus(); return; }
    const f = S.form; const amt = parseFloat(String(f.amount).replace(/,/g, ''));
    const dup = !f.editId && !S.ui.dupOk && DATA.transactions.find(t => t.title.toLowerCase() === f.title.toLowerCase() && Math.abs(Math.abs(t.amount) - amt) < 0.01 && (TODAY - t.date) < 864e5 * 1.5);
    if (dup) { S.dialog = { title: 'Possible duplicate', msg: `You added ${esc(dup.title)} for ${money(Math.abs(dup.amount), dup.cur)} ${dayLabel(dup.date).toLowerCase()}.`, buttons: [{ label: 'Save anyway', kind: 'primary', act: 'saveDup' }, { label: 'Cancel', act: 'dismiss' }] }; return render(); }
    S.ui.dupOk = false;
    if (f.editId) unpostTx(f.editId);
    const t = { id: f.editId || 'n' + Date.now(), title: f.title || (f.type === 'transfer' ? 'Transfer' : CATS[f.cat].name), cat: f.type === 'transfer' ? 'transfer' : f.cat, amount: f.type === 'income' ? amt : -amt, cur: f.cur, date: new Date(2026, 9, 5, 19), acct: f.acct, to: f.type === 'transfer' ? f.to : undefined, method: f.method, pending: f.status !== 'Posted', recurring: f.repeat !== 'Never' ? f.repeat : undefined, tags: f.tags ? f.tags.split(',').map(s => s.trim()).filter(Boolean) : [] };
    postTx(t); S.sheet = null; S.form = null;
    toast(f.editId ? 'Changes saved' : `${{ expense: 'Expense', income: 'Income', transfer: 'Transfer' }[f.type]} saved`, f.editId ? null : () => unpostTx(t.id));
  },
  saveDup() { S.dialog = null; S.ui.dupOk = true; ACTIONS.saveTx(); },
  formSave() {
    if (!S.sheet) return;
    const kind = S.sheet.arg; const [, fields, , done] = FORMS[kind];
    const missing = fields.map(([l, type, , req], i) => req && !['select', 'acct', 'switch'].includes(type) && !(S.ui.ff[`ff-${i}`] || '').trim() ? l : null).filter(Boolean);
    if (missing.length) { const el = document.getElementById('ff-err'); el.textContent = `Fill in: ${missing.join(', ')}.`; const first = fields.findIndex(([l]) => l === missing[0]); document.getElementById(`ff-${first}`)?.focus(); return; }
    if (kind === 'pin' && S.ui.ff['ff-0'] !== S.ui.ff['ff-1']) { document.getElementById('ff-err').textContent = 'The passcodes don’t match. Enter them again.'; return; }
    if (kind === 'pin' && !/^\d{4,6}$/.test(S.ui.ff['ff-0'])) { document.getElementById('ff-err').textContent = 'Use 4 to 6 digits.'; return; }
    S.sheet = null; S.ui.ff = {}; toast(done);
  },
  exportPick(k) { S.sheet = null; toast(`${k} ready — the share sheet would open (simulated)`); },
  clearAll() { if (S.ui.clearText !== 'DELETE') return; S.sheet = null; DATA = clone(EMPTY); P.dataset = 'empty'; syncControls(); S.stacks = { home: ['home'], activity: ['activity'], plan: ['plan'], wealth: ['wealth'], search: ['search'] }; S.tab = 'home'; toast('All data cleared'); },
  askSend(q) {
    S.chat.push({ me: true, t: esc(q) });
    const l = q.toLowerCase();
    const a = /dining/.test(l) ? `You’ve spent <b>${money(1056)}</b> on dining in October — 88% of your AED 1,200 budget.` : /afford/.test(l) ? `After bills due this month (${money(1278)}), you’d have about <b>${money(9800)}</b> left on 31 Oct. AED 3,000 is affordable but would put Shopping further over budget.` : /due|week/.test(l) ? `This week: du Mobile ${money(299)} (8 Oct) and tabby instalment ${money(349)} (9 Oct).` : 'I can answer questions about spending, budgets, bills, balances and goals. Try “What’s due this week?”';
    S.chat.push({ me: false, t: a }); render();
  },
  // Siri / system simulations (workbench + Siri page)
  siriLog() { siri('“Log 45 dirhams at Starbucks in FinTrack”', `Logged <b>${money(45)}</b> at Starbucks — Dining, from Cash wallet.`, () => postTx({ id: 's' + Date.now(), title: 'Starbucks', cat: 'dining', amount: -45, cur: 'AED', date: new Date(2026, 9, 5, 20), acct: 'a4', method: 'Cash', via: 'Siri' })); },
  siriBalance() { siri('“What’s my FinTrack balance?”', `Your net worth is <b>${money(netWorth().net)}</b>. <span class="muted">(Asks for Face ID first — the intent requires authentication.)</span>`); },
  siriBudget() { const b = DATA.budgets.find(x => x.cat === 'dining'); siri('“Show my budget status in FinTrack”', b ? `Dining: ${money(b.spent, 'AED', true)} of ${money(b.limit, 'AED', true)} (${pct(b.spent, b.limit)}%). Shopping is over by ${money(120, 'AED', true)}.` : 'You have no budgets yet.'); },
  siriOpen() { siri('“Open my FinTrack transactions”', 'Opening Activity…', () => { S.tab = 'activity'; S.stacks.activity = ['activity']; }); },
  siriThis() {
    const [id, p] = parse(curRoute());
    if (id !== 'txn') return siri('“Split this with Layla”', 'Open a transaction first — Siri uses what’s on screen. <span class="sim-tag">Proposed · iOS 27</span>');
    const t = DATA.transactions.find(x => x.id === p);
    siri('“Split this with Layla”', `Split <b>${esc(t.title)}</b> (${money(Math.abs(t.amount), t.cur)}) — Layla owes you ${money(Math.abs(t.amount) / 2, t.cur)}. <span class="sim-tag">Proposed · iOS 27</span>`);
  },
  simSMS() { DATA.review.unshift({ id: 'sms' + Date.now(), merchant: 'ADNOC 512', amount: 120, cur: 'AED', type: 'Expense', cat: 'transport', when: TODAY, channel: 'SMS', source: 'ENBD SMS', confidence: 0.93, acct: 'a1', card: '4821' }); siri('Bank SMS automation ran', 'FinTrack received a text from ENBD: <b>ADNOC 512, AED 120.00</b>. Added to To review. <span class="muted">(Shown as a notification on device.)</span>'); },
  simApplePay() { DATA.review.unshift({ id: 'ap' + Date.now(), merchant: 'Apple Store', amount: 99, cur: 'AED', type: 'Expense', cat: 'shopping', when: TODAY, channel: 'Apple Pay', source: 'Wallet automation', confidence: 0.95, acct: 'a5' }); siri('Apple Pay automation ran', 'Apple Store, AED 99.00 — added to To review.'); },
  // Scenes
  obNext() { S.ui.obStep = 1; render(); },
  obFinish() { const n = document.getElementById('ob-name')?.value?.trim(); if (n) DATA.profile.name = n; S.scene = null; toast(`Welcome, ${esc(DATA.profile.name)}`); },
  lockFace() { S.scene = null; S.ui.focusTitle = true; render(); },
  pinKey(dg) {
    if (S.ui.lockedOut) return;
    S.ui.pinEntry = (S.ui.pinEntry || '') + dg;
    if (S.ui.pinEntry.length === 4) {
      if (S.ui.pinEntry === '1234') { S.scene = null; S.ui.pinEntry = ''; S.ui.pinTries = 0; S.ui.focusTitle = true; }
      else { S.ui.pinEntry = ''; S.ui.pinTries = (S.ui.pinTries || 0) + 1; if (S.ui.pinTries >= 5) { S.ui.lockedOut = true; setTimeout(() => { S.ui.lockedOut = false; S.ui.pinTries = 0; render(); }, 30000); } }
    }
    render();
  },
  pinDel() { S.ui.pinEntry = (S.ui.pinEntry || '').slice(0, -1); render(); },
  restoreYes() { S.scene = null; toast('Restored 1,284 records from this iPhone'); },
  restoreNo() { S.scene = 'onboarding'; S.ui.obStep = 0; render(); },
  sidebarGo(arg) { const [tab, route] = arg.split('|'); S.tab = tab; S.stacks[tab] = route === ROOTS[tab] ? [route] : [ROOTS[tab], route]; S.ui.focusTitle = true; S.ui.selecting = false; render(); },
  closeSiri() { S.siri = null; render(); },
  undo() { const u = S.toast?.undo; S.toast = null; clearTimeout(toastTimer); if (u) u(); toast('Undone'); },
};
const INPUTS = {
  txSearch(v) { S.ui.q = v; const el = document.getElementById('tx-results'); if (el) { el.innerHTML = activityList(); postProcess(el); } },
  search(v) { S.ui.sq = v; const el = document.getElementById('s-results'); if (el) { el.innerHTML = searchResults(); postProcess(el); } },
  extra(v) { S.ui.extra = Number(v); S.ui.refocus = '#extra'; render(); },
  pname(v) { DATA.profile.name = v || 'You'; },
  filterAcct(v) { S.ui.filterAcct = v; S.ui.refocus = '#f-acct'; render(); },
  clearText(v) { S.ui.clearText = v; S.ui.refocus = '#clr'; render(); },
  bnplPick(v) { S.ui.bnplPick = v; },
};

// ---------------- scenes ----------------
function renderScene() {
  if (S.scene === 'onboarding') {
    if (!S.ui.obStep) return `<div class="scene hero-bg" role="main"><div style="font-size:3em" aria-hidden="true">◈</div><h1 class="large-title" tabindex="-1" style="color:#fff">FinTrack</h1>
      <p style="font-size:1.05em;line-height:1.5">Your accounts, budgets and bills in one place — kept on this iPhone.</p>
      <ul style="line-height:1.9;padding-inline-start:1.2em"><li>Bank emails, SMS and Apple Pay arrive for you to approve</li><li>Budgets, bills and goals with reminders</li><li>Net worth across accounts, investments and property</li></ul>
      <div style="flex:1"></div><button class="btn block" style="background:#fff;color:#0A6E7E" data-act="obNext">Continue</button></div>`;
    return `<div class="scene" role="main"><h1 class="large-title" tabindex="-1">Set up</h1><div class="form-group"><div class="field"><label for="ob-name">Your name</label><input id="ob-name" placeholder="Name" value=""></div>
      <div class="field"><label for="ob-cur">Main currency</label><select id="ob-cur"><option>AED — UAE dirham</option><option>SAR — Saudi riyal</option><option>USD — US dollar</option><option>EUR</option><option>GBP</option><option>INR</option></select></div>
      <div class="field"><label for="ob-face" style="flex:1">Lock with Face ID</label><input id="ob-face" type="checkbox" class="switch" role="switch" checked></div></div>
      <p class="inline-note">You can change these later in Settings.</p><div style="flex:1"></div><button class="btn primary block" data-act="obFinish">Get started</button><button class="btn block" data-act="obFinish">Skip for now</button></div>`;
  }
  if (S.scene === 'lock') {
    const tries = S.ui.pinTries || 0;
    return `<div class="scene hero-bg" role="main" style="align-items:center;text-align:center"><h1 class="large-title" tabindex="-1" style="color:#fff;font-size:1.6em">FinTrack is locked</h1>
      <button class="btn" style="background:rgba(255,255,255,.2);color:#fff" data-act="lockFace">Unlock with Face ID</button><p style="margin:4px 0">or enter your passcode <span class="sim-tag" style="color:#fff;background:rgba(0,0,0,.25)">sample: 1234</span></p>
      <div class="pin-dots" role="img" aria-label="${(S.ui.pinEntry || '').length} of 4 digits entered">${[0, 1, 2, 3].map(i => `<i class="${i < (S.ui.pinEntry || '').length ? 'on' : ''}"></i>`).join('')}</div>
      <p role="alert" style="min-height:1.4em;margin:0">${S.ui.lockedOut ? 'Too many attempts. Try again in 30 seconds.' : tries ? `Wrong passcode. ${5 - tries} attempts left.` : ''}</p>
      <div class="keypad">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map(n => `<button data-act="pinKey" data-arg="${n}" ${S.ui.lockedOut ? 'disabled' : ''}>${n}</button>`).join('')}<span></span><button data-act="pinKey" data-arg="0" ${S.ui.lockedOut ? 'disabled' : ''}>0</button><button data-act="pinDel" aria-label="Delete digit">⌫</button></div></div>`;
  }
  if (S.scene === 'restore') return `<div class="scene" role="main"><h1 class="large-title" tabindex="-1">Welcome back</h1><p>FinTrack found a backup saved on this iPhone from <b>3 Oct 2026</b> (1,284 records). Receipts and attachments aren’t included.</p><div style="flex:1"></div><button class="btn primary block" data-act="restoreYes">Restore my data</button><button class="btn block" data-act="restoreNo">Start fresh</button></div>`;
  return '';
}

// ---------------- shell rendering ----------------
function renderSidebar() {
  const items = (tab, list) => list.map(([label, route, icon, badge]) => {
    const st = S.stacks[tab];
    const cur = S.tab === tab && (route === ROOTS[tab] ? st.length === 1 : st[1] === route || (st[1] && parse(st[1])[0] === parse(route)[0]));
    return `<button class="sb-item" data-act="sidebarGo" data-arg="${tab}|${route}" ${cur ? 'aria-current="page"' : ''}><span aria-hidden="true">${icon}</span><span>${label}</span>${badge ? `<span class="badge" aria-label="${badge} to review">${badge}</span>` : ''}</button>`;
  }).join('');
  const n = pendingReview().length;
  return `<nav class="sidebar glass" aria-label="FinTrack sections"><div style="padding:0 12px 10px;font-weight:700;font-size:1.25em">FinTrack</div><button class="pill-btn prominent" style="width:100%;justify-content:center;margin-bottom:6px" data-go="sheet:add">＋ Add transaction</button>
    ${items('home', [['Home', 'home', '🏠']])}${items('activity', [['Activity', 'activity', '🧾', n]])}${items('plan', [['Plan', 'plan', '🎯']])}${items('wealth', [['Wealth', 'wealth', '🏦']])}${items('search', [['Search', 'search', '🔍']])}
    <div class="sb-h">Plan</div>${items('plan', [['Budgets', 'budgets', '🎯'], ['Bills & Subscriptions', 'bills', '🧾'], ['Goals', 'goals', '⭐️'], ['Income', 'income', '💼'], ['Debt', 'debt', '🏦'], ['Household', 'family', '👨‍👩‍👦'], ['Planning tools', 'tools', '🧭']])}
    <div class="sb-h">Wealth</div>${items('wealth', [['Net worth', 'networth', '📈'], ['Investments', 'investments', '💹'], ['Property & assets', 'assets', '🏠'], ['Cards & rewards', 'rewards', '🎁']])}
    <div class="sb-h">More</div>${items('home', [['Insights', 'insights', '✨'], ['Reports', 'reports', '📊']])}${items('activity', [['Import & Sync', 'import', '⇅']])}${items('home', [['Settings', 'settings', '⚙︎']])}</nav>`;
}
function renderMain() {
  const route = curRoute(); const [id, p] = parse(route); const sc = SCREENS[id];
  const stack = S.stacks[S.tab];
  const title = sc.title(p);
  const large = sc.large !== false;
  const prev = stack.length > 1 ? titleOf(stack[stack.length - 2]) : null;
  const backBtn = prev ? `<button class="back-btn glass" data-act="back" aria-label="Back to ${esc(prev)}"><span class="back-chev" aria-hidden="true">‹</span><span>${esc(prev)}</span></button>` : '';
  const body = P.loading && stack.length === 1 && id !== 'search' ? skeleton() : sc.render(p);
  return `<main class="main" aria-label="${esc(title)}"><div class="navbar ${large ? '' : 'inline'}" id="navbar"><div class="nav-lead">${backBtn}</div><div class="nav-title" ${large ? 'aria-hidden="true"' : ''}>${large ? esc(title) : `<h1 class="nav-h1" tabindex="-1" style="font-size:1em;margin:0">${esc(title)}</h1>`}</div><div class="nav-trail">${sc.trail ? sc.trail(p) : ''}</div></div>
    <div class="scroller" id="scroller"><div class="content">${large ? `<div><h1 class="large-title" tabindex="-1">${esc(title)}</h1>${sc.sub ? `<p class="subtitle">${sc.sub(p)}</p>` : ''}</div>` : ''}${body}</div></div>
    ${!isRegular() ? renderBottom() : ''}</main>`;
}
function renderBottom() {
  const n = pendingReview().length;
  const tab = (t, icon, label, badge) => `<button class="tab" role="tab" aria-selected="${S.tab === t}" data-act="switchTab" data-arg="${t}" aria-label="${label}${badge ? `, ${badge} to review` : ''}"><span class="ti" aria-hidden="true">${icon}</span><span class="tl">${label}</span>${badge ? `<span class="badge" aria-hidden="true">${badge}</span>` : ''}</button>`;
  return `<div class="bottom">${S.tab !== 'search' ? `<div class="accessory glass"><button class="pill-btn prominent acc-main" data-go="sheet:add">＋ Add transaction</button><button class="circle-btn" style="background:transparent" data-act="quickScan" aria-label="Scan a receipt">📷</button></div>` : ''}
    <div class="tabrow"><div class="tabbar glass" role="tablist" aria-label="Main sections">${tab('home', '🏠', 'Home')}${tab('activity', '🧾', 'Activity', n)}${tab('plan', '🎯', 'Plan')}${tab('wealth', '🏦', 'Wealth')}</div>
    <button class="search-tab glass" role="tab" aria-selected="${S.tab === 'search'}" data-act="switchTab" data-arg="search" aria-label="Search">🔍</button></div></div>`;
}
ACTIONS.back = back;
ACTIONS.quickScan = () => { openSheet('add'); ACTIONS.scanReceipt(); };

function render() {
  const dev = document.getElementById('device');
  // keep scroll position per route and focus across re-renders
  const sc = document.getElementById('scroller');
  if (sc) (S.scroll = S.scroll || {})[S.tab + '/' + curRoute()] = sc.scrollTop;
  const sb = document.getElementById('sheet-body'); const sheetScroll = sb ? sb.scrollTop : 0;
  const active = document.activeElement && dev.contains(document.activeElement) ? (document.activeElement.id ? '#' + document.activeElement.id : null) : null;

  const [w, h] = SIZES[P.size]; const [dt, ax] = TEXT[P.text];
  dev.className = 'device' + (isRegular() ? ' regular' : '');
  Object.assign(dev.dataset, { appearance: P.appearance, contrast: P.contrast, transparency: P.transparency, motion: P.motion, ax: String(ax) });
  dev.style.setProperty('--dw', w + 'px'); dev.style.setProperty('--dh', h + 'px'); dev.style.setProperty('--dt', dt);
  applyAccent(dev);
  dev.setAttribute('dir', P.rtl ? 'rtl' : 'ltr'); dev.setAttribute('lang', P.rtl ? 'ar' : 'en');
  dev.innerHTML = `<div class="status-bar" aria-hidden="true"><span>9:41</span><span>${P.network === 'offline' ? '✈︎' : '▂▄▆ ◠'} ▭</span></div><div class="island" aria-hidden="true"></div>
    <div class="app" ${S.scene || S.sheet || S.dialog ? 'aria-hidden="true" inert' : ''}>${isRegular() ? renderSidebar() : ''}${renderMain()}</div>
    ${S.scene ? renderScene() : ''}${S.sheet ? renderSheet() : ''}${renderDialog()}
    ${S.toast ? `<div class="toast glass" role="status"><span class="tt">${S.toast.msg}</span>${S.toast.undo ? `<button class="pill-btn" style="background:transparent;color:var(--accent-text)" data-act="undo">Undo</button>` : ''}</div>` : ''}
    ${S.siri ? `<div class="siri glass" role="status"><div class="glow" aria-hidden="true"></div><div style="display:flex;justify-content:space-between;gap:8px;align-items:center"><span class="sim-tag">Simulated Siri</span><button class="more-btn" data-act="closeSiri" aria-label="Close">✕</button></div><div class="muted" style="font-size:.85em">${S.siri.q}</div><div>${S.siri.a}</div></div>` : ''}
    <div class="sr-only" aria-live="polite" id="live">${S.toast ? S.toast.msg.replace(/<[^>]+>/g, '') : ''}</div>`;
  postProcess(dev);
  if (S.sheet?.kind === 'add') updateAddDerived();

  const sc2 = document.getElementById('scroller');
  if (sc2) {
    sc2.scrollTop = (S.scroll || {})[S.tab + '/' + curRoute()] || 0;
    const nb = document.getElementById('navbar');
    const onScroll = () => nb.classList.toggle('scrolled', sc2.scrollTop > 30);
    sc2.addEventListener('scroll', onScroll, { passive: true }); onScroll();
  }
  const sb2 = document.getElementById('sheet-body'); if (sb2 && !S.ui.focusSheet) sb2.scrollTop = sheetScroll;
  // focus management
  if (S.dialog) dev.querySelector('#dlg-t')?.focus();
  else if (S.ui.focusSheet && S.sheet) { S.ui.focusSheet = false; dev.querySelector('#sheet-title')?.focus(); }
  else if (S.scene) dev.querySelector('.scene h1')?.focus();
  else if (S.ui.refocus) { dev.querySelector(S.ui.refocus)?.focus(); S.ui.refocus = null; }
  else if (S.ui.focusTitle) { S.ui.focusTitle = false; (dev.querySelector('.large-title') || dev.querySelector('.nav-h1'))?.focus({ preventScroll: true }); }
  else if (active) dev.querySelector(active)?.focus({ preventScroll: true });
  renderNotes();
  document.getElementById('route-label').textContent = S.scene ? `scene: ${S.scene}` : `${S.tab} › ${S.stacks[S.tab].map(titleOf).join(' › ')}${S.sheet ? ` + sheet: ${S.sheet.kind}` : ''}`;
}
const ACCENTS = { teal: ['#0E9C8A', '#0A7A6D', '#2FD4BE'], blue: ['#1A6FD0', '#1A62B8', '#4A9EFF'], purple: ['#7C5BD0', '#6A4BBD', '#A07EE8'], coral: ['#E5736B', '#B8473F', '#FF9590'], gold: ['#C8902B', '#8E6414', '#E8B64B'], rose: ['#D04B7C', '#B23A66', '#FF70A6'] };
function applyAccent(dev) {
  const [l, lt, dk] = ACCENTS[ui('accentName', 'teal')];
  const dark = P.appearance === 'dark';
  dev.style.setProperty('--accent', dark ? dk : l); dev.style.setProperty('--accent-text', dark ? dk : lt); dev.style.setProperty('--accent-fill', dark ? dk : lt);
}
// Pseudo-localisation: expand text ~40% and accent letters, to check long translations.
const ACC = { a: 'á', e: 'é', i: 'î', o: 'ö', u: 'ü', A: 'Å', E: 'É', I: 'Î', O: 'Ö', U: 'Ü', c: 'ç', n: 'ñ' };
function postProcess(root) {
  if (!P.pseudo) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, { acceptNode: n => (n.parentElement.closest('script,style,.status-bar,input,textarea,select,bdi,.badge,svg') || !/[A-Za-z]{2}/.test(n.nodeValue) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT) });
  const nodes = []; while (walker.nextNode()) nodes.push(walker.currentNode);
  nodes.forEach(n => { const t = n.nodeValue; const pad = '·'.repeat(Math.ceil(t.trim().length * 0.4)); n.nodeValue = t.replace(/[aeiouAEIOUcn]/g, ch => ACC[ch] || ch).replace(/(\S)(\s*)$/, `$1${pad}$2`); });
}

// ---------------- workbench: notes, matrix, controls ----------------
function renderNotes() {
  const el = document.getElementById('notes-body'); if (!el) return;
  if (S.scene) { el.innerHTML = `<h3>${{ onboarding: 'Onboarding', lock: 'Lock screen', restore: 'Restore after reinstall' }[S.scene]}</h3><p>${{ onboarding: 'Four marketing pages + setup become two steps: what FinTrack does, then name / currency / Face ID. Skip keeps working.', lock: 'Face ID first, passcode keypad with spoken progress, 5-try lockout for 30 s (same rules as LockScreenView).', restore: 'Shown on a fresh install when an on-device snapshot exists.' }[S.scene]}</p>`; return; }
  const [id] = parse(curRoute()); const n = SCREENS[id].notes || {};
  const sheetNote = S.sheet?.kind === 'add' ? `<p class="k">Sheet open: Add transaction</p><ul><li>Type, amount, merchant, account, date and category first; everything else under “More details”.</li><li>Scan receipt and Dictate are visible buttons (were buried in the form).</li><li>Save explains why it’s unavailable; Cancel with changes asks before discarding; swipe-down is blocked while there are changes.</li><li>Same duplicate warning and balance check as today.</li></ul>` : '';
  el.innerHTML = `<h3>${esc(SCREENS[id].title(parse(curRoute())[1]))}</h3>${sheetNote}<p class="k">Purpose</p><p>${n.purpose || ''}</p><p class="k">Primary action</p><p>${n.primary || ''}</p>
    ${(n.moved || []).length ? `<p class="k">What changed</p><ul>${n.moved.map(x => `<li>${x}</li>`).join('')}</ul>` : ''}${(n.a11y || []).length ? `<p class="k">Accessibility</p><ul>${n.a11y.map(x => `<li>${x}</li>`).join('')}</ul>` : ''}`;
}
function renderMatrix() {
  const tb = document.getElementById('matrix-body');
  tb.innerHTML = FEATURES.map(([area, feat, cur, prob, prop, r]) => `<tr><td>${area}</td><td>${esc(feat)}</td><td>${esc(cur)}</td><td>${esc(prob)}</td><td>${esc(prop)}</td><td><button data-show="${r}">Show</button></td></tr>`).join('');
  document.getElementById('matrix-count').textContent = `${FEATURES.length} rows`;
}
function showRoute(r) {
  S.sheet = null; S.dialog = null; S.scene = null;
  if (r.startsWith('sheet:') || r.startsWith('scene:')) return go(r);
  const owner = ownerTab(r);
  S.tab = owner; S.stacks[owner] = parse(r)[0] === ROOTS[owner] ? [ROOTS[owner]] : [ROOTS[owner], r];
  S.ui.focusTitle = false; render();
  document.getElementById('device').scrollIntoView({ behavior: P.motion === 'reduced' ? 'auto' : 'smooth', block: 'center' });
}
function syncControls() {
  document.querySelectorAll('[data-pref]').forEach(g => g.querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', String(P[g.dataset.pref] === b.dataset.v))));
  document.querySelectorAll('[data-flag]').forEach(c => { c.checked = c.type === 'checkbox' ? !!(c.dataset.on ? P[c.dataset.flag] === c.dataset.on : P[c.dataset.flag]) : c.checked; });
}

// ---------------- events ----------------
function init() {
  const dev = document.getElementById('device');
  dev.addEventListener('click', e => {
    const el = e.target.closest('[data-go],[data-act]');
    if (!el || !dev.contains(el)) return;
    if (el.dataset.act === 'dismiss' && e.target.closest('[data-stop]') && e.target !== el) return; // clicks inside the dialog box
    if (el.dataset.act === 'closeSheet' && el.classList.contains('scrim') && S.sheet) { closeSheet(false); return; }
    if (el.disabled || el.getAttribute('aria-disabled') === 'true' && el.dataset.act !== 'saveTx') return;
    if (el.dataset.go) { e.preventDefault(); return go(el.dataset.go, el); }
    const fn = ACTIONS[el.dataset.act];
    if (fn) { if (el.type !== 'checkbox' && el.type !== 'radio') e.preventDefault(); fn(el.dataset.arg, el); }
  });
  dev.addEventListener('input', e => {
    const t = e.target;
    if (t.dataset.field && S.form) { S.form[t.dataset.field] = t.value; S.form.dirty = true; if (['method'].includes(t.dataset.field)) { S.ui.refocus = '#' + t.id; render(); } else updateAddDerived(); }
    else if (t.dataset.ffield) S.ui.ff[t.dataset.ffield] = t.value;
    else if (t.dataset.input && INPUTS[t.dataset.input]) INPUTS[t.dataset.input](t.value, t);
  });
  dev.addEventListener('change', e => { const t = e.target; if (t.dataset.field && S.form && t.tagName === 'SELECT') { S.form[t.dataset.field] = t.value; S.form.dirty = true; S.ui.refocus = '#' + t.id; render(); } });
  dev.addEventListener('submit', e => { e.preventDefault(); if (e.target.dataset.form === 'ask') { const q = document.getElementById('ask-q').value.trim(); if (q) { ACTIONS.askSend(q); S.ui.refocus = '#ask-q'; render(); } } });
  dev.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    if (S.siri) return ACTIONS.closeSiri();
    if (S.dialog) return ACTIONS.dismiss();
    if (S.sheet) return closeSheet(false);
    if (S.stacks[S.tab].length > 1) back();
  });
  // workbench controls
  document.querySelectorAll('[data-pref]').forEach(g => g.addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    const k = g.dataset.pref; P[k] = b.dataset.v;
    if (k === 'dataset') { DATA = clone(P.dataset === 'empty' ? EMPTY : SAMPLE); S.stacks = { home: ['home'], activity: ['activity'], plan: ['plan'], wealth: ['wealth'], search: ['search'] }; }
    if (k === 'appearance') S.ui.theme = P.appearance;
    syncControls(); render();
  }));
  document.querySelectorAll('[data-flag]').forEach(c => c.addEventListener('change', () => {
    const k = c.dataset.flag; P[k] = c.dataset.on ? (c.checked ? c.dataset.on : c.dataset.off) : c.checked;
    if (k === 'loading' && c.checked) setTimeout(() => { P.loading = false; syncControls(); render(); }, 2500);
    render();
  }));
  document.querySelectorAll('[data-wb]').forEach(b => b.addEventListener('click', () => {
    const a = b.dataset.wb;
    if (a.startsWith('scene:') || a.startsWith('sheet:')) { S.sheet = null; S.dialog = null; go(a); }
    else if (ACTIONS[a]) ACTIONS[a]();
    document.getElementById('device').focus?.();
  }));
  document.getElementById('matrix-body').addEventListener('click', e => { const b = e.target.closest('[data-show]'); if (b) showRoute(b.dataset.show); });
  document.getElementById('reset').addEventListener('click', () => { DATA = clone(SAMPLE); Object.assign(P, { dataset: 'sample', loading: false, network: 'online', syncError: false, notifPerm: 'granted', camPerm: 'granted' }); S.tab = 'home'; S.stacks = { home: ['home'], activity: ['activity'], plan: ['plan'], wealth: ['wealth'], search: ['search'] }; S.sheet = S.dialog = S.scene = S.siri = S.toast = null; S.ui = {}; syncControls(); render(); });
  if (matchMedia('(prefers-color-scheme: dark)').matches) P.appearance = 'dark';
  try { const hash = location.hash.slice(1); if (hash && SCREENS[hash]) showRoute(hash); } catch (e) { /* ignore */ }
  document.getElementById('size-label').textContent = SIZES[P.size][2];
  document.querySelector('[data-pref="size"]').addEventListener('click', () => { document.getElementById('size-label').textContent = SIZES[P.size][2]; });
  renderMatrix(); syncControls(); render();
}
document.addEventListener('DOMContentLoaded', init);
