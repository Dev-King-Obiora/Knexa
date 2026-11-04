# Knexa AI — Upstash Redis data model

No SQL database or `schema.sql` is used. Redis is the primary store through the Upstash REST API.

## Key map

| Key | Type / content | Purpose |
|---|---|---|
| `knexa:user:{KNEXA_ID}` | JSON string | Account credential hashes, creation time, subscription pointer and expiry |
| `knexa:login:{KNEXA_ID}` | String | ID lookup index |
| `knexa:users` | Set | Account IDs for owner reporting |
| `knexa:usage:{KNEXA_ID}:{feature}:{YYYY-MM-DD}` | Integer with expiry | Atomic daily quota counter |
| `knexa:payment:{reference}` | JSON string | Paystack transaction intent and verified status |
| `knexa:payments` | Set | Payment references for admin reporting |
| `knexa:user_payments:{KNEXA_ID}` | Set | A student's payment history index |
| `knexa:subscription:{subscription_id}` | JSON string | 30-day subscription record |
| `knexa:subscriptions` | Set | Subscription IDs |
| `knexa:settings` | JSON string | Owner-managed free quotas |
| `knexa:login_attempts:{ip_hash}` | Integer with expiry | Login throttling |

## Atomic operations

1. **Account creation:** a Lua script claims the user document and login index together and adds the ID to the users set. It prevents partial account creation and ID collisions.
2. **Daily quota consumption:** a Lua script checks and increments a daily counter in one operation. Concurrent requests cannot exceed the configured allowance.
3. **Payment fulfilment:** a Lua script locks the payment/user update into one Redis execution, changes the payment to paid, writes the subscription and sets the user's expiry to exactly 2,592,000 seconds after its start. A paid reference returns as a duplicate and cannot grant another subscription.
4. **Owner access:** backend routes verify the signed bearer token and compare its account ID to the server-side `OWNER_KNEXA_ID`.

## Account document

The user JSON contains a salted PBKDF2-HMAC-SHA256 hash of the access code and recovery code. Plaintext credentials are returned only once at creation or recovery and are never stored in Redis.

## Expiry

The subscription expiry is an epoch timestamp. Every authenticated profile and quota check compares it with server time. After 30 days, the user is automatically treated as Free; no scheduled job is required for enforcement. Expired subscription metadata remains available for audit/reporting.

## Operational notes

- Upstash Redis REST credentials must remain server-side in Render.
- Do not enable public Redis access or expose the REST token to the browser.
- Redis data persistence/backup settings should be enabled in the Upstash console.
- Admin scans are bounded and intended for a small-to-medium launch; add cursor pagination for large-scale reporting.
- For multi-worker/multi-instance CBT continuity, migrate exam session objects to Redis before scaling Render beyond one worker.
