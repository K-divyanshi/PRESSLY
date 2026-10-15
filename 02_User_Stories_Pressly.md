# Pressly — User Stories and Requirements

**Problem statement:** SKIT005 — AI-Based Press Note Generation and Official Communication Assistant  
**Status:** Finalized MVP scope

## 1. Roles
- **Guest:** can access public landing/authentication screens.
- **Author:** creates, edits, saves, revises, and approves their own notes in the MVP.
- **Approver:** the MVP may allow an authorized author to approve their own note; the design should allow a separate approver role later.
- **System:** validates inputs, calls Gemini, stores versions, and enforces ownership and status rules.

## 2. Epic A — Authentication

### US-01: Register
**As a** new user, **I want** to create an account, **so that** I can save and manage press notes.

**Acceptance criteria**
- Valid registration creates an account with a unique identifier.
- Passwords are securely hashed on the server.
- Duplicate or invalid registration is rejected clearly.
- No password hash or secret is returned.

### US-02: Sign in and sign out
**As a** registered user, **I want** to sign in and sign out, **so that** my notes remain private.

**Acceptance criteria**
- Valid credentials create an authenticated session.
- Invalid credentials return a generic error.
- Protected endpoints reject unauthenticated requests.
- Session/token handling follows the selected secure implementation.

### US-03: Private ownership
**As a** user, **I want** to access only my own notes, **so that** others cannot read or alter my drafts.

**Acceptance criteria**
- Every note has an owner.
- All read/edit/delete/version/approval operations check ownership server-side.
- Guessing another note ID cannot bypass authorization.

## 3. Epic B — Press-Note Creation

### US-04: Enter event facts
**As an** author, **I want** to enter verified event information, **so that** Pressly can draft an accurate note.

**Fields**
- Event/programme name.
- Event description (aim for 50–60 words).
- Date/time and venue, when known.
- Institution/organizer.
- Participant count/categories, if known.
- Key activities and verified outcomes.
- Speaker names/designations and approved quotes, if available.
- Official contact details, if applicable.
- Language, template, and optional writing instructions.

**Acceptance criteria**
- Required fields are marked clearly.
- Unknown information may remain blank or be marked unknown.
- Server-side validation and length limits are applied.
- User can correct facts before generation.

### US-05: Select Hindi or English
**As an** author, **I want** to choose the output language, **so that** the note suits the audience.

**Acceptance criteria**
- Backend accepts only supported language options.
- Output uses the selected language consistently.
- Names, titles, dates, numbers, and facts are preserved.
- Language can be changed in a later revision without changing event facts.

### US-06: Choose a template
**As an** author, **I want** to select a template, **so that** the note follows a suitable official structure.

MVP templates: general event; inauguration/launch; workshop/seminar/conference; achievement/award; institutional announcement.

**Acceptance criteria**
- Template changes structure/tone only.
- Unknown template IDs are rejected.
- Selected template is stored with the note.

### US-07: Generate a draft
**As an** author, **I want** Pressly to generate a draft from my event facts, **so that** I spend less time formatting official communication.

**Acceptance criteria**
- Backend calls the configured Gemini model using a server-side key.
- Output follows the structured response contract.
- Output includes a headline and coherent opening/body.
- AI must not invent quotes, names, numbers, dates, awards, results, or affiliations.
- Missing facts are flagged or represented with explicit placeholders.
- Every generated draft requires human review.
- Quota/network/model errors are shown clearly and safely.
- API key is never sent to the browser.

### US-08: Edit generated text
**As an** author, **I want** to edit the draft, **so that** I can correct details and meet institutional requirements.

**Acceptance criteria**
- Generated text is editable.
- Changes save only through explicit save or a clearly specified autosave.
- New generation cannot silently overwrite user edits.
- AI-generated and user-edited content are distinguishable where practical.

### US-09: Request a revision
**As an** author, **I want** to request changes to tone, length, clarity, or structure, **so that** I can refine a draft.

**Acceptance criteria**
- User can enter revision instructions.
- Revision uses the current draft and saved event facts.
- AI is instructed not to add facts.
- Previous version is preserved.
- Revision remains unapproved until human approval.

## 4. Epic C — Speech-to-Text (Conditional)

### US-10: Dictate event details
**As an** author, **I want** to dictate event details, **so that** I can fill the form by voice.

**Acceptance criteria**
- Feature appears only when a suitable no-cost transcription path is configured.
- Recording/upload status is visible.
- Transcript appears in editable fields.
- User reviews and confirms transcript before generation.
- Browser speech recognition may be a fallback where supported.
- If no suitable free option is available, disable speech input gracefully; manual entry remains available.

## 5. Epic D — Saved Notes and Version History

### US-11: Save a draft
**As an** author, **I want** to save my work, **so that** I can return to it later.

**Acceptance criteria**
- Note stores owner, event/title, language, template, source facts, content, status, and timestamps.
- Saved draft can be reopened.
- Unsaved changes are clearly indicated or handled by a defined autosave.

### US-12: View and restore versions
**As an** author, **I want** to revisit prior versions, **so that** I can compare or recover an earlier draft.

**Acceptance criteria**
- Each saved revision has a version number and timestamp.
- Historical versions remain immutable.
- Restoring an old version creates a new version.
- Only the owner/authorized approver can access history.

## 6. Epic E — Review and Approval

### US-13: Submit for review
**As an** author, **I want** to mark a draft ready for review, **so that** its status is clear.

**Acceptance criteria**
- Status transitions are checked server-side.
- AI generation never marks a note approved.
- Support `draft`, `in_review`, `approved`; `changes_requested` is optional.
- Status timestamps are stored.

### US-14: Approve a note
**As an** authorized reviewer, **I want** to approve a reviewed note, **so that** users can distinguish approved content from drafts.

**Acceptance criteria**
- Approval requires explicit action.
- Approver and timestamp are recorded.
- Editing an approved note revokes approval or creates a new unapproved version.
- No automatic external publishing occurs.

## 7. Epic F — Basic Export

### US-15: Copy or print a note
**As an** author, **I want** to copy or print a note, **so that** I can use it in my official workflow.

**Acceptance criteria**
- Copy-to-clipboard and/or print-friendly output works in supported browsers.
- Export shows draft/approved status.
- No external service is contacted to distribute the note.

## 8. Epic G — Text-to-Image (Stretch)

### US-16: Generate an illustrative image
**As an** author, **I want** an optional supporting image, **so that** I can add a visual asset when appropriate.

**Acceptance criteria**
- Disabled unless model access and free quota are verified.
- Generated asset is labelled AI-generated.
- It is not presented as proof of the real event.
- Failure does not block press-note generation.

## 9. Epic H — Speech-to-Speech / Live Voice (Stretch)

### US-17: Use live voice interaction
**As an** author, **I want** voice-based interaction, **so that** I can dictate details and hear responses conversationally.

**Acceptance criteria**
- Not required for MVP.
- Consider only after core flow is stable.
- Verify free access, model availability, quota, privacy, and browser support first.
- Text input remains available.

## 10. Cross-Cutting Rules
- API key is server-only and stored in an environment variable.
- Do not commit secrets.
- Backend validation is mandatory.
- Treat AI output as untrusted: parse, validate, and safely render it.
- Rate-limit generation and cap input/output length.
- Handle quota, network, model, and validation errors clearly.
- External sharing, public share links, email/WhatsApp distribution, and in-app reminders are not part of the core scope.

## 11. Priority

| Priority | Stories |
|---|---|
| P0 — Must have | US-01 to US-09, US-11 to US-14 |
| P1 — Should have | US-15 |
| Conditional | US-10, only if a suitable free transcription path is verified |
| Stretch | US-16 and US-17 |
