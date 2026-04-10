# VaultLocal

A personal finance manager that runs entirely in your browser — no server, no subscriptions, no data leaving your device unless you choose.

## Features

- **Multi-bank import** — Upload statements from PTSB, Revolut, and Bank of Ireland (CSV/XLS)
- **Smart categorisation** — 30+ built-in vendor rules plus your own custom rules; AI-assisted fallback for unknowns
- **Safe-to-spend dashboard** — Salary-aware calculation that deducts pending direct debits before your next payday
- **Spending analytics** — 6-period trend charts, category breakdowns, daily heatmap, outlier detection, and forecasts
- **Debt tracker** — Loan and credit card balances with interest calculations and payoff date projections
- **Subscription Guillotine** — Identify and manage recurring costs
- **Runway planner** — Salary forecasting and holiday/leave planning
- **AI financial advisor** — Conversational analysis using LM Studio (local) or Google Gemini (cloud)
- **Cloud sync** — Manual backup and restore across devices via JSONBin

## Getting Started

### Run locally

Open `vaultlocal_79.html` directly in any modern browser. No installation or build step required.

On first launch you will be prompted to set a 4-digit PIN. Default demo debts are seeded automatically and can be edited or deleted in the **Debt** page.

### Run on iPhone / another device

The app must be served over HTTPS to work on iOS Safari and to be installable as a home screen app. The quickest free option is Cloudflare Pages:

1. Push this repo to GitHub.
2. Connect it to [Cloudflare Pages](https://pages.cloudflare.com) and set the root HTML file as the entry point.
3. Open the generated `*.pages.dev` URL on your iPhone and tap **Share → Add to Home Screen**.

See [Architecture](#architecture) below for the full cross-device plan.

## Configuration

Open the **Settings** page after first launch to configure:

| Setting | Description |
|---|---|
| Monthly income & payday | Used for safe-to-spend and runway calculations |
| Account balances | Current balance per account for the dashboard |
| AI provider | LM Studio (local) or Google Gemini API key |
| LM Studio endpoint | Default: `http://192.168.1.187:1234` |
| JSONBin API key & bin ID | Required for cloud sync |

## AI Providers

### LM Studio (local, private)

Run [LM Studio](https://lmstudio.ai) on your machine and load any chat model (Qwen3, DeepSeek-R1, etc.). Set the server endpoint in Settings. Chain-of-thought output (`<think>` blocks) is stripped automatically.

### Google Gemini (cloud)

Enter a Gemini API key in Settings. Uses `gemini-2.0-flash` by default.

## Data & Privacy

All transaction data is stored in your browser's **IndexedDB** — it never leaves your device unless you explicitly push a backup to JSONBin. The JSONBin backup excludes raw transactions; it syncs direct debits, debts, rules, and settings only.

The PIN provides a UI-level lock. It does not encrypt the underlying database.

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full improvement plan including PWA support, cross-device sync, and offline caching.

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Vanilla JS, CSS custom properties |
| Storage | IndexedDB + localStorage |
| Charts | Chart.js 4.4.0 |
| Spreadsheet parsing | SheetJS (XLSX) 0.18.5 |
| Cloud backup | JSONBin.io |
| AI (local) | LM Studio |
| AI (cloud) | Google Gemini 2.0 Flash |
