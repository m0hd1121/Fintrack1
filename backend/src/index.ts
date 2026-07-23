// FinTrack email-transaction sync Worker.
//
// Flow:
//   bank alert email --(user's forwarding rule)--> Email Routing
//     --> this Worker's `email()` handler --> parse --> insert pending txn (D1)
//     --> APNs push to the user's iPhone.
//   The iOS app then calls the HTTP API (`fetch()` handler) to pull pending
//   transactions into its review queue and to acknowledge (confirm/reject/edit).
//
// The user is identified by the local-part of the recipient address, e.g. a
// bank alert forwarded to `ab12cd34@sync.example.com` belongs to user "ab12cd34".

import PostalMime from 'postal-mime';

export interface Env {
  DB: D1Database;
  APNS_TOPIC: string;   // app bundle id
  APNS_HOST: string;    // https://api.push.apple.com  (or api.sandbox.push.apple.com)
  // secrets:
  APNS_KEY: string;     // contents of the .p8 APNs auth key (PEM)
  APNS_KEY_ID: string;  // 10-char key id
  APNS_TEAM_ID: string; // 10-char Apple team id
  APP_API_KEY: string;  // shared bearer token the iOS app sends
}

// ---------------------------------------------------------------------------
// Parsed transaction shape
// ---------------------------------------------------------------------------

interface ParsedTx {
  amount: number;
  currency: string;
  direction: 'debit' | 'credit';
  merchantRaw: string | null;
  merchant: string | null;
  cardLast4: string | null;
  availableBalance: number | null;
  reference: string | null;
  bankName: string;
  category: string;
  confidence: number;
}

// ===========================================================================
// Worker handlers
// ===========================================================================

export default {
  // ----- Inbound bank alert email --------------------------------------------
  async email(message: ForwardableEmailMessage, env: Env, _ctx: ExecutionContext): Promise<void> {
    const userId = localPart(message.to);
    if (!userId) return;

    let parsed;
    try {
      parsed = await PostalMime.parse(message.raw);
    } catch {
      return;
    }

    const subject = parsed.subject || message.headers.get('subject') || '';
    const text = parsed.text || (parsed.html ? htmlToText(parsed.html) : '');
    const from = parsed.from?.address || message.from || '';

    const tx = parseBankEmail(subject, text, from);
    if (!tx) return; // not a recognizable transaction alert — ignore silently

    const fp = await fingerprint(userId, tx);
    const id = crypto.randomUUID();
    const now = Date.now();

    const res = await env.DB.prepare(
      `INSERT OR IGNORE INTO pending_txns
        (id,user_id,fingerprint,bank_name,sender,subject,snippet,message_id,received_at,
         amount,currency,merchant_raw,merchant,direction,card_last4,available_balance,
         reference,suggested_category,confidence,status,created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'pending',?)`
    ).bind(
      id, userId, fp, tx.bankName, from, subject, snippet(text),
      parsed.messageId || message.headers.get('message-id') || '', now,
      tx.amount, tx.currency, tx.merchantRaw, tx.merchant, tx.direction,
      tx.cardLast4, tx.availableBalance, tx.reference, tx.category, tx.confidence, now
    ).run();

    // Only notify on a genuinely new row (dedup index blocks repeats).
    if (res.meta.changes > 0) {
      const amt = `${tx.currency} ${tx.amount.toFixed(2)}`;
      const verb = tx.direction === 'credit' ? 'received' : 'spent';
      const where = tx.merchant ? ` at ${tx.merchant}` : '';
      await pushToUser(env, userId, 'New transaction to review', `${amt} ${verb}${where} — tap to confirm`, { txnId: id });
    }
  },

  // ----- App-facing HTTP API -------------------------------------------------
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (path === '/health') return json({ ok: true });

    // All API routes require the shared bearer token.
    const auth = request.headers.get('authorization') || '';
    if (auth !== `Bearer ${env.APP_API_KEY}`) return json({ error: 'unauthorized' }, 401);

    try {
      // Register / refresh this device's push token.
      if (path === '/v1/devices' && request.method === 'POST') {
        const body = await request.json<{ userId?: string; deviceToken?: string; platform?: string }>();
        if (!body.userId || !body.deviceToken) return json({ error: 'userId and deviceToken required' }, 400);
        const now = Date.now();
        await env.DB.prepare(
          `INSERT INTO devices (device_token,user_id,platform,created_at,updated_at)
           VALUES (?,?,?,?,?)
           ON CONFLICT(device_token) DO UPDATE SET user_id=excluded.user_id, updated_at=excluded.updated_at`
        ).bind(body.deviceToken, body.userId, body.platform || 'ios', now, now).run();
        return json({ ok: true });
      }

      // List pending transactions for a user.
      if (path === '/v1/pending' && request.method === 'GET') {
        const userId = url.searchParams.get('userId');
        if (!userId) return json({ error: 'userId required' }, 400);
        const status = url.searchParams.get('status') || 'pending';
        const rows = await env.DB.prepare(
          `SELECT * FROM pending_txns WHERE user_id = ? AND status = ? ORDER BY created_at DESC LIMIT 200`
        ).bind(userId, status).all();
        return json({ pending: rows.results ?? [] });
      }

      // Acknowledge (the app pulled/confirmed/rejected these) so we stop
      // returning + re-notifying them.
      if (path === '/v1/pending/ack' && request.method === 'POST') {
        const body = await request.json<{ userId?: string; ids?: string[]; status?: string }>();
        if (!body.userId || !body.ids?.length) return json({ error: 'userId and ids required' }, 400);
        const newStatus = ['pulled', 'confirmed', 'rejected'].includes(body.status || '') ? body.status! : 'pulled';
        const placeholders = body.ids.map(() => '?').join(',');
        await env.DB.prepare(
          `UPDATE pending_txns SET status = ? WHERE user_id = ? AND id IN (${placeholders})`
        ).bind(newStatus, body.userId, ...body.ids).run();
        return json({ ok: true, updated: body.ids.length });
      }

      return json({ error: 'not found' }, 404);
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  },

  // ----- Daily cleanup -------------------------------------------------------
  async scheduled(_event: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    const cutoff = Date.now() - 30 * 24 * 3600 * 1000;
    await env.DB.prepare(`DELETE FROM pending_txns WHERE status != 'pending' AND created_at < ?`).bind(cutoff).run();
  },
};

// ===========================================================================
// Bank-alert parsing (heuristic — the app can refine on device)
// ===========================================================================

const CURRENCIES = ['AED', 'USD', 'EUR', 'GBP', 'SAR', 'QAR', 'KWD', 'BHD', 'OMR', 'INR', 'PKR', 'EGP', 'JPY', 'CNY', 'CHF', 'CAD', 'AUD', 'SGD'];

function parseBankEmail(subject: string, text: string, from: string): ParsedTx | null {
  const body = `${subject}\n${text}`.replace(/ /g, ' ').replace(/[ \t]+/g, ' ');
  const flat = body.replace(/\s+/g, ' ');

  // Amount + currency (either order): "AED 1,234.56" or "1,234.56 AED".
  const cur = CURRENCIES.join('|');
  const re = new RegExp(`\\b(${cur})\\b[\\s:]*([0-9][0-9,]*\\.?[0-9]{0,2})|([0-9][0-9,]*\\.[0-9]{2})\\s*\\b(${cur})\\b`, 'i');
  const m = flat.match(re);
  if (!m) return null;
  const currency = (m[1] || m[4]).toUpperCase();
  const amount = parseFloat((m[2] || m[3]).replace(/,/g, ''));
  if (!(amount > 0)) return null;

  const lower = flat.toLowerCase();
  const debitWords = ['debited', 'purchase', 'spent', 'withdrawn', 'payment of', 'paid', ' pos ', 'deducted', 'charged', 'sent'];
  const creditWords = ['credited', 'received', 'deposit', 'refund', 'salary', 'reversal', 'cashback'];
  let direction: 'debit' | 'credit' = 'debit';
  const hasCredit = creditWords.some((w) => lower.includes(w));
  const hasDebit = debitWords.some((w) => lower.includes(w));
  if (hasCredit && !hasDebit) direction = 'credit';

  const cardM = flat.match(/(?:ending|card|xxxx|x{4}|\*{2,}|no\.?|account)\s*[:*x# ]*\s*(\d{4})\b/i);
  const cardLast4 = cardM ? cardM[1] : null;

  const merchM = flat.match(/\b(?:at|to|from|merchant[:]?)\s+([A-Z0-9][A-Za-z0-9 &.'*_\-]{2,40})/);
  const merchantRaw = merchM ? merchM[1].trim().replace(/\s+(on|dated|for)\b.*$/i, '').trim() : null;

  const balM = flat.match(/available balance[^\d]{0,20}([0-9][0-9,]*\.\d{2})/i);
  const availableBalance = balM ? parseFloat(balM[1].replace(/,/g, '')) : null;

  const refM = flat.match(/(?:ref(?:erence)?|txn|transaction)\s*(?:no\.?|number|id)?\s*[:#]?\s*([A-Z0-9]{6,})/i);
  const reference = refM ? refM[1] : null;

  return {
    amount,
    currency,
    direction,
    merchantRaw,
    merchant: merchantRaw ? tidyMerchant(merchantRaw) : null,
    cardLast4,
    availableBalance,
    reference,
    bankName: guessBank(from),
    category: guessCategory(merchantRaw, direction),
    confidence: 0.6,
  };
}

function tidyMerchant(s: string): string {
  return s.replace(/\s{2,}/g, ' ').replace(/\b\d{2,}\b/g, '').replace(/[*#]+/g, '').trim() || s;
}

function guessBank(from: string): string {
  const d = from.split('@')[1]?.toLowerCase() ?? '';
  const map: Record<string, string> = {
    emiratesnbd: 'Emirates NBD', enbd: 'Emirates NBD', adcb: 'ADCB', fab: 'FAB',
    bankfab: 'FAB', mashreq: 'Mashreq', dib: 'Dubai Islamic Bank', rakbank: 'RAKBANK',
    hsbc: 'HSBC', citi: 'Citibank', sc: 'Standard Chartered', adib: 'ADIB',
  };
  for (const key of Object.keys(map)) if (d.includes(key)) return map[key];
  const host = d.split('.')[0];
  return host ? host.charAt(0).toUpperCase() + host.slice(1) : 'Bank';
}

function guessCategory(merchant: string | null, direction: 'debit' | 'credit'): string {
  if (direction === 'credit') return 'Other';
  const m = (merchant || '').toLowerCase();
  if (/adnoc|enoc|eppco|petrol|fuel/.test(m)) return 'Fuel';
  if (/carrefour|lulu|spinneys|grocery|market|supermarket/.test(m)) return 'Food & Dining';
  if (/restaurant|cafe|coffee|kfc|mcdonald|talabat|deliveroo/.test(m)) return 'Food & Dining';
  if (/uber|careem|taxi|rta|metro/.test(m)) return 'Transportation';
  if (/pharmacy|hospital|clinic|aster|medcare/.test(m)) return 'Medical';
  if (/netflix|spotify|apple|google|subscription/.test(m)) return 'Subscriptions';
  return 'Other';
}

async function fingerprint(userId: string, tx: ParsedTx): Promise<string> {
  const basis = `${userId}|${tx.amount}|${tx.currency}|${tx.cardLast4 ?? ''}|${(tx.merchantRaw ?? '').toLowerCase()}`;
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(basis));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ===========================================================================
// APNs push (token-based JWT, ES256, via Web Crypto)
// ===========================================================================

async function pushToUser(env: Env, userId: string, title: string, body: string, data: Record<string, unknown>): Promise<void> {
  const rows = await env.DB.prepare(`SELECT device_token FROM devices WHERE user_id = ?`).bind(userId).all<{ device_token: string }>();
  const tokens = rows.results ?? [];
  if (tokens.length === 0) return;

  const jwt = await apnsJWT(env);
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: 'default', badge: 1, 'content-available': 1 },
    ...data,
  });

  for (const { device_token } of tokens) {
    const res = await fetch(`${env.APNS_HOST}/3/device/${device_token}`, {
      method: 'POST',
      headers: {
        authorization: `bearer ${jwt}`,
        'apns-topic': env.APNS_TOPIC,
        'apns-push-type': 'alert',
        'apns-priority': '10',
      },
      body: payload,
    });
    // Prune tokens Apple says are dead.
    if (res.status === 410 || res.status === 400) {
      await env.DB.prepare(`DELETE FROM devices WHERE device_token = ?`).bind(device_token).run();
    }
  }
}

let cachedJWT: { token: string; iat: number } | null = null;

async function apnsJWT(env: Env): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  // APNs tokens are valid up to 60 min; refresh every ~50 min.
  if (cachedJWT && nowSec - cachedJWT.iat < 3000) return cachedJWT.token;

  const header = { alg: 'ES256', kid: env.APNS_KEY_ID };
  const claims = { iss: env.APNS_TEAM_ID, iat: nowSec };
  const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));
  const signingInput = `${enc(header)}.${enc(claims)}`;

  const key = await importP8(env.APNS_KEY);
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(signingInput));
  const token = `${signingInput}.${b64url(new Uint8Array(sig))}`;
  cachedJWT = { token, iat: nowSec };
  return token;
}

async function importP8(pem: string): Promise<CryptoKey> {
  const b64 = pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('pkcs8', der, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
}

// ===========================================================================
// Helpers
// ===========================================================================

function localPart(addr: string): string | null {
  const at = addr.indexOf('@');
  if (at <= 0) return null;
  const lp = addr.slice(0, at).toLowerCase().replace(/[^a-z0-9._-]/g, '');
  return lp || null;
}

function htmlToText(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<br\s*\/?>(?=)/gi, '\n')
    .replace(/<\/(p|div|tr|li|h[1-6])>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&[a-z]+;/gi, ' ');
}

function snippet(text: string): string {
  return text.replace(/\s+/g, ' ').trim().slice(0, 200);
}

function b64url(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}
