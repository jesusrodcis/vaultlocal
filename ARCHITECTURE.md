# Architecture Plan — Cross-Device (PC + iPhone)

## Current State

```
Browser (PC)
├── vaultlocal_79.html   ← entire app, opened as file://
├── IndexedDB            ← all transaction/debt/rule data
├── localStorage         ← PIN, settings, AI config
└── JSONBin (manual)     ← backup/restore (DDs, debts, rules, settings only)
```

**Problem:** `file://` URLs don't support service workers or PWA install prompts, and iOS Safari has limited IndexedDB reliability when the file is loaded locally. To use the app on iPhone it must be served over HTTPS.

---

## Target State

```
HTTPS host (Cloudflare Pages — free)
└── vaultlocal_XX.html + manifest.json + sw.js + icons/

PC browser                      iPhone (installed PWA)
├── IndexedDB (local)           ├── IndexedDB (local)
├── localStorage                ├── localStorage
└── Auto-sync ──────────────── └── Auto-sync
              │
         Sync backend (TBD — see Phase 2)
```

---

## Phases

### Phase 1 — Host + PWA Install (do this first, unblocks iPhone)

**Goal:** App installable on iPhone home screen, works offline.

**Changes:**

1. **Static hosting** — Deploy to Cloudflare Pages (or GitHub Pages / Netlify).
   - Push repo to GitHub.
   - Connect to Cloudflare Pages → set root file as entry point.
   - Get a free `*.pages.dev` HTTPS URL.

2. **Web App Manifest** (`manifest.json`)
   ```json
   {
     "name": "VaultLocal",
     "short_name": "Vault",
     "start_url": "/",
     "display": "standalone",
     "background_color": "#f5f5f3",
     "theme_color": "#04342C",
     "icons": [{ "src": "icon-192.png", "sizes": "192x192", "type": "image/png" },
               { "src": "icon-512.png", "sizes": "512x512", "type": "image/png" }]
   }
   ```
   Add `<link rel="manifest" href="manifest.json">` to the HTML `<head>`.

3. **Service Worker** (`sw.js`) — cache-first for CDN assets
   ```
   Cache on install:
   - chart.js (CDN)
   - xlsx.js (CDN)
   - the app HTML itself
   ```
   This makes the app fully offline on both PC and iPhone after the first load.

4. **Icons** — Generate a 192×192 and 512×512 PNG from the existing vault SVG logo.

**Outcome:** Open the `pages.dev` URL on iPhone → Share → Add to Home Screen. App launches full-screen, works offline.

---

### Phase 2 — Reliable Cross-Device Sync

**Goal:** Sync transactions, debts, DDs, rules, and settings automatically between PC and iPhone without manual push/pull.

**Current limitation:** JSONBin sync is manual and only covers non-transaction data (debts, DDs, rules, settings). Transactions are never synced.

**Recommended approach: Supabase (free tier)**

Supabase provides a Postgres database + REST API + realtime subscriptions. Free tier: 500MB storage, 50,000 rows.

```
Each device ──UPSERT──▶ Supabase (transactions, debts, DDs, rules, settings)
            ◀──FETCH── on app open / manual sync
```

**Schema (rough):**
| Table | Key columns |
|---|---|
| `transactions` | `id`, `user_hash`, `date`, `description`, `amount`, `category`, `account`, `synced_at` |
| `debts` | `id`, `user_hash`, `name`, `balance`, `rate`, `type`, `updated_at` |
| `direct_debits` | `id`, `user_hash`, `name`, `amount`, `day`, `status` |
| `rules` | `id`, `user_hash`, `pattern`, `category` |
| `settings` | `user_hash`, `key`, `value` |

**Auth:** Use a simple shared secret (a UUID the user generates once in Settings) as `user_hash`. No email/password signup required. This keeps the app serverless-simple while isolating data per user.

**Migration path:**
- Keep JSONBin sync as a legacy fallback during transition.
- Add a "Sync to cloud" toggle in Settings that switches between JSONBin (old) and Supabase (new).
- On first Supabase sync, push all local IndexedDB data up.
- On subsequent syncs, merge by `synced_at` timestamp (last-write-wins per record).

**Alternative (even simpler):** Use Cloudflare Workers + KV — no external service needed if already on Cloudflare Pages. Slightly more setup but keeps everything under one provider.

---

### Phase 3 — Polish & Stability (ongoing)

These are independent improvements that don't block Phase 1 or 2.

| Item | Details |
|---|---|
| **IndexedDB robustness** | Replace the nuke-and-retry pattern with proper `versionchange` event handling and migration scripts |
| **PIN security** | Hash the PIN with SHA-256 before storing in localStorage (still UI-lock only but no plaintext) |
| **CDN resilience** | Bundle Chart.js and XLSX into the HTML (or cache via service worker) so the app works without internet on first load |
| **AI timeout** | Make LM Studio timeout configurable in Settings (currently hard-coded to 60s) |
| **Transfer mapping** | Complete the feature — apply transfer labels as a special category so they appear correctly in analytics |
| **Date parsing** | Consolidate all date parsing into a single utility function with explicit format detection order |

---

## Recommended First Step

Start with **Phase 1**. It requires:

1. A GitHub repo (or any Git host)
2. A free Cloudflare Pages account
3. Three new files: `manifest.json`, `sw.js`, and two PNG icons

The HTML file needs only two small edits: add the manifest link tag and register the service worker. No structural changes to the app logic.

This unblocks iPhone use immediately. Phase 2 (sync) can follow once the PWA is working on both devices.
