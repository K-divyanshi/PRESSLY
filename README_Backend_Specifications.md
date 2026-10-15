# Pressly Backend Specifications

This folder contains the backend design deliverables for **Pressly — AI-Based Press Note Generation and Official Communication Assistant** (SKIT005).

> These are specifications and a database schema, not a completed Express backend. Applying the SQL creates the database tables and initial template records; it does not implement the HTTP endpoints.

## 1. Deliverables

- **`pressly_schema.sql`** — runnable MySQL 8 schema, foreign keys, indexes, Hindi-compatible `utf8mb4` character set, and the five MVP templates.
- **`Pressly_API_Contract.md`** — endpoint behavior, request/response shapes, authentication, validation, status transitions, error codes, ownership rules, and AI safeguards.
- **`README_Backend_Specifications.md`** — this setup guide and explanation.

## 2. Required software

- Node.js (current supported LTS recommended) for the eventual Express server.
- MySQL Server 8.0 or later.
- MySQL Workbench **or** the MySQL command-line client.
- A code editor such as VS Code.
- Gemini API access for generation. Confirm current model availability and free-tier quota in the Google AI account before choosing the `GEMINI_MODEL`; this document does not promise that any specific model remains free.

The frontend remains HTML, CSS, and vanilla JavaScript. The planned backend is Node.js + Express, database is MySQL, and AI calls use server-side Gemini integration.

## 3. Create a local database

Choose a development database name such as `pressly_db`. In MySQL Workbench, connect to your local MySQL server and run:

```sql
CREATE DATABASE pressly_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
```

The schema file creates tables in the currently selected database. It does **not** create the database itself.

### Option A — MySQL Workbench

1. Open MySQL Workbench and connect to your local MySQL 8 server.
2. Open a new SQL tab and run the `CREATE DATABASE` statement above.
3. Select `pressly_db` as the default schema (or run `USE pressly_db;`).
4. Open `pressly_schema.sql` in Workbench, confirm the selected schema is `pressly_db`, then execute the script.
5. Refresh the Schemas panel. You should see `users`, `press_note_templates`, `press_notes`, `press_note_versions`, and `press_note_status_history`.
6. Run the verification queries below.

### Option B — MySQL command line

From a terminal in the folder containing the SQL file:

```bash
mysql -u root -p -e "CREATE DATABASE pressly_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
mysql -u root -p pressly_db < pressly_schema.sql
```

Replace `root` with your own local MySQL account if needed. Enter the password only at the interactive prompt; do not put it in a command, source file, or screenshot.

### Verify the schema

Run in Workbench or the MySQL client:

```sql
USE pressly_db;
SHOW TABLES;
SELECT template_key, name_en, name_hi, is_active
FROM press_note_templates
ORDER BY sort_order;
SHOW CREATE TABLE press_notes;
```

Expected table names: `users`, `press_note_templates`, `press_notes`, `press_note_versions`, `press_note_status_history`.

**Important:** the schema includes `DROP TABLE IF EXISTS` statements so the file can be reapplied during early development, but reapplying it deletes those tables and their data. Use only on a fresh/throwaway development database unless you have a backup.

## 4. Backend environment variables

The eventual Express implementation should read configuration from environment variables, using a package such as `dotenv` for local development. Example `.env.example` values:

```dotenv
NODE_ENV=development
PORT=3000

DB_HOST=localhost
DB_PORT=3306
DB_NAME=pressly_db
DB_USER=pressly_app
DB_PASSWORD=replace_with_local_database_password

SESSION_SECRET=replace_with_a_long_random_secret
SESSION_COOKIE_NAME=pressly.sid

GEMINI_API_KEY=replace_with_your_existing_key
GEMINI_MODEL=replace_with_a_model_verified_for_your_account
GEMINI_TIMEOUT_MS=30000
GEMINI_MAX_OUTPUT_TOKENS=2048

SESSION_SECURE_COOKIE=false
FRONTEND_ORIGIN=http://localhost:5500
```

These are placeholders, not working credentials. Do not ask anyone to paste the actual Gemini key into chat or documentation. Do not commit `.env`; add it to `.gitignore`. Keep the key in backend environment configuration only. The browser must never receive it.

For production HTTPS, set `SESSION_SECURE_COOKIE=true`, use a strong unique `SESSION_SECRET`, restrict database permissions, and configure the frontend origin explicitly. Do not use the database root account for the app in a deployed environment; create an application user with only the permissions it needs.

The existing Gemini key may already be tested, but model access and free-tier quotas can change. Confirm the configured model and quota before a demo. Keep billing disabled as required by the project plan, and never silently fall back to a paid model.

## 5. How the database maps to the API

| Table | Purpose | Main API use |
|---|---|---|
| `users` | Account identity, password hash, role, active state | register/login/me; note ownership and approval actor |
| `press_note_templates` | Stable template keys and bilingual metadata | list templates; validate generation/save template |
| `press_notes` | Current saved note state and queryable event fields | create/list/get/edit/soft-delete/review |
| `press_note_versions` | Immutable content/source-fact snapshots | save edits, list/get/restore history |
| `press_note_status_history` | Append-only status-transition audit trail | submit, request changes, approve, approval revocation, restore audit |

The SQL uses relational columns for common fields and JSON for variable lists such as participants, speakers, quotes, warnings, and structured content. `utf8mb4` supports Hindi text.

## 6. Rules the backend must enforce

### Authentication and privacy

- Hash passwords on the server with Argon2id or bcrypt; never store plaintext passwords.
- Use server-side sessions with an opaque `HttpOnly` cookie. Rotate the session on login and destroy it on logout. Use `SameSite=Lax`, `Secure=true` over HTTPS, and CSRF tokens for state-changing cookie-authenticated requests.
- Every private note query must check both the note ID and the authenticated owner ID. Return the same `NOTE_NOT_FOUND` response for another user's note and a nonexistent/deleted note.
- Use parameterized SQL; validate route IDs, language, template key, body fields, and lengths.
- Return safe error messages. Never reveal SQL details, stack traces, password hashes, session IDs, or AI credentials.

### Generation and saving

- `POST /api/press-notes/generate` returns an **unsaved candidate**. It must not insert a saved note or version.
- `POST /api/press-notes` saves a user-confirmed candidate as version 1.
- `POST /api/press-notes/:id/revise` returns another **unsaved candidate**. The user must explicitly save it with `PATCH`.
- The event/programme name is required. Unknown dates, participant counts, quotes, and outcomes may remain unknown; the description's 50–60 words are guidance, not a hard block.
- Gemini output is untrusted. Validate its structure, flag missing facts, and require human review. On timeout, quota exhaustion, unavailable model, or malformed output, return a controlled error—never a fake success.

### Versioning and transactions

- Version numbers start at 1 for the first save and increase by 1 for each saved content change or restore.
- Saved version rows are immutable. Do not update or delete them during normal operations.
- Restoring an earlier version copies its snapshot into current state and creates a **new** version with `action_type=restore`; it does not overwrite the old version.
- Use a database transaction and row lock for every operation that updates the current note and inserts a version/status-history record. Roll back all writes if any part fails.
- Status-only changes are recorded in `press_note_status_history`; they do not rewrite historical version rows.

### Review and approval

The source user stories say the MVP may allow an author to approve their own note and also mention a separate approver role as a future possibility. This contract therefore uses owner-only self-approval for the MVP: the owner submits a note for review and may explicitly approve it. It is a practical MVP assumption, not a claim of independent institutional review. Any stricter college policy should replace this before implementation.

Allowed main transitions:
- `draft` → `in_review`
- `changes_requested` → `in_review`
- `in_review` → `changes_requested`
- `in_review` → `approved`
- Content edit or restore of an approved note → `draft` with approval metadata cleared

AI generation or revision never approves a note. Approval records the approver and timestamp. Editing approved content must revoke approval in the same transaction as the new version.

## 7. Templates included

The schema seeds the five template keys listed in the finalized PRD and user stories:

- `general_event`
- `inauguration_launch`
- `workshop_seminar_conference`
- `achievement_award`
- `institutional_announcement`

Templates control structure and tone only; they must not add facts.

## 8. Conditional, stretch, and deferred scope

- **Conditional:** speech-to-text only if a suitable no-cost path is verified. Manual entry must always work.
- **Stretch:** text-to-image and speech-to-speech/live voice; neither blocks the core MVP.
- **Deferred/out of scope:** public share links, email/WhatsApp/social distribution, reminders, automated external publishing, full collaborative editing, and advanced analytics.
- **Basic export:** copy/print can be implemented locally in the frontend; no export-processing service is needed.

## 9. Recommended implementation order

1. Create the database and apply the schema.
2. Set up Express, configuration, and database connection using environment variables.
3. Implement authentication and session/CSRF middleware.
4. Implement template listing and validation.
5. Implement note create/list/get/edit/delete with ownership checks and transactions.
6. Implement immutable version history and restoration.
7. Implement status transitions and audit history.
8. Implement Gemini generation/revision with timeouts, output validation, rate limits, and safe errors.
9. Test Hindi/English, missing facts, malicious optional instructions, cross-user access, version restore, approval revocation, and quota/model failures.
10. Add optional transcription only after a suitable no-cost approach is verified.

## 10. Documentation-only status

At this stage, these deliverables specify the schema and API behavior. They do not include `server.js`, Express routes/controllers, session middleware, database access code, or live Gemini integration. An API endpoint returns real responses only after that implementation exists and is configured.
