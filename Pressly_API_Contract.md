# Pressly REST API Contract

**Problem statement:** SKIT005 — AI-Based Press Note Generation and Official Communication Assistant  
**Base path:** `/api`  
**Status:** Backend design contract for the finalized MVP; this document does not mean the endpoints have already been implemented.

## 1. Source alignment and decisions

This contract follows the supplied PRD, user stories, and success/test scenarios. It preserves the MVP template set, Hindi/English support, factual-integrity requirements, private ownership, immutable version history, explicit human approval, and optional/disabled modalities.

### Deliberate MVP decisions

1. **Authentication:** server-side sessions using an opaque session ID in an `HttpOnly` cookie. The session store should be MySQL-backed or another persistent server-side store; do not use Express's in-memory session store outside local throwaway development. Cookie settings: `HttpOnly`, `SameSite=Lax`, `Secure=true` in HTTPS production, `Path=/`, and a suitable expiry. For local HTTP development, `Secure=false` only in local configuration. Use CSRF tokens for state-changing requests when cookie sessions are used, and validate `Origin`/`Referer` as a defense-in-depth measure. Rotate the session ID after login; destroy it at logout.
2. **Approval:** the supplied user stories explicitly allow an author to approve their own note in the MVP, while leaving room for a separate approver role later. Accordingly, an owner with an authenticated active account may approve their own note after submitting it for review. An `approver` role may be used by a future separately authorized workflow, but this MVP does not imply organization-wide cross-user access. Ownership still applies to every note operation.
3. **Versions:** only explicit saves create versions. AI generation and revision return unsaved candidates. The frontend must ask the user to confirm saving a candidate. Every content save creates an immutable snapshot. Status-only transitions do not need a new content version; they create an audit-history row associated with the current version.
4. **Editing and approval:** any content/fact/template/language change to an approved note revokes approval and moves it to `draft`; the same transaction clears `approved_by_user_id` and `approved_at`, creates a new version, and records the transition. Restoring a version also creates a new version and leaves the note unapproved.
5. **Missing facts:** unknown details may be blank or explicitly marked unknown. Event/programme name is required; the 50–60-word description is guidance, not a hard validation block.
6. **No invented behavior:** generation must fail safely for invalid templates, AI timeouts, quota exhaustion, unavailable models, or malformed output. No automatic paid-model fallback.

## 2. Common conventions

### 2.1 Authentication and request security

All private endpoints require a valid session. Public endpoints are `GET /api/health`, `GET /api/templates`, and registration/login. Logout requires authentication. For cookie-authenticated state-changing requests, send the CSRF token as `X-CSRF-Token`; `GET /api/auth/me` may include a token issued by the session middleware, or the implementation may expose a small CSRF bootstrap route if needed. Do not put session IDs or secrets in localStorage.

Use HTTPS in deployment. Apply reasonable JSON body limits, input length limits, login/generation rate limits, secure headers, and generic login errors. Passwords must be hashed server-side with Argon2id or bcrypt using a suitable work factor. SQL must be parameterized (or use a safe query builder/ORM). Never return `password_hash`, session identifiers, Gemini credentials, SQL errors, or stack traces.

### 2.2 JSON envelope

Success:
```json
{
  "success": true,
  "data": {},
  "meta": {}
}
```
`meta` is optional and is used for pagination or request metadata. If not needed, it may be omitted.

Error:
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "One or more fields are invalid.",
    "details": [
      { "field": "language", "issue": "Must be 'en' or 'hi'." }
    ],
    "requestId": "server-generated-correlation-id"
  }
}
```
`details` and `requestId` may be omitted when not applicable. Messages are safe for clients; internal logs may include a correlation ID and technical details without exposing secrets.

### 2.3 Common data shapes

**Source facts** (the server validates allowed keys and length limits):
```json
{
  "eventName": "College Science Exhibition",
  "eventDescription": "Students displayed science and engineering projects at a college exhibition.",
  "eventDate": "2026-11-12",
  "eventTime": "10:30:00",
  "timeZone": "Asia/Kolkata",
  "venue": "College campus",
  "institutionName": "Example College",
  "organizer": "Department of Computer Science",
  "participantCount": null,
  "participantCategories": ["students", "faculty"],
  "activities": ["Project displays"],
  "outcomes": ["Student projects were displayed"],
  "speakers": [],
  "approvedQuotes": [],
  "contactInfo": null,
  "additionalInstructions": "Keep the tone formal."
}
```
Example data is synthetic and must not be presented as facts about a real institution. Omit unknown fields or use `null`/empty arrays. Do not use an empty string as a fake fact.

**Structured AI candidate**:
```json
{
  "headline": "College Science Exhibition showcases student projects",
  "language": "en",
  "dateline": null,
  "openingParagraph": "Students displayed science and engineering projects at a college exhibition.",
  "bodyParagraphs": ["The exhibition featured project displays."],
  "closingParagraph": null,
  "contactBlock": null,
  "missingInformation": ["Event date was not supplied."],
  "warnings": [],
  "requiresHumanReview": true
}
```
The exact prose is illustrative only. The backend validates types, selected language, required fields, limits, and `requiresHumanReview === true`. It should check output against supplied facts where feasible, but cannot claim that an AI has independently verified the event.

### 2.4 Identifiers and limits

- `:id`: positive decimal integer representing `press_notes.id`.
- `:versionNumber`: positive integer for an immutable version.
- `language`: exactly `en` or `hi`.
- `templateKey`: one active key returned by `GET /api/templates`.
- Suggested initial limits: full name 120 chars; email 254 chars; password 10–128 chars; event name/title 240 chars; description 5,000 chars; instructions 2,000 chars; revision instructions 1,000 chars; generated headline 300 chars; body paragraph count 1–12; body paragraph 4,000 chars each; page size 1–50. Enforce request/output token limits based on the configured model/quota.
- Dates use `YYYY-MM-DD`; times use `HH:mm:ss`; timezone should be an IANA timezone identifier when supplied.
- Return `404 NOTE_NOT_FOUND` for a note not owned by the current user as well as a nonexistent/deleted note, to avoid revealing its existence.

## 3. Endpoint index

| Group | Method and path | Auth |
|---|---|---|
| Health | `GET /api/health` | No |
| Templates | `GET /api/templates` | No |
| Auth | `POST /api/auth/register` | No |
| Auth | `POST /api/auth/login` | No |
| Auth | `POST /api/auth/logout` | Yes |
| Auth | `GET /api/auth/me` | Yes |
| Generation | `POST /api/press-notes/generate` | Yes |
| Notes | `POST /api/press-notes` | Yes |
| Notes | `GET /api/press-notes` | Yes |
| Notes | `GET /api/press-notes/:id` | Yes |
| Notes | `PATCH /api/press-notes/:id` | Yes |
| Notes | `DELETE /api/press-notes/:id` | Yes |
| Revision | `POST /api/press-notes/:id/revise` | Yes |
| Versions | `GET /api/press-notes/:id/versions` | Yes |
| Versions | `GET /api/press-notes/:id/versions/:versionNumber` | Yes |
| Versions | `POST /api/press-notes/:id/versions/:versionNumber/restore` | Yes |
| Review | `POST /api/press-notes/:id/submit-review` | Yes |
| Review | `POST /api/press-notes/:id/request-changes` | Yes |
| Review | `POST /api/press-notes/:id/approve` | Yes |
| Optional | `POST /api/speech/transcribe` | Conditional |

## 4. Health and templates

### `GET /api/health`

- **Auth:** none.
- **Purpose:** basic liveness check only. Do not disclose environment variables, model ID, database host, API key status, or infrastructure details.
- **Success `200`:**
```json
{ "success": true, "data": { "status": "ok" } }
```
- **Errors:** `503 SERVICE_UNAVAILABLE` if the application cannot serve requests.
- This endpoint does not promise that Gemini quota is available.

### `GET /api/templates`

- **Auth:** none.
- **Purpose:** return active reusable template metadata.
- **Success `200`:**
```json
{
  "success": true,
  "data": {
    "templates": [
      {
        "templateKey": "general_event",
        "name": { "en": "General Event", "hi": "सामान्य कार्यक्रम" },
        "description": {
          "en": "General institutional event or programme press note.",
          "hi": "सामान्य संस्थागत कार्यक्रम के लिए प्रेस नोट।"
        }
      }
    ]
  }
}
```
- **Validation:** only active templates are returned; metadata comes from `press_note_templates`.
- **Errors:** `500 INTERNAL_ERROR` for a safe generic server failure.
- **Database mapping:** `press_note_templates`.

## 5. Authentication

### `POST /api/auth/register`

- **Auth:** none.
- **Purpose:** create an account and establish a session.
- **Request:**
```json
{ "fullName": "Asha Sharma", "email": "asha@example.test", "password": "replace-with-a-strong-password" }
```
- **Validation:** trimmed full name 2–120 chars; syntactically valid email, normalized consistently (trim and lowercase); password 10–128 chars. Do not silently trim or alter password characters. Rate-limit registration.
- **Behavior:** hash password using Argon2id or bcrypt; insert user with role `author`; create/rotate session. Never return the hash.
- **Success `201`:**
```json
{ "success": true, "data": { "user": { "id": 12, "fullName": "Asha Sharma", "email": "asha@example.test", "role": "author" } } }
```
- **Errors:** `400 VALIDATION_ERROR`; `409 EMAIL_ALREADY_REGISTERED`; `429 RATE_LIMITED`; `500 INTERNAL_ERROR`.
- **Database mapping:** `users`.

### `POST /api/auth/login`

- **Auth:** none.
- **Request:**
```json
{ "email": "asha@example.test", "password": "replace-with-a-strong-password" }
```
- **Behavior:** compare against stored hash; rotate session ID after success; update `last_login_at`.
- **Success `200`:** same public `user` shape as registration.
- **Errors:** `400 VALIDATION_ERROR`; `401 INVALID_CREDENTIALS` with the same generic message for unknown email and wrong password; `403 ACCOUNT_INACTIVE`; `429 RATE_LIMITED`.
- Do not reveal whether a particular email is registered in login errors.

### `POST /api/auth/logout`

- **Auth:** yes; CSRF protection required.
- **Request:** no body.
- **Behavior:** destroy server-side session and expire cookie.
- **Success `200`:** `{ "success": true, "data": { "loggedOut": true } }`.
- **Errors:** `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `500 INTERNAL_ERROR`.

### `GET /api/auth/me`

- **Auth:** yes.
- **Success `200`:**
```json
{ "success": true, "data": { "user": { "id": 12, "fullName": "Asha Sharma", "email": "asha@example.test", "role": "author" } } }
```
- **Errors:** `401 UNAUTHENTICATED`; `403 ACCOUNT_INACTIVE`.
- Never return `password_hash`, cookie/session IDs, or secrets.

## 6. Generate and save press notes

### `POST /api/press-notes/generate`

- **Auth:** yes; apply per-user rate limits and request/output caps.
- **Purpose:** create an **unsaved** AI draft candidate. It does not create a `press_notes` row or a version.
- **Request:**
```json
{
  "templateKey": "general_event",
  "language": "en",
  "sourceFacts": {
    "eventName": "College Science Exhibition",
    "eventDescription": "Students displayed science and engineering projects at a college exhibition.",
    "eventDate": null,
    "venue": "College campus",
    "participantCount": null,
    "outcomes": ["Student projects were displayed"],
    "approvedQuotes": [],
    "additionalInstructions": "Use a concise formal tone."
  }
}
```
- **Validation:** required active template; language `en` or `hi`; `sourceFacts.eventName` required (trimmed, 1–240 chars); validate all known fields and nested structures; allow unknown date/count/quotes to remain absent; description length guidance 50–60 words is not a hard block. If template key is invalid, reject before calling Gemini.
- **Behavior:** backend sends only relevant validated facts and a factual-integrity instruction to Gemini using server-only `GEMINI_API_KEY` and configured `GEMINI_MODEL`. Parse/validate structured output. Retry malformed output at most once if safe and useful; otherwise return error. Every candidate has `requiresHumanReview: true`. Never silently switch to a paid model.
- **Success `200`:**
```json
{
  "success": true,
  "data": {
    "candidate": {
      "headline": "College Science Exhibition showcases student projects",
      "language": "en",
      "dateline": null,
      "openingParagraph": "Students displayed science and engineering projects at a college exhibition.",
      "bodyParagraphs": ["The exhibition featured project displays."],
      "closingParagraph": null,
      "contactBlock": null,
      "missingInformation": ["Event date was not supplied.", "Participant count was not supplied."],
      "warnings": [],
      "requiresHumanReview": true
    },
    "saved": false
  }
}
```
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `404 TEMPLATE_NOT_FOUND`; `429 RATE_LIMITED`; `429 AI_QUOTA_EXCEEDED`; `502 AI_SERVICE_UNAVAILABLE` for upstream timeout/network/model errors; `502 AI_INVALID_RESPONSE` for unusable malformed output; `500 INTERNAL_ERROR`.
- **Privacy:** avoid sending unnecessary sensitive personal data to Gemini. Tell users their supplied facts are processed by the configured AI service.
- **Database mapping:** read `press_note_templates`; no note/version write.

### `POST /api/press-notes`

- **Auth:** yes.
- **Purpose:** explicitly save a user-confirmed candidate as a new note and version 1.
- **Request:**
```json
{
  "templateKey": "general_event",
  "title": "College Science Exhibition",
  "language": "en",
  "sourceFacts": { "eventName": "College Science Exhibition", "eventDescription": "Student projects were displayed." },
  "content": {
    "headline": "College Science Exhibition showcases student projects",
    "language": "en",
    "dateline": null,
    "openingParagraph": "Students displayed science and engineering projects at a college exhibition.",
    "bodyParagraphs": ["The exhibition featured project displays."],
    "closingParagraph": null,
    "contactBlock": null,
    "missingInformation": ["Event date was not supplied."],
    "warnings": [],
    "requiresHumanReview": true
  },
  "changeSummary": "Initial saved draft"
}
```
- **Validation:** active template key, supported language, required title/event name, source facts and structured content schema. Require `requiresHumanReview: true` for generated candidates; the server, not the client, determines initial status `draft`. Never accept client-supplied approval metadata or status as authoritative.
- **Behavior:** in one transaction, insert `press_notes` with status `draft`, `current_version_number=1`, no approval metadata; insert `press_note_versions` version 1 with `action_type=initial_save`; insert status history with action `created`, previous status `NULL`, new status `draft`, version 1. Only save content explicitly submitted after user confirmation.
- **Success `201`:** `{ "success": true, "data": { "note": { "id": 101, "title": "College Science Exhibition", "language": "en", "status": "draft", "currentVersionNumber": 1, "approvedAt": null, "createdAt": "2026-11-12T10:30:00.000Z" } } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `404 TEMPLATE_NOT_FOUND`; `409 SAVE_CONFLICT` where applicable; `500 INTERNAL_ERROR`.
- **Database mapping:** `press_notes`, `press_note_versions`, `press_note_status_history`, `press_note_templates`.

### `GET /api/press-notes`

- **Auth:** yes.
- **Purpose:** list the current user's non-deleted notes.
- **Query:** `page` default `1`; `pageSize` default `10`, range `1–50`; optional `status` from the four defined statuses; optional `language` `en|hi`; optional `q` search over title/event name (length cap 100).
- **Success `200`:**
```json
{
  "success": true,
  "data": {
    "notes": [
      { "id": 101, "title": "College Science Exhibition", "language": "en", "status": "draft", "currentVersionNumber": 2, "updatedAt": "2026-11-12T11:00:00.000Z" }
    ]
  },
  "meta": { "page": 1, "pageSize": 10, "totalItems": 1, "totalPages": 1 }
}
```
- **Security:** every query includes `owner_user_id = currentUser.id AND deleted_at IS NULL`; parameterize search/filter values.
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `500 INTERNAL_ERROR`.

### `GET /api/press-notes/:id`

- **Auth:** yes; owner only.
- **Success `200`:** returns note fields, structured `sourceFacts`, structured `content`, warnings, missing information, current version number, approval metadata, and timestamps. Never return password/session/AI secrets.
- **Errors:** `400 INVALID_ID`; `401 UNAUTHENTICATED`; `404 NOTE_NOT_FOUND`; `500 INTERNAL_ERROR`.
- **Database mapping:** `press_notes`, with optional current version lookup.

### `PATCH /api/press-notes/:id`

- **Auth:** yes; owner only; CSRF protection required.
- **Purpose:** explicitly save user edits. Partial updates are permitted for documented editable fields only: `title`, `language`, `templateKey`, `sourceFacts`, `content`, and `changeSummary`.
- **Request example:**
```json
{
  "title": "Updated Science Exhibition Note",
  "sourceFacts": { "eventName": "College Science Exhibition", "eventDescription": "Updated factual description." },
  "content": {
    "headline": "College Science Exhibition",
    "language": "en",
    "dateline": null,
    "openingParagraph": "Updated opening based on the supplied facts.",
    "bodyParagraphs": ["Updated body."],
    "closingParagraph": null,
    "contactBlock": null,
    "missingInformation": [],
    "warnings": [],
    "requiresHumanReview": true
  },
  "changeSummary": "Corrected wording"
}
```
- **Validation:** reject unknown fields, invalid language/template, oversized content, invalid JSON structures, and stale `currentVersionNumber` if supplied. Recommend optimistic concurrency: client sends `expectedVersionNumber`; server returns `409 VERSION_CONFLICT` if current version differs.
- **Behavior:** lock note row and check owner/deleted status in a transaction. For a content/fact/template/language change, insert the next immutable version, update current fields/current version, and record status history if status changes. If current status was `approved`, revoke approval and set `draft`, clear approval metadata, set review required, and record `approval_revoked`. If unchanged content, return current note without creating a version.
- **Success `200`:** `{ "success": true, "data": { "note": { "id": 101, "status": "draft", "currentVersionNumber": 3, "approvedAt": null } } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND` or `TEMPLATE_NOT_FOUND`; `409 VERSION_CONFLICT`; `422 INVALID_CONTENT`; `500 INTERNAL_ERROR`.

### `DELETE /api/press-notes/:id`

- **Auth:** yes; owner only; CSRF protection required.
- **Behavior:** soft-delete by setting `deleted_at`; do not delete versions/history. This is a terminal user action for the MVP; deleted notes disappear from list/get/revise/review/version endpoints. No restore-from-trash endpoint is included.
- **Success `200`:** `{ "success": true, "data": { "deleted": true } }`
- **Errors:** `400 INVALID_ID`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND`; `500 INTERNAL_ERROR`.
- **Database mapping:** update `press_notes.deleted_at`; preserve child rows.

## 7. AI-assisted revision

### `POST /api/press-notes/:id/revise`

- **Auth:** yes; owner only; generation rate limits apply.
- **Purpose:** return an **unsaved revision candidate** based on current saved source facts/content. It does not overwrite the note or create a version.
- **Request:**
```json
{
  "instructions": "Make the note shorter and clearer without changing any facts.",
  "language": "en"
}
```
- **Validation:** instructions required, 1–1,000 chars; language optional but if supplied must be `en` or `hi`; note must be non-deleted and owned by current user. The backend uses the current saved facts and content. It must preserve names, dates, numbers, quotes, and outcomes and must not add unsupported facts.
- **Success `200`:** `{ "success": true, "data": { "candidate": { "headline": "Revised headline", "language": "en", "dateline": null, "openingParagraph": "Revised opening.", "bodyParagraphs": ["Revised body."], "closingParagraph": null, "contactBlock": null, "missingInformation": [], "warnings": [], "requiresHumanReview": true }, "saved": false, "basedOnVersionNumber": 2 } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `404 NOTE_NOT_FOUND`; `429 RATE_LIMITED`; `429 AI_QUOTA_EXCEEDED`; `502 AI_SERVICE_UNAVAILABLE`; `502 AI_INVALID_RESPONSE`; `500 INTERNAL_ERROR`.
- **Saving:** user must review candidate and explicitly call `PATCH /api/press-notes/:id` with the chosen content. The save creates the next version. Revision itself never approves.

## 8. Version history

### `GET /api/press-notes/:id/versions`

- **Auth:** yes; note owner only.
- **Query:** `page` default `1`; `pageSize` default `20`, range `1–50`.
- **Success `200`:** list version number, action type, creator's public identity (id/name only), change summary, status snapshot, restore source if any, and timestamp. Do not expose another user's notes or version data.
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `404 NOTE_NOT_FOUND`; `500 INTERNAL_ERROR`.

### `GET /api/press-notes/:id/versions/:versionNumber`

- **Auth:** yes; owner only.
- **Success `200`:** immutable snapshot including title, language, template key/metadata, source facts, content, warnings, missing-information list, status snapshot, creator, change summary, timestamp.
- **Errors:** `400 INVALID_ID` or `INVALID_VERSION_NUMBER`; `401 UNAUTHENTICATED`; `404 NOTE_NOT_FOUND` or `VERSION_NOT_FOUND`; `500 INTERNAL_ERROR`.

### `POST /api/press-notes/:id/versions/:versionNumber/restore`

- **Auth:** yes; owner only; CSRF protection required.
- **Request:** `{ "changeSummary": "Restored earlier wording", "expectedVersionNumber": 3 }`
- **Behavior:** in one transaction, lock the note; validate ownership, active note, source version, and optional expected version; copy the selected historical title/language/template/facts/content into current fields; assign `current_version_number + 1`; insert a new version with `action_type=restore` and `restored_from_version_number` equal to the selected historical version; set status to `draft`, `requires_human_review=true`, clear approval metadata, and append status history if status changed (or an audit event indicating restore if the status was already draft). Never update/delete the selected historical row.
- **Success `201`:** `{ "success": true, "data": { "noteId": 101, "restoredFromVersionNumber": 1, "currentVersionNumber": 4, "status": "draft" } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND` or `VERSION_NOT_FOUND`; `409 VERSION_CONFLICT`; `500 INTERNAL_ERROR`.

## 9. Review and approval workflow

### State transitions

| Current status | Action | New status | Allowed actor |
|---|---|---|---|
| `draft` | submit review | `in_review` | Owner |
| `changes_requested` | submit review | `in_review` | Owner |
| `in_review` | request changes | `changes_requested` | Owner in MVP |
| `in_review` | approve | `approved` | Owner in MVP |
| `approved` | content edit or restore | `draft` | Owner |
| `draft` | content edit | `draft` | Owner |
| `changes_requested` | content edit | `changes_requested` until resubmitted | Owner |

The owner-only request-changes/approve policy reflects the supplied MVP user stories that authors can manage and approve their own notes. It is a pragmatic student-MVP assumption, not a claim of independent institutional review. If the college requires separation of duties, add an explicit authorized reviewer workflow before implementation; do not simply let any authenticated user approve any note. An `approver` role alone does not grant cross-owner access under this contract.

All transitions are server-validated, transactional, and written to `press_note_status_history`. AI generation and AI revision cannot change status to `approved`.

### `POST /api/press-notes/:id/submit-review`

- **Auth:** yes; owner only; CSRF protection required.
- **Allowed current status:** `draft` or `changes_requested`.
- **Request:** `{ "comment": "Ready for review", "expectedVersionNumber": 3 }` (comment optional; max 1,000 chars).
- **Behavior:** set `in_review`; approval metadata must be null; insert status history with action `submitted_for_review` and current version.
- **Success `200`:** `{ "success": true, "data": { "id": 101, "status": "in_review", "currentVersionNumber": 3 } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND`; `409 INVALID_STATUS_TRANSITION` or `VERSION_CONFLICT`; `500 INTERNAL_ERROR`.

### `POST /api/press-notes/:id/request-changes`

- **Auth:** yes; owner only in the MVP; CSRF protection required.
- **Allowed current status:** `in_review`.
- **Request:** `{ "comment": "Please confirm the venue before approval.", "expectedVersionNumber": 3 }`
- **Validation:** comment required, 1–1,000 chars.
- **Behavior:** set `changes_requested`, clear approval metadata, insert status-history row with action `changes_requested` and comment.
- **Success `200`:** `{ "success": true, "data": { "id": 101, "status": "changes_requested" } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND`; `409 INVALID_STATUS_TRANSITION` or `VERSION_CONFLICT`; `500 INTERNAL_ERROR`.

### `POST /api/press-notes/:id/approve`

- **Auth:** yes; owner only in MVP; CSRF protection required.
- **Allowed current status:** `in_review` only.
- **Request:** `{ "comment": "Reviewed against supplied event facts.", "expectedVersionNumber": 3 }` (comment optional, max 1,000 chars).
- **Behavior:** require deliberate human request. Set status `approved`, `approved_by_user_id=currentUser.id`, `approved_at=UTC timestamp`, `requires_human_review=false`; insert status-history row with action `approved`. Approval is for the current saved version only. Any subsequent content edit/restore revokes it.
- **Success `200`:**
```json
{
  "success": true,
  "data": {
    "id": 101,
    "status": "approved",
    "currentVersionNumber": 3,
    "approvedBy": { "id": 12, "fullName": "Asha Sharma" },
    "approvedAt": "2026-11-12T12:00:00.000Z"
  }
}
```
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `403 CSRF_INVALID`; `404 NOTE_NOT_FOUND`; `409 INVALID_STATUS_TRANSITION` or `VERSION_CONFLICT`; `500 INTERNAL_ERROR`.

**Important schema note:** `press_note_versions.status_snapshot` captures the status at snapshot creation. Status-only changes are audited in `press_note_status_history`; they do not rewrite immutable snapshots. Approval metadata on the current note refers to the current version only.

## 10. Conditional speech-to-text (not a required MVP endpoint)

### `POST /api/speech/transcribe` — disabled unless a suitable no-cost path is verified

- **Auth:** yes; CSRF protection required for uploads.
- **Status:** conditional, not a release blocker. Do not implement until provider cost/quota, privacy, endpoint support, and browser/device behavior are checked. Manual text entry must always work.
- **Request:** multipart form field `audio`; enforce strict upload size/type/duration limits. Do not store uploaded audio by default.
- **Success `200`:** `{ "success": true, "data": { "transcript": "Editable transcript text", "requiresUserConfirmation": true } }`
- **Errors:** `400 VALIDATION_ERROR`; `401 UNAUTHENTICATED`; `413 AUDIO_TOO_LARGE`; `422 TRANSCRIPTION_UNAVAILABLE`; `502 TRANSCRIPTION_SERVICE_ERROR`.
- The transcript is only a suggestion; the user must review/correct it before generation. If disabled, return a controlled `422 TRANSCRIPTION_UNAVAILABLE` and keep manual fields usable.

## 11. Error code catalogue

| HTTP | Code | Meaning |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Missing, invalid, unknown, or oversized request fields |
| 400 | `INVALID_ID` / `INVALID_VERSION_NUMBER` | Invalid route identifier |
| 401 | `UNAUTHENTICATED` | No valid session |
| 401 | `INVALID_CREDENTIALS` | Generic login failure |
| 403 | `FORBIDDEN` / `CSRF_INVALID` / `ACCOUNT_INACTIVE` | Authenticated but action/session/account is not permitted |
| 404 | `NOTE_NOT_FOUND` | Note missing, deleted, or not owned by current user |
| 404 | `VERSION_NOT_FOUND` | Version does not belong to the note or does not exist |
| 404 | `TEMPLATE_NOT_FOUND` | Template key unknown or inactive |
| 409 | `EMAIL_ALREADY_REGISTERED` | Email unique constraint conflict |
| 409 | `VERSION_CONFLICT` | Current version changed since client read it |
| 409 | `INVALID_STATUS_TRANSITION` | Requested workflow transition is not allowed |
| 422 | `INVALID_CONTENT` | Candidate content does not meet the structured content contract |
| 422 | `TRANSCRIPTION_UNAVAILABLE` | Optional transcription is disabled |
| 429 | `RATE_LIMITED` | Application request limit reached |
| 429 | `AI_QUOTA_EXCEEDED` | Gemini free-tier quota/rate limit reached |
| 502 | `AI_SERVICE_UNAVAILABLE` | Gemini timeout, network failure, or model unavailable |
| 502 | `AI_INVALID_RESPONSE` | Gemini returned unusable or malformed output |
| 500 | `INTERNAL_ERROR` | Unexpected safe-to-report server error |
| 503 | `SERVICE_UNAVAILABLE` | Application cannot serve the request |

Do not reveal provider internals to clients. Internally log a request/correlation ID, sanitized provider error category, and timing; never log credentials or full sensitive event content unnecessarily.

## 12. Database mapping and transactional requirements

| API behavior | Tables |
|---|---|
| Register/login/me | `users` + server-side session store |
| Template listing/validation | `press_note_templates` |
| Generate unsaved candidate | `press_note_templates`; no note write |
| Save first draft | `press_notes`, `press_note_versions`, `press_note_status_history` |
| List/get/edit/delete note | `press_notes` |
| Save edit or AI revision candidate | `press_notes`, `press_note_versions`; status history when transition occurs |
| List/get/restore versions | `press_notes`, `press_note_versions`, status history when needed |
| Submit/request/approve | `press_notes`, `press_note_status_history` |

Use a transaction and row lock for any operation that changes current note state and/or creates a version or status-history row. A recommended save sequence is: begin; select the note by `(id, owner_user_id)` `FOR UPDATE`; validate expected version and state; update current row; insert version row with the next number; insert status history if status changed; commit. Roll back on any failure. Never delete version/history rows during ordinary note deletion.

## 13. Operational and AI safeguards

- Use `GEMINI_API_KEY` only on the backend. Use `GEMINI_MODEL` as a configurable model ID and verify current model availability and free-tier terms in the actual Google AI account before demo. This contract makes no guarantee that a particular model is currently free.
- Keep billing disabled as required by the project plan. Enforce request/output caps, timeouts, and per-user limits. Do not switch models or providers automatically to a paid option.
- On timeout/network/model errors, return `502 AI_SERVICE_UNAVAILABLE`; on quota/rate errors, return `429 AI_QUOTA_EXCEEDED`; on malformed output, retry at most once if safe, then return `502 AI_INVALID_RESPONSE`.
- Do not return fabricated success or save malformed output. Preserve the user's input in the frontend when an error occurs.
- Treat model output as untrusted. Validate JSON structure and field lengths, safely render text (never inject AI output as raw HTML), and show missing-information warnings.
- Require a human to review every generated/revised candidate. Only `/approve` after a permitted transition can approve a saved version.
- Do not send unnecessary sensitive personal information to Gemini. Inform users that AI processing is used.

## 14. Features outside the core API contract

- **Conditional:** speech-to-text, only after a suitable no-cost implementation is verified.
- **Stretch:** text-to-image and speech-to-speech/live voice; not MVP endpoints.
- **Deferred/out of scope:** public share links, email/WhatsApp/social distribution, in-app reminders, automated external publishing, full collaborative editing, advanced analytics.
- **Basic export:** copy and browser print can be implemented locally in the frontend; no export service is needed.
