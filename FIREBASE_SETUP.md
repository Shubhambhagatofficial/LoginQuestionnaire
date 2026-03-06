# Firebase setup for questionnaire

Follow these steps so the app can load questionnaire questions from your Firebase project.

## 1. Create / use a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/).
2. Use your existing empty project or create a new one.

## 2. Add an iOS app to the project

1. In the project overview, click **Add app** and choose **iOS**.
2. Use this **iOS bundle ID**: `com.example.LoginQuestionnaireApp`  
   (It must match the app’s **Bundle Identifier** in Xcode: **Signing & Capabilities**.)
3. App nickname and App Store ID are optional. Click **Register app**.

## 3. Download and add `GoogleService-Info.plist`

1. Download **GoogleService-Info.plist** from the Firebase setup step.
2. In Xcode, drag `GoogleService-Info.plist` into the **LoginQuestionnaireApp** group (same level as `ContentView.swift`).
3. When asked, enable **Copy items if needed** and add to the **LoginQuestionnaireApp** target.

Without this file, the app will crash at launch when it calls `FirebaseApp.configure()`.

## 4. Enable Firestore

1. In the Firebase Console left sidebar, go to **Build → Firestore Database**.
2. Click **Create database**.
3. Choose **Start in test mode** (for development). Set proper security rules before production.
4. Pick a Firestore location and confirm.

## 4b. Fix "Missing or insufficient permissions"

If the app shows **Missing or insufficient permissions** when loading the questionnaire, update your Firestore rules so the app can read data:

1. In Firebase Console go to **Build → Firestore Database**.
2. Open the **Rules** tab.
3. Replace the rules with one of the options below, then click **Publish**.

**Option A – Allow read for questionnaire data (recommended for dev):**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /questionnaires/{docId} {
      allow read: if true;
      allow write: if false;
    }
    match /sections/{docId} {
      allow read: if true;
      allow write: if false;
    }
    match /sectionOptions/{docId} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

**Option B – Allow all reads (only for local/testing):**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

After publishing, run the app again; the permission error should be gone. For production, restrict `read` (e.g. `allow read: if request.auth != null;`) and avoid leaving `write` open.

## 5. Create the questionnaire document

The app reads from a Firestore document that describes one questionnaire screen (e.g. the “Skills” screen).

- **Collection ID:** `questionnaires`
- **Document ID:** `skills` (this is the screen the app loads by default)

### Option A: Using the Firebase Console UI

1. Go to **Firestore Database**.
2. Click **Start collection**.
3. **Collection ID:** `questionnaires` → **Next**.
4. **Document ID:** `skills` → **Next**.
5. Add the fields below (you can add fields one by one; for `sections`, use type **map** and add the first section, then add more array elements or use **Import** if available).

### Option B: Using the structure below

Create a document at `questionnaires/skills` with this structure. You can paste the JSON in the Firestore **Import** flow if your project supports it, or recreate the fields manually.

**Document path:** `questionnaires` / `skills`

| Field      | Type   | Value |
|-----------|--------|--------|
| `title`   | string | `Skills` |
| `subtitle`| string | `Tell us a bit more about yourself` |
| `sections`| array  | (see below) |

**sections** (array of maps):

**Section 1 – Checkbox**

| Field               | Type    | Value |
|---------------------|---------|--------|
| `type`              | string  | `checkbox` |
| `question`           | string  | `How many of these tasks have you done before? (select all that apply)` |
| `options`            | array   | `["Cutting vegetables", "Sweeping", "Mopping", "Cleaning bathrooms", "Laundry", "Washing dishes"]` |
| `hasNoneOfTheAbove`  | boolean | `true` |
| `required`           | boolean | `false` |

**Section 2 – Radio**

| Field      | Type    | Value |
|-----------|---------|--------|
| `type`    | string  | `radio` |
| `question`| string  | `Do you have your own smartphone?` |
| `options` | array   | `["Yes", "No"]` |
| `required`| boolean | `true` |

**Section 3 – Radio**

| Field      | Type    | Value |
|-----------|---------|--------|
| `type`    | string  | `radio` |
| `question`| string  | `Have you ever used google maps?` |
| `options` | array   | `["Yes", "No"]` |
| `required`| boolean | `true` |

**Section 4 – Date**

| Field      | Type    | Value |
|-----------|---------|--------|
| `type`    | string  | `date` |
| `label`   | string  | `Date of birth` |
| `required`| boolean | `true` |

### Example JSON (for reference)

If your tool supports importing JSON into Firestore, the document could look like this (structure only; Firestore typically uses maps/arrays in the UI):

```json
{
  "title": "Skills",
  "subtitle": "Tell us a bit more about yourself",
  "sections": [
    {
      "type": "checkbox",
      "question": "How many of these tasks have you done before? (select all that apply)",
      "options": ["Cutting vegetables", "Sweeping", "Mopping", "Cleaning bathrooms", "Laundry", "Washing dishes"],
      "hasNoneOfTheAbove": true,
      "required": false
    },
    {
      "type": "radio",
      "question": "Do you have your own smartphone?",
      "options": ["Yes", "No"],
      "required": true
    },
    {
      "type": "radio",
      "question": "Have you ever used google maps?",
      "options": ["Yes", "No"],
      "required": true
    },
    {
      "type": "date",
      "label": "Date of birth",
      "required": true
    }
  ]
}
```

## 6. Run the app

1. Build and run the iOS app in Xcode.
2. Log in so you reach the questionnaire screen.
3. The app will fetch the document from `questionnaires/skills`. You should see the title, subtitle, and sections you defined; if Firestore is empty or the document is missing, you’ll see a loading or error state (and the Retry button if we surface the error).

## Changing the screen ID

The app currently loads the document with ID **skills**. To load a different screen:

1. In Firestore, create another document under the `questionnaires` collection (e.g. `profile`, `preferences`).
2. In code, change the constant in `QuestionnaireView.swift`:

   ```swift
   private let defaultScreenId = "skills"  // change to your document ID
   ```

## Security (before production)

- In **Firestore → Rules**, replace test mode with rules that allow read (and write, if needed) only for authenticated users or your app.
- Do not commit `GoogleService-Info.plist` with real keys to a public repo if it contains sensitive data; use environment-specific config or secrets management if required.
