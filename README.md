# KingMath-AI

FastAPI + single-page frontend for the KingMath mathematics/science tutor, image solver and CBT practice system, extended with Supabase accounts, daily plan limits, monthly Pro subscriptions, Paystack verification, manual OPay review and a private admin dashboard.

## Quick start

1. Install: `pip install -r requirements.txt`
2. Run: `uvicorn main:app --host 0.0.0.0 --port 8000`
3. Open the Replit web preview.
4. Configure Replit Secrets and run `schema.sql` in Supabase SQL Editor before testing account/payment features.

See [REPLIT_SETUP.md](REPLIT_SETUP.md) for the exact setup steps. No `.env` file is included or required; all credentials belong in Replit Secrets / hosting environment variables.

## Files

- `main.py` — original FastAPI AI/CBT backend plus account, quota, subscription, payment and admin APIs.
- `index.html` — original frontend plus account, checkout and private admin interfaces.
- `schema.sql` — Supabase tables, indexes, secure quota/payment RPCs and profile trigger.
- `requirements.txt` — Python dependencies.
- `.replit` — Replit run command.

Active CBT exam sessions remain in process memory as in the original implementation; a server restart can interrupt a running exam. Subscription and payment records are stored in Supabase.
