# Knexa AI — Production Integration Package

Knexa AI is a mathematics and science learning platform with AI text solving, image/camera solving, practice generation and a timed CBT examination engine.

## Architecture

- Frontend: Vercel (single-page `index.html`)
- Backend: Render (FastAPI `main.py`)
- Primary data store: Upstash Redis REST API
- Text AI: Groq
- Image/camera AI: Gemini
- Payments: Paystack (₦3,500 for exactly 30 days of Pro)

There is no Supabase dependency, SQL schema, email registration, email verification or traditional password registration. `schema.sql` has been replaced by `REDIS_DATA_MODEL.md`.

## Files

- `main.py` — FastAPI backend, preserved tutor/CBT engine, Redis accounts, atomic quotas, Paystack, owner-only admin APIs.
- `index.html` — responsive Knexa frontend, account creation/login/recovery, Pro checkout, student learning and CBT interface.
- `requirements.txt` — Python dependencies.
- `.env.example` — environment variable template.
- `vercel.json` — rewrites `/admin` to the single-page frontend shell.
- `REDIS_DATA_MODEL.md` — Redis key model and atomic Lua operations.
- `REPLIT_SETUP.md` — deployment and configuration checklist.

## Local run

```bash
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

The app requires environment variables. Never put API keys in `index.html`, GitHub, or frontend environment variables.

## Important CBT deployment note

The original CBT exam sessions are held in process memory to preserve the existing exam engine. Use exactly **one Render worker** until exam state is moved to Redis in a separately tested migration. A Render restart can interrupt an in-progress examination; completed user/account/payment data is persisted in Upstash.

## Account security

Knexa creates a unique Knexa ID, random access code and private recovery code automatically. The access code and recovery code are shown once at account creation; the recovery code is stored as a salted PBKDF2 hash and cannot be retrieved. The student must store their credentials securely. A recovery operation resets the access code and rotates the recovery code.

## Owner dashboard bootstrap

1. Deploy the backend and configure Redis and the other secrets.
2. Open the app, create your own Knexa account and securely save its three credentials.
3. Copy the generated Knexa ID.
4. Set `OWNER_KNEXA_ID` in Render to that exact ID and redeploy.
5. Sign in with that owner account and open `/admin`.

All admin APIs independently verify the authenticated Knexa ID against `OWNER_KNEXA_ID`. Hiding the admin link in the browser is not treated as security.

## Payment activation

Configure the Paystack webhook URL as:

`https://YOUR-RENDER-SERVICE.onrender.com/api/payments/paystack/webhook`

Subscribe to `charge.success`. The backend validates the HMAC-SHA512 signature, transaction reference, NGN currency and exact expected amount before atomically activating Pro. A payment reference is idempotent and cannot grant multiple 30-day periods.

Paystack requires a receipt email for transaction initialization. Students may enter an email at checkout; it is used only for Paystack receipts and is not used as a Knexa login or registration identity. If omitted, a non-inbox placeholder address is sent; configure a real receipt email field if Paystack requires it for your account.

## Before production

Run the checklist in `REPLIT_SETUP.md`. Set a stable, random `SECRET_KEY` (at least 32 random bytes), configure CORS to the exact Vercel origin, and test account creation, recovery, quotas, successful/failed webhook events, duplicate webhooks, expiry, and owner access.
