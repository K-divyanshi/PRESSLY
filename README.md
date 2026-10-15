# Pressly — local project

This package contains the Pressly frontend and Node/MySQL backend. Keep your local `.env` private; it is not included in this ZIP.

## Requirements

- Windows 10/11
- Node.js 20 or newer and npm
- MySQL 8 or newer
- VS Code with Live Server (or another local static web server)
- A configured Gemini API key and model access for AI generation
- A current Chrome or Edge browser, microphone permission, and internet access for speech recognition

## Use your existing Pressly database

If you already have a working Pressly backend and database, copy your existing `pressly-backend/.env` into this package's `pressly-backend` folder. Preserve its database, session, frontend-origin, and AI settings. Do not share that file.

The `pressly-backend/schema.sql` file is for a fresh database only: it drops and recreates Pressly tables. **Do not run it against an existing database.** For an existing database, `pressly-backend/feature_migration.sql` is the additive migration for category management, reminders, and password reset. V4 adds optional AI image storage; run `pressly-backend/image_migration.sql` once in MySQL Workbench (it is safe to rerun and does not alter existing notes). Image generation also requires the image model to be enabled for your Gemini API key. Set `GEMINI_IMAGE_MODEL` in your private `.env` if the default model is not available to your account.

From a terminal in `pressly-backend`, run:

```powershell
npm install
npm test
npm start
```

Confirm `http://localhost:3000/api/health` responds successfully. The backend must be running before using the app.

## Start the frontend

Do not open `index.html` as a `file://` URL. In VS Code, right-click `index.html` and select **Open with Live Server**. Use `http://localhost:5500` unless you have updated `FRONTEND_ORIGIN` in your private `.env` to match the exact browser origin. Restart the backend after changing `.env`.

The frontend calls `http://localhost:3000/api`. If the backend address is different, change the `API` constant near the top of `app.js`.

## Included functionality

- Sign in, registration, profile editing, password change and password-reset routes.
- Press-note generation, editing, AI revision, saved drafts, review transitions, history and version restoration.
- Optional event-related AI image generation during candidate creation, with the image saved alongside its press note.
- Category management, varied templates, dark mode, and speech dictation with live captions.
- Listen to generated notes with the browser's speech playback.
- Event reminders with browser notifications and an in-app alert while the signed-in Pressly tab is open. Grant notification permission when adding a timed reminder. Browser notifications are not delivered after Pressly is closed; this package does not include a remote push-notification service.

Speech recognition and speech playback depend on browser support and the selected speech language matching the speaker. In Chrome or Edge, allow microphone access when prompted. The browser's speech-recognition service may also require an internet connection. If recognition is unsupported or microphone access is blocked, Pressly displays an explanatory message. Speech-to-text accuracy depends on the browser, language service, microphone, background noise, and accent; review the live transcript before saving.

Text AI generation requires valid local AI credentials, model access, and available quota. Image generation is optional, makes a separate model request, and requires access to the image model set in `GEMINI_IMAGE_MODEL`. The package does not include API keys or change your selected text model automatically.

## Database and security notes

- Authenticated requests use session cookies and CSRF protection.
- No session ID, password, API key, or database credential is stored in frontend files.
- AI-generated candidates are unsaved until you select **Save Draft** and require human review.
- Contact organization, email, and phone are displayed as separate labeled lines. The missing-information warning cards are hidden while the review requirement remains visible.

## Verification

- Backend tests: 14 passed, 0 failed.
- Frontend JavaScript syntax check passed.
- Database-backed sessions, AI generation, and microphone/notification behavior depend on your local MySQL, AI account, browser permissions, and device; they must be exercised in that configured environment.
