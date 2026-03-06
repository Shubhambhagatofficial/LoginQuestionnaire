# LoginQuestionnaireApp

A SwiftUI app with three screens: **Login** → **Questionnaire** → **Break**.

## Architecture

- **AppState** (`AppState.swift`) – Central state: `isLoggedIn` and `currentFlow` (questionnaire vs break). Injected via `@EnvironmentObject`.
- **ContentView** – Root view: shows `LoginView` when not logged in; otherwise shows `QuestionnaireView` or `BreakView` based on `currentFlow`.
- **LoginView** – Login/sign-up screen with username, password, optional referral checkbox, terms links, and Continue button (enabled only when both fields are filled).
- **QuestionnaireView** – Placeholder; ready for your design from upcoming screenshots.
- **BreakView** – Placeholder; ready for your design.

## How to run

1. Open `LoginQuestionnaireApp.xcodeproj` in Xcode.
2. Select a simulator or device (iOS 17+).
3. Press **Run** (⌘R).

## Regenerating the Xcode project

If you add or remove files under `LoginQuestionnaireApp/`, regenerate the project:

```bash
cd LoginQuestionnaireApp && xcodegen generate
```

## Next steps

- Add Questionnaire screen UI from your next screenshots.
- Add Break screen UI when you share its design.
- Replace placeholder Terms/Privacy URLs in `LoginView` with your real links.
- Add real auth (e.g. API call) in `LoginView` instead of `appState.login()`.
