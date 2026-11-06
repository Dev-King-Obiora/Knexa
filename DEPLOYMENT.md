# Knexa AI — PWA and subscription upgrade

This package extends the existing Knexa AI `index.html` and FastAPI `main.py`. It does not replace the existing providers, authentication model, Redis database, payment provider, or hosting architecture.

## Files

- `index.html` — updated student experience, Pro plan selector, owner settings interface, installation UI, and service-worker registration.
- `main.py` — existing backend extended with four-plan pricing, calendar-month subscription fulfilment, configurable daily CBT usage, public plan data, and PWA asset routes.
- `manifest.json` — install metadata and app shortcuts.
- `service-worker.js` — app-shell cache and offline navigation fallback. It deliberately excludes API routes, admin pages, and requests carrying an Authorization header.
- `offline.html` — standalone offline fallback page.
- `icons/knexa-192.png`, `icons/knexa-512.png`, `icons/knexa-maskable-512.png`, `icons/knexa.svg` — application icons.

## Deploy to Vercel (frontend)

Place `index.html`, `manifest.json`, `service-worker.js`, `offline.html`, and the complete `icons/` directory at the deployed site root. Keep the frontend URL as:

`https://knexa-ai.vercel.app`

The service worker must remain at `/service-worker.js` at the site root so it can control the full app. PWA installation requires HTTPS; Vercel's production domain already uses HTTPS.

## Deploy to Render (backend)

Replace the deployed backend file with this package's `main.py`. Keep the PWA companion files (`index.html`, `manifest.json`, `service-worker.js`, `offline.html`, and `icons/`) beside `main.py` in the same application directory. The backend reads its sibling `index.html` and now exposes the PWA assets from its own origin as well.

Keep the existing start command, for example:

`uvicorn main:app --host 0.0.0.0 --port $PORT`

No new environment variables are introduced. Retain the existing secrets and configuration. Confirm these existing values are correct:

- `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN`
- `PAYSTACK_SECRET_KEY`
- `OWNER_KNEXA_ID`
- `SECRET_KEY` (set a stable, random secret so signed sessions remain valid across restarts)
- `FRONTEND_ORIGIN=https://knexa-ai.vercel.app`
- `PUBLIC_APP_URL=https://knexa-ai.vercel.app`
- `GROQ_API_KEY` and `GEMINI_API_KEY`

Do not put any secret key in `index.html`, the manifest, or other frontend assets.

## Pricing and subscription behaviour

The initial plans are Monthly ₦5,000, Quarterly ₦19,000, Half-Yearly ₦28,000, and Annual ₦55,000. Plan IDs and durations are fixed by the backend; the owner can adjust price, enable/disable each plan, description, and promotional label in the private Admin Dashboard.

The backend stores the selected plan, configured amount, and duration on the pending payment record before redirecting to Paystack. Payment verification checks the amount against that stored record, not an amount sent by the browser. A price change after checkout does not alter an already-created payment. Subscription fulfilment is idempotent and adds the purchased calendar-month period after any unexpired existing Pro period. Existing account expiry timestamps are not migrated or reset.

The free CBT allowance defaults to **2 exam generations per Africa/Lagos calendar day**. The owner can change it in Admin settings, including to `0`. It is enforced through the existing atomic Upstash quota operation; browser storage is not used as the authority. Existing daily counters remain in Redis until their current Lagos-day expiry.

The existing Redis key `knexa:settings` is extended to contain plan settings and free-use limits. Previously saved text/image limits are retained; missing new settings use the new defaults. No Redis flush or manual migration is required.

## Validation performed

- Python bytecode compilation for `main.py`.
- JavaScript syntax checks for the application script and service worker.
- HTML parsing and manifest JSON validation.
- PNG signature and 192×192 / 512×512 icon-dimension checks.
- FastAPI smoke tests for `/`, `/manifest.json`, `/service-worker.js`, `/offline.html`, and all three PNG icon routes.
- Backend import, default plan values, default CBT allowance, and calendar-month boundary checks.

Live Paystack transactions, real Upstash writes, Groq/Gemini calls, and installation prompts on physical Android/iOS/desktop devices were not run in this environment. Verify those after deployment using the production secrets and test payment mode before announcing the upgrade as live.

## Post-deployment checks

1. Open `https://knexa-ai.vercel.app/` in Chrome and confirm the manifest and `/service-worker.js` load without errors.
2. Install from the browser's install prompt. On iOS, use Safari → Share → Add to Home Screen.
3. Sign in with the owner Knexa ID, open Private admin, change one test plan setting and save. Confirm the student plan selector reflects it.
4. Set free CBT uses to `2`, generate two CBTs on a free test account, and confirm the third is rejected. Repeat with `0`, then restore the intended value.
5. Use Paystack test mode to check each enabled plan. Confirm the exact amount, currency, and subscription duration before moving to live mode.
6. Switch offline after the app has loaded once. The public app shell/offline page should remain available; AI, account, payment and exam API operations should show a connection error and must not be served from cache.
