# Pressly — Product Requirements Document (PRD)

**Project:** Pressly — AI-Based Press Note Generation and Official Communication Assistant  
**Problem statement:** SKIT005  
**Status:** Finalized MVP scope  
**Stack:** HTML, CSS, Vanilla JavaScript, Node.js, Express, MySQL, Google Gemini API  
**Languages:** Hindi and English

## 1. Product Overview
Pressly helps authorized users draft formal, factual, neutral press notes from structured event information. It uses Google Gemini through a server-side API integration. Every generated note is a draft until a human reviews and explicitly approves it.

Pressly must not invent missing facts, quotes, names, attendance figures, dates, outcomes, or institutional claims.

## 2. Problem
Preparing official press notes manually can take time and produce inconsistent structure, tone, or language. Pressly streamlines drafting while preserving factual control and human approval.

## 3. Goals
1. Generate structured press-note drafts from user-provided event facts.
2. Support Hindi and English.
3. Provide manual text entry and speech-to-text input if a suitable no-cost implementation is verified.
4. Allow users to review, edit, revise, and save drafts.
5. Maintain version history.
6. Support human review and approval.
7. Offer reusable official communication templates.
8. Keep AI requests and the API key on the backend.
9. Keep the core flow usable without paid API features.

## 4. Explicitly Out of Scope for Core MVP
- Public share links or external publishing.
- Email, WhatsApp, and social-platform distribution.
- In-app reminders, scheduled reminders, and notification systems.
- Automated publishing without human approval.
- Full collaborative editing and advanced analytics.
- Paid-only AI capabilities.
- Text-to-image and speech-to-speech/live voice are stretch features only. They must not block core delivery and must remain disabled unless no-cost access and quota are verified.

## 5. Target Users
- College/institutional public-relations teams.
- Event coordinators and administrative staff.
- Student clubs and societies.
- Authorized users preparing official event communications.

## 6. Core User Flow
1. User registers or signs in.
2. User opens the press-note form.
3. User enters verified event facts manually or uses speech-to-text if enabled.
4. User selects Hindi or English and a template.
5. Backend validates the form and sends relevant facts to Gemini.
6. Gemini returns a structured draft.
7. Backend validates the AI response and flags missing or uncertain facts.
8. User reviews and edits the draft.
9. User may request a revision while preserving the factual constraints.
10. Each saved revision is recorded in version history.
11. User explicitly marks a version as reviewed/approved.
12. User can copy or print the note using basic local export, if included.

## 7. Functional Requirements

### FR-01 — Authentication
- Users can register, sign in, and sign out.
- Passwords are securely hashed server-side.
- Protected endpoints require authentication.
- Users can access only their own notes and versions.

### FR-02 — Event Input
Collect:
- Event/programme name (required).
- Event description, ideally 50–60 words (guidance, not a hard block).
- Date/time and venue, when known.
- Institution/organizer.
- Participant count and categories, if known.
- Key activities and verified outcomes.
- Speaker names/designations and approved quotes, if supplied.
- Official contact person/details, if applicable.
- Output language: Hindi or English.
- Template and optional writing instructions.

Unknown details may remain blank or be explicitly marked unknown. Do not force users to invent information.

### FR-03 — AI Press-Note Generation
- Use a Gemini model available to the project's account and free-tier quota.
- Keep model ID configurable through an environment variable.
- Require a formal, factual, neutral, concise tone.
- Prefer structured output containing headline, opening, body paragraphs, missing-information warnings, and optional contact block.
- Do not invent quotes, names, numbers, dates, awards, outcomes, or affiliations.
- Flag missing facts or use explicit placeholders.
- Every generated note requires human review.

### FR-04 — Bilingual Output
- Generate Hindi or English as explicitly selected.
- Preserve names, titles, dates, numbers, and facts.
- Do not mix languages unless requested.
- Do not overwrite user edits without confirmation.

### FR-05 — Speech-to-Text (Conditional)
- If enabled, let users record/upload speech and transcribe it into editable fields.
- Require the user to review and correct the transcript before generation.
- Verify model availability, endpoint, quotas, browser support, and privacy implications before implementation.
- If no suitable free option is available, disable this feature gracefully; manual text entry must always work.

### FR-06 — Draft Editing and Revision
- Generated content is editable.
- Users can request revisions such as shorter, clearer, or more formal.
- Revision prompts must preserve the supplied facts and forbid invention.
- Save the prior version before storing a new revision.

### FR-07 — Saved Notes and Version History
- Store owner, title/event name, language, template, source facts, generated content, status, and timestamps.
- Store each saved revision with a version number.
- Allow users to reopen and restore prior versions as new versions.
- Enforce ownership in the backend.

### FR-08 — Templates
MVP templates:
- General event press note.
- Inauguration/launch.
- Workshop/seminar/conference.
- Achievement/award announcement.
- Institutional announcement.

Templates change structure and tone only; they must not introduce facts.

### FR-09 — Review and Approval
- Statuses: `draft`, `in_review`, `approved`; `changes_requested` may be included.
- Approval is a deliberate human action, never automatic.
- Record approver and timestamp.
- Editing an approved note must revoke approval or create a new unapproved version.
- No external publishing.

### FR-10 — Optional Text-to-Image (Stretch)
- Enable only if the chosen model is confirmed available within the no-cost quota.
- Label generated assets as AI-generated.
- Never present generated imagery as documentary evidence of a real event or a real person attending.
- Core text generation must work when image generation is unavailable.

### FR-11 — Optional Speech-to-Speech / Live Voice (Stretch)
- Not part of the core MVP.
- Consider only after core drafting, editing, persistence, and approval are stable.
- Verify free-tier access, model support, privacy, and quotas before enabling.

### FR-12 — Basic Export
- Copy-to-clipboard and/or print-friendly browser output may be included.
- Clearly label drafts versus approved notes.
- Direct email/WhatsApp/social sharing and public share links are out of scope.

## 8. Non-Functional Requirements
- **Security:** Never expose the Gemini key in browser code, client JavaScript, source control, or API responses.
- **Privacy:** Minimize personal data; avoid sending sensitive information to AI; disclose AI processing.
- **Factual integrity:** No fabricated facts; explicit missing-data warnings.
- **Reliability:** Handle invalid input, timeouts, model unavailability, and quota errors.
- **Usability:** Responsive, accessible forms and readable Hindi text.
- **Maintainability:** Separate routes, controllers/services, validation, database access, and configuration.
- **Cost control:** Keep the project on the Gemini API Free Tier and do not enable billing. Use request/output limits.
- **Auditability:** Record versions, status changes, and approval events.

## 9. Suggested Architecture
- Frontend: HTML, CSS, Vanilla JavaScript.
- Backend: Node.js + Express.
- Database: MySQL.
- AI: `@google/genai` server-side.
- Authentication: secure session or correctly implemented token-based authentication; use HTTP-only secure cookies where appropriate.
- Configuration: `.env` values such as `GEMINI_API_KEY`, `GEMINI_MODEL`, database credentials, and session secret. Exclude `.env` from Git.

Possible API groups:
- `/api/auth/*`
- `/api/press-notes/*`
- `/api/templates`
- `/api/speech/transcribe` (conditional)
- `/api/health`

Database schema and API contract are separate deliverables to be designed next.

## 10. Suggested AI Output Contract
- `headline`
- `language`
- `dateline`
- `openingParagraph`
- `bodyParagraphs` (array)
- `closingParagraph` (optional)
- `contactBlock` (optional, only when supplied)
- `missingInformation` (array)
- `warnings` (array)
- `requiresHumanReview` (boolean; true for generated drafts)

The backend must parse and validate model output. If parsing fails, retry safely at most once when appropriate or return a clear error. Malformed output must not be saved as approved content.

## 11. Acceptance Criteria
1. Users can register and sign in.
2. Valid event facts produce an English draft.
3. Hindi generation works for the same facts.
4. The agreed test set shows no invented dates, names, numbers, quotes, or outcomes.
5. Users can edit and save drafts.
6. Saving a revision preserves earlier versions.
7. Notes and versions are private to their owner.
8. Approval status and timestamp are recorded.
9. Invalid input and AI errors are handled without exposing secrets.
10. The core flow works without image generation, live voice, sharing, or reminders.
11. The API key never appears in frontend assets or committed files.
12. Core usage stays within the available free-tier quota and billing remains disabled.

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| AI invents facts | Constrained prompt, structured output, warnings, human approval, factual tests |
| Free quota runs out | Clear errors, request/output limits, safe retry policy, sample fallback |
| Model ID changes | Environment-configured model and documented replacement process |
| Hindi changes meaning | Fact-preservation instruction and bilingual review tests |
| API key leaks | Server-only environment variable, `.gitignore`, key rotation |
| Speech/image features unavailable or paid | Keep optional; verify free-tier access before enabling |
| Approved note edited | Revoke approval or create a new unapproved version |

## 13. Final Scope
**MVP:** authentication, event form, English/Hindi drafting, factual safeguards, editing, saved notes, version history, templates, human review/approval, and basic local export.

**Deferred/stretch:** text-to-image, speech-to-speech/live voice, external sharing, public share links, email/WhatsApp integrations, and in-app reminders. Speech-to-text is conditional on a suitable no-cost option; manual text entry is always available.
