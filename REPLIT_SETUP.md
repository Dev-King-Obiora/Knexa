# Knexa AI deployment setup

## 1. Upstash Redis
1. Create a Redis database in Upstash.
2. Copy the REST URL and REST token.
3. Keep both values private; add them only to Render environment variables.
4. Enable persistence/backups in the Upstash console.

## 2. Render backend
Create a Python Web Service from the Knexa repository.

- Build command: `pip install -r requirements.txt`
- Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT --workers 1`

Add all variables from `.env.example`. Use a newly generated stable `SECRET_KEY`. Add the real Vercel URL to `FRONTEND_ORIGIN` and `PUBLIC_APP_URL`. Add the Render hostname to `ALLOWED_HOSTS`.

## 3. First owner account
1. Deploy the backend.
2. Open the Vercel frontend and select **Create Knexa ID**.
3. Save the displayed Knexa ID, access code and recovery code securely.
4. In Render, set `OWNER_KNEXA_ID` to your Knexa ID exactly.
5. Redeploy Render. Only this account can use `/admin` and the admin APIs.

Do not share your recovery code or access code with anyone.

## 4. Paystack
1. Add your Paystack secret key to Render.
2. In Paystack Dashboard, configure webhook URL:
   `https://YOUR-RENDER-SERVICE.onrender.com/api/payments/paystack/webhook`
3. Subscribe to `charge.success`.
4. Test using Paystack test credentials before switching to live credentials.
5. The backend grants exactly 30 days only after verifying a successful NGN 350,000 kobo transaction.

## 5. Vercel frontend
Deploy `index.html` as the frontend. Before deploying, edit the `meta name="knexa-api"` value near the top of `index.html` and replace `https://YOUR-RENDER-SERVICE.onrender.com` with your real Render backend URL. The browser must call the Render backend over HTTPS.

## 6. Mandatory tests
- Create two student accounts; confirm unique Knexa IDs.
- Sign in and sign out with ID/access code.
- Reset access code with the recovery code; confirm the old code no longer works and the new recovery code is returned once.
- Exhaust each Free daily quota and confirm HTTP 429.
- Confirm Pro has the higher limits.
- Attempt a forged webhook signature; it must fail.
- Verify a real/test Paystack success with wrong amount/currency; it must not activate.
- Send the same valid webhook twice; only one subscription is created.
- Confirm Pro is treated as Free after 30 days.
- Confirm a non-owner account receives HTTP 403 from every `/api/admin/*` endpoint.
- Confirm the owner can open `/admin`.
- Test text solve, image solve, practice generation, CBT generation, answer saving, timer, submit, score and explanations.
- Keep one Render worker until CBT sessions are persisted in Redis.

## 7. Deployment caution
The frontend must point to the Render API and the Render CORS allowlist must contain the exact Vercel origin. Never put Groq, Gemini, Paystack or Upstash secrets in Vercel client-side variables.
