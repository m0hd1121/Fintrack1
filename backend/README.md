# FinTrack Email-Sync Backend (Cloudflare Worker)

Background bank-email → pending-transaction sync with push notifications.

```
bank alert email
   │  (your mailbox forwarding rule)
   ▼
Cloudflare Email Routing ──▶ this Worker (email handler)
                               │ parse → insert pending txn (D1)
                               ▼
                            APNs push ──▶ your iPhone
                               │
   iOS app ◀── GET /v1/pending ┘   (pull into review queue)
   iOS app ──▶ POST /v1/pending/ack (confirm / reject / edit)
```

## Already done (provisioned by the assistant)

- **D1 database** `fintrack-email-sync` — id `45339d6a-3847-472d-92ab-26070a8a1d56`
- Tables `devices` + `pending_txns` (see `schema.sql`) are created.
- `wrangler.jsonc` already references that database id.

## What you still need

1. A **Cloudflare account** with a domain you control added, and **Email Routing** enabled on it.
2. An **Apple Developer account** with an **APNs Auth Key** (`.p8`) — App IDs → Keys → create a key with *Apple Push Notifications service (APNs)* enabled. Note the **Key ID** and your **Team ID**.
3. The Push Notifications capability enabled on the app's App ID (`com.mohd.fintrackpro.FinTrack`).

## Deploy

```bash
cd backend
npm install
npx wrangler login

# Secrets (never commit these):
npx wrangler secret put APNS_KEY       # paste the FULL contents of AuthKey_XXXX.p8
npx wrangler secret put APNS_KEY_ID    # 10-char key id
npx wrangler secret put APNS_TEAM_ID   # 10-char Apple team id
npx wrangler secret put APP_API_KEY    # any long random string; the app sends this

npm run deploy
```

`APNS_HOST` defaults to production (`api.push.apple.com`). For a development build
signed for the sandbox, set `"APNS_HOST": "https://api.sandbox.push.apple.com"` in
`wrangler.jsonc` and redeploy.

## Wire up Email Routing

1. Cloudflare dashboard → your domain → **Email Routing**.
2. Create a **catch-all** rule (or a specific address) that **sends to a Worker** →
   pick `fintrack-email-sync`. So any address at, say, `sync.yourdomain.com` reaches
   the Worker.
3. The **local-part is the user id**: an alert forwarded to
   `ab12cd34@sync.yourdomain.com` is filed for user `ab12cd34`. The iOS app
   generates this id and shows you the exact address to forward to.

## Set up mailbox forwarding

In Gmail/Outlook/etc., add a filter: **from your bank's alert sender → forward to**
the address the app shows you (`<yourUserId>@sync.yourdomain.com`). That's the only
place your real mailbox is touched — Cloudflare never sees your mailbox password or
tokens.

## HTTP API (used by the app)

All routes require `Authorization: Bearer <APP_API_KEY>`.

| Method | Path | Body / query | Purpose |
|---|---|---|---|
| POST | `/v1/devices` | `{userId, deviceToken, platform}` | register APNs token |
| GET  | `/v1/pending` | `?userId=…&status=pending` | list pending txns |
| POST | `/v1/pending/ack` | `{userId, ids:[…], status}` | mark pulled/confirmed/rejected |
| GET  | `/health` | — | health check |

## Notes

- The parser (`parseBankEmail` in `src/index.ts`) is a heuristic starting point for
  UAE bank alerts (amount+currency, debit/credit, card last-4, merchant, balance).
  Extend the keyword/regex tables for your banks; the app can also refine on device.
- `PendingEmailTransaction` (the app's transient review queue) is intentionally the
  only model **not** covered by the app backup — this backend is its source of truth.
