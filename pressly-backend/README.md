# Pressly Backend — Node.js / Express / MySQL / Gemini

Implements the Pressly REST API and its browser frontend integration. The application adds user-managed event categories, profile and password updates, one-time password reset tokens for local development, in-app future event reminders, browser speech dictation/playback, and template presentation variants.

## Requirements
- Node.js 20+ and npm
- MySQL 8+
- Gemini API key and a model available to **your** account (verify free-tier access and keep billing disabled)

## Run locally (Windows PowerShell or VS Code terminal)

1. Create a fresh MySQL database in MySQL Workbench:
   ```sql
   CREATE DATABASE pressly_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
   USE pressly_db;
   ```
2. For a brand-new empty database only, open `schema.sql` in Workbench and execute it. **This setup file drops existing core tables and data. Never run it against a database with data you need.** For an existing Pressly installation, back up the database and execute `feature_migration.sql` if you have not already installed category, reminder, and password-reset tables. V4 image storage is added separately with `image_migration.sql`; it is safe to rerun and does not modify existing notes.
3. Create a MySQL user with permissions on `pressly_db` (or configure a local development user that already has access).
4. Copy `.env.example` to `.env`; enter your local DB credentials, a long random `SESSION_SECRET`, and your own Gemini API key. The example model is `gemini-3.8-flash`; make sure this model is available to your API project. Never upload or commit `.env`.
5. Run:
   ```powershell
   npm install
   npm test
   npm start
   ```
6. Visit `http://localhost:3000/api/health` and `http://localhost:3000/api/templates`.

The browser microphone uses the built-in Web Speech API (Chrome/Edge on localhost or HTTPS). The browser asks for microphone permission the first time. Generated-note playback uses the browser's speech synthesis. Password reset tokens are returned by the API only when `NODE_ENV` is not `production`, for local development. The authenticated Settings screen also supports a current-password-verified password change. Production forgotten-password delivery requires connecting an email delivery service before enabling public reset requests.

The new authenticated endpoints are `/api/categories` (GET/POST), `/api/categories/:id` (PATCH/DELETE), `/api/auth/profile` (PATCH), `/api/auth/password-reset` (authenticated current-password change), `/api/auth/password-reset/request` and `/api/auth/password-reset/confirm` (one-time token flow), and `/api/reminders` (GET/POST) plus `/api/reminders/:id` (PATCH/DELETE). Private category and reminder data is scoped to the signed-in user.

If you are updating an existing installation, preserve the private values in its `.env`, set `GEMINI_MODEL=gemini-3.8-flash`, optionally set `GEMINI_IMAGE_MODEL=gemini-3.1-flash-image` for image generation, and restart the backend. Environment settings are read at startup.

For cross-origin frontend requests, set `FRONTEND_ORIGIN` to your actual frontend origin (for example `http://localhost:5500`), use `credentials: 'include'`, and after register/login or `GET /api/auth/me`, send the returned `csrfToken` in `X-CSRF-Token` for every state-changing authenticated request. Use the same hostname consistently for cookies (`localhost` vs `127.0.0.1`).

### Example authenticated request
```js
const r = await fetch('http://localhost:3000/api/auth/login', {method:'POST',credentials:'include',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'student@example.com',password:'a-strong-password'})});
const {data} = await r.json();
const response = await fetch('http://localhost:3000/api/press-notes/generate',{method:'POST',credentials:'include',headers:{'Content-Type':'application/json','X-CSRF-Token':data.csrfToken},body:JSON.stringify({templateKey:'general_event',language:'en',sourceFacts:{eventName:'College Science Exhibition',eventDescription:'Students displayed engineering projects.'}})});
console.log(await response.json());
```

## Security and design
- Passwords are hashed with bcrypt; sessions are server-side in MySQL with HttpOnly SameSite cookies and CSRF tokens.
- Notes are scoped to the logged-in owner; save/restore/status changes use database transactions and locks.
- Gemini runs only on the server; candidates are **not saved automatically**, and approval requires an explicit review workflow.
- Generated text is not independently fact-verified; human review is essential. Render all text as text content, not HTML.
- Production requires HTTPS, `SESSION_SECURE_COOKIE=true`, a trusted reverse proxy, secret management, and deployment-specific security testing.

## Verification limitations
The frontend and backend JavaScript syntax checks pass, all 11 backend validation tests pass, and the Express app initializes. Database-backed category, profile, password, reminder, and existing note workflows still require a running MySQL instance and the additive migration; browser microphone playback requires a supported browser and microphone permission. A live Gemini request and full database/browser end-to-end run were not available in this environment, so those external integrations are not claimed as verified.
