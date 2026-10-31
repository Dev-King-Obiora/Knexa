# KingMath-AI — Replit setup

## Files

Keep `main.py`, `index.html`, `schema.sql`, `requirements.txt`, and `.replit` in the project root. No `.env` file is required or included. Do not upload secrets into source code or GitHub.

## 1. Install and run

Replit should install from `requirements.txt`. If it does not, open the Shell and run:

```bash
pip install -r requirements.txt
```

Run the app with:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 2. Supabase database and Auth

1. Create/open your Supabase project.
2. Open **SQL Editor → New query**.
3. Paste all of `schema.sql` and run it once.
4. Open **Project Settings → API** (or API Keys) and copy the Project URL, publishable/anon key, and service-role/secret key.
5. In **Authentication → Providers → Email**, enable Email and password. Keep email confirmation enabled. Configure your SMTP/email delivery in Supabase before public launch; the built-in test email service has sending limits.
6. In Replit → **Tools → Secrets**, add:

| Secret | Value |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_PUBLISHABLE_KEY` | Your Supabase publishable key (`sb_publishable_...`) |
| `SUPABASE_SECRET_KEY` | Your Supabase secret key (`sb_secret_...`) — private, backend only |
| `ADMIN_EMAILS` | The exact email address you use to sign in, lowercase |
| `SECRET_KEY` | A long random string (at least 32 random bytes) |
| `TRUST_PROXY` | `true` when running behind Replit/Render/Vercel reverse proxies |
| `GROQ_API_KEY` | Your existing Groq key |
| `GEMINI_API_KEY` | Your existing Gemini key |
| `PAYSTACK_SECRET_KEY` | Paystack test secret key first, then live secret when ready |
| `PUBLIC_APP_URL` | Your public frontend URL, including https:// |
| `FRONTEND_ORIGIN` | Your exact frontend origin, e.g. https://your-app.vercel.app (no trailing slash) when frontend and backend use different domains |
| `OPAY_BANK_NAME` | Your OPay bank label |
| `OPAY_ACCOUNT_NAME` | Exact beneficiary/account name |
| `OPAY_ACCOUNT_NUMBER` | Your receiving account number |
| `OPAY_INSTRUCTIONS` | Optional payment instruction shown to users |

Never put `SUPABASE_SECRET_KEY`, any legacy `service_role` key, `PAYSTACK_SECRET_KEY`, Groq, Gemini, or `SECRET_KEY` in `index.html` or a Vercel public environment variable. The backend also accepts the legacy `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` names if your project only exposes legacy keys.

## 3. Make yourself the only admin

Set `ADMIN_EMAILS` to your own verified sign-in email only. Do not add customer emails. The admin page is hidden for ordinary users, but every admin API endpoint also checks this allowlist on the server. Restart the Replit app after changing Secrets.

## 4. Paystack

1. Start in Paystack Test Mode and put the test secret key in `PAYSTACK_SECRET_KEY`.
2. Set the Paystack webhook URL to `https://YOUR-REPLIT-OR-RENDER-DOMAIN/api/payments/paystack/webhook`.
3. Test a complete checkout. Pro is activated only after server-side verification of successful status, exact NGN amount, matching reference, and the signed webhook/callback flow.
4. After successful end-to-end testing, switch to live keys and configure the live webhook URL. Do not test live payments with a real customer account.

## 5. Frontend and backend hosting

The simplest first verification is to run the whole app from Replit, where `index.html` and `/api/*` share one origin. Your current Vercel frontend + Render backend arrangement needs the API base URL configured. In `index.html`, change `<meta name="kingmath-api" content="">` to `<meta name="kingmath-api" content="https://YOUR-RENDER-SERVICE.onrender.com">` (no trailing slash), then deploy the HTML to Vercel. On Render, set `FRONTEND_ORIGIN` to your exact Vercel origin, for example `https://your-app.vercel.app`, and set `PUBLIC_APP_URL` to that same frontend URL. For a same-origin Replit test, leave the meta content empty.

## 6. Important current limits

- Free plan limits initially: 10 text AI calls/day, 3 image AI calls/day, one topic-practice request/day, and one generated CBT/day. The text/image limits and Pro price can be changed in the private admin dashboard. The SQL seed row is the initial source of the ₦5,000 price and 10/3 daily AI limits. CBT/practice limits are currently one/day for Free.
- Pro uses configurable fair-use caps (default 500 text and 100 image AI calls/day; 100 practice/CBT requests/day). These are safeguards, not unlimited service.
- Subscription renewal is manual. A verified payment adds one calendar month; a payment made before expiry extends from the existing expiry date. Expired subscriptions are treated as Free by the server.
- Email verification is handled by Supabase Auth. Automated 7/3/1-day expiry reminder emails are not enabled in this compact build; configure a scheduled email job before promising reminders to customers.
- Active CBT exam state remains in memory as in the original code. Restarting the backend can interrupt an active exam. User accounts, payments, subscriptions and daily quotas are stored in Supabase.
- Manual OPay transfers remain pending until you approve them in the private admin dashboard. A receipt or submitted transfer reference is not automatic proof of payment.
- Set your OPay details and Paystack key before enabling checkout. A missing configuration fails closed with a clear message.

## 7. First test checklist

1. Register with an email you control and verify it from your inbox.
2. Sign in and confirm the account displays Free.
3. Use the solver and topic practice; confirm daily usage limits work.
4. Register a separate test customer and confirm it cannot open the admin dashboard or admin APIs.
5. As your admin email, open **Private admin** and verify user/payment overview loads.
6. Test Paystack in Test Mode and confirm Pro appears only after successful server verification.
7. Submit a test OPay request and approve/reject it from admin.
8. Confirm expiry/downgrade behavior in a test database before launch.

Do not claim production-ready until the tests above pass on your own deployed Supabase, Paystack, and hosting accounts.
