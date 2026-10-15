# Pressly — Success Criteria and Test Scenarios

**Problem statement:** SKIT005 — AI-Based Press Note Generation and Official Communication Assistant  
**Status:** Finalized MVP acceptance and test plan

## 1. Definition of Success
Pressly succeeds when an authenticated user can enter verified event facts, generate a formal press-note draft in Hindi or English, edit it, save revisions, and explicitly approve a version—without invented facts or API-key exposure.

The core flow must work while optional speech/image/live-voice features are disabled.

## 2. MVP Success Metrics

| Area | Success criterion |
|---|---|
| Generation | Valid event facts produce a structured draft |
| Language | Hindi and English generation both pass test cases |
| Factual integrity | No invented dates, names, quotes, numbers, affiliations, awards, or outcomes in the agreed test set |
| Missing data | Unknown details are flagged or left as placeholders |
| Editing | User can edit and save a draft |
| Versioning | Saving a revision preserves the prior version |
| Ownership | Users cannot access other users' notes or versions |
| Approval | Approval is explicit and records approver/time |
| Security | API key is absent from frontend assets and client-visible responses |
| Resilience | Validation, network, model, and quota errors are handled safely |
| Cost | Core usage remains within the available free-tier quota; billing is not enabled |
| Scope | Core flow does not depend on image generation, live voice, sharing, or reminders |

## 3. Synthetic Test Data
Use non-confidential sample events:
- Event: College Science Exhibition.
- Description: Students displayed science and engineering projects at a college exhibition.
- Date: Leave blank for missing-data tests; supply a test date for complete-data tests.
- Venue: College campus or a clearly fictional venue.
- Participants: Leave blank unless supplied.
- Outcomes: Student projects were displayed.
- Quotes: None supplied.
- Language: English, then Hindi.

Do not present invented sample details as facts about a real institution.

## 4. Functional Test Scenarios

### TS-01 — Successful registration
**Given** a new user enters valid registration details, **when** they submit, **then** an account is created and no password/hash is returned.

### TS-02 — Duplicate registration
**Given** an account already exists, **when** the same unique identifier is registered, **then** the request is rejected without creating a duplicate.

### TS-03 — Authentication
**Given** valid credentials, **when** the user signs in and requests a protected endpoint, **then** access is granted. Unauthenticated requests are rejected.

### TS-04 — English generation
**Given** valid event facts and English selected, **when** generation is requested, **then** a structured English draft is returned and marked as requiring human review.

### TS-05 — Hindi generation
**Given** the same facts and Hindi selected, **when** generation is requested, **then** output is in Hindi and preserves names, dates, numbers, and facts.

### TS-06 — Missing date
**Given** the date is blank/unknown, **when** generation occurs, **then** no date is invented and missing information is flagged or explicitly left as a placeholder.

### TS-07 — Missing participant count
**Given** no count was supplied, **when** a note is generated, **then** no attendance figure is invented.

### TS-08 — No quote supplied
**Given** no quote was provided, **when** a note is generated, **then** no fabricated quote or attributed statement appears.

### TS-09 — Malicious or conflicting optional instruction
**Given** optional notes request a fabricated quote or attendance figure, **when** generation occurs, **then** factual-integrity rules take precedence and no fact is fabricated.

### TS-10 — Edit and save
**Given** a generated draft, **when** the user edits and saves it, **then** stored content reflects those edits.

### TS-11 — Revision creates new version
**Given** saved version 1, **when** a revision is saved, **then** version 1 remains intact and version 2 is stored with its own timestamp.

### TS-12 — Restore an older version
**Given** multiple versions, **when** an earlier version is restored, **then** it becomes a new version rather than overwriting history.

### TS-13 — Ownership enforcement
**Given** user A owns a note and user B is signed in, **when** B attempts to access A's note, **then** access is denied without revealing note content.

### TS-14 — Approval
**Given** a draft is reviewed, **when** an authorized user explicitly approves it, **then** status, approver, and timestamp are stored. AI generation alone never approves a note.

### TS-15 — Editing after approval
**Given** an approved note, **when** its content changes, **then** approval is revoked or the change creates a new unapproved version.

### TS-16 — Unsupported template
**Given** an unknown template ID, **when** the backend receives it, **then** it rejects the request and does not call Gemini.

### TS-17 — API key secrecy
**Given** the app is inspected in the browser and network tools, **when** requests/responses and client assets are checked, **then** the Gemini API key is not exposed.

### TS-18 — Free-tier quota exhausted
**Given** Gemini returns a quota/rate-limit error, **when** generation is requested, **then** the app displays a useful message, preserves entered facts, avoids endless retries, and does not silently switch to a paid model.

### TS-19 — Model unavailable
**Given** the configured model is invalid/unavailable, **when** generation is requested, **then** a clear service error is returned and no false success is shown.

### TS-20 — Malformed AI output
**Given** Gemini returns output outside the expected JSON contract, **when** backend validation runs, **then** the system retries at most once if appropriate or returns a safe error; malformed output is not approved.

### TS-21 — Basic export
**Given** a saved note, **when** the user copies or prints it, **then** content is legible and draft/approved status is visible. No external message is sent.

### TS-22 — Speech-to-text, if enabled
**Given** a no-cost transcription method is configured, **when** a user records/uploads a sample, **then** a transcript appears for review and is not submitted without confirmation. If disabled, manual entry still works.

## 5. Optional Feature Tests — Not MVP Gates

### TS-23 — Text-to-image (stretch)
Only if free-tier access and quota are confirmed:
- An illustrative image can be generated.
- It is labelled AI-generated.
- It is not presented as documentary proof of the event.
- Image failure does not block note generation.

### TS-24 — Speech-to-speech/live voice (stretch)
Only if no-cost access and quota are confirmed:
- Voice interaction works within supported device/browser constraints.
- User can stop and switch to text.
- Audio-data handling is explained.
- If unavailable, core features remain unaffected.

## 6. Security and Quality Checklist
- [ ] `.env` is excluded from source control.
- [ ] Gemini API key is backend-only.
- [ ] Passwords use an appropriate hashing library.
- [ ] Every protected route enforces authentication and ownership.
- [ ] Inputs are validated and length-limited server-side.
- [ ] AI output is treated as untrusted and safely rendered.
- [ ] Generation is rate-limited with timeout/output limits.
- [ ] Database queries are parameterized.
- [ ] Errors do not disclose secrets, stack traces, or sensitive database details.
- [ ] Quota exhaustion does not trigger paid billing or infinite retries.
- [ ] Approval status is auditable.
- [ ] A notice explains AI processing and human review requirements.

## 7. Demo Acceptance Checklist
1. Register or sign in.
2. Enter sample event facts.
3. Generate an English press note.
4. Generate a Hindi version.
5. Demonstrate that missing date/count/quote details are not invented.
6. Edit and save the draft.
7. Save a second version and reopen the first.
8. Approve a version and show its status.
9. Demonstrate that another user cannot access the note.
10. Demonstrate graceful quota/model error handling.
11. Confirm the API key is stored only in the backend environment.
12. Show the core flow working with image generation, live voice, sharing, and reminders disabled.

## 8. Deferred Features
These are not MVP failures:
- Public share links.
- Direct email, WhatsApp, or social sharing.
- In-app or scheduled reminders.
- Optional text-to-image generation.
- Optional speech-to-speech/live voice.
- Speech-to-text if no suitable no-cost implementation is verified.

## 9. Release Decision
The MVP is ready for demonstration when P0 tests and security checks pass, the bilingual draft-to-approval flow works, and no critical factual-integrity or ownership issue remains. Optional modalities and distribution/reminder features are not release blockers.
